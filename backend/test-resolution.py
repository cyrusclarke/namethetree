"""End-to-end tests for backend/002-resolution.sql (server-side rep payouts).

Note on Supabase rate limits: anon signups are aggressively throttled on the
free tier. This test creates 20 accounts across three cases; running it more
than once in a short window will hit HTTP 429. Wait ~10 min between runs, or
run individual cases by commenting the others out.


Reads Supabase URL + anon key from config.js so no secrets are hardcoded.

Cases:
    (A) six voters agree on winning label      -> all +8
    (B) planter votes wrong, others carry it   -> planter -7 (=-2 loser -5 rename),
                                                  winners +8, other losers -2
    (C) simple dissenter                       -> dissenter -2, winners +8

Usage:  python3 backend/test-resolution.py
"""
import json, re, sys, time, urllib.request, urllib.error
from pathlib import Path

# ---------- config ----------
CFG = Path(__file__).parent.parent / 'config.js'
if not CFG.exists():
    sys.exit("config.js not found; expected at " + str(CFG))
cfg = CFG.read_text()
URL = re.search(r"supabaseUrl:\s*['\"]([^'\"]+)['\"]", cfg).group(1)
KEY = re.search(r"supabaseAnonKey:\s*['\"]([^'\"]+)['\"]", cfg).group(1)

def req(method, path, headers, data=None):
    r = urllib.request.Request(URL + path, data=data, method=method)
    for k, v in headers.items(): r.add_header(k, v)
    try:
        resp = urllib.request.urlopen(r)
        return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()

def signup(_retries=6):
    # anon signup is aggressively rate-limited on the free tier;
    # back off on 429 rather than aborting the whole suite
    for attempt in range(_retries):
        st, body = req('POST', '/auth/v1/signup',
                       {'apikey': KEY, 'Content-Type': 'application/json'}, b'{}')
        if st < 300:
            d = json.loads(body)
            return d['user']['id'], d['access_token']
        if st == 429:
            wait = 2 ** attempt  # 1, 2, 4, 8, 16, 32
            print(f"    (429 rate-limited, backing off {wait}s)")
            time.sleep(wait)
            continue
        sys.exit(f"signup failed HTTP {st}: {body[:200]!r}")
    sys.exit("signup exhausted retries against rate limiter")

def rest(method, path, tok, body=None, prefer=None):
    h = {'apikey': KEY, 'Authorization': 'Bearer ' + tok,
         'Content-Type': 'application/json'}
    if prefer: h['Prefer'] = prefer
    return req(method, path, h,
               json.dumps(body).encode() if body is not None else None)

def get_rep(uid, tok):
    st, body = rest('GET', f'/rest/v1/profiles?id=eq.{uid}&select=rep', tok)
    return json.loads(body)[0]['rep']

def ensure_profile(uid, tok, seed_rep=0):
    rest('POST', '/rest/v1/profiles', tok, {'id': uid},
         prefer='resolution=ignore-duplicates')
    if seed_rep:
        # bump rep so we can observe negative deltas (base rep of 0 would clamp them to 0)
        rest('PATCH', f'/rest/v1/profiles?id=eq.{uid}', tok, {'rep': seed_rep})

def plant(planter_uid, planter_tok, lat=51.5, lng=-0.1):
    st, body = rest('POST', '/rest/v1/trees', planter_tok,
                    {'lat': lat, 'lng': lng, 'created_by': planter_uid},
                    prefer='return=representation')
    if st >= 300: sys.exit(f"plant failed {st}: {body[:200]!r}")
    return json.loads(body)[0]['id']

def cast(tree_id, tok, label):
    st, body = rest('POST', '/rest/v1/rpc/cast_vote', tok,
                    {'p_tree': tree_id, 'p_label': label})
    return st, (json.loads(body) if body else {})

def cleanup(tree_id, tok):
    rest('DELETE', f'/rest/v1/trees?id=eq.{tree_id}', tok)

# ---------- test runner ----------
def run_case(name, users, planter_ix, labels, expected_deltas, seed_reps=None):
    """users: list of (uid, tok). planter_ix: index of the planter within users.
       labels: label each user votes. expected_deltas: rep change per user, in order.
       seed_reps: optional list of starting rep per user (default 0 for all)."""
    print(f"\n=== {name} ===")
    seeds = seed_reps or [0]*len(users)
    for (uid, tok), seed in zip(users, seeds):
        ensure_profile(uid, tok, seed_rep=seed)
    planter_uid, planter_tok = users[planter_ix]
    tree_id = plant(planter_uid, planter_tok)

    before = [get_rep(u, t) for u, t in users]
    for (uid, tok), label in zip(users, labels):
        st, r = cast(tree_id, tok, label)
        if st >= 300: sys.exit(f"cast failed {st}: {r!r}")
    after = [get_rep(u, t) for u, t in users]
    deltas = [a - b for a, b in zip(after, before)]

    print(f"  labels:   {labels}")
    print(f"  before:   {before}")
    print(f"  after:    {after}")
    print(f"  deltas:   {deltas}")
    print(f"  expected: {expected_deltas}")
    ok = deltas == expected_deltas
    print(f"  {'PASS' if ok else 'FAIL'}")
    cleanup(tree_id, planter_tok)
    return ok

# ---------- signup a fresh pool of users per case (avoid rep bleed between tests) ----------
def fresh_users(n):
    users = []
    for _ in range(n):
        users.append(signup())
        time.sleep(0.4)  # be nice to the auth rate limiter
    return users

all_pass = True

# CASE A: 6 voters all agree on "Oak"
# expected: everyone +8 (all winners), no rename penalty because winning label matches planter's vote
all_pass &= run_case(
    "A: unanimous winners (+8 each)",
    fresh_users(6), planter_ix=0,
    labels=['Oak']*6,
    expected_deltas=[8]*6,
)

# CASE B: planter votes "Steve", 6 others vote "Oak" so Oak reaches weight 6 and 6/7 share = 86%.
#   -> Oak wins. Planter voted losing label AND owns the tree -> -2 (loser) + -5 (rename) = -7 from planter's base rep.
#   -> Planter seeded with rep=10 so -7 is observable (0-clamp would mask it otherwise).
#   -> Other 6 voters (Oak) -> +8 each.
all_pass &= run_case(
    "B: planter is wrong (rename penalty -7)",
    fresh_users(7), planter_ix=0,
    labels=['Steve'] + ['Oak']*6,
    expected_deltas=[-7] + [8]*6,
    seed_reps=[10] + [0]*6,   # planter starts at 10 so we can see -7
)

# CASE C: 6 Elm voters (planter + 5 others) + 1 Steve dissenter = 7 users total.
#   -> Elm reaches weight 6 on the 6th Elm vote (share 6/7 = 86%) -> resolves.
#   -> To catch Steve in the loser-payout query, they must vote BEFORE the resolving vote.
#   -> Order: Elm x5, Steve, Elm (resolving). At resolution: 6 Elm + 1 Steve in votes table.
#   -> Steve seeded at rep=5 so we can observe -2 (base rep 0 would clamp to 0).
all_pass &= run_case(
    "C: one dissenter (-2), 6 winners (+8 each)",
    fresh_users(7), planter_ix=0,
    labels=['Elm']*5 + ['Steve'] + ['Elm'],
    # deltas indexed to users: planter(Elm)+8, Elm+8, Elm+8, Elm+8, Elm+8, Steve-2, Elm+8
    expected_deltas=[8, 8, 8, 8, 8, -2, 8],
    seed_reps=[0]*5 + [5] + [0],  # dissenter starts at 5 so we can see -2
)

print("\n" + ("ALL PASS" if all_pass else "FAILURES"))
sys.exit(0 if all_pass else 1)
