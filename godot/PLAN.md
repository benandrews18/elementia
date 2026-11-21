# Elementia in Godot: the plan

The living plan for rebuilding Elementia in Godot 4. **Every session working
on the Godot version starts here:** read "Where we are", do the next open
task, and update the log before finishing.

Decided 2026-11-15. The HTML game in `game/` is the working prototype and the
reference for every rule and screen until the Godot version replaces it.

---

## Where we are

**Current milestone:** M5.5 Editable in the Godot editor (M5 done)
**Next task:** M5.5 is done once you've made an edit in the editor
yourself (EDITING.md); then M6. Start every session with `git status`: the user may
have edited scenes in the editor.
Republish the preview: export Web, copy build/web/* to
../elementia-site/godot/, commit, push main (ask the user first).

Log (newest first, one line per session):
- 2026-11-20: M5.5 review fixes: stations scale with the map width
  (tablets), YOU ARE HERE and the station colours editable, dead helpers
  gone, dim/scrim pieces, tools/recolour.py (a colour everywhere at once;
  a style shared by scenes can't follow tokens.tres, so this replaces that).
- 2026-11-20: Faster, stricter checks: tools/check.py (PASS needs the pass
  line), ui_play headless (~15s, was ~2.5min) with --only sections, every
  screen state shot in one Godot run (~35s, was ~3min), scene roots no longer
  anchored (35 size warnings gone).
- 2026-11-20: M5.5 step 4 done: the other 10 windows are scenes; new shot
  states (reward_open, roll, order_restrict, order_grand); shot_diff takes
  state names and drops stale shots. Step 5 done (station, item card,
  shop row, pin/Craft piece). Step 6 done (mat, element chip). Step 7
  done (trays, hub, Quark bar). Pattern found: labels sized before they're
  in the tree kept their text's size (off-centre); scenes fix that.
- 2026-11-17: M5.5 step 3: the map is a scene (map.tscn, MapNode pieces with
  @tool so the editor shows their icons; Map.make()). Over to the user.
- 2026-11-17: M5.5 steps 0-1 (before/after check; colours in tokens.tres).
  Fixed on the way: the suit-spend balloon drew on its replacement (Godot
  errors), the Market's auto-close could shut a tray the player reopened,
  and ui_play's Market-bounce check was flaky (now a play counter).
- 2026-11-17: Planned M5.5 (screens, windows and repeated pieces as scenes,
  layout numbers in the Inspector, colours in tokens.tres) with the user,
  before M6. Reverses the "styling is code" decision.
- 2026-11-17: M5 review 2 fixes: the Market keeps phone-sized squares on
  wide screens and scrolls; the opening's slide 2 falls back like the HTML;
  a square crafted from the open Market bounces there; ConfirmDialog.scrim()
  for the 3 trays. ui_play crafts a Market square through its bench and
  balloon, and each section must reach its end (a script error used to
  pass quietly; verified). shot.gd --size WxH. M5 done.
- 2026-11-17: M5: the opening is whole: logo, HowToPlay (3 slides from the
  data, ✕ Hide for good: Progress.tip_hidden/hide_tip), capstone choice,
  then the To-Do List + PinTip, fade into the station. 🎁 🎉 fetched.
  M5 built; next: the M5 review (Lock-In onwards since the last review).
- 2026-11-17: M5: the To-Do List (TodoTray from the hub button: pinned
  rows, full breakdown trees, pins, Get a Hint lighting the suggestion).
  Game.todo_hint() (computeTodoHint()) matches the HTML game on 4 states
  (rules_test); Catalog.still_needed/item_open; Tok.tinted(colour).
- 2026-11-17: M5: the Market (MarketTray panel from the hub's Market button,
  Home reads Map: stations visited, 3 rows of 4 with their "?", capstones;
  MarketCraft: craft a square from its Crafting Bench; the row sequence and
  RowReward pay the "?"; first square opens the tray, later ones mark "!").
  ui_play plays those moments. No 🎁 image yet.
- 2026-11-16: M5 review fixes: a run still at visit 0 (quit during the
  capstone choice) restarts the opening; closing the mat after the run ends
  shows the end screen again (and New Game doesn't); Game.reward_of() is the
  one dice/"?" rule; ConfirmDialog.dim()/close_x() and Tok.parch_button()
  replace 7/2/4 copies. ui_play checks both dead ends (verified failing).
- 2026-11-16: M5: Convert (ConvertTray panel: element grid, FROM stack,
  arrow 3:1, TO; ElementPicker; the result flies to the Inventory) and
  spending a "?" (UnknownPick: this station's elements). ui_play converts
  through the tray.
- 2026-11-16: M5: the opening's capstone choice and confirm (CapstoneChoice:
  grid, station card via MapScreen.station_card(boxed), components, the
  gift flying to the Inventory, fade into the station). New Game and a
  first launch (no save) go through it; the demo board is gone. 34 more
  Noto emoji fetched (user OK'd). Still to do: logo + how-to-play slides,
  To-Do List + pin tip.
- 2026-11-16: M5: EndGame (game over, Run Complete with Continue in
  Overtime, hard limit, crafted everything): scores, capstones, biggest turn,
  most visited, trophies won (awarded there) and Stars; confetti; New Game
  records History (random capstone until the opening exists). 32 emoji the
  end screen and trophies use have no Noto image yet (ask before fetching).
- 2026-11-16: M5: the board-check opening: Shutter (Round N / 24, title,
  challenge line), MatExpand (dark round the new slots on growth turns),
  OrderInfo (clock, rule in icons, Unknown Element swap; also from the
  mat's challenge chip); the Final Score shutter on the map. 🚫 ⬜ 🏠 drawn
  (no Noto images). ui_play also plays turn 24's final score.
- 2026-11-16: M5: the Lock-In count (cards and chips bounce beat by beat,
  the meter climbs), the Bonus Dice window (LockInReward, why / Unknown
  Element hints), fade through black to the station; the final score
  counts too. ConfirmDialog.window() shared. shot.gd: --call a,b and --wait.
  M4 preview republished (live pck byte-identical to the export).
- 2026-11-15: M4 review fixes: pin/fold taps save (Game._changed()); a
  selection moves one ring (late-game select ~80 -> ~21ms); ui_play crafts
  through the suit-spend balloon and checks what's spent; drawer rows plain.
- 2026-11-15: M4 done: suit-spend balloon, ConfirmDialog (Last, run-ending
  Lock-In), drawer Elements tab, select a card -> Crafting Bench with Add /
  Remove. 5 comparison shots, ui_play passes.
- 2026-11-15: M4: Crafting Bench on the station (tap a card: its ShopRow,
  Craft, pin, close); bench shot 81 elements, 0 off. Unpinned pins grey.
- 2026-11-15: M4: RollPopup (dice tumble, reveal, Collect flies to the
  Inventory button) on Home's Roll.
- 2026-11-15: 13 more Noto emoji (hub faces, pin, challenge chips) in
  assets/emoji (from 2D/png/128 of googlefonts/noto-emoji, user OK'd).
  Ask before more downloads.
- 2026-11-15: M4: MapScreen (art, nodes, paths, here label, station card)
  matches (17 elements, card 5px short). App: Travel (quiet check or the
  board-check Lock-In), Shop re-entry, Lock In, End. `tests/ui_play` plays a
  whole run through the screens (found 2 redraw bugs).
- 2026-11-15: M4: StationScreen (art + wash, header, element chips, crafted
  bar, shop cards with pin/Craft, Convert button) and QuarkTopBar; App shows
  it and Home's Roll / Map work. Station shot 110 elements, 1 off (title,
  Nunito wider). Tok.font(weight, spacing); ✓ drawn (Tok.tick). Suit costs
  paid automatically for now (suggest_suit_picks). Missing emoji: + 📌.
- 2026-11-15: M4 started: `ui/app.gd` (screens, panels, Home's face as
  hubHomeFace()), `HubBar` (wood bar, framed side buttons, glossy Home ball
  shader + brass rim), `Frame9` shared 9-slice. Hub matches (mat shot 115
  elements, 1 off by 2.1px). Missing Noto emoji so far: 🛒 🥾 🔒 🏁 🗺️ ⬅️.
- 2026-11-15: User tested the preview on the iPhone: "looks and feels great". Go.
- 2026-11-15: M3 preview published (/elementia/godot/). Images import as lossy
  WebP (game files 27 -> 5.5 MB; engine wasm 40 MB). Demo board doesn't save.
- 2026-11-15: M3 review fix: a tap rebuilds only the mat half; the item list
  re-dims in place (late-game tap ~70ms -> ~10ms on a PC). Inventory list
  passes input through so the wheel / touch scroll reaches the ScrollContainer.
- 2026-11-15: M3 web build works (browser pane: draws, taps place/remove).
  Nunito bundled; UI emoji as Noto PNGs (assets/emoji); ★ and ↺/↻ drawn
  (not in Nunito). Export templates installed (%APPDATA%/Godot). Build is
  ~66 MB (wasm 40 MB, pck 27 MB): shrink before release.
- 2026-11-15: M3: the whole drawer (mat by growth stage, tabs, Last/Clear,
  fold line, inventory by tier, tap to place/remove). Mat 109 elements, 1
  off by 2.1px. Shortcuts noted in display_mat.gd (Elements tab, Layouts,
  "?", Last's confirm, the Crafting Bench flow come in M4).
- 2026-11-15: M3 started: Display Mat top (QuarkMeter, combo chips incl.
  challenge and capstone chips, the growing mat page with stacked tier 1
  cards, lit halos, complete glow). `compare.mjs` now runs shots (gallery,
  mat at run 1's visit-18 check): mat 109 elements, 1 off by 2.1px.
  Measure text with `Tok.font().get_string_size()`, not Label min size
  (Label adds ~5px).
- 2026-11-15: M2 done: BenchPanel (hub_frame 9-slice drawn at 16px) matches.
  QuarkBar moves to M3 and hub buttons / top bar to M4: each component is
  built with the screen that uses it.
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
  doesn't quit Godot, it just sits there forever. A run cut off there exits
  0 with no pass line, so never trust an exit code or a grep: run checks
  through `tools/check.py`, which needs the pass line too.
- **Which check when** (decided 2026-11-20):
  - after each change: `python godot/tools/check.py fast`, plus
    `--only <section>` when a play-test section covers what changed (`run`,
    `final_score`, `market`, `todo`). About a minute.
  - before a review, a milestone or a publish: `check.py full` (adds the
    whole play test, ~15s headless, and the HTML comparison report).
  - an intended visual change: look at `build/after/diff_<state>.png`, then
    `check.py accept`. The screen states are `tests/shot_states.gd`.
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
| Every check, with a clear PASS/FAIL | `python godot/tools/check.py fast [--only market]` / `full` / `accept` |
| Rules parity | `G --headless --path godot --quit-after 600 res://tests/parity.tscn` |
| Rule tests (button-only rules) | `G --headless --path godot --quit-after 600 res://tests/rules_test.tscn` |
| The play test (or one section) | `G --headless --path godot --quit-after 20000 res://tests/ui_play.tscn [-- --only market]` |
| Screenshot | `G --path godot --quit-after 300 res://tests/shot.tscn -- --screen <res path> --out <png> [--save <json>] [--scale 2]` |
| Icon sheet | `--screen res://tests/icon_sheet.gd` |
| HTML vs Godot side by side | `node godot/tools/compare.mjs` -> `godot/build/compare.html` |
| Before/after screens | `python godot/tools/shot_diff.py shoot godot/build/after [state ...]` (one Godot run) then `... diff godot/build/before godot/build/after` |

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

**Styling:** through M5, `Tok` helpers in `ui/theme/tok.gd` (colours as
constants, boxes and labels built in code). From M5.5: colours and fonts in
`ui/theme/tokens.tres` (editable in the Inspector), screens, windows and
repeated pieces as scenes; see M5.5. The wooden bench and hub frames (CSS
`border-image`) are 9-slice `StyleBoxTexture`s.

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
- [x] Tokens from the CSS (`ui/theme/tok.gd`); font = the device's own
- [x] Components: ItemCard (tier 1 / 2 / capstone sizes), BenchPanel
      (QuarkBar -> M3, buttons and top bar -> M4, built with their screens)
- [x] A component gallery scene, and the Chrome screenshot side plus the
      side-by-side `compare.html`, first used on the gallery; element
      positions dumped from both sides and compared by number

### M3 Proof of concept: the Display Mat (~1-2 sessions)
- [x] The Display Mat screen with real data, cards placed and scored, its
      Quark meter and combo chips
- [x] ItemCard "lit" states: gold halos on pips / station badges in a live combo
- [x] Web export (thread-less, so GitHub Pages works): `export_presets.cfg`,
      `G --headless --path godot --export-release "Web" build/web/index.html`
- [x] Published as a preview page: https://benandrews18.github.io/elementia/godot/
- [x] **User tests it on the iPhone.** Go (2026-11-15).

### M4 Core loop (~3-5 sessions)
- [x] Map and travel, station hub (hub buttons, top bar), rolling, shop and
      crafting, inventory drawer
- [x] **Done when:** a whole run can be played in Godot from start to Lock-In
      (`tests/ui_play`).

### M5 Run flow (~3-5 sessions)
- [x] Opening, Lock-In screens and check orders, mat expansion reveal, BINGO
      tray and To-Do, convert, Market, suit spend, game over and end of run

### M5.5 Editable in the Godot editor (~3-4 sessions)
**Why:** so the user can open the project in the Godot editor and change
how screens look (move, resize, recolour, retext, swap images, later
animate) without code. Done now, before M6, so nothing new is built the old
way and M8's polish can happen in the editor. Decided 2026-11-17.

**What becomes what:**
- **A scene (`.tscn`) for every screen's frame and every window:** the fixed
  layout (backgrounds, headers, buttons, panels, labels and their text) is
  placed in the scene, not built in `_ready()`. Its script only fills it in.
- **A scene for every repeated piece**, placed by code from the data: item
  card, shop row, shop card, element chip, combo chip, Market square, map
  node, pill and parchment buttons, the parchment window. Editing the piece
  changes every copy.
- **Layout numbers in the Inspector:** what code still places (card gaps,
  columns, the mat's row height, shop packing) reads `@export` values on the
  screen's root, so they're edited in the editor's side panel.
- **Colours and fonts in one editable file:** `ui/theme/tokens.tres` (a small
  Resource with an `@export` per colour and font, colour pickers in the
  Inspector) replaces the constants in `tok.gd`; `Tok` reads from it, so
  callers don't change. A Godot Theme (`theme.tres`) holds the default font
  and label/button styles.
- **Stays in code:** rules and data (`core/`, `game/`, `data/`), anything whose
  count or order comes from the data (which cards, which slots are open,
  which elements a station shows), and the animations until M8 moves them to
  AnimationPlayer timelines.

**Care rules (every step):**
- One screen or piece per commit; it must look and behave the same as before.
- Before/after check: a screenshot of the same state before and after the
  conversion, compared pixel by pixel (`tools/shot_diff.py`, new). Any
  visible change is a bug unless planned. Then the usual `compare.mjs`
  numbers (no worse), `ui_play`, `rules_test`, parity.
- Node names in scenes are stable and meaningful (`Header`, `CraftButton`):
  tests and code find nodes by name, and the user sees them in the editor.
- The `cmp` tags the comparison uses move into the scenes as node metadata.
- No game logic in scenes; scripts stay where they are (`ui/...`).
- Scenes are text files: Claude writes them by hand and checks them with
  screenshots (it can't use the editor itself).

**Order:**
- [x] 0. `tools/shot_diff.py` (before/after pixel check) and a "before" shot
      set of every screen and window (kept in `build/`, not committed).
      27 states in `tests/shot_states.gd`; two runs are pixel-identical.
- [x] 1. Tokens: `tokens.tres` (`Tokens` resource, a colour picker per
      colour); `Tok` reads it. Zero visual change. A project-wide
      `theme.tres` (Nunito default) moved centred labels whose text
      overflows them ~4px, so it's left out: set the font on each scene's
      root instead, and check with the before/after diff.
- [ ] 2. Shared pieces: parchment window, pill / parchment buttons, element
      chip, item card, combo chip. **Converted as the first screen that needs
      each one comes up** (decided in the session: gets the map to the user
      sooner, and each piece is proved in a real screen). Done: MapNode;
      NineSlice (any 9-slice image: parchment, banner, pills); the
      parchment window with its title banner, the pill button and the
      parchment button (`ui/pieces/*.tscn`), which every window uses; the
      Nunito weights as font files (`ui/theme/fonts`). Intended change: the
      Game Over "Review my collection" button is as wide as its text (145px,
      it was 162 from a mis-measure).
- [x] 3. **Pilot: the map** (`ui/screens/map.tscn`: art, the 8 MapNode
      copies anchored to their spots, paths drawn between wherever they sit).
      Pixel-identical except "YOU ARE HERE", now centred in its pill as in the
      HTML (it sat 3px right). The station card stays code for now (data,
      and the capstone choice uses it): with the station screen (step 5).
      **Stop here: the user opens it in the editor and tries it** (drag a
      node, change a colour, press play). Go / adjust / stop.
- [x] 4. Windows: confirm, end game, Lock-In reward, challenge, how-to-play,
      pin tip, capstone choice, row reward, "?" pick, element picker,
      roll pop-up, suit-spend balloon, Market craft. Each is
      `ui/overlays/<name>.tscn` + a script that only fills it (`X.make()` /
      `X.open()`; never `X.new()`, which skips the scene). Pixel-identical
      except three intended fixes, centred like the HTML: the Lock-In "?"
      lines (sat up to 18px right), the roll pop-up's "GATHERING" (4px).
      Texts that depend on the data are `@export` strings on the root.
      Still code: the shutter and the mat-expand animation (M8).
- [x] 5. Station: frame scene (`ui/screens/station.tscn`: art, header,
      labels, crafted bar, shop heading; columns, gap, card ratio and the
      pin/Craft row's height on its root), the item card
      (`ui/components/item_card.tscn`, every card in the game), the shop
      row (`ui/components/shop_row.tscn`) and the pin/Craft piece
      (`ui/pieces/shop_acts.tscn`). Pixel-identical. Still code: the
      element chip (shared by six screens; with step 6) and the round
      header buttons.
- [x] 6. Display Mat / inventory: `ui/screens/display_mat.tscn` (drawer,
      the mat page's two looks, fold button; side, top, gaps, padding, card
      ratio on its root); the list's cards are the item card scene; the
      element chip is a piece (`ui/pieces/element_chip.tscn`). Pixel-
      identical except long chip captions, now centred under their chip.
      Still code: the combo chips and the Quark Meter (drawn).
- [x] 7. Trays and shell: `ui/overlays/{market,todo,convert}_tray.tscn`,
      `ui/components/hub_bar.tscn` (side buttons, Home, faces and frames in
      the Inspector; `HubWood` its own script) and `quark_top_bar.tscn`.
      Intended changes: the hub's side labels fill their buttons (were
      3px low, off-centre; now within 1px of the HTML); the Market footer is
      centred. Still code: the To-Do trees, Market squares, Quark Meter.
- [x] 8. A short "Editing Elementia in Godot" guide (`godot/EDITING.md`): how
      to open it, which scene is which screen, what's safe to change, what
      lives in the data instead, and the commit-before-a-session rule.
- [ ] **Done when:** every screen and window opens as a scene in the editor,
      all checks pass, and the user has made an edit themselves.

**Working together:** if the user edits in the editor, they commit before
the next session (or tell Claude), and Claude starts each session with
`git status`, so the two never overwrite each other. The editor also adds
`.uid` / `.import` files and may rewrite scenes when saving: commit those.

### M6 Everything around the run (~3-4 sessions)
- [ ] Welcome, tour and hints, settings, item reference, pins, trophies,
      history, saved layouts and Combo Lab, dev mode
- New screens are built as scenes from the start (M5.5 rules).

### M7 Mini-games (size unknown; decide first)
- [ ] Decide which of the 8 to keep. Then port them one at a time.

### M8 Polish (ongoing)
- [ ] Animations (crafting, travel, reveals), screen transitions, sound and
      music, haptics, a loading screen, performance on an older phone
- Animations move to AnimationPlayer timelines in the scenes, so the user
  can tune timing in the editor.

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
- 2026-11-15: M3 go: the user tested the Display Mat preview on the iPhone
  and it looks and feels right. The port continues with M4.
- 2026-11-15: The 5x5 BINGO card (an HTML Settings switch) is retired: not
  ported; the Market is 3 rows of 4. Goldens force `prefs.classicBingo = false`.
- 2026-11-15: `Game.craft(name, picks)` is the safe craft (asks for suit-cost
  picks); `craft_raw()` is the HTML game's unchecked rule, for replay only.
- 2026-11-15: Font = Nunito (user's choice), bundled (`assets/fonts`, OFL),
  for every device and the web. The HTML game still uses system fonts, so
  text widths differ slightly in comparisons.
- 2026-11-15: Styling is code (`Tok` helpers + components), not a Theme
  .tres: every CSS value sits next to the component using it, and the
  comparison checks it.
- 2026-11-17: **Reverses "styling is code":** the user wants to edit the
  game in the Godot editor. Screens and windows become scenes, repeated
  pieces become scenes placed by code, layout numbers are `@export`ed, and
  colours / fonts live in `ui/theme/tokens.tres` (M5.5, before M6). Rules
  and data stay in code. The HTML comparison still runs on every converted
  screen while the HTML reference exists.
- 2026-11-15 (plan review): goldens come from the simulator; rule tables
  are exported from the running game, never copied; no old-save migration;
  no pixel-difference overlay; comparison page built in M2.

## Open questions (for the user, when they come up)

- **Mini-games:** keep all 8, some, or none? (M7)
- **Sound and music:** source and style. (M8)
- **App identity:** store name, bundle id (e.g. `com.<you>.elementia`),
  developer account names. (M9)
- **iOS builds need a Mac:** own, borrowed or rented? (M9)
- **During the port, does the HTML game keep getting updates** (beyond data
  tweaks)? Every rule change then has to be made twice.
- **Godot location:** move it out of Downloads (e.g. `C:\Godot\`) so it doesn't
  get cleaned up; update "Setup facts" if it moves.
