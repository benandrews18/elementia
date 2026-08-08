# Elementia — Handoff Document
*Generated at the end of a long Claude.ai session, for continuation in Claude Code.*

## 1. What Elementia is

A STEM summer-camp game (Little-Alchemy-inspired) for ~40 kids aged 8-12, in groups
of 3, running 1-2 hours. 8 physical stations, each with a 6-sided die whose faces
map to 6 distinct raw elements (uniform 1/6 odds — no "champion" face-doubling
anymore, that mechanic was removed this session). Each station visit: roll the die
some number of times (currently modeled at TAKE=5 per visit, not yet locked as a
final real-world rule), collect elements, and combine elements/items into new
items using printed recipe cards. Every station has a capstone — a deep, ambitious
build requiring materials from multiple stations.

**Core economy rule (added this session): crafted items are permanent "unlocks."**
Once a group crafts Water, they keep it forever and can use it in any future
recipe without spending it. **Only raw elements are consumed/depleted.** This was a
deliberate, major design change partway through the session (see §4) — it fixes a
long list of otherwise-impossible recipes and should be treated as the current
intended game rule going forward, not just a simulation convenience.

## 2. Current file state

- **`build_guide.py`** is the single source of truth for the game's actual
  content (all 8 stations, every recipe, every dice pool). It ALSO generates the
  Station Guide PDF as a side effect of being imported/run.
- **All three PDFs (Station Guide, Full Card Deck, Element Cards) are fully
  up to date** as of this handoff — every change discussed in this session has
  been pushed into `build_guide.py` and the PDFs regenerated from it. Nothing is
  sitting in a "simulation-only, not yet real" state anymore.
- The `simulation/` folder's `model.py` reads `build_guide.py` directly with
  **no override layer** — it's a clean 1:1 reflection of the real game.

## 3. How to regenerate the PDFs

```bash
python3 pdf_generation/build_guide.py        # writes guide.html, prints station count
python3 pdf_generation/render.py             # guide.html -> Elementia_Station_Guide.pdf
python3 pdf_generation/build_cards_full.py   # writes full_cards_*.html
python3 pdf_generation/render_cards_full.py  # -> Elementia_Full_Card_Deck.pdf (merges portrait+landscape)
python3 pdf_generation/build_element_cards.py
# then a small inline Playwright call renders element_cards.html -> Elementia_Element_Cards.pdf
# (see the tail of a recent session transcript, or just re-add a render step
#  identical to render.py but pointed at element_cards.html)
python3 pdf_generation/check.py              # verifies no station-guide page overflows
python3 pdf_generation/check_full.py         # verifies no card overflows
```

All rendering uses **Playwright + Chromium** (HTML → PDF), not a PDF library
directly. This was a deliberate choice partway through the original design
process because it made complex layouts (grids, badges, dice) far easier than
direct PDF manipulation. **One gotcha**: Playwright's `page.pdf()` ignores the
`landscape` argument if you also pass explicit `width`/`height` — use
`format="Letter"` + `landscape=True/False` instead (see `render_cards_full.py`
for the working pattern; `render.py` predates this fix and uses explicit
width/height for portrait-only output, which is fine since it never needs
landscape).

## 4. Simulation methodology — read this before trusting any old numbers

Three progressively-better simulation models were built this session. **Only the
two exported here (`simulate_kid.py`, `simulate_capstone_focus.py`) are trustworthy
— several earlier attempts (not exported) hit real bugs and should not be
resurrected without the fixes described below.**

### Model 1: `simulate_kid.py` — "realistic camp session"
13 groups, 12-15 station visits each, TAKE=5, multi-focus behavior (each group
commits to 2-3 goal items rather than one, no random "distraction" — groups
pick a small fixed set of things they want and pursue them opportunistically).
Reports % of groups reaching each item at least once. Good for print-quantity
planning and "what does an average session look like."

### Model 2: `simulate_capstone_focus.py` — "best-case reachability"
Each group is assigned ONE random capstone and pursues it with complete,
single-minded focus for 15 visits, fully random dice, **cannot visit the same
station twice in a row**. This answers "is X achievable at all by a maximally
dedicated group" — the honest ceiling. Use this to judge whether a capstone is
structurally sound vs. structurally broken.

### Both models share `total_needs()` — the DAG-correct requirement calculator
This function walks a goal's recipe tree and returns how many of each raw
element / each unique crafted item are needed. **It must treat the recipe graph
as a DAG, not a tree** — i.e., if both Deer and Ecosystem-directly need Tree,
that's ONE Tree needed total (permanent unlock), not two. Elements are the only
things that genuinely accumulate demand across multiple consumers.

## 5. Bugs found this session — do not reintroduce these

**Bug A: Station-routing ignored scarcity.** Early station-choice logic scored a
station by "how many recipes can I finish here" (+2 per craftable item), with
raw-element needs only worth +1 flat regardless of how rare that element was.
This meant a station hosting many items (e.g. Deep Mine, with 4+ recipes) would
*always* outrank a station that was the *only* source of one specific needed
element (e.g. Power Plant for Sn) — so simulated groups would never visit the
exclusive-source station at all, and anything needing that element looked
permanently impossible (0% completion) when it was actually fine.
**Fix:** weight element contributions by scarcity — an element with only 1
source station gets a big bonus (10), 2 sources a medium bonus (5), 3+ sources
a small flat bonus (1). See `choose_station()` in `simulate_capstone_focus.py`
for the corrected version. **This fix alone took Farm from a bugged 0% to a
real 34%, and several capstones (Homestead, Locomotive) from 0% to 50-90%.**

**Bug B: `total_needs` double/triple/quintuple-counted shared ingredients.**
The original `flatten_needs` multiplied quantities down through the tree
assuming every reference to an ingredient needed its own fresh copy — correct
for a spend-it-and-it's-gone economy, **wrong for the permanent-unlock economy**
this game now uses. Ecosystem's true Water requirement was being computed as 5
(it should be 1) because Water is referenced by 4 different branches of its
tree (Deer, 2×Salmon-path, Tree-building's Clay). This silently made any
capstone with branching demand on a shared item look far harder than it really
was. **Fix:** rewritten as a proper DAG walk — each unique non-element item
is counted at most once, and its own raw-element cost is paid once, no matter
how many parents reference it. See `total_needs()` in either simulation file
for the corrected version. **This fix alone took Ecosystem from a bugged 0-20%
to a real 77-95%.**

**Lesson for future work:** whenever a completion rate is suspiciously low
(especially a hard 0%), don't accept "the recipe must be too hard" — trace an
isolated single-group attempt with full logging (station visited each turn,
what's been crafted so far, what's still missing at the end) before concluding
anything about game balance. Both bugs above were found exactly this way, and
both turned out to be simulation logic errors, not real design problems.

## 6. Open / unresolved items — your call on these

1. **The Quarry's dice pool is still the old style** (`Ca,Ca,C,K,Si,Al`, with Ca
   doubled) — every other station moved to 6 distinct elements this session,
   but Quarry was restored late and never got the same treatment. Low priority,
   but worth deciding for visual/mechanical consistency.
2. **TAKE=5 dice rolls per visit** and **"no repeat station twice in a row"**
   were tested extensively in simulation but never explicitly confirmed as
   final real-world rules for physical play — they're baked into the sim
   defaults but you may want to reconsider before printing a rulesheet.
3. **City, Space Station, and Multi-Layer Cake remain hard** (5-6%, 2-5%, and
   0% respectively even under best-case focused play) — this is now believed
   to be real difficulty (both bugs above are fixed), not a bug, but worth a
   final sanity check if you want every capstone reachable in one session.
4. Clay's recipe uses `Al + Si + Water` (a crafted item) rather than a third
   raw element — this was an intentional choice ("groups often already have a
   spare Water") but is the one recipe in the game mixing raw elements with a
   crafted-item ingredient in a MATERIAL-tier recipe; worth knowing if you
   want tier tagging to stay strictly consistent.

## 7. Design principles established this session (worth preserving)

- **Permanent-unlock economy** (see §1) — this is now core, not optional.
- **Farm-style catalysts**: an ingredient can be marked "required but not
  consumed" (Farm for Cow/Chicken/Grain) using a trailing `*` in the recipe
  string parsed by `parse_requirements()`.
- **Station pools should be 6 distinct elements** with genuine local recipe
  use for as many of them as possible — audit any station where an element
  sits in the pool with zero local consumer (that's "bloat," per your framing
  from earlier in the session — flavor is a luxury this game can't afford at
  this scale, everything should pull weight).
- **Capstone reach**: deliberately keep capstones requiring materials from
  multiple stations (reach 3+) — this is the mechanic that makes the game
  "make campers travel," and it's been a recurring design goal throughout.
