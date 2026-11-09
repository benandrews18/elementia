# Changelog

All notable content/gameplay changes. The content version is `"version"`
in `game/js/data.js`; it shows on the game's Settings screen and is stamped
on any printed PDFs. Bump it (date-based) when content changes. See
`CLAUDE.md` for how to build and publish.

Entries before 2026-11-08 refer to `build_guide.py`, `build_all.py` and
`Elementia_Handoff/`, which are now gone or moved (see the 2026-11-08 entry).

## Unreleased

- **Desktop view:** on a wide screen the game now shows in a phone-width
  (430px) column at full window height, with the phone layout rules on,
  instead of a 768px tablet column. Trays that sit just off-screen on a
  phone no longer show beside the column, and station backdrop art shows.
  Phones and tablets are unchanged. Width is `--frame-w` in
  `game/css/desktop-frame.css`.

## v2026.11.08 (Classic-only data, lighter download, cleanup)

- **Display Mat:** Glass, Water, Limestone and Natural Gas now count only at
  stations whose shops sell them in Classic (on mat cards, station combos
  and Item Reference). Before, they also counted at Power Plant/Observatory,
  Old Growth Forest, Greenhouse and The Bakery.
- **Lock-In reward** now reads "+n on your next roll" (it showed a wrong
  total when Mini-Games set the base dice).
- **Smaller download:** retired items' data and art removed; the page is
  about 7.3 MB instead of 11 MB.
- Removed code that could no longer run: the "New Items Unlocked" reveal,
  the old Lock-In banner, per-mode save plumbing. Saves still load.
- Repo: `data.js` holds only Classic rows (no separate `CORE_SET`); smoke
  test gained rule checks; a hook syntax-checks edited JS; `game/deploy.py`
  publishes to the website.

## 2026-11-08 — the game is now the source of truth; repo reorganized

- **Game data lives in the game.** `game/js/data.js` (stations, dice, shops,
  recipes, points, tiers) and `game/js/model.js` (Classic item set, suit
  costs) are the source of truth. `build_guide.py` had drifted about two
  months behind (dice 6 vs 3, 75 point values, 12 recipes, 4 station dice
  pools); it now reads the game instead of holding its own copy.
  `game/build_game.py`, which copied the other way, is removed, as is the
  game's unused `avgVisits` data.
- **Print pipeline moved to `print/`**, Classic only: Station Guide, Card
  Deck, Element Cards. `python print/build_pdfs.py`. PDFs not re-rendered
  yet. Full-deck, print-run and item-reference scripts removed.
- **Archived** (`archive/`, not maintained): landscape edition, card game,
  board game, side scroller, old simulators and balance tools, field-game
  PDFs, old handoff CSVs. Removed stale `HANDOFF.md` and
  `CURRENT_GAME_STATE.md`.
- **Smoke test** committed: `node game/tools/run_smoke.mjs`.
- Added `CLAUDE.md` with the workflow.

## 2026-11-08 — digital game fixes and cleanup (content still v2026.08.16)

Code-only; no item, recipe or point changes, so `CONTENT_VERSION` and the
PDFs are unchanged.

- **BINGO card redraw**: when an old save's card is redrawn (one of its
  items left the Classic set in a rebalance), its completed lines, waiting
  rewards and centre choice are now cleared with it. Before, lines already
  paid on the old card never paid on the new one.
- **Suit costs**: the "can I pay this?" check now counts only each suit's
  four core elements, the same ones the spend bubble offers. An old save
  still holding Zinc could light up Craft for an item the bubble then
  couldn't pay for.
- **Removed**: the three experimental Dev Tools switches (Compass-gated
  tracking, tiered conversion, Tractor harvest), which were off by default.
  Dice per roll is fixed at 3 and conversion at 3-for-1.
- **Removed dead code**: the old "?" spotlight cash-in mode (replaced by
  the element picker), an unused BINGO reward helper, and leftover
  sub-zone notes.

## v2026.08.08b (layout/stacking fixes, item points recalibrated)

- **Layout fixes from the previous pass**: map screen background now
  reaches the true top of the viewport (no residual gap); the topbar
  pills, pins tray, and floating pins/convert buttons all moved to
  negative z-index so every real window (drawer, settings, Job Board,
  Item Reference, the map's station-preview card) renders above them
  automatically instead of the other way around; pills are now map-screen
  only (hidden entirely on station/reference screens); station and map
  titles reverted to their original left-aligned layout; the map's
  station-preview card sits flush with the top edge; closed a stray gap
  between the open pins tray and the bottom hub (was double-counting the
  device safe-area inset).
- **Station shop cards**: item icons enlarged within their existing card
  border; the MATERIAL/COMPONENT/CREATION tier label removed (CAPSTONE
  tag stays); cards now extend to the screen edges horizontally, same
  height as before; the job-highlight green ring on capstone cards now
  correctly wraps the whole capstone box instead of rendering with no
  room to breathe; cards belonging to the selected pinned item's
  ingredient closure now also show a small corner badge with that
  pinned item's own icon, alongside the existing green ring.
- **Map**: removed the small direction arrows on station paths; dashed
  line segments now render at a consistent size regardless of an edge's
  angle (vector-effect:non-scaling-stroke, since the map's non-uniform
  stretch was distorting the dash pattern differently per angle); the
  path web no longer draws at all while still choosing a starting
  station, only once one's picked.
- **Convert Elements**: window gets a visible 2px border against the
  scrim; the "+" and "Pick element" placeholder text is now white
  (was unreadable dark-on-dark), switching to dark automatically once
  an element's picked and the box goes white to match; Convert/Close
  buttons pushed down further from the picker boxes above them.
- **Pinned items tray**: extra bottom padding so item text can't render
  under the floating buttons anymore; boot icon changed to 🥾.
- **Job Board**: available offers now list above the accepted "My Jobs"
  section (was reversed); both sections collapse independently. New red
  badge on the Jobs hub button when a station's offers haven't been
  opened yet, separate from the existing green "ready to turn in" badge.
  New "!" attention badges on the floating pins button (pinned items
  exist but none is selected) and convert button (holding 3+ of some
  element) — both get a white border too, for contrast against busy
  backgrounds.
- **Element card popup**: flavor text removed; symbol + name now center
  in the remaining space above the suit pill instead of sitting fixed
  near the top with empty space beneath.
- **Item catalog**: the 7 items sold at multiple stations (Water,
  Limestone, Natural Gas, Sand, Steel, Glass, Soil) now appear in the
  same relative order in every shop that carries them; every station's
  shop otherwise sorts by point value. Point values recalibrated from
  scratch using `AvgVisits` + `Steps` out of the reachability simulation
  (empirical crafting difficulty, not just recipe depth) — the old
  values had drifted noticeably out of sync with actual difficulty after
  many content changes (e.g. Salmon was 4pts despite averaging ~12
  visits to reach; Egg was 14pts at only ~5.6). Capstones keep a flat
  point premium on top of the same formula so they still read as the
  special payoff items.

## v2026.08.08 (minimal-hub UI pass, station item cap)

- **Topbar**: replaced the visits progress bar + score circle with two
  floating "pill" overlays (👢 visits x/max, ⭐ score) that sit
  transparently over whatever's underneath instead of a solid bar.
- **Pins + Convert**: pulled out of the topbar entirely into two circular
  floating buttons just above the bottom hub (pins on the left, convert
  on the right). The pins button now opens a tray that slides up from
  behind the hub (closed state sits z-index-below the hub, hidden behind
  it; open state rests flush above it) instead of showing pinned items
  inline in the topbar — tapping the button again slides it back down.
- **Map station previews**: the preview card is now edge-to-edge (no
  side padding/radius) and its item row no longer wraps — a single
  horizontally-scrollable line, so every item fits on one row.
- **Item cap**: Greenhouse and Deep Mine both had 11 shop items (max is
  10). Cut Sand from Greenhouse (still sold at The Ocean and Old Growth
  Forest) and Soil from Deep Mine (still sold at Greenhouse and Old
  Growth Forest) — both remain fully reachable, just with one fewer home
  each.

## v2026.08.07 (map graph, alloy recipes, digital-game UI pass)

- **Station map**: added 2 more edges (The City ↔ The Power Plant, The
  Power Plant ↔ Deep Mine), on top of last version's custom web — 16
  edges total. Aluminum Alloy and Titanium Alloy no longer need Fe.
- **Icons**: Rubber Tire's icon changed again (🔘) after the previous
  swap still didn't read as a tire; Microchip's icon changed to 🎛️.
- **Digital game UI**: the topbar's "Jobs" row is now a "Pinned" row —
  sourced from the existing pin list (manual pins from Item Reference
  now show up here too, not just job items, though taking a job still
  auto-pins its items same as before) and always visible, even empty.
  Added a quick-convert button next to it that jumps straight to the
  Convert Elements screen. Station item-shop cards now get the same
  green checkmark badge as the map's station preview icons for owned
  items, and the green ring for job/pin-selected items is thicker and
  sits inset (into the card's own padding) rather than growing outward.
  The bottom hub's center button turns into a back arrow whenever a
  panel is open (Inventory, Pinned/Job Board, Settings, Item Reference,
  Convert) and just closes it instead of also navigating to the map —
  including while a station roll is still pending, which previously
  blocked even closing an open panel.
- **Bug fix**: the Convert Elements picker's element boxes were
  rendering with no border at all (not just "thin" as first reported) --
  a leftover from the picker restyle two versions back, where the color
  application moved onto an element whose border comes from a CSS custom
  property (--suit) that nothing was actually setting. Fixed by setting
  --suit inline, the same pattern every other bordered element box in
  the game already uses.

## v2026.08.06 (element roster rebalance, item catalog rework via reachability testing)

- **Element roster**: Na and Cl retired (their only consumer, Salt, is
  gone) in favor of Ni and S — both now do real work across the catalog
  instead of dead-ending in one item.
- **Item catalog**: Salt, Mushroom, and Steam removed (Steam's two
  dependents, Cloud and Plastic, were re-plumbed to not need it); Rubber
  Tire, Stainless Steel, DNA, and Life added; Eggs renamed to Egg and
  reworked to be made from DNA directly rather than from Chicken (Chicken
  now depends on Egg instead of the reverse); Multi-Layer Cake renamed to
  Fruit Cake and gained Banana in its recipe. 72 unique items, 8
  stations, still 10 shop slots per station.
- **Recipe rebalance**: Steel simplified (no longer needs Furnace);
  Battery, Bone, Concrete, Microchip, Cloud, and Plastic recipes reworked;
  several foundational items (Clay, Limestone, Sand, Water, Glass, Soil)
  now sell at 3 stations instead of 2, easing the biggest structural
  bottlenecks. Station dice pools reshuffled to back the new recipes with
  locally-available elements (e.g. Power Plant now rolls its own Ni/Fe for
  Battery). Life's recipe further deepened to DNA + Bone + Star + Water +
  Clock.
- All of the above was iteratively tested against the reachability
  simulator (`Elementia_Handoff/handoff/simulation/`) before being
  applied — the full 72-item x 8-station grid runs with zero DNFs (every
  item reachable from every starting station).

## v2026.08.02 (job-tracking map, Job Board grid, icon fixes, reference cleanup)

- **Map job-tracking replaces manual pinning.** The map's top-of-screen
  selector row now auto-populates from every item across the player's
  *accepted* job cards, labeled "📋 Jobs" on the left, instead of the
  previous round's manually-pinned items (that pinning feature stays
  exactly as-is, just for Item Reference's own use now -- the two are
  fully decoupled). Selecting an item highlights its ingredient-item
  closure among the icons that station cards show.
- **Station cards always show every shop item.** Previously only a
  selected pin's own components appeared; now every item the station
  sells is always visible (icon-only, greyed out by default), and
  selecting a job item highlights the matching ones in place rather than
  filtering the row down to just them -- the full shop stays visible
  either way. This row now sits directly under the dice pool; the
  capstone line (with its dashed rule above it, back where it started)
  moved to the bottom of the card.
- **Job Board: real cards in a grid.** Both the Job Board's own cards and
  the Accepted Jobs section are now a responsive grid of compact cards
  instead of one stacked column -- items, then bonus points, then the
  action button beneath each card, rather than everything crammed into
  one horizontal row.
- **Item Reference cleanup.** Dropped the "MADE FROM" ingredient summary
  (redundant with the "Full breakdown" toggle) and the tier tag pill from
  every row. The "AT" label in front of a station's name is gone too --
  just the icon and name remain.
- **Icon fixes:** Natural Gas is now a barrel (🛢️, was 💨, which Steam
  also used); Clay is now a pot (🏺, was 🟤, an unlabeled brown circle);
  Soil now matches Greenhouse's own station icon (🌱, was 🟫); Flour gets
  a hand-drawn sack-of-flour icon (custom SVG, same `__TOKEN__` pattern as
  Orca/Coral) since it shared its old glyph (🌾) with its own ingredient,
  Grain, one station over. **Shell removed entirely** -- it was Ca+C+O,
  identical to Limestone, with nothing else in the game depending on it.
- **Job Board eligibility widened:** `JOB_MIN_CREATION_POINTS` 16 -> 13,
  so more of the game's mid-tier Creations can show up as job cards.
- Regenerated `print_quantities.json` and ran the full 16-step build
  pipeline (content/data changes touch the printed materials too, not
  just the digital game).
- Verified via direct DOM/state inspection: station card child order is
  exactly pool -> item icons -> capstone line; the highlighted icons at
  a given station match `componentClosure()`'s own output; Item
  Reference's pin cap and pinned section work identically to before and
  leave `selectedJobItem` untouched; both grids render as CSS grid with
  the action button as each card's last child; and the new Flour icon
  renders as a real embedded `<svg>` rather than falling back to a
  missing-glyph box.

## v2026.08.01 (pinned-icons map experiment, capstone card redesign, Job Board simplification)

- **Pinned-icons-on-station-cards experiment.** The map header's old
  "X dice rolls per visit / X visits left" line is gone (the visit count
  is still in the topbar); in its place, up to 3 pinned items (see last
  round's pinning feature) show as tappable chips. Tapping one selects it
  (green highlight, only one at a time) and every station card grows a
  row of icon-only chips below its capstone line showing which of that
  item's full ingredient-item closure -- direct and indirect, recursive
  -- happens to be sold there. A cross-map shopping list for whatever
  you're chasing. Capped at 3 pins (`MAX_PINS`) specifically so this row
  never wraps.
- **Station card capstone line redesign.** Dropped the gold "CAPSTONE"
  pill label, bumped the capstone emoji up a size, and the item name is
  now plain white text instead of the muted default (still turns green
  once owned, that signal stays). The dashed rule that used to separate
  the dice pool from the capstone line now sits *below* it instead --
  that's where the new pinned-component icon row lives, when one's
  selected.
- **Item Reference: no more self-jump.** Tapping a nested item's name in
  an expanded breakdown now just expands that node in place, like the
  arrow next to it always did -- it no longer jumps to that item's own
  row. Jumping away mid-lookup turned out to be more disorienting than
  useful once you're already on the reference screen looking things up.
  (The Job Board -> Item Reference jump from last round is unaffected --
  see below, that's the one place this still makes sense.)
- **Job Board: dropped the inline tree.** Job cards no longer show an
  expandable ingredient breakdown of their own -- Item Reference is the
  one place for that now. Items show as flat chips (icon, name, owned
  checkmark); tapping one still jumps to Item Reference, same as before.
- **Job Board layout.** The action button (Take This Job / Turn In) and
  its bonus-points value are now grouped together and horizontally
  aligned with the item chips, on the right side of the card, instead of
  stacked full-width below them.
- Fixed a real bug caught while testing the pin cap: showing the "you
  can only pin 3 items" hint and then immediately calling render() hid
  it in the same tick, since render() unconditionally calls hideHint()
  -- a real user would never have seen the message. A second, related
  bug: even after skipping that render(), a page-wide
  `click -> hideHint()` listener (the same one the existing ingredient
  hints already route around with `stopPropagation()`) was undoing it a
  moment later as the same click bubbled past it. Both fixed together;
  verified the hint now actually stays on screen.
- Verified via direct DOM/state inspection: the pin cap refuses a 4th
  pin without touching state; selecting/deselecting a pin toggles the
  right chip and shows/hides the right icons per station, matched
  against `componentClosure()`'s own output; the capstone label and old
  header text are gone from the DOM; nested-node taps in Item Reference
  stay on screen and expand locally; the Job Board has no
  `.mission-tree` left anywhere; and the full job-card-tap ->
  Item-Reference-with-breakdown-open path still works end to end.

## v2026.08.01 (Item Reference expansion, pinning, Job Board deep-link)

- **Item Reference: full recursive breakdown.** Every row now has a
  "▸ Full breakdown" toggle that expands the same recursive to-do tree
  the Job Board uses (own children collapse/expand independently, all
  the way down to raw elements) -- reuses `jobNodeHTML()` as-is rather
  than building a second tree renderer. The existing flat one-line
  recipe summary stays put above it; this is additive; nothing about
  the quick-scan view changed.
- **Item Reference: pinning.** A 📌 on every row pins it into its own
  section at the top of the list. Pins live in `prefs` (not `state`),
  since they're a personal habit ("I keep looking this up"), not game
  progress -- they survive a session reset or switching save groups
  rather than resetting with them.
- **Job Board deep-link.** Tapping an item's name anywhere in a
  recursive tree -- a job card, or now Item Reference's own expanded
  breakdown -- jumps straight to that item's row in Item Reference,
  auto-expanding its breakdown and briefly highlighting the row. Tapping
  the small arrow next to it still just expands/collapses in place, as
  before; splitting "expand" from "go look this up" into two separate
  hit targets on the same `mission-tree` component is what makes it
  work identically in both places for free -- the job board's own tree
  didn't need any of its own new code.
- Verified via direct DOM/state inspection: pin/unpin doesn't duplicate
  or lose rows; the search filter still applies correctly to the pinned
  section; multi-level expand/collapse tracks independently per node at
  any depth; and the full path -- take a job, open the Job Board, tap
  the item's name -- correctly closes the Job Board, switches to Item
  Reference, and lands with that item's breakdown already open.

## v2026.08.01 (recipe/tier changes, Convert redesign, quick fixes)

- **Recipe & tier changes:**
  - Plastic now sold at The Power Plant instead of The Ocean (same recipe:
    Natural Gas + Steam).
  - Computer: now Battery + Plastic + Si (was Si + Cu + Plastic).
  - Robot: now Computer + Engine + Mirror + Au + Al (was ...+ Battery).
  - New item: **Shell** (Ca + C + O), a flavor Material at The Ocean, same
    formula as Limestone (both are calcium carbonate).
  - Maple Syrup: now just Amber (dropped the Furnace requirement).
  - Retiered for consistency: Steel → Material (its recipe was always pure
    elements, just mistagged); Amber, Grain, Milk, Eggs → Component (Milk/
    Eggs were tagged Material despite costing an item, not elements).
  - Regenerated `print_quantities.json` from the updated recipe graph and
    re-verified full depth resolution (69/69 items reachable).
- **Convert Elements:** picker buttons now show "+" instead of "?" and
  actually look tappable (solid border, pressable shadow); the Convert
  button only turns green once both sides are picked (previously showed
  green regardless of its `disabled` state -- `.bigbtn` had no `:disabled`
  style at all). Every element square -- both Convert boxes and the picker
  grid -- now shows a distinct representative color per element instead of
  a flat generic fill.
- **Fixed a real scroll bug:** the station roll animation's final
  `render()` was wired as `anim.onfinish = render` directly, which passes
  the animation's own finish event as `render`'s first argument --
  landing in its `resetScroll` parameter and silently forcing the page
  back to the top after every roll. Now wrapped so no argument leaks
  through.
- Item Reference's search bar is now sticky (pinned just below the
  topbar) so it stays reachable while scrolled through the list.

## v2026.08.01 (Game Modes + Job Board)

- **Game Modes:** picking Play from the welcome screen now opens a
  one-time mode picker (Zen / Classic / Hard) before the map appears.
  - **Zen** removes the visit limit entirely and hides the Job Board
    button -- pure sandbox crafting.
  - **Classic** is the existing default: visit-limited, Job Board active.
  - **Hard** is Classic plus item consumption: crafting something now
    spends one copy of each non-catalyst, non-Capstone item ingredient
    (Components and Creations), not just its elements. Capstones are
    never consumed. This makes `state.items` a multiset in Hard Mode
    only -- Zen/Classic are unaffected and keep unique-name arrays
    exactly as before. The inventory drawer now groups duplicate items
    into one row with a `×N` badge instead of repeating rows.
  - Deliberately no tier-based exemptions in Hard Mode -- some items
    (e.g. Farm) are known to break under real consumption, and that's
    accepted as the nature of the challenge rather than patched around,
    since the mode isn't meant to be tuned/balanced like Classic.
- **Job Board** replaces the old single-pick Mission sheet: the board now
  offers a refreshing batch of 3 jobs (1-2 "largest items" each, drawn
  from Capstones and high-point Creations) instead of one fixed mission.
  Taking a job commits it permanently to your list; turning in a
  completed job keeps the item(s) owned forever and adds a bonus equal
  to the sum of their own point values to your score. Multiple jobs can
  be active and turned in independently. The board is unavailable in Zen
  Mode.
- Internal rename throughout (state fields, function names, element IDs,
  CSS classes) from "mission" to "job"/"job board", except the recursive
  ingredient-tree markup/classes shared with the item-card view, which
  were deliberately left as-is since renaming them wouldn't be visible
  to a player. Also removed a few small pieces of dead code uncovered
  during the rename (an unreachable click handler, unused CSS for an
  element that no longer exists).

## v2026.07.31 (re-sync dice faces to the sorted legend)

- The station dice legend's face numbers (die pip counts) previously kept
  each element's original position in `build_guide.py`'s data so a face
  wouldn't get relabeled -- but the actual roll is fully simulated
  in-app (`Math.random()`, no physical die read by the player), so that
  constraint didn't apply, and the result was the legend (sorted by
  atomic number) no longer matching its own pip counts. Both the legend
  and the roll itself now read from one shared, atomic-number-sorted
  list (`sortedDice()`), so face N always means the same element in both
  places. (This only affects the digital game's internal roll simulation
  -- it doesn't touch `build_guide.py` or the printed materials pipeline,
  which weren't part of this ask.)

## v2026.07.31 (play-animation stutter, convert stack z-order)

- Fixed a small stutter at the end of the Play animation: the Map hub
  button now unlocks the instant you roll (with a smooth color
  transition) instead of waiting for the animation's deferred final
  render, and the playbar's leftover top margin is now zeroed in step
  with its height so the shop doesn't visibly snap that last bit into
  place when the DOM swaps in.
- Fixed the Convert screen's FROM stack: the ghost squares are real
  sibling elements behind the real box now, not `::before`/`::after` on
  it -- a negative z-index on a box's own pseudo-element still paints
  above that box's own background/border, so the ghosts were bleeding
  over the real box's edge instead of tucking cleanly behind it.

## v2026.07.31 (theme removal, welcome flow, animation polish)

- **Light theme is gone, not just hidden.** Collapsed the CSS down to one
  dark palette (no more `:root`/`[data-theme=dark]`/`prefers-color-scheme`
  triple-block to keep in sync) and removed the theme toggle, `prefs.theme`,
  and the `data-theme` attribute entirely.
- Convert Elements: the FROM stack's ghost squares now trail down-left
  instead of up-left, so the front square's own centered text actually
  reads as centered against the whole cluster.
- The inventory punch now fires as soon as the flying element (first dice
  card, or the converted result) makes contact, not once the whole
  fly/shrink/fade animation has fully finished. The station roll's bag
  punch also only fires once per roll now. The Convert FROM stack pops
  out of existence at the same time the result flies to the inventory,
  instead of just sitting there until the screen resets.
- Hub buttons now switch panels in one tap: tapping a different button
  closes whatever's open AND opens its own target immediately, rather
  than requiring a second tap. Mission/Inventory/Settings now go green
  while their panel is open, matching Items.
- Welcome screen is a true full-bleed background image now (no border/
  frame), with Play/Settings floating over it. Settings opened from the
  welcome screen shows on top of it instead of closing it, and returns to
  the same welcome screen when closed. The mission picker no longer
  pre-opens behind the welcome screen -- it only appears once Play is
  actually tapped.

## v2026.07.31 (hub behavior, convert redesign, animation fixes)

- Removed the "Light" theme option entirely -- just Auto (follow the
  device) or a forced Dark now.
- The hub is always on top: overlays (Settings, Convert, etc.) render
  behind it instead of covering the Map button.
- Any hub button now closes whichever panel is already open, rather than
  opening a new one behind/over it -- including Settings, which
  previously didn't close on a second press.
- Fixed a real bug (caught via testing under reduced-motion): the Play
  animation's final render() was gated on a CSS transition event, which
  resolves near-instantly for reduced-motion users and could yank the
  still-flying dice cards out of the DOM mid-flight. It's now gated on
  the actual fly animation finishing instead.
- Reworked the Play animation per feedback: the inventory bag now punches
  only once; the rolled dice appear in the Play button's own slot (the
  title bar expands to fit them, then contracts to 0 as they fly out,
  instead of after); the shop now visibly scrolls upward while the dice
  are still in the air, not once they've landed.
- Removed the gap above the station title bar -- it now sits directly
  under the Visits bar.
- Station dice-legend chips are bigger, taller squares with larger text,
  still six to a row.
- Convert Elements: the FROM box is now three diagonally-stacked squares
  (matching the "trade 3 of these" reference), the element name inside
  both boxes is larger and white, the Convert button gives a small punch
  on confirm, and the resulting element flies into the inventory bag the
  same way a station roll does.

## v2026.07.31 (station layout + play animation)

- Station screen is edge-to-edge on phones now: no outer gutter around the
  card, no rounded corners on the sides. Main's bottom padding still
  clears the hub under the last shop row.
- The station title bar and the dice-gather legend are now one continuous
  dark card (fixed dark tone in both themes) instead of two separately
  backgrounded sections.
- "MAKE HERE" is now "ITEM SHOP", in white instead of muted grey.
- **New: Play-button choreography.** Tapping PLAY pops the rolled dice out
  one at a time (not all at once), holds a beat once they're all up, then
  flies them into the inventory hub icon -- which punches outward as they
  land -- before the vacated space collapses so the shop slides up to
  fill it. The PLAY button itself pops away on press; there's no more
  disabled "Rolled" state to show afterward.
- Settings (and every other full-screen overlay) now stops above the hub
  instead of covering it.
- Welcome slide: large Play/Settings buttons instead of tap-anywhere.
- Guided tour: "TUTORIAL" title + "Tap anywhere to continue" caption
  above the slide, and a bordered frame around it (reads as "a picture of
  the game", not the game itself; shrinks the slide slightly to make
  room for the border).
- Inventory element boxes bumped back up slightly (last round's shrink
  went a bit too far).
- The mission picker (shown at the start of a new session) is now a
  full-screen "Choose 1 Mission" sheet showing all three options at once,
  no scrolling needed and no explanatory paragraph.
- Elements on station map cards, and in each station's dice legend, are
  now sorted by atomic number (the legend keeps each symbol's true die
  face number, so it still matches the physical dice).
- Shop item card gradient's base color is now a dark navy matching the
  dark theme's own palette, instead of a neutral grey.

## v2026.07.31 (follow-up polish)

- Map banner gradient flipped: opaque/dark on the left, art visible on
  the right (was the reverse).
- Inventory element boxes roughly halved in size.
- "Convert Elements" is now a real filled button, not a text-link-style
  one.
- The conversion screen's FROM-side picker now reads as clearly "your
  inventory": small "INVENTORY" kicker label instead of a big dialog
  title, smaller explanatory text, every held element shown (not just
  ones that already qualify) with a green border on anything at 3+ and
  everything else greyed out and inert, quantity text enlarged.
- Tighter vertical spacing between crafted-item rows in the inventory
  list.
- Shop item card gradient's left (opaque) end pushed further toward
  fully opaque in both themes; the right end is unchanged.
- The Map/Home hub button is larger; the other four hub buttons tightened
  up slightly to make room.

## v2026.07.31

- **Deep Mine now rolls Ag instead of C.** Steel and Furnace (both Deep
  Mine recipes needing C) now require bringing Carbon in from one of the
  six other stations that still roll it -- the same "reach outside your
  own station" pattern already used throughout the game.
- **New: element conversion.** Trade 3 of any one raw element for 1 of
  any other, from a new screen opened via a button in the inventory
  drawer. Two boxes with an arrow between them -- tap either to pick from
  a shared picker (the left side only offers elements you have 3+ of; the
  right side is anything else). Neither side can duplicate the other, so
  an X-for-X trade can't happen regardless of which box is picked first.
- **Inventory overhaul:** elements now sort by atomic number instead of
  alphabetically, shown as boxed symbols with the quantity underneath
  (matching the mission tree's element framing) instead of a small pill
  with a badge. Crafted-item rows are noticeably larger (icon and text
  both). The score, previously only visible in the topbar -- which the
  drawer covers when open -- now also shows in the drawer's own header,
  far right.
- **Item Reference rebuilt** to use the full row width: a large icon on
  the left, name/tier/points on one line to its right, ingredients and
  build locations flowing horizontally beneath instead of the previous
  narrow fixed-width grid columns (which is also what forced the old
  mobile breakpoint to stack everything vertically -- this layout doesn't
  need one).
- **Card popup now opens centered** on screen instead of pinned near the
  top (same top-of-viewport clipping bug as the tall-overlay fix from
  the last round, just on `.pc-card` instead of `.sheetbox`, which never
  got that fix). Opening a card by tapping an inventory item no longer
  auto-dismisses it; opening one via a fresh purchase still does, exactly
  as before.
- **Map station cards now show that station's banner art**, faded via a
  gradient (nearly invisible on the left, nearly opaque on the right) so
  it doesn't fight with the title/dice-pool text sitting on top.
  `build_campaign_art.py` gained a `banners/` output alongside its
  existing `tutorial/`/`backdrops/` ones.
- **Fixed: tapping the Map button before rolling gave no feedback at
  all.** It used a real `disabled` attribute, which swallows the click
  event entirely -- combined with no hover state on touch, that meant a
  locked tap did nothing visible. Now shows the existing hint-popover
  ("Tap PLAY before returning to the map") instead, and does nothing at
  all when unlocked (the button is genuinely still clickable underneath;
  `mapLocked()` gates the behavior instead of the DOM state).
- **The guided tour (including the every-new-session welcome slide) can
  no longer be skipped** -- removed the SKIP button and the Escape-to-
  close shortcut. Forward/backward navigation (tap zones, arrow keys)
  is unaffected.
- Station dice: the element name is now inside the same colored chip as
  the symbol, directly underneath it, instead of sitting below the chip
  as a separate line.
- Shop item card background is now a left-to-right gradient (opaque on
  the left, fading toward the right) instead of a flat color, so the
  item name/icon stay easy to read while more of the station backdrop
  shows through toward the row's other end. Dark theme's station-backdrop
  wash was also lightened (.6 -> .42 opacity) -- it was reading as too
  muted/dark against the art.

## v2026.07.29.3 (dark default, welcome slide, drawer fix)

- **Dark is now the default theme** for any device with no saved
  preference yet. Existing/explicit theme choices are untouched.
- **The welcome slide now opens every new session** -- the very first
  time the game is ever loaded, and every explicit "Start a brand new
  session" (Settings, or after a session ends). Reloading the page
  mid-session does not re-trigger it. Dismissing it (tap, skip, or
  Escape) reveals the mission picker immediately underneath, exactly as
  before -- it doesn't fall through into the rest of the guided tour.
- **Fixed: the last few inventory items were unreadable**, hidden behind
  the bottom button hub. `#drawer` used to run the full screen height
  behind the hub (which sits on top via z-index); now it stops flush
  above the hub, mirroring the fix already applied to the mission sheet.
- Shop item background color changed to a shade from the dark theme's
  own palette (`--mute`, `#7d8899`) instead of each theme's own lighter
  grey -- same transparency as before (.48/.54), just one consistent hue
  in both themes now. Dark theme was already using this exact color, so
  only light theme's cards actually changed. Dark theme's own opacity
  bumped separately right after (.54 -> .64) since the color-only change
  was barely noticeable there.

## v2026.07.29.3 (campaign art, cont'd)

- Shop item rows now sit on a soft translucent grey card
  (`--item-bg`, themed) instead of nothing, so they stand out clearly
  against the new station backdrops. Craftable items keep their existing,
  more prominent green -- this is only the default/needs-more-ingredients
  and owned states, which previously had no background of their own at
  all. Capstone box items are unaffected (they already override to
  `background:none` to avoid double-backgrounding inside the gold box).
  Opacity bumped up twice more after the first pass read as too faded:
  .16/.20 -> .32/.38 -> .48/.54 (light/dark).

## v2026.07.29.3 (campaign art)

- **Welcome slide added to the front of the guided tour.** The hand-
  illustrated "Elementia" title art (`images/Welcome Screen.png`) is now
  `game/tutorial/0.webp`, the tour's opening slide before the 15 existing
  ones. `game/build_campaign_art.py` (new) generates it, alongside:
- **Each station screen now shows its own faded backdrop art.** The
  station's own illustration is layered into the `.sheet` card's
  background (not just the page margins around it, which are nearly
  invisible on the phones/tablets this actually runs on) via a themed
  wash so it stays consistent across light/dark and never fights with
  text -- every item row, ingredient chip, and button keeps its own
  solid background, so legibility is untouched. Only shows behind an
  actual station; the map, inventory, reference, and settings screens
  are unaffected. `images/Elementia Logo.png` is intentionally unused
  (reference art only).
- `build_artifact.py`'s image-inlining step is now general (any
  `tutorial/*.webp` or `backdrops/*.webp` reference, not just the tour
  slide array), so it picked up the new backdrops with no changes needed
  beyond widening the regex.

## v2026.07.29.3 (game-only follow-ups, one more)

- **The old text-based "Welcome to Elementia" rules screen is gone.**
  "Guided tour" in Settings is renamed **"How to Play"** and is now the
  one and only how-to-play entry point — it no longer auto-opens on
  first run either. Removed alongside it: the `helpBtn` row, the
  `#tutorial` overlay markup/CSS, and `prefs.seenTutorial` (which existed
  solely to gate that screen). The mission picker's auto-open on first
  visit to the map — previously gated on "has the player closed the
  tutorial yet" — now just fires on its own condition (first map view,
  no mission chosen yet), since there's no tutorial left to wait on.

## v2026.07.29.3 (game-only follow-ups, cont'd again)

- **Fixed: tall overlays clipped their own top off-screen with no way to
  scroll up to it.** Every dialog in the game (`.overlay`/`.sheetbox`)
  vertically centered via `align-items:center`, which centers "through
  the ceiling" once content is taller than the viewport — exactly what
  the redesigned Settings became. Switched to `align-items:flex-start` +
  `margin:auto` on the box itself: auto margins can't go negative, so
  they collapse to 0 and the box settles flush to the top (scrollable)
  instead of overflowing both directions. Short dialogs still center
  exactly as before. Fixes every overlay, not just Settings.
- **"No repeat station twice in a row" now defaults to on** for new
  sessions, nudging players toward spreading out across stations instead
  of farming the one they're standing at.

## v2026.07.29.3 (game-only follow-ups, cont'd)

- **Settings redesigned as one bordered row per setting**, matching the
  card language already used everywhere else (history rows, mission tree,
  inventory list): icon + label + description on the left, a single clear
  control on the right. Replaces the old dense multi-button-per-line
  layout. Toggles (No repeat station, Unlimited visits) are now real
  switch controls instead of bare checkboxes; "Start a brand new session"
  is visually flagged as the one destructive action in the list. Fixed a
  latent bug along the way: the Theme button used to lose its own label
  the first time you tapped it (`textContent` overwrite replaced "◐ Theme"
  with just "☾") — it now shows an icon plus the current mode ("Auto" /
  "Light" / "Dark") that updates correctly on every tap.

## v2026.07.29.3 (game-only follow-ups)

- Element names now show next to the symbol in the mission tree (boxed,
  e.g. "Al Aluminum") and underneath the die chip at each station (e.g.
  "Si" over "Silicon") — new `ELEMENT_NAMES` lookup in elementia.html,
  hand-kept in sync with `build_element_cards.py`'s element list. Station
  dice layout/sizing untouched; the name is a small added label only.
- **Button hub now stays on top of the mission sheet**, not the other way
  around — reversed from v2026.07.29.2's "hide the hub while the mission
  sheet is open" approach once it became clear the hub should stay visible
  and tappable instead. `#hub` raised above `#missionSheet`/`#missionScrim`
  in z-index, and the sheet's open-state position now stops flush above
  the hub instead of covering it.
- **New History window**, opened from a "🕓 History" row in Settings:
  lists past runs (most recent first) with turn count, final score, and
  completed capstones (symbols only). Recorded automatically whenever a
  session ends or is reset early; stored under `elementia-history-v1`,
  capped at 50 runs.
- **Inventory items are now tappable** — opens the same card popup used
  elsewhere in the game, so players can review a crafted item's recipe
  and points without needing to find it at a station again.

## v2026.07.29.3

- **Brick removed.** Furnace and Building both route through Clay
  directly now (Furnace: Clay + C; Building: Concrete + Glass + Steel +
  Clay). 68 items in the game, down from 69. Shortens the Furnace/Steam
  chain by one hop each, which ripples through everything downstream —
  Steam, Cloud, Plastic, Storm, Rainbow, Car, Computer, Rocket,
  Skyscraper, City, Robot, Maglev Train, Ecosystem, Space Station, Bread,
  Cake, Multi-Layer Cake, Waterworks, and Museum all got 1-2 points
  cheaper to match, recomputed with the same difficulty formula as the
  full recalibration (points = 0.545 × (n_items + 0.5×elem_qty +
  1.5×depth)), not guessed.
- **No more per-element carry cap.** Rolling past 3 of an element used to
  bounce it back to the pool; elements now just stack in inventory with
  no ceiling. Removed the cap enforcement in `doRoll()`, the "FULL" /
  greyed-out die treatment, the inventory chip's red "full" state, the
  "max 3 of each element" line on the map and in the drawer, and the
  matching tutorial rule and printed-guide footer text.
- The Quarry's dice were `Ca, Ca, C, K, Si, Al` (Ca on two faces); one Ca
  face is now Oxygen, giving the Quarry a new element instead of a
  duplicate.
- Not touched: `element_stock.py`'s physical-card print-quantity sizing
  still assumes the removed cap (it's what bounded peak concurrent
  demand). Worth revisiting before the next print run, since demand is
  no longer capped at 3-per-group in theory.

## v2026.07.29.2

- **Mission tree is read-only.** No Craft buttons in the mission sheet —
  it's a map of what's still needed, not a second place to build from.
  Crafting stays at the station shop, where it belongs.
- Dropped the MATERIAL/COMPONENT/CREATION/CAPSTONE tag from mission tree
  rows and the red inventory-count bubble on the hub — both were noise
  next to the name/location/done-state that's actually there to read.
- Raw elements in the mission tree now sit in a bordered box (matching
  the printed element cards), so they read as a different *kind* of thing
  from crafted items at a glance, not just another row in the list.
- **All toast popups removed** — the "Collected X · Y returned" message
  on every roll, the mission-set/mission-complete/theme/new-session/
  settings-saved confirmations, all of it. Every one of these duplicated
  something already visible elsewhere (the rolled-dice cards, the
  mission sheet itself, the theme icon, the reset screen, the settings
  fields) — nothing is lost, just no longer said twice.
- Skyscraper: Building + Cloud (was Concrete + Glass + Cloud) — now
  reaches through Building rather than duplicating its ingredients,
  making it a genuinely bigger build. Skyscraper 14→16, City 22→23.
- Mission-sheet/hub stacking hardened: the hub is now force-hidden
  (`visibility:hidden`, not just out-z-indexed) whenever the mission
  sheet is open, so it can't be tapped through or peek out from behind
  it under any rendering quirk.

## v2026.07.29

- **Mission tree shows where things come from.** Every row — items and
  raw elements, at every depth — now carries the station emoji it's
  found at, no text. The "need" label is gone; grey vs. green already
  says it.
- **Home is a raised circle in the middle of the hub**, and is greyed out
  and untappable at a station until the visit's dice are rolled (the
  visit is already spent by then, so leaving early only wastes it).
  Closing the item reference now returns you to the station you opened it
  from rather than the map, which also closes that as a way around the lock.
- **Single player.** The Groups / save-slot system is removed: one save,
  one key (`elementia-save-v3`). Existing progress is migrated forward on
  first load (the active group's save wins) and every old key is swept up.
- **Fixed: "Start a brand new session" did nothing.** It gated on
  `window.confirm()`, which sandboxed frames — including the published
  Artifact — suppress silently, returning `false` without ever prompting,
  so the handler always early-returned. Confirmations are now an in-page
  dialog, which works everywhere.
- **Points recalibrated across all 69 items** against a component-tree
  difficulty score (`n_items + 0.5*elem_qty + 1.5*depth`, scale fit
  robustly to the well-calibrated majority). Validated before applying:
  an item is now always worth strictly more than everything inside its
  own tree (13 violations before, 0 after — e.g. Cloud 4 was cheaper than
  the Steam 7 it's built from; Pancakes 24 tied the Cake 24 it contains).
  Biggest moves: Rainbow 9→16, Plastic 5→10, Computer 7→12, Cloud 4→9,
  Storm 7→12, Rocket 13→18, Car 14→18, Ecosystem 17→22, Robot 18→22,
  Maglev Train 15→19; down: Waterworks 18→11, Skyscraper 20→14,
  Multi-Layer Cake 33→28, City 26→22, Museum 23→19, Homestead 24→20.
- **Farm is no longer a special case.** `farm_section` removed entirely;
  Cow/Chicken/Grain now sit in the Greenhouse shop like any other item.
  All crafted items have been permanent unlocks (owned, never spent) for
  a long time, so the "Farm is required, but not spent" carve-out — and
  its separate box on the station page, its catalyst flagging, and its
  tutorial rule — were leftovers from when Farm was the only such item.
- **UI: bottom hub.** Map / Mission / Inventory / Items / Settings now
  live in a fixed bottom bar on every screen, replacing the floating
  mission tab (which covered content), the station-only "Return to Map"
  bar, the drawer's own map button, and the topbar icon cluster.
- **UI: topbar rebuilt.** Removed the back button, the "⚗️ Elementia"
  title, the "Group" label, and the capstone counter. Visits are now a
  progress bar that fills as stations are visited (amber at ≤3 left, red
  when spent); total score sits in a gold circle at the top right,
  deliberately matching the points badge on the printed cards.

## v2026.07.28.3

- Cement removed entirely; Concrete now Ca + Clay + Sand + Water directly
  (was Cement + Sand + Water, Cement itself Ca + Clay). Same "thin
  pass-through" pattern as Brick — this one shortens Bridge/Building
  without touching Skyscraper/Waterworks (those are bottlenecked by
  Cloud/Steam, not Concrete).
- Mission window rebuilt: was a centered modal opened from a topbar icon,
  now a persistent bullseye tab fixed at the bottom-left corner on every
  screen, sliding a bottom-sheet panel up/down. The 2 mission capstones
  are listed vertically, and every node — at any tier, all the way down
  to raw elements — expands independently to reveal its own ingredients,
  functioning as a real to-do list (✓ done / Craft-if-ready / still
  needed at a glance). Expand state survives re-renders and crafting.

## v2026.07.28.2

- Steam: Water + Furnace (was Water + C) — now a Deep Mine chain item
  instead of a shallow one; ripples into Cloud, Plastic, Rainbow/Storm,
  and Maglev Train, all of which get meaningfully harder as a result.
- Waterworks: Concrete + Steam (was Concrete + Furnace).
- Skyscraper: Concrete + Glass + Cloud (was Building + Glass + Mirror) —
  now reaches into the Observatory via Cloud instead of Mirror.
- Mission picker is now a full-screen overlay shown once at the true
  start of a session (after the tutorial, if it's a new player), instead
  of an always-visible banner on the map. Tapping either capstone in the
  overlay expands its full recipe card (live have/need status, working
  Craft button) in place.
- Inventory drawer no longer auto-focuses the filter input on open (was
  popping the mobile keyboard immediately); added a "Return to Map"
  button to the drawer footer.

## v2026.07.28

- Card graphics: points moved into a circular badge in the top-right
  corner; tier tag moved to the old points position below the icon.
- Bronze/Steel points 3→2, Clay 2→3 (matches difficulty-audit findings).
- Furnace added to Deep Mine (Brick + C); Bread/Cake/Pancakes/Multi-Layer
  Cake recipes restructured around it.
- Maple Syrup: Amber + Furnace (was Amber + Sugar).
- Rainbow: Storm + Glass (was Glass + Water).
- Maglev Train: dropped redundant Tools (Engine already requires it).
- Space Station: dropped redundant Computer (Rocket already requires it).
- City rework: Bridge (+Water), Skyscraper (+Mirror), Waterworks
  (reworked to Concrete + Furnace) — each now reaches into another
  station's item, matching Museum's existing Dinosaur/Building pattern.
- Mission cards: pick 1 of 3 capstone-pair missions per session
  (Ticket to Ride style), tracked to completion.
- Digital game: visit-limit setting (with Unlimited option), dice-per-visit
  setting, live points counter, crafted-item card popup, full UI overhaul
  (condensed topbar, icon bar, Settings menu, bottom map-return bar,
  mobile-width dice row, item-reference search-overlap fix).
- Infra: git repo initialized; `build_all.py` and `game/build_artifact.py`
  replace the previous manual multi-command build/publish process.

## Earlier (pre-changelog)

Everything before this file existed — element carry cap, 15-visit session
limit, permanent-unlock economy, capstone celebrations, multi-group saves,
in-game item reference, printable card decks and print-run sizing. See
`Elementia_Handoff/handoff/HANDOFF.md` and `CURRENT_GAME_STATE.md` for
the pre-git project history.
