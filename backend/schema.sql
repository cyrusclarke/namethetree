-- Name That Tree — Supabase / Postgres schema
-- Phase 2: make the crowd real. Trees + votes are shared; consensus is computed
-- server-side so weighting, resolution, and reputation can't be cheated.
--
-- Apply in the Supabase SQL editor (or `supabase db push`). Safe to re-run.

-- ---------- extensions ----------
create extension if not exists "pgcrypto";      -- gen_random_uuid()

-- ---------- profiles ----------
-- One row per player. Anonymous device accounts first (Supabase anon auth),
-- upgradeable later. Everyone starts SPROUT; rep drives vote weight.
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  handle      text unique,
  rep         integer not null default 0,
  created_at  timestamptz not null default now()
);

-- trust ladder → vote weight (mirrors the client LEVELS table; server is source of truth)
create or replace function rep_weight(rep integer) returns numeric
language sql immutable as $$
  select case
    when rep >= 600 then 5      -- TREE ELDER
    when rep >= 280 then 3      -- ARBORIST
    when rep >= 120 then 2      -- RANGER
    when rep >= 40  then 1.5    -- SCOUT
    else 1                      -- SPROUT
  end;
$$;

-- ---------- trees ----------
create table if not exists trees (
  id          uuid primary key default gen_random_uuid(),
  lat         double precision not null,
  lng         double precision not null,
  photo_url   text,
  created_by  uuid references profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists trees_geo_idx on trees (lat, lng);

-- ---------- votes ----------
-- One weighted vote per player per tree (upsert to change your mind).
-- weight is snapshotted from the voter's rep at cast time, recomputed server-side.
create table if not exists votes (
  id          uuid primary key default gen_random_uuid(),
  tree_id     uuid not null references trees(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  label       text not null,
  label_key   text not null,             -- normalised (lowercased, trimmed) for tallying
  weight      numeric not null default 1,
  created_at  timestamptz not null default now(),
  unique (tree_id, user_id)
);
create index if not exists votes_tree_idx on votes (tree_id);

-- ---------- consensus view ----------
-- Leading label per tree with total weight + share; resolved at >=6 weight and >=60% share.
create or replace view tree_consensus as
with tallies as (
  select
    tree_id,
    label_key,
    max(label) as display,          -- any canonical display for this key
    sum(weight) as label_weight
  from votes
  group by tree_id, label_key
),
ranked as (
  select
    t.*,
    sum(label_weight) over (partition by tree_id) as total_weight,
    row_number() over (partition by tree_id order by label_weight desc) as rn
  from tallies t
)
select
  tree_id,
  label_key,
  display                                    as leading_label,
  label_weight,
  total_weight,
  case when total_weight > 0 then label_weight / total_weight else 0 end as share,
  (label_weight >= 6 and label_weight / nullif(total_weight,0) >= 0.6)   as resolved
from ranked
where rn = 1;

-- ---------- cast_vote RPC ----------
-- Server-authoritative vote: recomputes the caller's weight from their rep,
-- normalises the label, and upserts. Clients never set weight directly.
create or replace function cast_vote(p_tree uuid, p_label text)
returns void language plpgsql security definer as $$
declare
  v_uid uuid := auth.uid();
  v_key text;
  v_weight numeric;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  v_key := regexp_replace(lower(trim(p_label)), '[^a-z0-9× ]', '', 'g');
  v_key := regexp_replace(v_key, '\s+', ' ', 'g');
  if v_key = '' then raise exception 'empty label'; end if;
  select rep_weight(rep) into v_weight from profiles where id = v_uid;
  if v_weight is null then v_weight := 1; end if;

  insert into votes (tree_id, user_id, label, label_key, weight)
  values (p_tree, v_uid, trim(p_label), v_key, v_weight)
  on conflict (tree_id, user_id)
  do update set label = excluded.label, label_key = excluded.label_key,
                weight = excluded.weight, created_at = now();
end;
$$;

-- ---------- row level security ----------
alter table profiles enable row level security;
alter table trees    enable row level security;
alter table votes    enable row level security;

-- profiles: readable by all; you can only write your own row
drop policy if exists profiles_read on profiles;
create policy profiles_read on profiles for select using (true);
drop policy if exists profiles_upsert on profiles;
create policy profiles_upsert on profiles for insert with check (auth.uid() = id);
drop policy if exists profiles_update on profiles;
create policy profiles_update on profiles for update using (auth.uid() = id);

-- trees: readable by all; any authenticated player can plant
drop policy if exists trees_read on trees;
create policy trees_read on trees for select using (true);
drop policy if exists trees_insert on trees;
create policy trees_insert on trees for insert with check (auth.uid() = created_by);

-- votes: readable by all; writes go through cast_vote() RPC only
drop policy if exists votes_read on votes;
create policy votes_read on votes for select using (true);
-- (no direct insert/update policy: cast_vote is security definer)

-- ---------- realtime ----------
-- Enable realtime on trees + votes so the map updates live across devices.
alter publication supabase_realtime add table trees;
alter publication supabase_realtime add table votes;
