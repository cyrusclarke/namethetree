# DECISIONS — Name That Tree

Notable architectural choices, one line of rationale each. Newest at top.

## 2026-08-03 (verification)
- **No browser on the build host** (managed Chromium sandbox won't launch; no user Chrome). Verification stack instead: (1) `node --check` on JS extracted from index.html, (2) **jsdom** full-page load — runs the whole inline script, asserts key elements exist + zero runtime errors on init, (3) real Postgres (Docker) for schema + consensus logic, (4) curl against live Pages. Real render + iPhone feel still need Cyrus.
- **jsdom load check passed clean**: all screens/buttons/video/PWA links present, no runtime errors during boot with Phase 1 + Phase 2 changes.

## 2026-08-04 (server-side reputation + resolution)
- **Resolution is permanent and race-safe.** Once `resolved_at` is set on a tree, it stays. The `IF FOUND` guard in `cast_vote` ensures only one concurrent transaction triggers payouts; a second concurrent resolver gets a clean verdict without double-paying.
- **`cast_vote` returns jsonb instead of void.** Breaking change to the function signature (requires DROP + CREATE, not just REPLACE). Returns `{verdict, repDelta, rep, resolved, resolvedLabel}` so the client can treat the server as the single source of truth for reputation. The client ignores return data if it doesn't understand it, so backward-compatible in practice.
- **Server-authoritative rep; client-authoritative score.** Rep (trust weight) is computed and stored server-side in `profiles.rep`. Score (points) stays purely local/cosmetic. This means rep is consistent across devices; score is per-device flavour.
- **`_localVerdict` helper preserves offline play.** All local-mode logic is extracted into a helper that runs identically to pre-backend behaviour. Backend mode tries the server first, falls back to `_localVerdict` on network failure. Zero regression for offline/PWA play.
- **Pending vote settlement via realtime.** When `syncFromBackend` runs (triggered by realtime `onChange`), it checks if any pending votes' trees are now resolved. If so, it awards local pts + shows a toast. Rep was already adjusted server-side by the resolver's `cast_vote`, so the client just syncs `state.rep` from the server.

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
