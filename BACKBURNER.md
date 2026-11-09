# Backburner / future to-do

Ideas and planned features that are worth doing eventually but aren't in
active development. Add to this freely; nothing here is scheduled.

## Game feel / UI

- **Selection color: green → gold.** Swap the "this is selected/tracked"
  highlight (job-highlight rings, pin badges, `.map-job-chip.selected`,
  the tracked-item pill on station preview cards) from `--ok` to `--gold`,
  which already reads well against the map backdrops. Craftable/owned/
  success states (Craft button, owned checkmarks, `.map-node.here`) stay
  green — different meaning, shouldn't change. `--gold`/`--gold-soft`/
  `--gold-line` already exist in `elementia.html`.
- **Welcome screen intro animation.** A brief pan/fade through
  `backdrops/ocean.webp` before the existing `#tour.welcome` slide, so the
  game doesn't hard-cut straight to the title card on first boot. Needs a
  transition treatment between the ocean art's flat line-art style and the
  tutorial slides' denser painted style (a literal crossfade would look
  like a jump-cut without new art).
- **Progressive item reveal.** Hide shop items (in-station and on the
  map's station-preview row) until a player is roughly deep enough to
  reasonably reach them, gated on `state.visits` vs. each item's
  how many visits it typically takes to reach. The old reachability
  simulator that estimated this (`archive/simulation/`) ran on outdated
  data, so it would need reviving against the current game first.
- **Element "where do I get this" hint.** Tapping an element token in a
  shop recipe now opens its element card instead of the old hint listing
  which stations roll it. If that source info turns out to be missed, it
  needs somewhere new to live — the element card itself was deliberately
  simplified, so probably not there.

## Mini-games

- **Gravity wells in the Observatory.** Small gravitational attraction
  between the ship and the asteroids/planets drifting past. Deferred until
  the vertical reorientation has been played enough to know whether it
  adds anything.
- **Dice-count tied to mini-game score.** Every game now shows a live
  `🎲 N` readout (`DICE_MIN`/`DICE_MAX`, currently 3–6), but the main game
  still rolls a fixed `TAKE = 5` — the two aren't wired together yet.
  Waiting on enough playtesting to lock the range and curve.
- **Wire the mini-games into `elementia.html`.** They're still standalone
  files driven by `sandbox.html` / `tuning_lab.html`; nothing calls
  `runMinigame()` from the real game yet. Also needs
  `MINIGAME_BACKDROP_BASE` / `MINIGAME_ASSET_BASE` set for the built
  single-file layout, and `build_artifact.py` checked for the sprite/
  backdrop assets they now reference.

## Content

- **Catalog expansion beyond 72 items.** A larger roster (16 elements,
  redesigned 8-station item catalog) referenced in earlier planning, but
  the actual design work for it isn't recoverable from any file or git
  history in either repo — would need to be designed from scratch as its
  own dedicated session, not treated as "wiring up an existing plan".
  (Covers tracker tasks #123–#132.)
- **The City needs its own art.** `STATION_BG["The City"]` still points at
  `backdrops/quarry.webp` from the station's previous name, and the Deep
  Mine mini-game's rock frames are a sunny outdoor scene rather than
  anything underground. Both are flagged in-code.
