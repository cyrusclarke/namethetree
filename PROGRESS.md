# PROGRESS — Name That Tree

Running log of what shipped and what's next. Newest at top.

## 2026-08-03 — Session 1 (Cygent)

**Starting state:** v0.2 prototype, single `index.html` (~1389 lines), no build step, simulated crowd, localStorage only.

### Phase 1 — PWA foundations ✅ (shipped)
- [x] `manifest.webmanifest` + pixel-art icons (192/512/maskable/apple-touch)
- [x] Service worker (cache-first shell, network-first tiles/APIs) + registration
- [x] Wired into `index.html` (manifest, theme-color, apple-touch-icon)
- [x] Real GPS `watchPosition` + 30m proximity rule + nearest-tree banner
- [x] Live camera viewfinder via `getUserMedia` (upload fallback)
- [x] Mobile polish (safe-area insets, no rubber-band, haptics)
- [x] HTTPS deploy — **live: https://cyrusclarke.github.io/namethetree/**

**Phase 1 done criteria:** installable PWA over HTTPS, full loop playable. ✅
Outstanding: real-iPhone spot-check by Cyrus (Add to Home Screen + outdoor play).

### Phase 2 — real backend (in progress)
- [x] Supabase schema (`backend/schema.sql`): profiles / trees / votes, `tree_consensus` view, `cast_vote` RPC, `rep_weight`, RLS, realtime
- [x] `net.js` data layer: anon auth, fetch trees/votes/consensus, plant, castVote, realtime onChange
- [x] Wired into index.html behind `BACKEND.on` flag — opt-in via `window.NTT_CONFIG`, local mode unchanged
- [x] Vote + plant write-through to server in backend mode; simulateCrowd disabled when live
- [ ] **Needs Cyrus:** create Supabase project, run schema, enable anon auth, hand me URL + anon key
- [ ] Photo storage (Supabase Storage) so planted trees show real user snaps
- [ ] Server-side reputation payouts + resolution (edge function / RPC)
- [ ] Vite refactor (ES modules) once backend is proven, keeping loop runnable

### Notes
- Browser sandbox won't launch on this host; verifying via node --check on extracted JS + curl against live Pages. Real-render + iPhone checks need Cyrus.
