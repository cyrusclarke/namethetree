# AGENTS.md — Build instructions for autonomous agents

> If your framework reads a different filename (`CLAUDE.md`, `.cursorrules`, etc.), copy or symlink this file to it. This is the single source of truth for how to build **Name That Tree**.

---

## 🌳 Mission

Turn Name That Tree from a single-file web prototype into a **polished, multiplayer, installable game that runs great on an iPhone**. Keep it genuinely fun, keep the NES / Game Boy pixel aesthetic, and make the wisdom-of-the-crowd tree-naming *real* (right now the "crowd" is faked locally).

**North star:** a game people play outdoors on their phone that makes them better at recognising trees — and crowd-sources a living, geolocated map of the world's trees. Science knows 60,000+ tree species with ~9,000 still undiscovered; this game should help chip at that.

Read `README.md` for the player-facing pitch and the current game design.

---

## ⚙️ How to operate (read this first)

- **Move fast, ship constantly.** There is a large API budget — *burn it*. Favour many small, shipped, working increments over big planned ones. Iterate in tight loops: build → run → verify → commit → repeat.
- **Be autonomous.** Make reasonable decisions and proceed. Don't stop to ask permission for routine choices (library picks, file layout, art, refactors). Only surface a decision if it's expensive to reverse *and* genuinely ambiguous.
- **Always playable.** The game **must run at every commit**. Never leave `main` broken. If a change is big, land it behind a flag or across small commits that each keep the game working.
- **Verify before you commit.** Actually run it, click through the core loop (map → tap tree → name it → result), and confirm the browser console is clean. Take a screenshot when you can. "It compiles" is not "it works."
- **Commit often, clearly.** Small commits, present-tense messages describing what + why. Push to `main`. (This repo has no CI gate; you are the gate.)
- **Parallelise when it helps.** Spin up sub-agents for independent tracks — pixel art, backend, playtesting, species data — and integrate.
- **Log decisions.** Append notable choices (backend picked, native wrapper picked, schema changes) to `DECISIONS.md` with a one-line rationale so the next session has context.
- **Keep a running log.** Append progress to `PROGRESS.md` (what shipped, what's next) at the end of each work session.

---

## 🧩 Current state — v0.2 (single `index.html`, ~1600 lines, no build step)

Everything is one self-contained file: HTML + CSS + vanilla JS, no dependencies to install. Leaflet + Press Start 2P font load from CDNs. Run it with any static server:

```bash
python3 -m http.server 4173   # then open http://localhost:4173
```

**What works today:**
- Treedex-device intro screen with a boot sequence + looping 8-bit WebAudio theme.
- Live world map (Leaflet / OpenStreetMap, pixel-filtered) seeded with geolocated demo trees near the player (falls back to Hyde Park if GPS denied).
- Core loop: tap a tree → 60s timer → **type any name** (free text) or pick a quick-pick species chip → weighted vote is cast → result screen shows the weighted tally.
- Wisdom-of-the-crowd consensus: votes are weighted by the voter's trust level; a name is CONFIRMED at ≥6 total weight and ≥60% share; leaders can flip and trees get publicly "renamed" (Wikipedia-style).
- Reputation ladder: SPROUT ×1 → SCOUT ×1.5 → RANGER ×2 → ARBORIST ×3 → TREE ELDER ×5. Rep is earned only when time proves a call right; penalties for overturned calls.
- Snap-your-own: capture a photo (crunched to retro pixels), name it, plant it on the map.
- Treedex: 16-species "field guide" + a growing "discovered by the crowd" section for confirmed names that match no known species.
- Procedurally-generated pixel tree sprites (canvas), real species photos from the iNaturalist / Wikipedia APIs, chiptune SFX.

## 🩹 Known fakes / simplifications to make real

These are the honest gaps — turning them real is most of the roadmap:
1. **The crowd is simulated** (`simulateCrowd()` invents weighted votes on a timer). Needs real players via a backend.
2. **State is `localStorage` only** — nothing is shared between devices. No accounts.
3. **Only 16 seed species.** The naming is open-ended (free text), but the "field guide" and sprites cover 16. Should scale toward a real taxonomic backend (GBIF / iNaturalist) so any species can be recognised/validated.
4. **Photos of demo trees are stock species shots**, not real user captures. Once there's a backend, every tree shows a player's own snap.
5. **No anti-abuse** beyond vote weighting. Needs rate limits, dedup, report/flag, sanity checks on new candidate names.

---

## 🗺️ Roadmap (build in this order; each phase must ship playable)

### Phase 1 — Make it a great installable iPhone web app (PWA)
Goal: it feels like a real app on an iPhone home screen, played in the field.
- [ ] Add a `manifest.webmanifest` + service worker so it's installable and works offline (cache the shell, tiles gracefully degrade).
- [ ] Live camera viewfinder via `getUserMedia` (keep `<input capture>` as fallback) so snapping feels native. Requires HTTPS.
- [ ] Real GPS: continuous `watchPosition`, "you are here" marker, and a **proximity rule** — you must be within ~30m of a tree to name/plant it (core to the outdoors concept).
- [ ] Mobile polish: safe-area insets (notch), no rubber-band scroll, big tap targets, haptics where available, portrait lock.
- [ ] Deploy to HTTPS (GitHub Pages if public, else Netlify/Vercel/Cloudflare Pages). Verify install + play on iOS Safari.
- **Done when:** you can "Add to Home Screen" on an iPhone and play the full loop outdoors over HTTPS.

### Phase 2 — Refactor + real backend (make the crowd real)
Goal: trees and votes are shared; the wisdom-of-crowd actually works across players.
- [ ] Refactor the monolith into a proper project (Vite + ES modules) **without losing the aesthetic or breaking the loop**. Keep a always-runnable dev build.
- [ ] Backend: **recommend Supabase** (Postgres + Auth + Storage + Realtime, generous free tier). Sketch schema:
  - `profiles(id, handle, rep int, created_at)`
  - `trees(id, lat, lng, photo_url, created_by, created_at)`
  - `votes(id, tree_id, user_id, label text, weight numeric, created_at)`
  - consensus as a SQL view / RPC (leading label, total weight, share, resolved bool).
- [ ] Auth: anonymous/device accounts first (low friction), upgradeable later. Everyone starts SPROUT ×1; support seeding a few curated experts at ARBORIST+.
- [ ] Move vote weighting, resolution, reputation payouts, and rename detection server-side so they can't be cheated.
- [ ] Replace `simulateCrowd()` with real votes + Realtime updates on the map.
- **Done when:** two phones see the same trees, and one player's confirmed name shows up on the other's map.

### Phase 3 — Package for the iPhone (native shell)
Goal: real native camera/GPS/push and a path to the App Store, ideally from the *same web codebase*.
- [ ] **Recommend Capacitor** to wrap the web app into a native iOS shell (fastest; one codebase). Add native plugins: Camera, Geolocation (incl. background), Push Notifications, Haptics.
- [ ] Push notifications: "a tree you named early was just CONFIRMED — +8 REP", "a new tree appeared near you".
- [ ] TestFlight build. (A full SwiftUI rewrite is *not* recommended unless a hard limitation forces it — log the reason in `DECISIONS.md` if you go native.)
- **Done when:** an installable TestFlight build runs the full loop with native camera + GPS + push.

### Phase 4 — Depth, trust & discovery
- [ ] Species validation: cluster free-text candidate names against GBIF/iNaturalist; auto-link confirmed names to real taxa; flag geographic clusters of confirmed-but-uncatalogued trees for review (the "discover a new species" angle).
- [ ] Anti-abuse: rate limits, dedup, report/flag, weight decay for bad actors, sockpuppet resistance.
- [ ] Progression/social: leaderboards, streaks, badges, per-species accuracy stats, friends, daily challenges.
- [ ] More species art + richer Treedex entries; seasonal variation; walking/exploration rewards.
- [ ] App Store submission.

---

## 🎨 Guardrails (don't break these)

- **Keep the NES / Game Boy pixel aesthetic** — Press Start 2P, chunky pixels, CRT feel, the Treedex-device framing. It's the game's identity.
- **Keep the core loop intact and always playable.** If you refactor, migrate feature-by-feature and keep it runnable throughout.
- **The crowd is the judge.** Never hardcode a single "correct" answer as ground truth — truth emerges from weighted consensus over time. That mechanic is the whole point.
- **Reputation must stay time-earned.** No instant trust for unproven players; keep penalties for overturned calls.
- **No secrets in the repo.** Backend keys/tokens go in env vars / platform secrets, never committed. `.env` is gitignored.
- **Privacy:** don't expose exact user locations publicly or store PII beyond what the game needs.

## ✅ Definition of done for any increment
Playable ✔ · console clean ✔ · works on a mobile viewport ✔ · committed with a clear message ✔ · `PROGRESS.md` updated ✔.

---

## 🚀 First moves for this session
1. Read `README.md` and skim `index.html` to understand the current architecture.
2. Create `PROGRESS.md` and `DECISIONS.md`.
3. Start **Phase 1**: add the PWA manifest + service worker and get an installable, HTTPS-deployed build playable on an iPhone. Ship it, then keep going.
