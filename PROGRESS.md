# PROGRESS — Name That Tree

Running log of what shipped and what's next. Newest at top.

## 2026-08-03 — Session 1 (Cygent)

**Starting state:** v0.2 prototype, single `index.html` (~1389 lines), no build step, simulated crowd, localStorage only.

### Shipping Phase 1 — PWA foundations
- [ ] `manifest.webmanifest` + icons
- [ ] Service worker (offline app shell)
- [ ] Wire both into `index.html`
- [ ] Real GPS `watchPosition` + proximity rule (~30m)
- [ ] Live camera viewfinder via `getUserMedia`
- [ ] Mobile polish (safe-area, no rubber-band, haptics)
- [ ] HTTPS deploy

### Next
- Phase 2: Vite refactor + Supabase backend (make the crowd real)
