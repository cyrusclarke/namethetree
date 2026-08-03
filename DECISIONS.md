# DECISIONS — Name That Tree

Notable architectural choices, one line of rationale each. Newest at top.

## 2026-08-03
- **Keep single-file `index.html` through Phase 1.** PWA (manifest + SW) doesn't require a build step; refactor to Vite waits for Phase 2 so we don't break the loop early.
- **Service worker: cache-first for app shell, network-first for map tiles.** Tiles are large + change; shell is small + stable. Offline degrades gracefully (cached shell, tiles blank).
- **Icons generated as PNG from the existing pixel aesthetic** rather than pulling external art — keeps identity, no new deps.
