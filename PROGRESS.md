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

### Next — Phase 2
- Vite refactor (ES modules) keeping the loop runnable throughout
- Supabase backend: profiles / trees / votes + consensus view
- Replace simulateCrowd() with real votes + Realtime
- Anonymous device auth first
