# -*- coding: utf-8 -*-
"""Bottleneck / pain-point analysis over reachability_grid.csv (see
simulate_reachability.py). Answers three distinct questions that "how many
visits does item X take" alone doesn't:

  1. STRUCTURAL BOTTLENECKS -- items many OTHER items' build trees pass
     through, weighted by how costly that item itself is. A slow item with
     high fan-out drags on everything downstream of it, not just itself.
  2. DIFFICULTY OUTLIERS -- items that take meaningfully longer than OTHER
     items of the same recipe depth (excludes capstones and >=19-point
     creations, i.e. the game's own "big items", per the user's question:
     which non-flagship items are surprisingly hard).
  3. ELEMENT SCARCITY -- elements many items need but few stations roll,
     a structural source of friction underneath the item-level numbers.
  4. STATION-SENSITIVITY -- items whose visit count swings the most
     depending on which station you start at (i.e. where the graph itself,
     not the recipe, is the bottleneck).

Requires reachability_grid.csv to already exist (run simulate_reachability.py
first) -- this script only re-derives structural facts from model.py plus
that CSV's numbers, it re-simulates nothing. As a side effect it writes
UsedBy/AvgVisits/BottleneckScore/Rank columns back into that same CSV
(sorted by Rank, biggest bottleneck first) so the full ranking -- not just
the top 15 printed to the console -- is there to sort/filter in a
spreadsheet.
"""
import csv, statistics, sys, pathlib
from collections import Counter, defaultdict

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from model import RECIPES, ELEMENTS, STEPS, ALL_STATIONS, STATIONS

CSV_PATH = pathlib.Path(__file__).resolve().parent / "reachability_grid.csv"

ITEM_POINTS, ITEM_TAG = {}, {}
for s in STATIONS:
    shop_items = list(s["shop"])
    if s.get("farm_section"):
        shop_items += s["farm_section"]["items"]
    for emoji, name, tag, recipe, points in shop_items:
        ITEM_POINTS[name] = points
        ITEM_TAG.setdefault(name, tag)
    ce, cn, ct, cr, cpts = s["capstone"]
    ITEM_POINTS[cn] = cpts
    ITEM_TAG.setdefault(cn, "CAPSTONE")

# 8 items in the current catalog are sold at TWO stations (Sand, Water,
# Sugar, Limestone, Soil, Steel, Clay, Glass). Earlier passes of this
# script only ever read RECIPES[item][0], silently treating all of them as
# single-homed via whichever station happened to be listed first in
# build_guide.py -- both closures below now union across EVERY home's
# ingredients instead (Soil in particular needs different things at its
# two homes: Greenhouse's needs Water too, Old Growth Forest's doesn't).
def closure_items(item):
    """Every item (not the item itself) in item's build tree."""
    seen = set()
    def visit(it):
        if it in ELEMENTS or it in seen:
            return
        seen.add(it)
        recs = RECIPES.get(it)
        if not recs:
            return
        for st, req, catalysts, tag in recs:
            for ing, qty in req.items():
                if ing in catalysts or ing in ELEMENTS:
                    continue
                visit(ing)
    for st, req, catalysts, tag in RECIPES[item]:
        for ing, qty in req.items():
            if ing in catalysts or ing in ELEMENTS:
                continue
            visit(ing)
    return seen

def closure_elements(item):
    elems, seen_items = set(), set()
    def visit(it):
        if it in ELEMENTS or it in seen_items:
            return
        seen_items.add(it)
        recs = RECIPES.get(it)
        if not recs:
            return
        for st, req, catalysts, tag in recs:
            for ing, qty in req.items():
                if ing in catalysts:
                    continue
                (elems.add if ing in ELEMENTS else visit)(ing)
    visit(item)
    return elems

items = list(RECIPES.keys())

used_by = Counter()
for y in items:
    for x in closure_items(y):
        used_by[x] += 1

elem_used_by = Counter()
for y in items:
    for e in closure_elements(y):
        elem_used_by[e] += 1
elem_station_count = {e: sum(1 for s in STATIONS if e in s["dice"]) for e in ELEMENTS}

rows = list(csv.DictReader(CSV_PATH.open(encoding="utf-8")))
avg_visits = {}
for r in rows:
    vals = [float(r[st].split(" ")[0]) for st in ALL_STATIONS if r[st] != "DNF"]
    if not vals:
        # Zn-dependent items (Brass, Trombone, Cruise Ship) are DNF at every
        # station in this model -- Zn only exists at the Island sub-zone,
        # outside this Python pipeline by design (see SUBZONES's own comment
        # in elementia.html). No visits data to analyze for these.
        avg_visits[r["Item"]] = {
            "mean": None, "min": None, "max": None, "spread": None,
            "steps": (int(r["Steps"]) if r["Steps"] != "" else None), "tier": r["Tier"],
        }
        continue
    avg_visits[r["Item"]] = {
        "mean": statistics.mean(vals), "min": min(vals), "max": max(vals),
        "spread": max(vals) - min(vals), "steps": int(r["Steps"]), "tier": r["Tier"],
    }

def section(title):
    print(f"\n=== {title} ===")

section("STRUCTURAL BOTTLENECKS (used by many other items x costly to get)")
scoreable = [it for it in items if avg_visits[it]["mean"] is not None]
bscore = sorted(
    ((used_by[it] * avg_visits[it]["mean"], it, used_by[it], avg_visits[it]["mean"],
      avg_visits[it]["tier"], avg_visits[it]["steps"]) for it in scoreable),
    reverse=True)
print(f"{'Item':<18}{'Tier':<11}{'Steps':<7}{'UsedBy':<8}{'AvgVisits':<10}{'Score':<8}")
for score, it, ub, mv, tier, steps in bscore[:15]:
    print(f"{it:<18}{tier:<11}{steps:<7}{ub:<8}{mv:<10.1f}{score:<8.1f}")

# ---- write UsedBy/AvgVisits/BottleneckScore/Rank back into the CSV, so ----
# ---- the full ranking (not just the top 15 printed above) is sortable ----
rank_of = {it: i + 1 for i, (score, it, ub, mv, tier, steps) in enumerate(bscore)}
score_of = {it: score for score, it, ub, mv, tier, steps in bscore}
unscoreable = [it for it in items if it not in rank_of]
for i, it in enumerate(unscoreable):
    rank_of[it] = len(bscore) + i + 1
station_cols = ALL_STATIONS
with CSV_PATH.open(newline="", encoding="utf-8") as f:
    orig_rows = list(csv.DictReader(f))
orig_rows.sort(key=lambda r: rank_of[r["Item"]])
with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
    fieldnames = ["Rank", "Item", "Tier", "Steps", "UsedBy", "AvgVisits", "BottleneckScore"] + station_cols
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    for r in orig_rows:
        it = r["Item"]
        mv = avg_visits[it]["mean"]
        out = {
            "Rank": rank_of[it], "Item": it, "Tier": r["Tier"], "Steps": r["Steps"],
            "UsedBy": used_by[it], "AvgVisits": (f"{mv:.1f}" if mv is not None else ""),
            "BottleneckScore": (f"{score_of[it]:.1f}" if it in score_of else ""),
        }
        for st in station_cols:
            out[st] = r[st]
        w.writerow(out)
print(f"\nWrote UsedBy/AvgVisits/BottleneckScore/Rank into {CSV_PATH.name} "
      f"({len(orig_rows)} rows, sorted by Rank -- biggest bottleneck first).")
if unscoreable:
    print(f"(No AvgVisits data for: {', '.join(unscoreable)} -- DNF at every station, see comment above.)")

section("UNUSUALLY HARD FOR THEIR DEPTH (excl. CAPSTONE and >=19pt creations)")
by_steps = defaultdict(list)
for it in scoreable:
    by_steps[avg_visits[it]["steps"]].append(avg_visits[it]["mean"])
steps_mean = {k: statistics.mean(v) for k, v in by_steps.items()}
steps_std = {k: (statistics.stdev(v) if len(v) > 1 else 1.0) for k, v in by_steps.items()}

outliers = []
for it in scoreable:
    av = avg_visits[it]
    pts = ITEM_POINTS.get(it, 0)
    if av["tier"] == "CAPSTONE" or pts >= 19:
        continue
    expected = steps_mean[av["steps"]]
    sd = steps_std[av["steps"]] or 1.0
    z = (av["mean"] - expected) / sd
    outliers.append((z, it, av["tier"], pts, av["steps"], av["mean"], expected))
outliers.sort(reverse=True)
print(f"{'Item':<18}{'Tier':<11}{'Pts':<5}{'Steps':<7}{'Actual':<9}{'PeerAvg':<9}{'Z':<6}")
for z, it, tier, pts, steps, mv, exp in outliers[:12]:
    print(f"{it:<18}{tier:<11}{pts:<5}{steps:<7}{mv:<9.1f}{exp:<9.1f}{z:<6.2f}")

section("ELEMENT SCARCITY (needed by many items, rolled at few stations)")
escore = sorted(
    ((elem_used_by[e] / max(elem_station_count[e], 1), e, elem_used_by[e], elem_station_count[e])
     for e in ELEMENTS), reverse=True)
print(f"{'Elem':<6}{'UsedByItems':<13}{'#Stations':<11}{'Ratio':<6}")
for ratio, e, ub, sc in escore:
    print(f"{e:<6}{ub:<13}{sc:<11}{ratio:<6.2f}")

section("MOST STATION-SENSITIVE ITEMS (best-start vs worst-start gap)")
for it in sorted(scoreable, key=lambda it: -avg_visits[it]["spread"])[:12]:
    av = avg_visits[it]
    print(f"{it:<18}{av['tier']:<11}min={av['min']:<6.1f}max={av['max']:<6.1f}spread={av['spread']:<6.1f}")
