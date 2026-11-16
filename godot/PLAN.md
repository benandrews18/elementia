# Elementia in Godot: the plan

The living plan for rebuilding Elementia in Godot 4. **Every session working
on the Godot version starts here:** read "Where we are", do the next open
task, and update the log before finishing.

Decided 2026-11-15. The HTML game in `game/` is the working prototype and the
reference for every rule and screen until the Godot version replaces it.

---

## Where we are

**Current milestone:** M0 Foundation (not started)
**Next task:** M0.1, create the project.

Log (newest first, one line per session):
- 2026-11-15: plan written. Godot 4.7.2 installed; a probe proved Claude can
  run it, screenshot a 390x844 screen in ~2s and view the picture.

---

## Goals

1. **Same game, more polish:** every rule identical to the HTML game, then
   better animation, feel and sound than the browser allowed.
2. **App stores:** Android (Google Play) and iOS (App Store) builds.
3. **Claude can check its own work:** rules by automatic tests, screens by
   screenshots compared with the HTML game, so the user's time goes on look
   and feel, not on spotting misaligned labels.

Not goals (until the user asks): new content or balance changes during the
port, landscape layout, multiplayer, accounts or cloud saves, ads.

---

## Ground rules

- **The HTML game is the reference.** When the Godot version disagrees with
  `game/`, Godot is wrong, unless the user decided to change it (record that
  in "Decisions").
- **Content stays in one place.** `game/js/data.js` remains the only place
  content is edited until cutover (M9). `godot/data/game_data.json` is
  generated from it by `godot/tools/export_data.py`; never hand-edit it.
- **Balance freeze, mostly.** Data tweaks (a recipe, a price) are fine: re-run
  the export. Rule changes in `game/js` during the port must also be made in
  Godot; the parity test (below) flags any that are missed.
- **Rules never touch the screen.** Rules code (`core/`) has no nodes, no
  drawing, no timers. Screens only call actions and read state. This is the
  one structural rule the HTML game didn't have, and it's what makes the
  parity tests and a later simulator possible.
- **Same save format.** The Godot save is the same JSON shape as the HTML
  game's `state` object, so the same save loads in both. That powers the
  tests and screenshots, and lets players carry a run across if we want.
- **One commit per logical change, on `master`**, as for the HTML game.
  Godot work doesn't trigger the HTML publish steps in `CLAUDE.md`.

---

## Setup facts (for future sessions)

- Godot: `C:\Users\benan\Downloads\Godot_v4.7.2-stable_win64.exe\` (a folder).
  Use `Godot_v4.7.2-stable_win64_console.exe` from scripts: it prints output
  and returns an exit code. Move it somewhere permanent? See "Open questions".
- Standard (GDScript) build, not .NET: .NET can't export to the web.
- Renderer: **Compatibility** (OpenGL / WebGL 2). It's the one that works for
  the web export and the widest range of phones. The probe ran on the PC's
  AMD Vega 8.
- Screenshots need a normal (not `--headless`) run: headless has no
  renderer. A window flashes for about 2 seconds.
- Export templates (web, Android, iOS) are not installed yet. Needed from M3.

---

## Architecture

```
godot/
  project.godot
  PLAN.md                  this file
  data/game_data.json      generated from game/js/data.js (don't edit)
  core/                    rules: plain GDScript classes, no nodes
  game/                    autoloads: Game (state + actions + signals), Save, Prefs, Rng
  ui/
    theme/                 the Theme resource: colours, fonts, panel styles
    components/            ItemCard, ItemIcon, BenchPanel, QuarkBar, Button styles ...
    screens/               one scene per screen (map, station, display_mat ...)
    overlays/              reveal, confirm, card popup, toasts ...
  assets/                  icons (Noto PNGs), backdrops, banners, frames, fonts, sounds
  tests/                   rules tests, parity runner, screenshot runner
  tools/                   export_data.py and other helpers
```

**How a screen works:** the `Game` autoload holds `state` (a Dictionary,
same shape as the JS `state`). A screen calls `Game.craft(item)`; `Game` runs
the rule in `core/`, saves, and emits `state_changed`; screens refresh from
state. That is the HTML game's `render()`-after-every-action pattern, just
split cleanly.

**Screen size:** design size **390x844** (iPhone 14), stretch mode
`canvas_items`, aspect `expand`. Every phone shows the same 390-wide layout
scaled to fit (the idea tested on the `fixed-screen` branch); taller phones
get extra height, and tablets get a wider layout (~587). Notches use
`DisplayServer.get_display_safe_area()`.

**Styling:** the CSS becomes one Theme resource plus a few component scenes.
The colours and sizes from `game/css/` become named constants in
`ui/theme/tokens.gd`, so a colour is changed in one place. The wooden
bench and hub frames (CSS `border-image`) become `NinePatchRect` / `StyleBoxTexture`.

**Icons:** the Noto emoji PNGs and custom art now embedded in
`game/assets/images.js` are written out as image files under `assets/icons/`
by a tool, so both versions show identical icons.

**Randomness:** all random numbers go through the `Rng` autoload (no
`randi()` scattered in code), so tests can feed it fixed numbers.

### JS file -> Godot mapping

| HTML game (`game/js/`) | Godot | Kind |
|---|---|---|
| `data.js` | `data/game_data.json` + `core/data.gd` (loader) | data |
| `model.js`, `map-graph.js` | `core/model.gd`, `core/map_graph.gd` | rules |
| `mat-scoring.js` | `core/mat_scoring.gd` | rules |
| `state.js` | `game/game.gd`, `game/save.gd`, `game/prefs.gd` | state |
| `crafting.js`, `station.js`, `travel.js` | `core/crafting.gd`, `core/station.gd`, `core/travel.gd` | rules |
| rule parts of `roll`, `convert`, `suit-spend`, `lock-in`, `bingo`, `end-game`, `trophies`, `history`, `mat-layouts`, `empty-elements`, `opening` | matching `core/*.gd` | rules (split from screen code) |
| screen parts of the files above, plus `hub`, `drawer`, `map`, `display-mat`, `job-board`, `pins`, `reference`, `card-popup`, `settings`, `welcome`, `tour`, `hints`, `overlays`, `combo-lab` | `ui/screens/*`, `ui/overlays/*` | screens |
| `render`, `render-helpers`, `input`, `low-motion` | Godot's own nodes, input and Theme; little to port | replaced |
| `craft-animations`, `travel` animation, reveals | Tweens and AnimationPlayer in M8 | polish |
| `minigames.js` + `minigames/*.js` (8 games, ~3,300 lines, off by default) | M7, if kept | optional |
| `dev.js` | `ui/dev/` (needed early: tests and screenshots use its jumps) | tool |
| `pwa.js`, `boot.js` | not needed | gone |

---

## How Claude checks its own work

### 1. Rules parity (automatic, every change)
- A Node script (`game/tools/record_golden.mjs`, using the existing
  `headless_game.mjs`) plays runs in the HTML game and records each step as
  **state before, the action, the random numbers it used, state after**.
- A Godot test (`tests/parity.gd`, run with `--headless`) replays every step:
  it loads "state before", feeds the same random numbers through `Rng`, runs
  the action, and compares with "state after", printing the first field that
  differs.
- Steps are independent, so one bug shows as one failing step rather than
  ruining the rest of the run.
- Goldens are re-recorded from the HTML game whenever its rules change, so a
  rule changed in JS but not Godot fails the test straight away.
- Plus small hand-written tests for edge cases, like `smoke_classic.js` today.

### 2. Screen comparison (every screen change)
- Both games load the **same save** and open the **same screen** at 390x844:
  the HTML game in headless Chrome, Godot through `tests/shot.gd`
  (`-- --save <file> --screen <name> --out <png>`, optionally with taps).
- A tool puts each pair side by side, with a difference overlay, into
  `godot/build/compare.html`. Claude looks at the pairs and fixes mismatches
  before showing the user.
- Layout numbers too: both sides dump each key element's position and size
  as JSON, and a script reports anything more than a few pixels off.
- A fixed set of screens and states (the "shot list") is kept in
  `tests/shots.json`, so every screen's check can be re-run later.

### 3. The browser pane
From M3 the web export runs in the browser pane, so Claude can play it,
tap through it and screenshot it.

### 4. The user
Look and feel, the real iPhone (notch, speed, touch) and taste calls. Each
screen ends with a short review: screenshots or the web preview, then notes.

---

## Milestones

Each milestone ends with a commit, an updated log above, and a short report
to the user. Rough sizes are in sessions and are guesses.

### M0 Foundation (~1 session)
- [ ] M0.1 Create `godot/` project (Compatibility renderer, 390x844,
      portrait, `.gitignore` for `.godot/`). Add a pointer to this plan in `CLAUDE.md`.
- [ ] M0.2 `tools/export_data.py`: data.js JSON block -> `data/game_data.json`.
- [ ] M0.3 Icon export: `images.js` + Noto PNGs -> `assets/icons/`; copy
      backdrops, banners, frames.
- [ ] M0.4 `tests/shot.gd` screenshot runner, and the matching Chrome side;
      side-by-side `compare.html`.
- [ ] M0.5 Parity skeleton: `record_golden.mjs` records one step; `parity.gd`
      replays it (will fail until M1, which is fine).

### M1 Rules core (~2-4 sessions)
- [ ] Data loader, model (elements, suits, suit costs, item catalog), map graph
- [ ] Mat scoring (collections, combos, BINGO), mat stages and growth
- [ ] Rolling and dice rules, crafting, station visits and limits, travel
- [ ] Convert, suit spend, Market
- [ ] Lock-In: breakpoints, check orders (requests, restrictions), game over
- [ ] BINGO board and redraws, opening and capstone pick, end of run
- [ ] Trophies, history, stars; save/load including old-save migration (`loadAll()`)
- [ ] **Done when:** parity passes on all recorded goldens (aim: 50+ runs).

### M2 Look foundation (~1-2 sessions)
- [ ] Theme + tokens from the CSS; font (see "Open questions")
- [ ] Components: ItemIcon, ItemCard (tier 1 / 2 / capstone sizes), BenchPanel,
      buttons, QuarkBar, top bar
- [ ] A component gallery scene, screenshotted next to the HTML versions

### M3 Proof of concept: the Display Mat (~1-2 sessions)
- [ ] The Display Mat screen with real data, cards placed and scored
- [ ] Web export (thread-less, so GitHub Pages works) published as a
      preview page, like `fixed-screen`'s `/preview/`
- [ ] **User tests it on the iPhone.** Go / no-go for the rest of the port.

### M4 Core loop (~3-5 sessions)
- [ ] Map and travel, station hub, rolling, shop and crafting, inventory drawer
- [ ] **Done when:** a whole run can be played in Godot from start to Lock-In.

### M5 Run flow (~3-5 sessions)
- [ ] Opening, Lock-In screens and check orders, mat expansion reveal, BINGO
      tray and To-Do, convert, Market, suit spend, game over and end of run

### M6 Everything around the run (~3-4 sessions)
- [ ] Welcome, tour and hints, settings, item reference, pins, trophies,
      history, saved layouts and Combo Lab, dev mode

### M7 Mini-games (size unknown; decide first)
- [ ] Decide which of the 8 to keep. Then port them one at a time.

### M8 Polish (ongoing)
- [ ] Animations (crafting, travel, reveals), screen transitions, sound and
      music, haptics, a loading screen, performance on an older phone

### M9 Release and cutover (~2-3 sessions plus store review time)
- [ ] Android: export templates, a signing key, Play Console listing, testing track
- [ ] iOS: a Mac, Apple developer account, Xcode export, TestFlight
- [ ] Store rules for a children's game: Apple Kids category and Google
      Families policy (no third-party ads or tracking, a privacy policy)
- [ ] Cutover: `data/game_data.json` becomes the content source; decide what
      happens to the HTML game, the website, the simulator, the breakpoint
      tuner and the print pipeline (they read `game/` today)

---

## Decisions

Recorded so they aren't re-argued. Add new ones with the date.

- 2026-11-15: Godot 4 (standard build), GDScript, Compatibility renderer.
- 2026-11-15: Inside this repo under `godot/`, not a new repo.
- 2026-11-15: Design size 390x844, stretch `canvas_items`, aspect `expand`.
- 2026-11-15: Save format identical to the HTML game's `state` JSON.
- 2026-11-15: Port rules first (M1) and prove one screen on the iPhone (M3)
  before building the rest.

## Open questions (for the user, when they come up)

- **Font:** the HTML game uses the phone's system font. Godot needs a font
  file bundled. Pick one in M2 (Claude will offer a few side by side).
- **Mini-games:** keep all 8, some, or none? (M7)
- **Sound and music:** source and style. (M8)
- **App identity:** store name, bundle id (e.g. `com.<you>.elementia`),
  developer account names. (M9)
- **iOS builds need a Mac:** own, borrowed or rented? (M9)
- **During the port, does the HTML game keep getting updates** (beyond data
  tweaks)? Every rule change then has to be made twice.
- **Godot location:** move it out of Downloads (e.g. `C:\Godot\`) so it doesn't
  get cleaned up; update "Setup facts" if it moves.
