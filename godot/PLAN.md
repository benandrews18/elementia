# Elementia in Godot: the plan

**Every session starts here:** `git status` (the user may have edited scenes
in the editor), then "Where we are" and the queue. Player-facing changes go in
`CHANGELOG.md` (the record the user keeps); the step-by-step history of the
port lives in git (this file before commit "PLAN.md trimmed", 2026-11-27).

## Where we are

The game is complete and playable (Classic Mode), published to the user's
Android phone and the website after every batch. Now: polish, sound, and new
mechanics. The 2026-11-27 whole-game review is in `REVIEW.md`.

## Work queue

One step at a time, in this order unless the user says otherwise.

1. Done 2026-11-27: **review fixes** (REVIEW.md 1-8).
1b. Done 2026-11-27: **Quick Rules** (Decisions 2026-11-27), all three parts.
2. **Sound effects** (no music: the user brings their own later). Kenney CC0
   packs (download approved, 2026-11-27): Interface, Casino (cards, chips),
   Impact. One `Sfx` autoload with a voice pool, `data/sounds.json`, SFX/UI
   buses with a limiter, a Sound switch in Settings. Plan in REVIEW.md.
   Skill: audio-system.
3. **Split the big files by job:** `display_mat.gd` (mat grid, combo chips,
   Lock-In count, hand play, bench, Inventory list), `app.gd` (router,
   CheckFlow, MarketFlow). Skill: scene-organization.
4. **Theme resource:** `Tok.box` styles into a `theme.tres` with type
   variations, editable in the Inspector. Skill: godot-ui.
5. **Folders by feature** (`ui/check/`, `ui/station/`, `ui/market/`,
   `ui/windows/` ...), moved in the editor so `.uid`s follow; comments lose
   their "(the user, date)" history notes (git has it).
6. **New mechanics (draft ideas: MECHANICS.md), designed first with godot-grill:** Catalysts (a choice
   of 2-4 passive rule-benders, awarded at points in the run), Stakes
   (difficulty the player picks at the start, like Balatro's), Mission mode
   (a set of items to craft, post-capstone ones included), Station events
   (mid-run effects, good or bad, often a choice). The user, 2026-11-27:
   choosing between 2-4 options is the heart of it.
7. Fixed motions to AnimationPlayer, a loading screen, a colour-blind check
   of the suit colours, profiling on the phone.
8. Release (M9): store builds, app identity.

## Ground rules

- **Godot is the game.** `game/` (the HTML prototype), `print/` and
  `archive/` are frozen history.
- **Content and tables stay in one place:** `data/game_data.json`. Tables
  built from them are computed (`Data.derive()`), never stored or copied
  into GDScript. A new item emoji: `python godot/tools/fetch_icons.py`.
- **The rules lock.** `tests/goldens` (in git) hold recorded rule steps;
  `tests/parity.gd` replays them. A rule change on purpose makes it fail:
  re-record with `parity.tscn -- --accept`, and the commit says why.
- **Rules never touch the screen.** `core/` and `game/` have no nodes, no
  drawing, no timers. Screens call actions and redraw on `state_changed`.
- **Saves:** a rule or data change must still load older saves
  (`Progress.upgrade()`, `saveVersion`).
- **Performance:** `check.py full` runs the redraw budget (`tests/perf.gd`).
  Scenes are instanced through `Tok.make()` (a scene nobody holds is re-read
  from disk by every `load()`).
- **One commit per logical change, on `master`.**

## Working with the user (standing rules)

- Each step ends with `check.py full` (or `release` when every screen or the
  hub changed), a commit, then `python godot/tools/phone.py` (skipped if no
  phone) and `python godot/tools/web.py "What changed"`, without asking; then
  the user compacts.
- A step building a new system loads its godot-prompter skill and reports
  the pattern picked (and the one rejected) before code; reviews use
  godot-code-review and ponytail-review/audit; open design questions go
  through godot-grill.
- Ask before any download (file, source, size). Noto emoji are pre-approved
  (`tools/fetch_icons.py`); the Kenney CC0 sound packs too (2026-11-27).
- Never push `master` to the site repo's `main`. The keystore and its
  password stay outside the repo. No personal info in external requests.
- Don't change CLAUDE.md. No parallel agent fan-outs.

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
- Export templates 4.7.2 are installed (web, Android, iOS).
- **Phone builds (Android, sideloaded; set up 2026-11-21):** everything lives
  outside the repo in `C:\Users\benan\Android\`: `jdk17` (OpenJDK 17),
  `sdk` (cmdline-tools, platform-tools, build-tools 35.0.1, android-35; no
  NDK/CMake, those are only for Gradle builds), the release key
  `elementia-release.keystore` (alias `elementia`) and its password in
  `elementia-keystore-password.txt`. **Losing the key means the phone app
  can't be updated** (reinstall, save lost): the user keeps a backup.
  Godot's editor settings point at the JDK and SDK (and
  `shutdown_adb_on_exit = false`, else each export drops the Wi-Fi phone). Preset "Android":
  arm64 only, app ID `io.github.benandrews18.elementia`, no Gradle.
  `python godot/tools/phone.py` builds the signed APK and installs it (`-r`
  keeps the save) on every phone adb sees; Wi-Fi pairing is once per phone
  (Settings > Developer options > Wireless debugging > Pair with code, then
  `adb pair IP:PORT CODE` and `adb connect IP:PORT`). Away from home: the
  APK goes to the user's Google Drive and they tap Install.
- **Web build (testers, iPhones):** preset "Web", no threads (GitHub Pages
  can't send the headers threads need); it is the website's root
  (benandrews18.github.io/elementia/; the HTML game it replaced is frozen).
  `python godot/tools/web.py "What changed"` checks, exports, copies over
  ../elementia-site and pushes main, then master to `source` (ask first).
- **Exports keep scenes as text** (`editor/export/convert_text_resources_to_binary=false`):
  Godot 4.7.2's binary conversion dropped overrides on instanced children
  (the welcome Play pill's hidden "OK" showed through, web and phone).
- **Always pass `--quit-after <frames>`** to test runs: a script error
  doesn't quit Godot, it just sits there forever. A run cut off there exits
  0 with no pass line, so never trust an exit code or a grep: run checks
  through `tools/check.py`, which needs the pass line too.
- **Which check when** (decided 2026-11-20; screens changed 2026-11-23,
  the user: the screen check cost ~100s every time):
  - after each change: `python godot/tools/check.py fast`, plus
    `--only <section>` when a play-test section covers what changed (`run`,
    `final_score`, `market`, `todo`, `cards`, `pins`, `tips`, `tutorial`...).
  - screens only when a look changed, and only that part's states:
    `--screens station,bench` (states whose names start with those; bare
    `--screens`: all). The screenshot window opens off-screen.
  - at the end of each step: `check.py full` (the whole play test).
  - before a release (a publish of a big batch, a milestone): `check.py
    release` (full and every screen).
  - an intended visual change: look at `build/after/diff_<state>.png`, then
    `check.py accept` (takes only the states the last run shot). The screen
    states are `tests/shot_states.gd`.
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
| Import assets (after new art) | `G --headless --path godot --import` |
| Every check, with a clear PASS/FAIL | `python godot/tools/check.py fast [--only market]` / `full` (+ redraw budget) / `release` / `accept` |
| Rules lock | `G --headless --path godot --quit-after 600 res://tests/parity.tscn [-- --accept]` (accept: after an intended rule change) |
| Icons for new item emoji | `python godot/tools/fetch_icons.py` |
| Rule tests (button-only rules) | `G --headless --path godot --quit-after 600 res://tests/rules_test.tscn` |
| The play test (or one section) | `G --headless --path godot --quit-after 20000 res://tests/ui_play.tscn [-- --only market]` |
| Phone build (+ install) | `python godot/tools/phone.py [build]` |
| Web build (+ publish: ask first) | `python godot/tools/web.py build \| "What changed"` |
| Screenshot | `G --path godot --quit-after 300 res://tests/shot.tscn -- --screen <res path> --out <png> [--save <json>] [--scale 2]` |
| Icon sheet | `--screen res://tests/icon_sheet.gd` |
| Before/after screens | `python godot/tools/shot_diff.py shoot godot/build/after [state ...]` (one Godot run) then `... diff godot/build/before godot/build/after` |


## Architecture

```
godot/
  data/game_data.json   the rules' data (DATA, tables)
  core/                 rules: plain GDScript, no nodes
  game/                 autoloads: Game (the run, actions, signals),
                        Progress (prefs, trophies, history, saving), Rng, Dev
  ui/
    app.gd              the root: screens, panels, the hub, the run's flows
    theme/              Tok (styles, labels, icons, the scene cache), Juice
                        (press feedback, motions), tokens.tres, fonts, shaders
    components/         ItemCard, ShopRow, HubBar, RefTree ...
    pieces/             small scenes (chips, pills, rows)
    screens/            map, station, display_mat, items_screen, welcome
    overlays/           windows, trays, pop-ups
    tutorial/           the scripted first run, hints, Professor Mouse
  assets/               icons, backdrops, banners, frames, fonts
  tests/                parity, rule tests, play test, perf, screenshots, sim
  tools/                check, phone, web, shot_diff, sim, fetch_icons
```

- **A screen:** `Game` holds `state` (a Dictionary, saved as JSON). A screen
  calls `Game.craft(item)`; Game runs the rule in `core/`, saves (at the
  frame's end) and emits `state_changed`; open screens rebuild. A screen
  under an opaque panel (the Display Mat, the Codex) is hidden and rebuilds
  when it shows again (`stale`).
- **Screen size:** 390x844, stretch `canvas_items`, aspect `expand`; the App
  sits inside the safe area (`App.local_rect()` for global rects).
- **Randomness:** rules use the `Rng` autoload only; visual randomness uses
  Godot's own.
- **Editing in the editor:** `EDITING.md`.

## Decisions

Recorded so they aren't re-argued. Add new ones with the date.

- 2026-11-27 (the user, Quick Rules grill): **a second tutorial, Quick
  Rules**, to compare with the guided one. The Play menu gets **Back** (to
  the title screen) and **How to Play** (Guided Tutorial or Quick Rules).
  Quick Rules builds the game up one part at a time on real screens (bare
  map, stations, hub buttons, Market, a capstone card, a challenge, a
  station visit, the map, convert, the clock) with Next; key moments also
  take the real tap (roll, gather, craft, travel, convert), sparingly.
  - **Delivered in three parts**, each published: (1) menu, map, hub,
    Market, capstone card; (2) the challenge; (3) station, map, Ocean,
    convert, clock.
  - **A demo, never saved**: a throwaway run like the Combo Lab; the real
    save is untouched.
  - **Text in a parchment card, no Professor Mouse**; it moves to keep
    clear of what it shows.
  - ~~The first New Game asks Guided Tutorial / Quick Rules / just play~~
    (replaced 2026-11-27, the user: **the first New Game plays Quick Rules**,
    no choice; the Guided Tutorial is out of the menus for now).
    Quick Rules there goes **straight into the new game** at its
    end; replays (How to Play) end **back at the Play menu**.
  - **✕ to leave, asking first.**
  - The 16-element rows: **by suit, then atomic number** (H C N O · P S K
    Ca / Mg Al Si Ti · Fe Ni Cu Ag).
  - Built (our choice): a QuickRules node with its steps as resources on
    its scene (editable in the Inspector, like the Tutorial's); each step
    stages the screen itself (hide/slide hub buttons, open a tray, play a
    card) and only Next, ✕ and the step's own target take taps. Rejected:
    reusing Tutorial/TutorialStep (its steps wait on the player's real
    progress and resume from a save; Quick Rules drives the game itself
    and is never saved); and still pictures of screens (they'd drift from
    the game).

- 2026-11-26 (the user, step 22 grill): **tracking as quests.** Long
  questline games keep one objective on screen, chapters with counts,
  progress worked out from what's owned (side trips never break it). The
  To-Do List keeps the component tree as a quest path: the capstone (or
  any pinned item) on top with a parts bar, its direct parts as chapters,
  one level per tap, never opening on its own. **Not directive**: no NEXT
  tags, no "Next:" line, no suggested pick; rows show facts (parts count,
  where made, ✓ owned, a green dot when craftable now); the player chooses.
  The quest holding the tracked item is open at the top; other pinned items
  are folded one-liners. **Pin and track are separate**: pinning (to come
  back to) never tracks unless Settings' "Auto-track on pin" (off by
  default) is on; the first pin asks "Track it now?" with "Don't ask
  again" (remembered as that setting). In the To-Do tree rows have only 🔍
  Track; tracking a part pins it (its own quest); 📌 sits on quest headers
  (drop the quest). **Crafting the tracked item stops tracking**, with a
  "!" on the 🔍 button: players keep setting their own goals. The shop's 🔍
  circle opens the compact list lit on that item. The suit pill always
  shows beside ⚛️. Opening: no part suggested, only a tip. The map reveal
  (one station, then the rest bounce in) plays every run. Rejected: auto
  next step, a reward per tracked craft, tracking moving up a level.
  A run starts with nothing tracked, and Start stays locked until the
  player tracks something (a line above Start says so). Assumed: Get a Hint
  stays, opt-in; the suit pill's totals are the elements owned per suit.

- 2026-11-26 (the user, step 17 grill): **capstones leave the mat.** Every
  crafted capstone is always on, beside the mat: no slots, never drawn
  (out of the deck). It counts like a card on the mat: its points (x2 with
  its whole recipe on the mat), station and suit combos, named
  collections and requests; restrictions ignore it (only played cards, so a
  restriction can always be kept). Ecosystem's streak becomes every check
  since it was made. The mat keeps its size (the 2 capstone slots are card
  slots). Plays and discards take any number of cards (HAND_PLAY_MAX and
  HAND_DISCARD_MAX go; still HAND_DISCARDS discards a check); tier 1
  flooding: no other change for now (revisit if it still floods).
  Requests at rounds 3-15 (new: Rainbow, all 4 suits on the mat; Grand
  Tour, cards from 5+ stations); restrictions only at 18 (easy) and 21
  (hard); "mostly new cards" (freshFaces) gone. Each Market square pays an
  Unknown Element when crafted; a finished row pays nothing. Main Menu from
  the end screen ends the run (no Continue). Re-tune the breakpoints after.
- 2026-11-24 (the user, step 16): the run's breakpoint gates don't end the
  run while testing (data `BREAKPOINT_GAME_OVER: false`; a miss just earns no
  bonus dice; Overtime still ends on a miss). Checks get a Done button (asks
  if a hand card still fits) and a preview of the picks' combos and points
  before Play. Tier 1 cards: two stand as tall as a tier 2 card, in the shop,
  the Inventory and on the mat. A 💡 on every craftable shop card (fades in
  once a visit). A shop card's suit circle fades when no element of that
  suit is held; owned cards never fade them. The clock's rim dots are gone.

- 2026-11-21: Cutover (the user): the HTML game is frozen and abandoned; the
  game is Godot only, released as the phone APK and the Godot web build;
  the print pipeline is dropped. See "Cutover".
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
  are exported from the running game, never copied; no HTML-save import (app saves are upgraded: see Same save format);
  no pixel-difference overlay; comparison page built in M2.
- 2026-11-21 (godot-prompter review, REVIEW.md): **Skills drive each step:**
  the matching godot-prompter skill is loaded before each step (listed on
  the steps) and godot-code-review runs at each step's end, alongside
  ponytail-review. **No parallel agent fan-outs** (they used up the usage
  limit); agents only when asked, one at a time. **Tests stay in
  check.py** (no GUT/gdUnit4: third-party code for little gain over the
  parity, rule, play and screen checks). **A mid-visit quit keeps the
  visit, in Godot only** (the HTML game keeps its behaviour; a deliberate
  parity exception). Low-processor mode on (the screenshot tools turn it
  off to draw every frame).
- 2026-11-22 (card playing, godot-grill with the user): **built first as a
  Challenge Test in the Combo Lab**; real checks switch over once it plays
  right. The test's deck is the **real run's items** (so Dev Panel tweaks
  shape it), the real run is never changed or saved by it. **The last
  check's mat stays** at a check's start; the deck is every owned card not
  on it. **Tap a hand card, then tap a slot** (empty: play there; a card:
  replace it, the old one to the discards); drag maybe later. Mat cards
  leave **only by being replaced** (no plain removal mid-check). The test
  starts with a **round picker** (the check rounds; mat size and challenge
  follow). **Lock-In** in the test plays the real count, shows the reward
  that round would give, then goes back to the lab.
- 2026-11-23 (card playing, the user): the mat stays between checks, but a
  check gets a **budget of plays and discards** (numbers in game_data.json,
  tuned by play; may grow over the run), so the deck can't be cycled
  through. Cards crafted since the last check form a **fresh side deck**
  dealt first; after it the rest are shuffled back into one deck. A
  **lifted card shows the score change** on each slot before it's played.
  Taking control of the mat: **Rehang** (all of a check's plays: the
  whole mat back into the deck, a bigger hand to rebuild from), **Take
  back** (a discard: one mat card back into the hand), **Frame** (one mat
  card stays through a Rehang; its cost still to settle). No time cost
  (no giving up visits). **Element draws:** 1 stock element of a suit
  draws a card with that suit's pip, always 1 for 1 (elements are already
  precious for crafting); an unknown element token draws any card the
  player picks. The convert tray (work queue 7) works during a check, so
  converting for a draw is a choice too.
- 2026-11-23 (card playing, the switch-over, the user): **Frame** holds up
  to 4 squares of mat cards through a Rehang (tier 1 = 1, tier 2/3 = 2, a
  capstone = 4, any mix). **A check in progress is saved** (hand, deck,
  budget) and resumes after the app closes. **Between checks the mat is
  locked in**, not adjustable; the **Combo Lab** is where players try
  combos freely, with all the old mat UI and features from before card
  playing (the two swap: real checks get the hand, the lab gets the old
  free mat). Hand 7, Draw 2, 10 max, 3 plays, 3 discards at every check
  for now. Spending an element on a draw asks first; a lifted card tapped
  onto the Elements page goes back into the hand.
- 2026-11-23 (UI feedback pass, step 6, the user): **mixed feel**: a light,
  quick squish-and-spring on every button, card and menu press (~93%,
  springs back with a small overshoot); game moments get more (a played
  card flies from the hand to its slot and settles, a replaced card slides
  off to the discards). Windows pop in with a soft bounce (backdrop fades,
  window from ~90% with overshoot) and shrink out quickly. **No sound
  yet** (M8; the press helper leaves room for it). **Haptics on key
  moments only** (card played, craft, Lock In), with a Settings switch.
  A **Low motion** switch in Settings with this step.
- 2026-11-23 (tutorial overhaul, step 9, the user; godot-grill):
  **First play is a scripted real run** on a fixed seed (known dice and
  shops): each step waits for the player to do the thing, and **only the
  step's target works** (the rest dimmed, ignoring taps). It runs
  **through the first Lock In** (stations, rolling, crafting, converting,
  the map, the first check played with cards), then the run carries on
  unscripted; it **counts as a real run** (History, trophies, capstones).
  **Everyone gets it once**: their next New Game after the update, old
  players too. **Skip at any time** (asks first); Settings' How to Play
  replays it. **Professor Mouse stays, calmer**: a small docked bubble and
  a spotlight on the one thing to tap, never covering it, never a surprise
  popup. **Later plays: very subtle hints**, not like the tutorial: a tiny
  💡 badge on the thing it's about (one soft fade-in, nothing more); a tap
  shows the hint with "Don't show again"; each shows once a run until
  hidden; Game Rules' switch turns them all off. **The old one-off windows**
  (the 3 How-to-Play slides, Periodic Table intro, 16 Elements, Display
  Mat rules, Challenges tip, Pin tip, Unknown Element tip) fold into
  tutorial steps or hints and stop popping on their own; they stay
  readable in Settings' Tutorial Messages.
- 2026-11-21: Settings switches and title-screen buttons for features that
  don't exist yet (Mini-Games, Auto card, Low motion, 5x5; Mini-Games,
  Combo Lab, Collections, Trophies) stay hidden until their features land.

- 2026-11-23 (the check reworked, the user, after the gameplay-loop talk):
  **The mat clears at every check** (rebuilding it from the newest cards
  was always the heart of a check; carrying strong boards over, or loading
  saved ones, spoiled runs). **"A card laid is a card played"**: nothing
  comes off the mat until the check ends (no Take Back, no mat discards),
  so a check really ends and wasted tier 1 cards can leave holes. **The
  mat's size ends the check** (it grows over a run as before); plays are
  unlimited, 1-5 cards each, **placed automatically** (score never depends
  on position). **Scoring: "anything you make in one play counts twice"**:
  the finished mat scores as before, and every combo made inside a single
  play counts once more (a suit/station/ingredient combo adds its bonus to
  the multiplier again; an item played with its full recipe scores x3, not
  x2; a collection completed in one play adds its bonus again; a combo that
  grows over plays scores at its final size plus the size played together;
  capstone effects only once). Rejected: per-play scores multiplied again
  at the end (compounds too fast), flat per-combo bonuses (a new table, no
  answer for complete items). **The hand refills 1 for 1** after every
  play and discard; **3 discards of up to 5 cards**; element draws (the
  Draw button, flipping the mat to its Elements side) are the paid way to
  grow the hand, up to 10. No check deck (too much management): discards
  out for the check are the deck thinning, a gamble. Supersedes the 2026-11-23
  "Hand 7, Draw 2, 10 max, 3 plays" and step 13's Take Back and mat
  discards.


## Open questions (for the user, when they come up)

- **App identity:** store name, bundle id, developer account names. (M9)
- **iOS builds need a Mac:** own, borrowed or rented? (M9)
- **Mini-games** (from the HTML game): keep any? Deferred.
- **Godot location:** move it out of Downloads (e.g. `C:\Godot\`) so it
  doesn't get cleaned up; update "Setup facts" if it moves.

## Log

One line per batch (details: CHANGELOG.md and git).

- 2026-11-27: whole-game review (REVIEW.md); review fixes; PLAN.md trimmed.
- 2026-11-27: tutorial strict (Tutorial last in the App for input; animations and the peek card aren't windows; a real window takes taps only inside itself; ui_play decoy taps every step); Mouse on the hub, balloon off the target, x/y counts; desktop web letterboxed (main.gd: KEEP aspect without a touchscreen).
- 2026-11-27: F11 on the web (head_include stops it reaching Godot's canvas); map reveal waits for the map in view (opening doesn't mark neighbours seen); Market Unknown squares open UnknownTip; Display Mat Score and Quark Combos texts.
- 2026-11-27: empty first check: App.auto_lock_in (the mat's self-ending check goes through it) shows Mouse's two lines (1/2, 2/2) behind a blocker, then hand_lock_in; not in the tutorial, the final check, a Challenge Test, or once matChecked.
- 2026-11-27: the details' track tip and Mouse's "tap its 🔍" draw the Noto image (no emoji in text); StartLock shows a round 🔍; the opening's Track glow is rings outside the button (draw_arc for round ones), nothing inside.
- 2026-11-27 (the user): Quick Rules' Professor Mouse: tools/mouse_poses.py cleans art_reference/mouse_poses (stray pieces, the coat made opaque) into assets/mouse_qr/*.webp; QuickStep.mouse (a pose; "": MOUSE_TOWARD by step, facing the spot, a lean toward it); QuickRules._place_mouse: on the hub, or on the card's top edge when it sits low; under the card.
- 2026-11-27 (the user): station shop cards: no_name + the Market's name label under (MarketTray.NAME_PX/NAME_H), bigger icon_px; Tok.icon outlines every item picture (Tok._is_item: ITEM_EMOJI values; a caller's material replaces it); MatRules: 3 pages (Next2; App.show_tip mat_rules3), _recipe_tree (double_item); screens all re-accepted (outlines).
- 2026-11-27 (the user): Quick Rules' text: QuickCard.keep_together (NBSP before a {picture}, after one starting a line, on each line's last space run; U+2060 after hyphens: HarfBuzz hides it, ICU won't break there; verified line by line); pictures at PX + 6; more pictures in the steps; the center button's {ui:discard} is {🃏}. The quick test checks every {token} resolves to an image and no device emoji is left in the words.
- 2026-11-27 (the user): Quick Rules is the only tutorial in the menus: the first New Game plays it (no TutorialPick: deleted), How to Play (Play menu, Settings) = App.replay_tutorial() = Quick Rules. The Guided Tutorial stays in the code (App.new_game(true); its test section starts it there) until the user wants it back.
- 2026-11-27: Quick Rules part 3 (two stations): acts visit/travel (ctx without go_station's first-visit pin), roll (a set roll in RollPopup), gather, bench, craft, pin, todo, detail, close, map, reveal (MapScreen._reveal on qr.stations), floats, pins, track, select, convert, cvopen/cvload/cvgo, clock; waits arrive/roll/gathered/crafted/reveal; QuickStep.tap (a real tap on a spot = Next); extra "pool"; ctx.qr flags paths/track/floats/convert/clock gate the map's paths and clock, the station's Settings and Convert, the 🔍 tracker and Track buttons (QuickRules.no_track). Its own pins (prefs restored; prefs not written in ctx.demo). Screens quick_pool/finds/convert/clock (shot budget per quick state 3000 frames); ui_play --only takes a comma list.
- 2026-11-27: Quick Rules part 2 (the challenge): QuickRules acts inventory/items/deal/play/discard/view/draw and lock_in() (App.hand_lock_in defers to it); QuickStep.wait ("mat", "reward", game time); the challenge's cards exported on quick_rules.tscn; Mat.stage honours state.demoStage (an 8-slot mat at turn 3's breakpoints); no Market moment, collection reveal or "New collection!" in ctx.demo. Juice.fly keeps a weakref to its slot. shot_batch waits on a state's `busy`; screens quick_hand, quick_reward.
- 2026-11-27: Quick Rules part 1: QuickRules (ui/tutorial: steps as QuickStep resources; Game.ctx.demo never saved, ctx.qr filters the map and hub; a multi-hole spotlight shader), QuickCard, TutorialPick (How to Play; the first New Game asks once), Play menu Back; emojify takes {ui:...} and tinted {suit:...}. Test section "quick"; screens tutorial_pick, quick_*.
- 2026-11-27: RefTree.suit_row(ringed) gives the breakdown the suit strip's rings; Named Collections' ★ is a drawn star in the banner's icon spot.
