# Elementia in Godot: the plan

The living plan for rebuilding Elementia in Godot 4. **Every session working
on the Godot version starts here:** read "Where we are", do the next open
task, and update the log before finishing.

Decided 2026-11-15. The HTML game in `game/` is the working prototype and the
reference for every rule and screen until the Godot version replaces it.

---

## Where we are

**Current milestone:** M2 Look foundation (M1 done)
**Next task:** M2: BenchPanel (hub_frame 9-slice), buttons, QuarkBar, top
bar; add each to the gallery and `tools/compare.mjs`.

Log (newest first, one line per session):
- 2026-11-15: M2 started: `ui/theme/tok.gd` (tokens, system font, box/label/
  icon helpers, icon outline shader), `ui/components/item_card.gd`,
  `tests/gallery.gd`, `tools/compare.mjs`. Cards: 127 elements, 0 off by
  more than 2px. Images now import with mipmaps (smooth when shrunk).
- 2026-11-15: M1 review fixes: 5x5 BINGO removed, safe craft(), Overtime
  tests, cross-run code split into `game/progress.gd`. Parity 3604/3604.
- 2026-11-15: M1 done. Parity 3594/3594 over 24 runs (incl. 6 on the 5x5
  BINGO card, and the trophies each run earns: 54 of 67 exercised).
  `tests/rules_test` covers convert, "?", suit costs, Market rewards,
  reroll, mat placement/Last, run start, trophies, history, save, collections,
  clues, layouts. Not ported (screens): Combo Lab sandbox, dev panel.
- 2026-11-15: M1 first batch: every action the sim plays is ported
  (`core/` catalog, mat, orders, market; `game/game.gd`). Parity 3580/3580
  over 24 runs (all 8 capstones on a mat, all 13 challenges, a game over).
  Planted bugs are caught.
- 2026-11-15: M0 done. Project, export (115 tables, 111 icons, art),
  shot runner (icon sheet: every icon imports), 3 golden runs (449 steps),
  parity runner (0/449 ported, as expected).
- 2026-11-15: plan reviewed; 8 fixes folded in (see Decisions).
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
- **Content and tables stay in one place.** Until cutover (M9) content is
  edited only in `game/js/` (`data.js`, plus the tables in `model.js`,
  `mat-scoring.js` and `lock-in.js`). `godot/data/game_data.json` is
  generated from the running HTML game by `godot/tools/export_from_game.mjs`
  (it loads the page through `game/tools/headless_game.mjs` and writes
  `DATA` plus every plain table: `ITEM_SUIT_COST_TABLE`,
  `LOCKIN_ROUND_ANCHORS`, `MAT_COLLECTIONS_RAW`, `MAT_GROW_ROUNDS`, the
  BINGO/Market constants ...). Never hand-copy a table into GDScript, and
  never hand-edit the JSON. Anything holding functions (e.g. the challenge
  checks in `CHECK_ORDERS`) is a rule and is ported as code.
- **Balance freeze, mostly.** Data tweaks (a recipe, a price) are fine: re-run
  the export. Rule changes in `game/js` during the port must also be made in
  Godot; the parity test (below) flags any that are missed.
- **Rules never touch the screen.** Rules code (`core/`) has no nodes, no
  drawing, no timers. Screens only call actions and read state. This is the
  one structural rule the HTML game didn't have, and it's what makes the
  parity tests and a later simulator possible.
- **Same save format.** The Godot save is the same JSON shape as the HTML
  game's `state` object, so the same save loads in both. That powers the
  tests and screenshots. Old-save upgrades (`loadAll()`'s migrations) are
  not ported: app players start fresh. Add an importer only if carrying
  runs across becomes a real feature.
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
- **Always pass `--quit-after <frames>`** to test runs: a script error
  doesn't quit Godot, it just sits there forever.
- Tests run as scenes (`res://tests/x.tscn`), not `-s` scripts, so the
  autoloads (Data, Rng, Game) are there.
- After adding a new `class_name` script, run the import once
  (`G --headless --path godot --import`): class names only register then.
- GDScript can't infer a type from untyped values (`var x := dict.key ...`
  is a parse error): write `var x: bool = ...`.

## Commands

G = `C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`

| What | Command (from the repo root) |
|---|---|
| Re-export data, icons, art from `game/` | `node godot/tools/export_from_game.mjs` |
| Re-record goldens (after rule changes) | `node godot/tools/record_golden.mjs [--runs 24]` |
| Import assets (after new art) | `G --headless --path godot --import` |
| Rules parity | `G --headless --path godot --quit-after 600 res://tests/parity.tscn` |
| Rule tests (button-only rules) | `G --headless --path godot --quit-after 600 res://tests/rules_test.tscn` |
| Screenshot | `G --path godot --quit-after 300 res://tests/shot.tscn -- --screen <res path> --out <png> [--save <json>] [--scale 2]` |
| Icon sheet | `--screen res://tests/icon_sheet.gd` |
| HTML vs Godot side by side | `node godot/tools/compare.mjs` -> `godot/build/compare.html` |

---

## Architecture

```
godot/
  project.godot
  PLAN.md                  this file
  data/game_data.json      generated from game/js/data.js (don't edit)
  core/                    rules: plain GDScript classes, no nodes
  game/                    autoloads: Game (the run: state + actions + signals),
                           Progress (prefs, trophies, history, layouts, saving), Rng
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
`randi()` scattered in code), so tests can feed it fixed numbers. Rule
code only uses it the way the JS does: `floor(r * n)` picks and the
shuffle in `mat-scoring.js`. Visual randomness (confetti, sparks) uses
Godot's own random and never touches `Rng`.

### JS -> GDScript pitfalls (check every ported rule against these)

- **Division:** in GDScript, whole number / whole number drops the fraction
  (`7/2` is `3`; in JS it's `3.5`). Example: the breakpoint interpolation
  `(round - r0) / (r1 - r0)` (`lock-in.js:92`) would always be 0. Write
  `float(a) / b` wherever the JS divides, and round only where the JS rounds
  (`Math.round`, `Math.floor`, `| 0`).
- **JSON numbers:** Godot's JSON loader makes every number a float, so a
  value is `3.0` when it came from a save and `3` when it came from code.
  Use `int()` where a number is a count or index. The parity compare treats
  `3` and `3.0` as equal.
- **Sorting:** JS's `sort` keeps tied items in their original order;
  Godot's `sort_custom` doesn't promise to. Every ported sort uses
  `core/util.gd`'s `stable_sort(arr, cmp)` (ties broken by original
  position), or a rule that sorts then picks with a random number picks a
  different item.
- **JS `String(null)` is "null"**, GDScript's `str(null)` is "<null>": use
  `Util.js_str()` for keys like `collector:null`.
- **`Math.round`** rounds halves up; Godot's `round()` rounds them away from
  zero. Use `Util.js_round()`.
- **`bool(null)` is an error** in GDScript: test `x == true` for a key that
  may be missing.
- **Truthiness and missing keys:** JS `undefined`/`0`/`""` checks and
  `obj.x || default` need explicit `dict.get("x", default)` in GDScript.
- **Iteration order:** JS objects and Godot Dictionaries both keep insertion
  order; keep building them in the same order as the JS.

### JS file -> Godot mapping

| HTML game (`game/js/`) | Godot | Kind |
|---|---|---|
| `data.js` | `data/game_data.json` + `core/data.gd` (loader) | data |
| `model.js`, `map-graph.js` | `core/model.gd`, `core/map_graph.gd` | rules |
| `mat-scoring.js` | `core/mat_scoring.gd` | rules |
| `state.js` | `game/game.gd` (the run), `game/progress.gd` (prefs, saving) | state |
| `crafting.js`, `station.js`, `travel.js` | `core/crafting.gd`, `core/station.gd`, `core/travel.gd` | rules |
| rule parts of `roll`, `convert`, `suit-spend`, `lock-in`, `bingo`, `end-game`, `trophies`, `history`, `mat-layouts`, `empty-elements`, `opening` | matching `core/*.gd` | rules (split from screen code) |
| screen parts of the files above, plus `hub`, `drawer`, `map`, `display-mat`, `job-board`, `pins`, `reference`, `card-popup`, `settings`, `welcome`, `tour`, `hints`, `overlays`, `combo-lab` | `ui/screens/*`, `ui/overlays/*` | screens |
| `render`, `render-helpers`, `input`, `low-motion` | Godot's own nodes, input and Theme; little to port | replaced |
| `craft-animations`, `travel` animation, reveals | Tweens and AnimationPlayer in M8 | polish |
| `minigames.js` + `minigames/*.js` (8 games, ~3,300 lines, off by default) | M7, if kept | optional |
| `dev.js` | `ui/dev/` in M6 (the screenshot runner has its own "load save, open screen" from M0) | tool |
| `pwa.js`, `boot.js` | not needed | gone |

---

## How Claude checks its own work

### 1. Rules parity (automatic, every change)
- **Recorder = the simulator.** `game/tools/sim/` already plays whole,
  varied runs through the HTML game's own rule functions, with animations
  and timers off and seeded dice. `godot/tools/record_golden.mjs` runs it
  with those functions wrapped (`goStation`, `doRoll`, `craft`,
  `startCheckOrder`, `confirmLockIn`, `quietCheck`, ... the list the sim
  calls) and records each call as **state before, the action and its
  arguments, the random numbers it used, state after**. Because the sim has
  timers switched off, "state after" is complete when the call returns.
- **Replay:** `tests/parity.gd` (run with `--headless`) loads "state
  before", feeds the same random numbers through `Rng`, runs the matching
  Godot action, and compares with "state after" (3 and 3.0 count as equal),
  printing the first field that differs.
- Steps are independent, so one bug shows as one failing step rather than
  ruining the rest of the run.
- **Re-record whenever `game/js` rules change**, so a rule changed in JS
  but not Godot fails straight away.
- **Actions that only exist in the HTML game's buttons** (convert 3:1,
  spending a "?", paying suit costs, collecting a Market row) have no rule
  function to wrap; the sim re-implements them. In Godot they become
  proper rules in `core/`, each with hand-written tests taken from the
  HTML game's behaviour, the way `smoke_classic.js` tests rules today.

### 2. Screen comparison (every screen change)
- Both games load the **same save** and open the **same screen** at 390x844:
  the HTML game in headless Chrome, Godot through `tests/shot.gd`
  (`-- --save <file> --screen <name> --out <png>`, optionally with taps).
- A tool puts each pair side by side into `godot/build/compare.html`.
  Claude looks at the pairs and fixes mismatches before showing the user.
  (No pixel-difference overlay: the two versions use different fonts, so
  every letter would differ and hide the real problems.)
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
- [x] M0.1 Create `godot/` project (Compatibility renderer, 390x844,
      portrait, `.gitignore` for `.godot/`). Add a pointer to this plan in `CLAUDE.md`.
- [x] M0.2 `tools/export_from_game.mjs`: `DATA` and the plain rule tables, read
      from the running HTML game -> `data/game_data.json`.
- [x] M0.3 Icon export: `images.js` + Noto PNGs -> `assets/icons/`; copy
      backdrops, banners, frames.
- [x] M0.4 `tests/shot.gd` screenshot runner with its own `--save <file>
      --screen <name>` (loads the save into `Game`, opens that scene
      directly). The comparison page waits for M2.
- [x] M0.5 Parity skeleton: `record_golden.mjs` wraps the sim's rule calls
      and records steps; `parity.gd` replays them (fails until M1, fine).

### M1 Rules core (~2-4 sessions)
- [x] Data loader, model (elements, suits, suit costs, item catalog), map graph
- [x] Mat scoring (collections, combos, BINGO), mat stages and growth
- [x] Rolling and dice rules, crafting, station visits and limits, travel
- [x] Convert, suit spend, Market
- [x] Lock-In: breakpoints, check orders (requests, restrictions), game over
- [x] BINGO board and redraws, opening and capstone pick, end of run
- [x] Trophies, history, stars; plain save/load (no old-save migration)
- [x] Convert, "?" spend, suit costs, Market collect: hand-written tests
- [x] **Done when:** parity passes on all recorded goldens (24 runs, one per
      capstone in turn, cover every capstone rule and challenge; 50 wasn't needed).

### M2 Look foundation (~1-2 sessions)
- [ ] Theme + tokens from the CSS; font (see "Open questions")
- [ ] Components: ItemIcon, ItemCard (tier 1 / 2 / capstone sizes), BenchPanel,
      buttons, QuarkBar, top bar
- [ ] A component gallery scene, and the Chrome screenshot side plus the
      side-by-side `compare.html`, first used on the gallery; element
      positions dumped from both sides and compared by number

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
- 2026-11-15: The 5x5 BINGO card (an HTML Settings switch) is retired: not
  ported; the Market is 3 rows of 4. Goldens force `prefs.classicBingo = false`.
- 2026-11-15: `Game.craft(name, picks)` is the safe craft (asks for suit-cost
  picks); `craft_raw()` is the HTML game's unchecked rule, for replay only.
- 2026-11-15: Font = the device's own (SystemFont: Segoe UI / Helvetica Neue /
  Arial), as the HTML game. Needs a bundled font for the web export (M3).
- 2026-11-15 (plan review): goldens come from the simulator; rule tables
  are exported from the running game, never copied; no old-save migration;
  no pixel-difference overlay; comparison page built in M2.

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
