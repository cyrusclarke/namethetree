# 🌳 Name That Tree

**Don't touch grass — name that tree!**

A Pokémon-Go-style mobile-web game for learning to identify trees. Go out into the world, photograph trees, and help a crowd converge on their true names. Old-school NES/Game Boy pixel aesthetic throughout.

Single self-contained `index.html` — no build step, no dependencies to install. Open it in a browser and play.

## How it works

- **Explore** a live world map (Leaflet + OpenStreetMap) seeded with geolocated trees near you.
- **Name it.** Tap a tree, get **60 seconds**, and type *any* name — a real species or "Steve". Quick-pick chips are just suggestions.
- **The crowd is the judge, Wikipedia-style.** Every guess is a secret, *weighted* vote. A name is **CONFIRMED** once it holds 60%+ of the vote weight. Silly names can lead early, but as trusted players pile onto the real species the name flips and the tree is publicly renamed.
- **Earn trust (REP).** Everyone starts a **SPROUT (×1)**. Reputation only moves when time proves you right: call an unconfirmed tree correctly and the crowd later agrees → **+8 REP**. Climb SCOUT ×1.5 → RANGER ×2 → ARBORIST ×3 → **TREE ELDER ×5** — higher trust casts heavier votes, so accurate experts can overturn a wrong-but-popular crowd.
- **Snap your own.** Photograph a real tree, name it, and plant it on the map for others.
- **Treedex.** A growing, open registry. The 16 seed species are a "Field Guide" of common quick-picks; crowd-confirmed names that match no catalogued species become **candidates** — a nod to the 60,000+ known tree species (with ~9,000 still undiscovered).

## Play locally

Any static file server works. For example:

```bash
python3 -m http.server 4173
```

Then open `http://localhost:4173`.

> **Note:** camera capture and GPS require HTTPS. For real phone testing, host it (Netlify / Vercel / GitHub Pages) and open the URL in Safari, then "Add to Home Screen".

## Status

**Phase 2 live.** Installable PWA over HTTPS, real Supabase backend (shared trees, votes, consensus, realtime, photo storage), server-authoritative reputation with resolution payouts. Live at [cyrusclarke.github.io/namethetree](https://cyrusclarke.github.io/namethetree/).

See `PROGRESS.md` for the running log, `DECISIONS.md` for architectural choices.

## How work is tracked

All open engineering work lives in [GitHub Issues on this repo](https://github.com/cyrusclarke/namethetree/issues). Labels used:

- `hygiene`, `content`, `feature` — the kind of work
- `backend`, `frontend` — where in the stack it lives
- `needs-decision`, `blocked` — waiting on something
- `size:S` / `size:M` / `size:L` — rough effort

### Change types

- **Trivial** (typo, comment) → direct push to `main`, no issue
- **Contained** (hygiene, small content) → issue for the record, commit with `closes #N` to `main`
- **Behavioural** (game logic, schema, user-visible flows) → issue + branch + PR against `main` before merge
- **Product decisions** → issue only; discussed in comments; implementation follows in a PR

## Tech

Vanilla HTML/CSS/JS · Leaflet · Press Start 2P · procedurally-generated pixel tree sprites (canvas) · WebAudio chiptune · real species photos from the iNaturalist / Wikipedia APIs.
