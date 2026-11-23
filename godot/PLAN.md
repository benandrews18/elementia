# Elementia in Godot: the plan

The living plan for rebuilding Elementia in Godot 4. **Every session working
on the Godot version starts here:** read "Where we are", do the next open
task, and update the log before finishing.

Decided 2026-11-15. The HTML game in `game/` is the working prototype and the
reference for every rule and screen until the Godot version replaces it.

---

## Where we are

**Current milestone:** Cutover (M6 done; M7 deferred; M5.5 done, bar the
user's own first edit in the editor)
**Next task:** step 9 part 3 of the work queue below (the 💡 hints). Start every session with `git status`: the user may
have edited scenes in the editor.
Publish every finished batch to the phone (`tools/phone.py`; skip it if not
connected) and the website (`tools/web.py "What changed"`), no ask (the user).

**Work queue (agreed order, 2026-11-22).** One step at a time. Each ends
with `check.py full`, a commit and a publish to both places, then a compact.
Each step that builds something new loads its godot-prompter skills first,
reports the pattern picked (and the one rejected) before code, and runs
godot-code-review at its end. A step with open decisions settles them first
with `godot-grill`.
1. Done: **List + side card view** in the Inventory and at stations (📋
   switches). Both views stay for now (the user is torn, 2026-11-22). The
   grid's cards lost their Pin / Craft: a tap puts the card on the
   Crafting Bench, which crafts and pins.
2. Done: **The Display Mat growing** on rounds where it gets bigger, in the check's
   reveal. Skills: tween-animation, animation-system.
3. Done: **Cutover C5:** the capstone celebration, the unlock reveal, the
   after-craft mini card. Skills: tween-animation, particles-vfx, godot-ui.
4. Folded into step 5 (the user, 2026-11-22): the **tier / display-size
   badge** exists to tell the player how much mat space a card takes when
   played, so it is designed with the hand, not ahead of it.
5. **Drawing and playing cards at checks** (designed below). Skills: godot-brainstorming for the design (scenes, state, save
   format), state-machine (the check's phases), save-load (old saves still
   load), godot-ui and hud-system (the hand), tween-animation (draws, plays,
   discards). It takes the mat out of the Inventory between checks and adds
   the Combo Lab button there.
   Progress (2026-11-22): the rules (core/hand.gd, rule tests) and the
   Combo Lab's Challenge Test (round picker, fanned hand, Draw +2,
   Discard, plays, Lock In back to the lab) are in; the size badge (full
   card, Crafting Bench, hand cards) and the hand's layout (right sides
   show; a tapped card lifts out as the full card) too (2026-11-23).
   Part 1 done (2026-11-23): the play and discard budget, the fresh side
   deck, the score preview, the hub during a check (Draw in the middle;
   Challenge, Discard, Scoring, Lock In) and the hand in two fans. Next:
   the user tries it.
   Part 2 done (2026-11-23): Rehang (the hub's 4th button, where Scoring
   was; the mat's "?" still has the rules), Take Back (tap a mat card: the
   hub's Discard turns into it), element draws on the mat's Elements tab
   (tap an element: 1 of it draws a card of its suit; "?" picks any deck
   card). The Convert button shows during a check and works exactly as in
   normal play (the user: no converting straight into a card; converting
   to a better suit before a draw is the player's choice). Draw stays one
   tap for 2. Switch-over
   done (2026-11-23, committed): real checks deal a saved hand, Lock In on
   the hub, the mat locked between checks, the Inventory's Combo Lab (the
   run's items), Frame. Reviewed (godot-code-review; one fix:
   the hand saved right after the deal). Step 5 is done. Second review
   (2026-11-23, ponytail-review + godot-code-review/optimization/scene-
   organization; the user: fix everything): the hand is dealt when the
   check's mat opens (Game.deal_hand() from App.open_panel; check_hand() a
   plain getter); lifting a card redraws only the hand and a layer over the
   mat (99ms -> ~33ms a tap on a PC); the preview scores the mat once; the
   free-play bubble sits where the card lands; "?" with a full hand says
   so; the map/station skip redraws under the Display Mat. Left for the
   swap of the two play spaces: the check table as its own screen
   (display_mat.gd holds both jobs, ~230 lines of hand code). 
   The hand (the user, 2026-11-22): fanned at the bottom of the screen like
   Hearthstone or Balatro. Every card in it must still show what matters
   at a glance: its size on the mat (the tier / display-size badge), its
   bonuses, its name. The card UI gets refined as part of this step.
6. Done (2026-11-23): **UI feedback pass** (decisions below). Juice
   (ui/theme/juice.gd, one node in the App): every press squishes and
   springs (offset transform, hooked on node_added: ~2ms on a 300-node mat
   redraw, nothing per frame); windows pop in and shrink out (a closing
   one moves into its own holder at once); trays rise in; a played card
   flies to its slot, a replaced one drops away; buzz on key moments
   (Android); the map's dust poof (tweens on their own random numbers:
   particles would shift the dice's global stream); toasts pop. Low motion
   and Vibration in Game Rules. Low motion doesn't yet shorten the older
   sequences (shutter, dice, Lock-In count): M8. Reviewed (one fix: a
   reparented node was hooked twice). Second review (godot-code-review +
   tween-animation/animation-system/particles-vfx; the user: fix
   everything): every motion and its numbers live in Juice, tunable in the
   Inspector on ui/theme/juice.tscn (grouped: Press, Windows, Trays, Card
   play, Dust, Buzz); one Juice tween per node (a new motion stops the old:
   no window wobbling when closed mid-pop); a small card flies with its
   small look; tests for the pop, the holder, Low motion and the flight.
7. Done (2026-11-23): **Convert tray taps** (the user, 2026-11-22; HTML reference: game/js/
   convert.js, renderConvertPicker() / renderConvertQuickGrid()): a tap on
   either big From / To box opens a window to choose that side's element;
   a tap on an element in the rows above puts it on the From side; a tap
   on a missing element in the Crafting Bench card's component list opens
   the Convert tray with it on the To side.
   The box taps, the picker and the quick grid were already in (convert_
   tray.gd, element_picker.gd), as was the full card's missing element;
   added: the Crafting Bench row's missing chips (ShopRow, meta "need:").
   Left out: the HTML's goal card in the tray (the item that sent you).
8. Done (2026-11-23): **The craft animation** (the user, 2026-11-22; port it carefully from
   the HTML, it took a while to get right: game/js/craft-animations.js,
   flyIngredientsAndReveal(), riseIntoStack(), fireworkBurst(),
   punchInventory()): the spent elements fly out and pop; the items the
   player keeps poke up from the bottom of the screen and go back down to
   show they're kept. Run the HTML in the browser pane to watch it.
   Skill: tween-animation (particles-vfx for the pops).
   Built in Juice (group Craft in the Inspector): craft_spend (the
   squares rise, pile fanned, pop; firework on Juice's own random numbers),
   craft_keep (kept items' mini cards under the hub), App._on_crafted
   (the small card waits for the pop; the Inventory bounces when the kept
   cards are down). Game.last_tax: the suit cost paid, shown as squares.
   Low motion: none of it plays. Not watched side by side with the HTML.
9. **Tutorial overhaul** (the user, 2026-11-23; big, plan and brainstorm
   it properly first: godot-grill, then godot-brainstorming). The Professor
   Mouse tutorials are obnoxious and don't flow. Replace them with:
   (a) a full interactive tutorial the very first time a player plays,
   tapped through step by step to learn the whole game (stations, rolling,
   crafting, converting, the map, checks played with cards, Lock In); and
   (b) in-game hints on later plays, each of which the player can choose to
   hide from then on. Start by listing every tip and coach step the game
   has now (prefs hiddenTips, guidedTutorialEnabled, sawMatCheckTutorial,
   the coach steps in App) and what each teaches.
   Grilled (2026-11-23; see Decisions). Today's tips: the opening's 3
   How-to-Play slides (classicTut; goal, gather & craft, the mat); How to
   Play's Periodic Table + 16 Elements windows and 7 coach steps (the
   hub's buttons, the gear); Mouse's once-ever walkthrough tips in
   App._walkthrough (firstroll, firstcraft, firstconvert,
   converttapmissing, gomap, checkmarket, pintrackshop) and the Pins
   tray's pinselect (prefs.tutorialHintsSeen); the windows: Display Mat
   rules at the first check ever (sawMatCheckTutorial), the Challenges tip
   (orderTip, once a run), the Pin tip (pinTip, capstone choice), the
   Unknown Element tip (sawEmptyElTip).
   Design (godot-brainstorming, 2026-11-23; the user: "go with your
   intuition"). Pattern: **the script as data, one driver**: TutorialStep
   resources (say, pose, target tag, until, done_if, dice, free) listed on
   ui/tutorial/tutorial.tscn (editable in the Inspector), run by Tutorial
   (a Node in the App). Rejected: steps hard-coded (not editable) and a
   node per step (~20 tiny scripts for "say, point, wait").
   - Targets: "hub:<id>" (a hub button) or a cmp tag (prefix) anywhere in
     the App; looked up each frame until found (popups appear late).
   - Locking: Tutorial._input marks every press outside the target (and
     the bubble) handled; a tap on the target advances (until "tap"), or
     the step waits on its done_if (a state test: rolled, owns:X,
     screen:map, at:<station>, lifted, played, visit:N...). until "next":
     Mouse's Next. free: nothing locked, waits on done_if.
   - Calm Mouse: MouseTip docks on the side away from the target; its
     "✕ Hide" becomes "Skip tutorial" (asks first).
   - Dice: a step's dice are fed to Rng (each face (i+0.5)/6); every step
     also reseeds Godot's random (seed(i)), so the check's deal and
     challenge come out the same.
   - Save: prefs.tutorialStep (the index; -1 off). Missing tutorialSeen:
     the next New Game runs it. Resume: back up over steps whose done_if
     isn't met yet (a bench that closed with the app), then skip forward
     over steps already done.
   - While it runs: no How-to-Play slides, Pin tip, Display Mat rules,
     Challenges tip or Mouse walkthrough tips (folded into steps).
   The route: Coral Reef at The Ocean (visit 1: roll H O N N; Water; Seaweed
   keeps the Water; Limestone's missing C via its chip and Convert 3 N);
   the map to Old Growth Forest (visit 2: roll Al Mg O P; Sand, Clay, then
   Soil from items only); Greenhouse (visit 3: roll C O K N, free: Sugar
   and/or Fertilizer, then the Map); travel: the first check (the hand,
   lift, play, Draw, Lock In); then "You're on your own".
   Parts: 1 the driver, Mouse's docking and Skip, visit 1; 2 visits 2-3,
   the check, the old windows folded; 3 the 💡 hints replacing the
   walkthrough tips.
   Parts 1 and 2 done (2026-11-23): ui/tutorial/ (Tutorial, TutorialStep,
   48 steps on tutorial.tscn), MouseTip.coach(); a play test taps through
   it all through the viewport (the lock, Skip, resume, replay). Found on
   the way: the tap that moves on must reach the target itself (a fade
   covering it doesn't count); a slow tap (Start, Collect, Travel) waits
   on its done_if, or the next step's dice get fed early (start_run draws
   for the Market); a window the step doesn't point into (New
   collection!) puts the tutorial aside, unlocked; so do the title screen
   and the Combo Lab. Settings' How to Play: the tutorial again (asks: a
   new game); the old walkthrough (start_coach, 7 hub steps) is gone; the
   Periodic Table + 16 Elements are a Tutorial Messages row. Open for the
   user: by the first check the mat already holds the run's cards, so
   "tap the mat to play it" replaces one (a negative score change shows).
   Next: part 3 (the 💡 hints).
10. **General fixes** (the user, 2026-11-23):
   (a) the station shop's card view: bigger item image and text to fill
   the cards, one standard image and text size that suits tier 1 up to
   capstone-sized cards; the card's icon circles the same size on every
   card (tier 1's points circle is smaller now);
   (b) the Crafting Bench's close "x" in its top-right corner, not the
   bottom right;
   (c) the gathering window (the roll popup) slightly smaller, to fit its
   contents;
   (d) the Inventory button bounces when an element or item flies into it,
   and every fly-in lands in its middle;
   (e) the station shop must show clearly what's craftable (the green
   border is too subtle) and what could be crafted with a conversion (the
   bench's ⚛ on missing elements, but visible from the shop itself), now
   the Craft buttons are gone. Open design: godot-grill first.
11. **General fixes, batch 2** (the user, 2026-11-23):
   (a) the hub's centre button showing a station (the "shop" face): its
   background the same colour as the map's station icons, not orange;
   (b) trays slide in from their own sides: the To-Do List from the left,
   the Convert tray from below, the Market from above;
   (c) the map's clock slightly larger, with small round markers around its
   edge for important moments (Display Mat expansions, check rounds);
   (d) the Inventory's minimised Display Mat (the "^" button under the mat):
   the format the HTML game had (port it from game/; look it up there);
   (e) the tracked items tray (the 🔍 pins tray): a tap on the map hides it;
   it comes out further from the bottom (its own button covers it now);
   bigger icons and text; a title "Pinned Items - Tap an item to track
   it!";
   (f) the tutorial's words name elements by their real names ("Carbon",
   not "C");
   (g) a check's restricted icons: the red cross-out drawn on top of the
   icon, not beside it, in the restriction description window.
 and unlimited (up to the hand's
10). Tap-to-mat is dropped from the Inventory but belongs in the Combo Lab
(now a main game feature): tap a card in the list to put it on the lab's
mat, tap it on the mat to take it off (part of step 5).

Log (newest first, one line per session):
- 2026-11-21: godot-prompter review (5 passes in REVIEW.md) and its fixes:
  safe saves, one save per action, low-processor mode, Items screen
  ~360 -> ~28 ms, Tap.tap (a drag isn't a tap), mid-visit resume (Godot
  only); checks stop re-shooting screens after a commit. Planet redesigned
  (both games). M6 step 4: the title screen and the Classic window. Step 5:
  Trophies and History. Step 6: the tracked item. Step 7: Professor Mouse,
  the tips and How to Play. Step 8: Saved Layouts, Collections, Combo Lab.
  Step 9: dev mode. Step 10: the M6 review (ponytail-review and five
  godot-prompter skills; 6 small fixes; M6 done).
- 2026-11-20: M6 planned (10 steps); step 1 done: the card pop-up and the
  element card, opened by taps across the screens. Step 2: the Items
  screen. Checks skip the screenshots when nothing visual changed. Step 3:
  Settings and the rules windows.
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

- **Godot is the game (since the cutover, 2026-11-21).** `game/` is the
  frozen HTML prototype: history, never a reference to sync with.
- **Content and tables stay in one place:** `godot/data/game_data.json`
  (`DATA`: stations, dice, shops, capstones; plus the plain tables:
  `ITEM_SUIT_COST_TABLE`, `LOCKIN_ROUND_ANCHORS`, `MAT_COLLECTIONS_RAW`,
  `MAT_GROW_ROUNDS`, the BINGO/Market constants ...). Tables built from
  them are computed (`Data.derive()`), never stored. Never copy a table into
  GDScript. Anything holding functions (e.g. the challenge checks) is code.
  A new item emoji: `python godot/tools/fetch_icons.py`.
- **The rules lock.** `tests/goldens` (in git) hold recorded rule steps; the
  parity test replays them. A rule change on purpose makes it fail: then
  `parity.tscn -- --accept` re-records, and the commit says why.
- **Rules never touch the screen.** Rules code (`core/`) has no nodes, no
  drawing, no timers. Screens only call actions and read state. This is the
  one structural rule the HTML game didn't have, and it's what makes the
  parity tests and a later simulator possible.
- **Same save format.** The Godot save is the same JSON shape as the HTML
  game's `state` object, so the same save loads in both. That powers the
  tests and screenshots. HTML saves aren't carried into the app (app
  players start fresh; an importer only if that becomes a real feature).
  The app's own saves do get upgraded: a save version and the `loadAll()`
  clean-ups, before M9 (review finding 5, 2026-11-21).
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
- **Which check when** (decided 2026-11-20):
  - after each change: `python godot/tools/check.py fast`, plus
    `--only <section>` when a play-test section covers what changed (`run`,
    `final_score`, `market`, `todo`, `cards`). Its screenshot part runs only
    when something that can change a screen changed since the screens last
    passed (`build/screens_ok`; `--screens` forces it). The screenshot
    window opens off-screen.
  - at the end of each step, and before a review, a milestone or a publish:
    `check.py full` (everything, the whole play test, the HTML comparison
    report). Not after every small change.
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
| Import assets (after new art) | `G --headless --path godot --import` |
| Every check, with a clear PASS/FAIL | `python godot/tools/check.py fast [--only market]` / `full` / `accept` |
| Rules lock | `G --headless --path godot --quit-after 600 res://tests/parity.tscn [-- --accept]` (accept: after an intended rule change) |
| Icons for new item emoji | `python godot/tools/fetch_icons.py` |
| Rule tests (button-only rules) | `G --headless --path godot --quit-after 600 res://tests/rules_test.tscn` |
| The play test (or one section) | `G --headless --path godot --quit-after 20000 res://tests/ui_play.tscn [-- --only market]` |
| Phone build (+ install) | `python godot/tools/phone.py [build]` |
| Web build (+ publish: ask first) | `python godot/tools/web.py build \| "What changed"` |
| Screenshot | `G --path godot --quit-after 300 res://tests/shot.tscn -- --screen <res path> --out <png> [--save <json>] [--scale 2]` |
| Icon sheet | `--screen res://tests/icon_sheet.gd` |
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
Planned 2026-11-20 from `game/js/` (~2,500 lines). Every new screen and
window is a scene from the start (M5.5 rules); each step gets shot states
(`tests/shot_states.gd`) and, where it's tapped through, a play-test section;
`tools/check.py fast` per change, `full` at the end of each step.
Order (each makes the next useful):
- [x] 1. Card pop-up (`card-popup.js`): `ui/overlays/card_pop.tscn` (an
      item's card; a capstone's landscape with its rule, grown to fit;
      drill into a component, Back, 📌) and `element_card.tscn`. Opened from
      station chips and crafted icons, the map card, owned Market squares
      and capstones, To-Do rows (`App.show_card` / `show_element_card`).
      Within ~3px of the HTML (compare shots cardpop, cardcap, elcard).
      Later: Item Info (with step 2); the capstone celebration, the unlock
      reveal and the after-craft mini card (craft moments, M8). Godot's
      windows dim the hub too (the HTML's don't): kept, as for every window.
- [x] 2. Items screen (`reference.js`): `ui/screens/items_screen.tscn`, a
      panel ("codex") from the hub's Items (Home reads Close); a
      `ui/pieces/ref_row.tscn` per open item, pinned ones in their own table;
      search (name, tier, station, recipe), sort; the bar sticks under the
      Quark bar; a row opens its breakdown. The tree is shared with the To-Do
      List (`ui/components/ref_tree.gd`, a parchment or dark look). Item Info
      on a card opens the screen at that item. Matches the HTML within ~4px.
      Noto's PNGs moved to `2D/png/128/` (fetch_noto_icons.py fixed).
- [x] 3. Settings (`settings.js`): the gear opens `ui/overlays/settings.tscn`
      (How to Play, Game Rules, Tutorial Messages, Reset); Game Rules has
      Tutorial tips (on again restores hidden tips); Tutorial Messages opens
      every tip window; the Display Mat rules (two pages: the mat's "?", the
      first check ever), the challenge and Unknown Element tips. All are
      `ParchDialog` scenes (content all in the scene, `{🕒}` emoji tokens) with
      `SettingRow` pieces. Later: Home (step 4), Dev Tools and Clear Cache
      (step 9), the Mini-games / Auto card / Low motion / 5x5 switches (with
      their features), the once-a-run challenge and Unknown tips (step 7).
- [x] 4. Welcome (`welcome.js`, `tour.js` showWelcomeSlide()): the title
      screen at every launch (`ui/screens/welcome.tscn`: Play, Settings), Play's
      Classic window (`ui/overlays/classic_mode.tscn`: the save's visits and
      points, Continue, New Game asking first), Settings' Home and the end
      screen's Main Menu (the run stays saved). `ui/pieces/gloss_button.tscn`:
      the glossy wood/green button, colours in the Inspector. Mini-Games, Combo
      Lab, Collections, Trophies and the Classic window's History stay hidden
      until their steps. Skills: godot-ui, input-handling.
- [x] 5. Trophies and History (`trophies.js`, `history.js` screens):
      `ui/overlays/trophies.tscn` (TrophyTile pieces, 5 to a row, scrolling;
      `trophy_detail.tscn`, the banner under the icon as in the HTML) from the
      title screen's Trophies; `history.tscn` (HistEntry rows, a tap opens the
      turn log; ⧉ copies JSON) from the Classic window. History's 🕓 shows once
      its image is fetched. Its intro wraps to 3 lines (2 in the HTML: Nunito
      a touch wider). Skills: godot-ui.
- [x] 6. Pins: the tracked item (`pins.js`; ctx.tracked, not saved, like
      the HTML): Game.toggle_pin (pin = track), the 🔍 button and the tracked
      pill (App's floats layer, over the panels), the pins tray
      (`ui/overlays/pins_tray.tscn`, PinChip), the card's tracking banner, the
      fly-in from a shop card; the map's badges, rings and tag; the shop's
      "needed for" badge (opens the To-Do List; shortcut: not scrolled to the
      item); the To-Do List leads with it. A 📌 unpin stops tracking
      everywhere (the HTML only does so from shop cards). Skills: hud-system.
- [x] 7. Hints and tips (`hints.js`, `tour.js`): Professor Mouse
      (`ui/overlays/mouse_tip.tscn`, the spotlight a shader), the walkthrough
      tips (prefs.tutorialHintsSeen; off with Game Rules' switch or ✕ Hide),
      the challenge tip (once a run) and the Unknown Element tip (once ever),
      How to Play from Settings as the HTML's (`tut_intro`, `tut_elements`,
      7 coach steps). The pin tip says tracking. Tests and shots turn the tips
      off (prefs.guidedTutorialEnabled) except where they test them. The
      intro's 🔬 shows once its image is fetched. Skills: hud-system.
- [x] 8. Saved layouts, collections, Combo Lab (`mat-layouts.js`,
      `combo-lab.js`): Saved Layouts from the mat's 💾 (search, sort, filters,
      LayoutRow with the mat's combo chips, now static
      `DisplayMatScreen.combo_chips`); Collections (title screen: Stars and
      clues; in a run: switches); the clue gifts (ClueOpen, ClueCard); "New
      collection!" once nothing else is open; Combo Lab (a sandbox run, never
      saved). The two list windows are dark (NineSlice.fill off on the blues).
      The mat's empty-combo hint added. Shortcuts: no in-run way into
      Collections yet (the HTML's is the Inventory filter bar, not ported);
      no "⭐ n" on the title's Collections button. Skills: godot-ui.
- [x] 9. Dev mode (`dev.js`): 5 taps on Settings' version show Dev Tools
      (`ui/overlays/dev_tools.tscn`: the Developer mode switch, Restore my
      real save, Clear Cache, History); the switch shows the 🛠 button (App's
      "Dev" layer, above everything) and its Dev Panel
      (`ui/overlays/dev_panel.tscn`, Godot's own controls in one dark theme,
      no parity with the HTML's look): Jump, Inventory, Snapshots (with the
      ready-made scenarios). The actions are `game/dev.gd`; a changed run is
      a dev run (no Stars, trophies; History's Dev runs tab, its own file).
      Data.icon finds keys written with FE0F. Shortcut: the HTML panel's
      Board and Events tabs aren't ported. Skills: godot-debugging.
- [x] 10. M6 review (2026-11-21): no --compare (every screen was compared
      as it was built); ponytail-review, then godot-code-review, save-load,
      responsive-ui, input-handling, godot-ui on steps 4-9. Fixed: Combo
      Lab hides the 🛠 button (its panel could save a dev run over the real
      one), one Game.fresh_ctx(), dev Grant/Remove that change nothing keep
      a real run, Restore checks file errors, one _window_open(), a stale
      comment. Left: two copies of the dark lists' sizing, no test for
      Restore / Clear Cache (dev only); the rest moved to M8 and M9.

### Review with the godot-prompter plugin (planned 2026-11-21, redone the same day)
**Why:** the user installed godot-prompter (59 skills, 9 agents) and wants
the project measured against it once, using every skill that applies, then
its skills used as we build the rest. **Report first, change nothing**; the
user picks the fixes.

**First try failed (2026-11-21):** 8 agents in parallel. Each started cold
and re-read the plan and the code, so the work was paid 8 times over; they
used up the user's 5-hour limit before any of them reported. **Rule from
this: no parallel agent fan-outs. Skills are loaded by Claude in the main
session; an agent only when the user asks, one at a time.**

**How:** Claude runs the passes itself, one at a time, loading each pass's
skills with the Skill tool (a skill is instructions, cheap; the code is read
once and reused across passes). Each pass reads only the files it names.
After each pass its findings are appended to `godot/REVIEW.md` and
committed, so a usage limit or a compaction loses nothing, and the user
gets a short summary and says "next" (or stops, or reorders). Biggest value
first:
1. **Code** (godot-code-review, gdscript-patterns, gdscript-advanced,
   godot-debugging): game/ and core/ (rules, state, saves), then the ui/
   scripts with logic (app, game flow, trays, dialogs).
2. **Architecture** (scene-organization, dependency-injection, event-bus,
   resource-pattern, state-machine, save-load): autoloads, App's panels and
   flow, Game._changed, saves and old-save loading.
3. **UI and touch** (godot-ui, responsive-ui, hud-system, input-handling,
   localization): project.godot input/stretch, taps vs scrolls, target
   sizes, tablets, safe areas, the cost of translating later.
4. **Performance** (godot-optimization, 2d-essentials, multithreading): the
   mat rebuild on each change, the Items screen's rows, per-node
   materials, load() in loops, startup.
5. **The small four, one pass**: editor tooling (addon-development; the
   @tool pieces, EDITING.md), shaders/renderer (shader-basics,
   rendering-pipeline), animation (animation-system, tween-animation; today's
   tweens, for M8), readiness (godot-testing, export-pipeline, web-export,
   mobile-development, assets-pipeline, audio-system, math-essentials; for
   M8/M9).

**Left out (don't apply to a 2D card game in GDScript):** 3d-essentials,
physics-system, player-controller, camera-system, ai-navigation, beehave,
limboai, phantom-camera, multiplayer-basics/sync, dedicated-server,
xr-development, csharp-godot/signals and godot-csharp-engineer,
gdextension, dialogue-system/manager, popochiu, procedural-generation,
inventory-system and ability-system (ours exist and match the HTML),
particles-vfx (with M8 if confetti moves to particles), web-services.
The 9 agents are the same skills with a cold start; not used for this.

**Each finding:** where, the problem, a concrete case, the fix, its size,
and **whether it conflicts with a decision in this plan** (pixel parity with
the HTML, hand placement, no project Theme, rules only in game/js...).
Conflicts go to the user as decisions, never fixed silently.

**Then:** one merged, ranked list (must / should / nice; plan conflicts
apart). The user picks; fixes follow the M5.5 care rules (one change per
commit, `check.py`, pixel-identical unless intended). What we adopt or
reject is recorded here as decisions and REVIEW.md is deleted. From then
on: Claude loads the matching skill before each step (e.g. godot-ui for a
new screen) and the godot-code-review skill at the end of each step,
alongside ponytail-review; no agents unless the user asks.

### M7 Mini-games (size unknown; decide first)
Deferred (the user, 2026-11-21): skipped for now, maybe later. The game
plays without them (each visit rolls straight away, as with the HTML's
Mini-games switch off); their switch and title-screen button stay hidden.
- [ ] Decide which of the 8 to keep (godot-grill first: a new system with
      open questions). Then port them one at a time (input-handling,
      tween-animation, math-essentials as each needs).

### Cutover: Godot stands alone (decided by the user 2026-11-21)
The HTML game is frozen as it is and abandoned: from here on the game is
the Godot project only. Releases: the APK on the user's phone
(`tools/phone.py`) and the Godot web build. The print pipeline is dropped
(a future board game would be its own project). After this, new game
design happens in Godot.
- [x] C1. Godot computes the tables the HTML derived from DATA
      (CORE_ITEM_NAMES, CAPSTONES, MAT_CARDS, STATION_SHOP, ...), so editing
      `data/game_data.json` is enough; a test proves they equal today's
      exported ones, then the copies leave the JSON. Done: `Data.derive()`
      (23 tables, all equal to the HTML's before the copies were removed).
- [x] C2. Content is edited in Godot: `data/game_data.json` is the source
      (how to add an item, a station, an icon); a Godot-side Noto icon
      fetch for new emoji.
- [x] C3. The checks stand alone: the parity goldens become a lock on
      Godot's own rules (`parity --accept` re-records after an intended rule
      change); the HTML-reading tools retire (export_from_game, compare,
      html_shot, record_golden; `check.py --compare`).
- [x] C4. Docs and publishing: the root CLAUDE.md becomes Godot-first,
      `game/` and `print/` marked frozen; the web build replaces the HTML
      game at the site root (the user, 2026-11-21), `tools/web.py`.
- [x] Phone notes (the user, 2026-11-21), smallest first:
  - [x] Professor Mouse tips off by default.
  - [x] Capstone choice: names centred; the Inventory lights up as the
        elements fly in.
  - [x] Map: tracked badges over the stations; YOU ARE HERE beside the
        Ocean; a tap on the map hides the station card.
  - [x] Station gathering window: element names centred, less padding,
        squares 0.8x.
  - [x] Convert tray: no atomic numbers.
  - [x] Stations: the title block reaches the top of the screen (no gap
        above the Quark bar); the backdrop covers the bottom too.
  - [x] Display Mat shutter title (every 3 rounds) centred.
  - [x] Lock-In button turns grey once tapped, while the score counts.
  - [x] Station shop cards: no station icon at the bottom.
  - [x] Tapping an element square at a station shop opens the Convert
        tray with that element picked.
  - [x] Convert tray: the chosen From/To squares show their atomic number
        and suit badge.
  - [x] Home's Shop face shows the current station's icon.
  - [x] The clock shows the round number in its middle.
  - [x] Track an item from the To-Do List tray (its track button on it).
  - [x] Inventory tap-to-mat: dropped (card playing takes the mat out of
        the Inventory); it goes into the Combo Lab instead (work queue 5).
  - [x] Sugar an ingredient of fruits (a content change: which fruits,
        and the rules lock re-recorded).
  - [x] Challenge window: the title states the ask, big icons, a labelled
        Reroll.
  - [x] The map's turn clock (missed in the port) and its info window.
  - [x] Safe area (moved here from M9 by the user, 2026-11-22; review 8):
        the top and bottom bars clear the phone's notch and gesture bar
        (main.gd insets the app; untested on the phone yet).
  - [x] Card view (the user, 2026-11-22): every card's component icons in
        one row, at a best-fit scale for all items (outliers adjusted one
        by one; Planet left out).
  - [x] Bigger: on a round where the Display Mat grows, the reveal shows
        the mat physically growing to its new size.
  - [x] Bigger: fewer repeated Craft / pin buttons at stations (work queue 1). Try first
        in the Inventory's compact view: a narrow scrolling list on the
        left (item name, its icon under it, no component items), the
        selected item's full card on the right (shop card size), the
        Crafting Bench still there; a Craft button at each row's right end
        carrying the convert icon at its top-right when a component can be
        converted.
- [ ] **Drawing cards at Display Mat checks** (designed with the user,
      2026-11-22; build after the phone notes):
  - The deck: every card the player owns that isn't on the mat, shuffled
    fresh at each check.
  - A check starts with a hand of 7. A "Draw cards" button draws 2 more.
    The hand holds at most 10.
  - A card played onto the mat or discarded is replaced 1 for 1 from the
    deck. Playing onto a filled slot replaces that card, and the replaced
    card goes to the discards. Discards are gone for the rest of that check.
    No limit on plays or discards: an empty deck is the limit.
  - Between checks the mat isn't shown in the Inventory, only the item
    list. A Combo Lab button in the Inventory lets players try board combos
    with their current cards, and collections found there unlock.
  - "Draw cards" is free and unlimited, up to 10 in hand (the user).
  - The Combo Lab: tap a card to put it on the lab's mat, tap it on the
    mat to take it off.
  - With it: a tier / display-size mark on cards: the Roman numeral plus
    blocks (1 for a small card, 2 stacked for a full one, 4 for a
    capstone). Its main job is telling the player how big a card is on
    the mat when they play it, so it is designed with the hand.
  - The hand (the user, 2026-11-22): fanned across the bottom of the
    screen, like Hearthstone or Balatro. Each card in the hand must show
    its size, its bonuses and its name clearly, so the card layout gets a
    design pass for the hand (cards overlap there, so the important parts
    sit where the fan leaves them visible).
- [ ] **UI feedback pass** (the user, 2026-11-22; after card playing): a
      wide look at UI motion: button presses, trays and windows coming on
      screen. Subtle overall, never at the cost of performance, but most UI
      elements give some feedback. Includes a small dust poof where the map
      is tapped off a station. (M8's animation notes apply.)
- Port check (2026-11-21): every HTML window has a Godot one except the
  capstone celebration and the unlock reveal (C5); the turn clock and its
  window were missed and are now in.
- [x] C5. The HTML moments Godot still lacks: the capstone celebration,
      the unlock reveal, the after-craft mini card. Then the user resumes
      game design; animations, sound, the user's visual notes (text
      alignment, the top and bottom bars in full screen) and the 9
      `shortcut:` notes carry on in M8 alongside it.

### M8 Polish (ongoing)
- [ ] Animations (crafting, travel, reveals), screen transitions, sound and
      music, haptics, a loading screen, performance on an older phone
- Animations: fixed motions (bounces, the logo, the shutter, the Lock-In
  count) move to AnimationPlayer timelines in the scenes, so the user can
  tune them in the editor; motions aimed at a place known only while playing
  (dice flying to the Inventory, confetti) stay tweens, their timings as
  Inspector numbers. Low motion shortens or skips both. (Review 16;
  skills: animation-system, tween-animation.)
- Sound: an audio bus layout (Music, SFX), one small Sound helper driven by
  named Game signals (crafted, rolled, row done, checked: review 6);
  volume switches in Settings. (Skill: audio-system.)
- Performance on a real phone (godot-optimization): re-measure the station
  and the mat (review 12); `tests/tmp/bench.gd`-style timing.
- On the phone too: bigger invisible tap areas for small buttons (review
  9); the on-screen keyboard mustn't cover the Dev Panel's text fields
  (review M6-9).
- Haptics: mobile-development.
- [x] Back (Android) / Escape closes the Dev Panel, the top window (its
      Close, else its backdrop), then the panel; never quits (review 14,
      moved here from M9 by the user, 2026-11-21).

### M9 Release and cutover (~2-3 sessions plus store review time)
- [ ] Android: export templates, a signing key, Play Console listing, testing track
- [ ] Before any store build: app saves get a version and the
      `loadAll()` clean-ups (review 5; the dev snapshots, dev history and
      backup files too, M6-10).
- Skills: export-pipeline, mobile-development, web-export, assets-pipeline.
- [ ] iOS: a Mac, Apple developer account, Xcode export, TestFlight
- [ ] Store rules for a children's game: Apple Kids category and Google
      Families policy (no third-party ads or tracking, a privacy policy)
- [ ] Cutover: `data/game_data.json` becomes the content source; decide what
      happens to the HTML game, the website, the simulator, the breakpoint
      tuner and the print pipeline (they read `game/` today)

---

## Decisions

Recorded so they aren't re-argued. Add new ones with the date.

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
