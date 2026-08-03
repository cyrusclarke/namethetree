# DECISIONS — Name That Tree

Notable architectural choices, one line of rationale each. Newest at top.

## 2026-08-03 (Phase 2 start)
- **Backend before Vite refactor.** The high-value + verifiable work (making the crowd real) goes first; the risky visual refactor waits. Backend logic is testable via Node/API without a browser (the sandboxed browser won't launch here).
- **Supabase** for backend (Postgres + anon Auth + Realtime). Free tier, no server to run.
- **Opt-in via `window.NTT_CONFIG`.** No config → game runs in local mode exactly as before, so `main` is never broken. Backend is a strict superset behind `BACKEND.on`.
- **Server-authoritative voting.** `cast_vote` RPC recomputes weight from rep; no direct insert policy on `votes`. Anon key is safe to ship because RLS + RPC enforce the rules.
- **`net.js` as the data seam.** All backend calls live in one module with a clean async API; the monolith folds server trees/votes into its existing local tree shape, so the UI is unchanged.
- **Schema validated against real Postgres (Docker) before handing to Cyrus.** Applied `schema.sql` clean; functionally tested consensus: SPROUT "Steve" (w1) loses to expert "Oak" (w8) → resolved 8/9=89%; change-your-mind upserts in place; empty labels rejected. Weights recomputed server-side from rep, exactly matching client rules (≥6 weight, ≥60% share).

## 2026-08-03 (Phase 1)
- **Keep single-file `index.html` through Phase 1.** PWA (manifest + SW) doesn't require a build step; refactor to Vite waits for Phase 2 so we don't break the loop early.
- **Service worker: cache-first for app shell, network-first for map tiles.** Tiles are large + change; shell is small + stable. Offline degrades gracefully (cached shell, tiles blank).
- **Icons generated as PNG from the existing pixel aesthetic** rather than pulling external art — keeps identity, no new deps.
