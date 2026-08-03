# Backend — Name That Tree (Phase 2)

Makes the crowd real: trees + votes shared across devices, consensus computed server-side.

## Stack
**Supabase** (Postgres + Auth + Realtime + Storage). Generous free tier, no server to run.

## Setup

1. Create a project at https://supabase.com (free tier).
2. In the SQL editor, run `schema.sql` (safe to re-run).
3. Enable **Anonymous sign-ins**: Auth → Providers → Anonymous → on.
   (Low-friction device accounts; everyone starts SPROUT ×1.)
4. Grab your project **URL** and **anon public key** (Settings → API).
5. Configure the client (see below). **Never commit keys** — they go in
   `config.js` which is gitignored, or via build-time env in Phase 2b.

## Client config

The game reads an optional global `window.NTT_CONFIG`. With no config it runs in
**local mode** (localStorage + simulated crowd) exactly as before — the backend is
strictly opt-in so `main` is never broken.

```html
<!-- drop this before the closing </body>, or serve config.js (gitignored) -->
<script>
  window.NTT_CONFIG = {
    supabaseUrl: 'https://YOUR-PROJECT.supabase.co',
    supabaseAnonKey: 'YOUR-ANON-KEY',
  };
</script>
```

The anon key is safe to expose in a browser **only because RLS + the `cast_vote`
RPC enforce all the rules server-side** (weights recomputed from rep, writes gated).

## Schema summary
- `profiles(id, handle, rep, created_at)` — one per player
- `trees(id, lat, lng, photo_url, created_by, created_at)`
- `votes(tree_id, user_id, label, label_key, weight)` — one per player per tree
- `tree_consensus` view — leading label, total weight, share, resolved bool
- `cast_vote(tree, label)` RPC — server-authoritative weighted vote
- `rep_weight(rep)` — trust ladder → vote weight

## Anti-cheat posture
- Clients never set vote weight; `cast_vote` recomputes it from the voter's rep.
- Writes to `votes` only via the security-definer RPC (no direct insert policy).
- Reputation payouts + resolution move server-side in Phase 2b (RPC/edge function)
  so they can't be forged from the client.
