-- Name That Tree — Migration 002: Server-side resolution + reputation payouts
-- Run in Supabase SQL Editor after schema.sql. Safe to re-run.
--
-- What this does:
--   1. Adds resolved_at / resolved_label to trees (permanent lock once crowd consensus holds)
--   2. Replaces cast_vote to detect resolution and pay out rep to all voters
--   3. Returns { verdict, repDelta, rep, resolved, resolvedLabel } so the client can trust
--      the server as the single source of truth for reputation
--
-- Rep payouts (match client rules):
--   Vote on already-resolved tree:  correct +3, wrong -3
--   Pending vote settled at resolution:  correct +8, wrong -2
--   Planter whose tree is renamed at resolution:  additional -5

-- ---------- schema additions ----------
ALTER TABLE trees ADD COLUMN IF NOT EXISTS resolved_at    timestamptz;
ALTER TABLE trees ADD COLUMN IF NOT EXISTS resolved_label text;

-- ---------- enhanced cast_vote ----------
-- Must DROP first because the return type changes from void → jsonb.
DROP FUNCTION IF EXISTS cast_vote(uuid, text);

CREATE FUNCTION cast_vote(p_tree uuid, p_label text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid             uuid := auth.uid();
  v_key             text;
  v_weight          numeric;
  v_was_resolved    boolean;
  v_resolved_label  text;
  v_rep_delta       integer := 0;
  v_verdict         text := 'pending';
  v_leading_key     text;
  v_leading_weight  numeric;
  v_total_weight    numeric;
  v_share           numeric;
  v_had_prior_vote  boolean;
  v_new_rep         integer;
  v_planter_id      uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  -- normalise label (same rules as client labelKey())
  v_key := regexp_replace(lower(trim(p_label)), '[^a-z0-9× ]', '', 'g');
  v_key := regexp_replace(v_key, '\s+', ' ', 'g');
  IF v_key = '' THEN RAISE EXCEPTION 'empty label'; END IF;

  -- voter's weight from their current rep
  SELECT rep_weight(rep) INTO v_weight FROM profiles WHERE id = v_uid;
  IF v_weight IS NULL THEN v_weight := 1; END IF;

  -- did this user already vote on this tree?
  v_had_prior_vote := EXISTS (
    SELECT 1 FROM votes WHERE tree_id = p_tree AND user_id = v_uid
  );

  -- current resolution state of the tree
  SELECT (resolved_at IS NOT NULL), resolved_label, created_by
    INTO v_was_resolved, v_resolved_label, v_planter_id
    FROM trees WHERE id = p_tree;

  -- upsert the vote (same as original cast_vote)
  INSERT INTO votes (tree_id, user_id, label, label_key, weight)
  VALUES (p_tree, v_uid, trim(p_label), v_key, v_weight)
  ON CONFLICT (tree_id, user_id)
  DO UPDATE SET label     = excluded.label,
                label_key = excluded.label_key,
                weight    = excluded.weight,
                created_at = now();

  IF v_was_resolved THEN
    -------------------------------------------------------------------
    -- CASE A: tree already resolved — immediate rep feedback
    -------------------------------------------------------------------
    IF NOT v_had_prior_vote THEN
      IF v_key = v_resolved_label THEN
        v_rep_delta := 3;  v_verdict := 'good';
      ELSE
        v_rep_delta := -3; v_verdict := 'bad';
      END IF;
      UPDATE profiles SET rep = GREATEST(0, rep + v_rep_delta) WHERE id = v_uid;
    ELSE
      v_verdict := 'changed';   -- re-vote on resolved tree, no rep change
    END IF;

  ELSE
    -------------------------------------------------------------------
    -- CASE B: tree not yet resolved — check if this vote tipped it
    -------------------------------------------------------------------
    SELECT tc.label_key,
           tc.label_weight,
           tc.total_weight,
           CASE WHEN tc.total_weight > 0
                THEN tc.label_weight / tc.total_weight ELSE 0 END
      INTO v_leading_key, v_leading_weight, v_total_weight, v_share
      FROM tree_consensus tc
     WHERE tc.tree_id = p_tree;

    IF v_leading_key IS NOT NULL
       AND v_leading_weight >= 6
       AND v_share >= 0.6 THEN
      -----------------------------------------------------------------
      -- RESOLUTION! Lock the tree (only one concurrent transaction wins).
      -----------------------------------------------------------------
      UPDATE trees
         SET resolved_at    = now(),
             resolved_label = v_leading_key
       WHERE id = p_tree
         AND resolved_at IS NULL;

      IF FOUND THEN
        -- this transaction won the resolution race: pay out all voters

        -- winners: +8 rep (your pending vote was correct)
        UPDATE profiles SET rep = rep + 8
         WHERE id IN (
           SELECT user_id FROM votes
            WHERE tree_id = p_tree AND label_key = v_leading_key
         );

        -- losers: -2 rep (your pending vote was wrong)
        UPDATE profiles SET rep = GREATEST(0, rep - 2)
         WHERE id IN (
           SELECT user_id FROM votes
            WHERE tree_id = p_tree AND label_key != v_leading_key
         );

        -- planter rename penalty: additional -5 if the planter voted on their
        -- own tree but their vote doesn't match the resolution
        IF v_planter_id IS NOT NULL THEN
          UPDATE profiles SET rep = GREATEST(0, rep - 5)
           WHERE id = v_planter_id
             AND id IN (
               SELECT user_id FROM votes
                WHERE tree_id = p_tree AND label_key != v_leading_key
             );
        END IF;

        v_verdict := 'resolved';
        IF v_key = v_leading_key THEN
          v_rep_delta := 8;
        ELSE
          v_rep_delta := -2;
        END IF;

      ELSE
        -- another transaction already resolved this tree;
        -- this voter's rep was paid out by the winner
        SELECT t.resolved_label INTO v_resolved_label
          FROM trees t WHERE t.id = p_tree;
        v_verdict := CASE WHEN v_key = v_resolved_label THEN 'good' ELSE 'bad' END;
        v_rep_delta := 0;
      END IF;

    ELSE
      v_verdict := 'pending';
    END IF;
  END IF;

  -- return the voter's current rep so the client can sync
  SELECT rep INTO v_new_rep FROM profiles WHERE id = v_uid;

  RETURN jsonb_build_object(
    'verdict',       v_verdict,
    'repDelta',      v_rep_delta,
    'rep',           COALESCE(v_new_rep, 0),
    'resolved',      v_was_resolved OR v_verdict = 'resolved',
    'resolvedLabel', CASE
                       WHEN v_verdict = 'resolved' THEN v_leading_key
                       WHEN v_was_resolved         THEN v_resolved_label
                       ELSE NULL
                     END
  );
END;
$$;
