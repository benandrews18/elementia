# Running the reachability simulation yourself

Everything here is plain Python (standard library only — no `pip install`
needed). If you can run the other scripts in this folder, you can run these.

## 1. Run the simulation

```bash
cd Elementia_Handoff/handoff/simulation
python simulate_reachability.py
```

This regenerates `reachability_grid.csv` in this same folder — 71 items x 8
stations, 40 trials per cell, a few seconds to run. It always reads the
*current* `build_guide.py`, so any data changes you've made are picked up
automatically, no separate build step required.

Then, to get the UsedBy / AvgVisits / BottleneckScore / Rank columns added
(and the console summary of bottlenecks/outliers/element scarcity):

```bash
python analyze_bottlenecks.py
```

This reads `reachability_grid.csv` back in, computes the rankings, and
rewrites the same CSV with those columns added — sorted by Rank, biggest
bottleneck first. Open it in Excel/Numbers/Sheets and sort however you like.

Run `simulate_reachability.py` again any time you change the data — it
overwrites the CSV from scratch, so `analyze_bottlenecks.py` needs a fresh
run after it each time too (order matters: simulate, then analyze).

## 2. Editing what gets tested

**Station element pools (dice) and item shops** both live in one place —
`Elementia_Handoff/handoff/pdf_generation/build_guide.py`, in the `STATIONS`
list. This is the same file the real game and printed cards are generated
from, so an edit here is a real proposed change, not a sandboxed copy —
but that also means it's the *only* file you need to touch, and every
script in this folder (including the two above) reads it live via
`model.py`, no rebuild step needed for simulation purposes.

**Dice** (6 element symbols per station):
```python
"dice":["C","O","H","Si","Na","Cl"],
```
Swap any symbol for another element's (see `ELEMENTS` — the 16 two-or-fewer-
letter symbols used throughout, e.g. `Ca`, `Cu`, `Fe`). Keep exactly 6.

**Shop items** (one tuple per item: emoji, name, tier, recipe string, points):
```python
("⏳","Sand","MATERIAL","Si + O",2),
```
- Tier is one of `MATERIAL` / `COMPONENT` / `CREATION` (capstones are the
  separate `"capstone"` entry at the end of each station block, not in `shop`).
- The recipe string is `+`-separated tokens: a bare 1-2 letter symbol means
  a raw element (`Si`), `emoji Name` means another item (`🌳 Tree`). A
  trailing `*` on a token marks it a catalyst (consumed check but not spent).
- **To give an item a second home**, add the same tuple (same name/recipe)
  to a *different* station's `shop` list. `model.py` and both simulation
  scripts already handle multi-homed items correctly (each home can even
  have a different recipe, like Soil currently does between Greenhouse and
  Old Growth Forest) — no code changes needed on your end for that.

**The station graph** (which stations connect to which) is separate from
`build_guide.py` — it lives in `simulate_reachability.py` itself, as
`CUSTOM_EDGES` near the top of the file. Edit that list directly to test a
different web; the script sanity-checks on startup that every station still
has at least one connection.

## 3. If you don't like a change

Everything here is tracked in git. `git diff` to see what you changed,
`git checkout -- Elementia_Handoff/handoff/pdf_generation/build_guide.py`
(or the specific file) to throw it away and get back to the last commit.
Nothing here touches the live game or the printed PDFs unless you separately
run `build_all.py` — editing `build_guide.py` and running the two scripts
above is fully self-contained to this simulation.
