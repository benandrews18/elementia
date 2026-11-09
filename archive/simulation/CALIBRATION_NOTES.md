# `simulate_classic_run.py` — calibration notes

## Why this file exists

Every other multi-visit simulator in this folder (`simulate_kid.py`,
`simulate_mission.py`, `simulate_pathing.py`, `simulate_pathing_v2.py`,
`simulate_capstone_focus.py`) models the **old physical summer-camp**
version of Elementia — 13 groups of kids, `TAKE=5`, 12-15 visits, and the
full ~159-item catalog. None of that matches the current single-player
digital game (`TAKE=6`, a 20-visit Classic Mode run, and a curated
79-item `CORE_SET`), so `simulate_classic_run.py` was written fresh
rather than adapted from camp-era heuristics.

It was calibrated against real Classic Mode session exports (from
History → Export, or History → the per-run ⧉ button next to a single
run once that shipped) reproduced below for reference.

**On "6 runs" vs "9 runs" (clarified 2026-09-12):** the user's own count is
6 runs from an earlier session's analysis + 3 more (D/E/F) added today =
9 real runs played so far. What's actually usable *here*, though, is only
the subset with a full per-visit item log attached to the export — that's
Run A/B/C (from the earlier session) plus D/E/F (today), i.e. 6 runs
total. The other 3 of the original 6 only ever had their AGGREGATE stats
(mean/min/max Display-Mat ceiling per round) captured, for the separate
Lock In calibration in `game/elementia.html`'s own `LOCKIN_ROUND_ANCHORS`
comment — not a full visitLog, so they can't be replayed through this
simulator or rescored against a new point curve. If those 3 still have a
History export sitting around, they'd upgrade this file from 6 usable
runs to 9; otherwise, new runs (which the user is already planning to
play) are equally good going forward.

## Reference runs

| | Run A | Run B | Run C | Run D | Run E | Run F |
|---|---|---|---|---|---|---|
| Score | 409 | 313 | 346 | 369 | 366 | 299 |
| Capstones | 1 (Maglev Train) | 2 (Robot, Maglev Train) | 1 (Homestead) | 2 (Robot, Metropolis) | 1 (Space Station) | 3 (Robot, Maglev Train, Metropolis) |
| Items crafted (20 visits) | 56 (~2.8/visit) | 45 (~2.25/visit) | 52 (~2.6/visit) | 44 (~2.2/visit) | 45 (~2.25/visit) | 39 (~1.95/visit) |
| Visits with 0 items crafted | 3/20 | 4/20 | 1/20 | 2/20 | 2/20 | 3/20 |

Runs D/E/F added 2026-09-12 (History exports; these three are also the
first exports to carry `bingoCard`/`bingoLinesCompleted` -- see "If you
get more reference runs" below). Station visit share across all 6 runs
combined (120 visits): The Power Plant 19%, The City 16%, Deep Mine 16%,
The Ocean 12%, The Observatory 12%, Old Growth Forest 9%, Greenhouse 4%,
The Bakery 3% -- D/E/F skew much harder toward Power Plant/City/Deep
Mine/Observatory than A/B/C did, tracking exactly the 4 capstones those
three runs happened to chase (Robot, Metropolis, Space Station, Maglev
Train all live at those 4 stations; none of the 6 runs' capstones came
from Greenhouse or The Bakery). Read as real run-to-run variance in which
capstone(s) a player is chasing, not a stable target distribution the
simulator should be fit tightly to -- still no station is ever fully
starved, and the earlier note about the simulator's own mild
over/under-visit skew stands unchanged.

**Capstone completion rate -- the real gap, confirmed harder by D/E/F.**
Combined across all 6 runs, real players average **1.67 capstones per
20-visit run** (1, 2, 1, 2, 1, 3) -- notably higher than A/B/C alone
suggested (mean 1.33). The simulator, still at `GOAL_AWARE_CHANCE=0.9`,
averages only **0.87**. Two things were tried against the new data and
BOTH failed to close the gap meaningfully:
  1. **Raising `GOAL_AWARE_CHANCE` toward 1.0** (i.e. the simulated player
     always picks the best-scoring reachable station, no randomness at
     all): capstone mean only reaches ~1.03 even at exactly 1.0 -- far
     short of 1.67, and pushing chance that high also stops looking like
     "a real player" at all (the whole point of this constant).
  2. **Weighting `score_station()`'s own scoring toward capstone-completing
     stations** (tried 2x/3x/4x/5x multipliers on both the "finishes an
     item outright" and "makes progress toward one" bonuses, specifically
     for capstone items): moved the mean only from 0.87 to ~0.97 even at
     4x, essentially noise.
  Conclusion: which station gets visited next isn't the bottleneck --
  `craft_all_possible()`/`rebalance_elements()` spend elements on
  whatever's finishable RIGHT NOW with no notion of holding some back for
  a capstone several visits out, so by the time a capstone's item
  ingredients are finally all in hand, there often isn't a good stretch of
  turns left (or aren't enough of the right elements banked) to also
  finish its own element cost. Real players seem to plan around this --
  see Run C's own note above about mis-timing being the FAILURE mode,
  which implies succeeding requires deliberately protecting elements for
  a specific target. Closing this gap for real would need actual
  lookahead (e.g. "don't spend element X below N if a not-yet-finished
  capstone still needs it"), which is a real design change to
  `rebalance_elements()`/`craft_all_possible()`, not a one-line weight
  tweak -- flagged here as the next real lever, deliberately NOT rushed in
  given neither quick attempt above moved the number. `GOAL_AWARE_CHANCE`
  stays at 0.9 and `score_station()`'s weights stay unchanged, since
  neither experiment produced a result worth the added complexity.

**Run C's own note from the player:** "Around turn 15-17 was a big
mistake because I mis-timed my creation of Star, which threw off my plan
to build Life as well." Traced against the actual log: by turn 15 (The
Observatory, Star's home) the player already owned Star's item
ingredients (Furnace, Clock) but had spent their last free H on Bakery
crafts a few turns earlier and never rolled another before reaching
Observatory again — turn 17 there produced zero elements it needed and
crafted nothing. This is a genuine "used a common element for a near-
term item instead of saving it for a specific later one" mistake, and
it's exactly the class of error `craft_all_possible()` + `rebalance_elements()`
already reproduce on their own: neither one holds an element back in
anticipation of a specific future recipe, they only react to shortfalls
that already exist. No code change needed here — this run is a
*validation* that the simulator's lack of lookahead matches how a real
(non-omniscient) player actually plays, not a gap to fix.

## Tuning history

1. **First pass** (`GOAL_AWARE_CHANCE=0.75`, whole-remaining-tree element
   shortfalls): mean score 281 over 500 trials — about 22% below the
   ~361 reference average, capstone rate too low (42% of runs finished
   zero capstones vs 0/2 reference runs).
2. **Frontier-only shortfalls**: `remaining_element_needs()` used to sum
   element demand across *every* not-yet-crafted core item, which diluted
   conversion priority across dozens of items still several crafts away.
   Narrowed it to only items whose non-element ingredients are *already
   owned* — "I have the pieces, I just need N more of this element" is
   what a real player is actually reacting to, not the whole remaining
   tech tree. Mean score → 295.
3. **`GOAL_AWARE_CHANCE` 0.75 → 0.9**: the single biggest lever. Mean
   score → 319 (median 320), capstone-rate 71% of runs finishing ≥1
   (mean 1.12/run) — within a stdev of both reference runs and no longer
   systematically low-balling either metric family (score, items/visit,
   capstone rate) at once.

Went no further than this after run C landed too (see above): with three
reference runs and run C sitting almost exactly between A and B, there's
no new signal pushing `GOAL_AWARE_CHANCE` in either direction. Chasing an
exact mean match on this few points still risks overfitting to noise
rather than tuning genuine player-behavior heuristics.

4. **Runs D/E/F landed 2026-09-12** (see the reference table above) and
   sharpened rather than changed the picture: score/items-per-visit still
   track the simulator reasonably (real combined mean score 350 vs sim
   308, real items/visit 2.34 vs sim 2.49), but capstone rate is now a
   confirmed, real gap (1.67 real vs 0.87 sim) rather than a 3-run
   coincidence. Tried and rejected raising `GOAL_AWARE_CHANCE` further and
   adding a capstone-completion weight to `score_station()` -- see the
   reference table's own writeup above for why neither moved the number.
   Left both unchanged; the real fix is a lookahead/element-reservation
   mechanic neither lever can fake.

5. **Found and fixed a stale `CORE_SET` (2026-09-12)**, while building the
   Point Curve tool's Classic-only item list: this script's own hand-
   transcribed `CORE_SET` still listed Greenhouse's core item as "Tractor"
   (should be Bicycle — Tractor moved to Deep Mine a while back) and
   Deep Mine's as "Titanium Alloy" (should be Tractor), and The Bakery's
   as "Bread"/"Cake" (both retired from the game entirely, in favor of
   Apple Pie/Fish Cakes). All three were simply never updated here when
   `elementia.html`'s own `CORE_SET` changed. Fixed to match; re-running
   after the fix moved the baseline only slightly (mean score 308→306,
   capstone mean 0.87→0.80) — not enough to invalidate anything above,
   but worth knowing this file's `CORE_SET` needs to be hand-resynced
   against `game/elementia.html`'s own copy (search `CORE_SET = new Set`)
   whenever that changes, since nothing currently catches drift between
   them automatically.

6. **Found deeper recipe drift while building the point-curve rebalance
   (2026-09-12), NOT fixed here.** `model.py` loads its recipes from
   `build_guide.py` (the PDF-guide source), and 4 of those have drifted
   from `elementia.html`'s real, live recipes: Homestead (real recipe
   uses Apple Pie, `build_guide.py` has Grain), Rocket (real: Fiberglass,
   `build_guide.py`: Solar Panel), Tractor (real recipe has no Farm
   ingredient at all; `build_guide.py` still lists one), and Space
   Station (real recipe adds a Solar Panel ingredient `build_guide.py`
   is missing). Of these, only Homestead's mismatch actually changes a
   computed recipe-depth (6 → 8, via Apple Pie's own depth of 7) — the
   other three's differing ingredient was never the deepest one either
   way. The point curve above uses the CORRECTED depth for Homestead
   (patched by hand in the one-off rebalance script, not in this file);
   `build_guide.py` itself was left alone since regenerating the PDF
   guide was explicitly out of scope for that pass. Fix `build_guide.py`
   directly next time PDFs are actually being touched.

## Known limitation — read before trusting this for anything but pacing

**This cannot see a player's Bingo card.** Real Classic Mode runs are
steered by a hidden 5×5 grid of item goals that materially changes which
items a real player prioritizes and when — that's very likely why the
reference runs favor certain items over similarly-reachable alternatives
the simulator might pick instead. `simulate_classic_run.py` still has no
equivalent signal and doesn't try to fake one, but **History's export now
includes the Bingo card and completed lines** (`bingoCard`,
`bingoLinesCompleted` on each run, added after runs A/B were captured --
they predate the field and don't have it) -- once enough exports carry
this, a genuine Bingo-aware heuristic becomes possible; see the note
below. Until then, use this for **aggregate pacing** (typical score
range, how many capstones a 20-visit run finishes, how bursty per-visit
crafting is, roughly how visits spread across stations) — not for "would
a real player craft X before Y."

## If you get more reference runs

Use History's per-run ⧉ export (next to each run, not just the "Export
all" button) to hand over one run at a time. Re-run
`python simulate_classic_run.py`, compare its printed aggregate stats
against the new run(s), and adjust `GOAL_AWARE_CHANCE` and/or
`score_station()`'s scarcity-bonus weights (8/3/1 for 1/2/3+ element
sources) — in that order, since those are the two levers tuning has
actually moved so far.

Once several runs carry a `bingoCard`, a real Bingo-aware heuristic
becomes possible: `score_station()` could add a bonus for stations that
produce/feed a card item not yet owned, weighted higher for items on a
line the player is already partway through (`bingoLinesCompleted` plus a
partial-line check against `bingoCard`). Don't build that off a guessed
card layout — wait for actual exported ones to test against, a wrong
guess is worse than the current no-Bingo-signal baseline.
