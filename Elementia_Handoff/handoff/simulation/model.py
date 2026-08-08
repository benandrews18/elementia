# -*- coding: utf-8 -*-
"""
Elementia print-quantity / reachability simulator -- DATA LAYER.

Loads STATIONS directly from build_guide.py (the single source of truth
that also generates the PDFs) and builds the derived structures every
simulation script needs: RECIPES, ELEMENTS, STEPS (crafting depth),
STATION_DICE, STATION_ITEMS.

As of this export, build_guide.py already contains every confirmed
change from the simulation phase -- there is NO override layer here
anymore. If you want to test a hypothetical change, either edit
build_guide.py directly (if you're confident) or add a clearly-labeled
override block at the bottom of this file (see SIMULATION_METHODOLOGY.md
for how prior override blocks were structured -- keep them temporary and
delete them once a decision is made, the way this session did).

The "steps" (crafting depth) of every item is used ONLY as an internal
weight for simulated groups' decision-making (which item to prioritize
when several are craftable) -- it is never displayed to players or
printed on any card.
"""
import importlib.util, sys, re, pathlib
from collections import Counter, defaultdict

HERE = pathlib.Path(__file__).resolve().parent
BUILD_GUIDE = HERE.parent / "pdf_generation" / "build_guide.py"

spec = importlib.util.spec_from_file_location("bg", BUILD_GUIDE)
bg = importlib.util.module_from_spec(spec)
sys.modules["bg"] = bg
spec.loader.exec_module(bg)
STATIONS = list(bg.STATIONS)
ALIAS = {"Coal / Charcoal": "Coal"}   # historical name mismatch, harmless to keep

# ---------------------------------------------------------------- data ----
RECIPES = {}
HOME = defaultdict(list)
ALL_STATIONS = [s["name"] for s in STATIONS]

def parse_requirements(recipe_str, catalysts):
    req = Counter()
    for tok in recipe_str.split("+"):
        tok = tok.strip()
        is_cat = tok.endswith("*")
        tok = tok.replace("*", "").strip()
        if re.fullmatch(r"[A-Z][a-z]?", tok):
            nm = tok
        else:
            parts = tok.split(" ", 1)
            nm = parts[1] if len(parts) == 2 else tok
            nm = ALIAS.get(nm, nm)
        req[nm] += 1
        if is_cat:
            catalysts.add(nm)
    return req

for s in STATIONS:
    # farm_section was removed 2026-07-29: crafted items are ALL permanent
    # unlocks (owned, never spent), so Farm never needed special casing --
    # `.get()` is kept only so an older build_guide.py still loads.
    all_items = list(s["shop"])
    if s.get("farm_section"):
        all_items += s["farm_section"]["items"]
    for emoji, name, tag, recipe, points in all_items:
        catalysts = set()
        req = parse_requirements(recipe, catalysts)
        RECIPES.setdefault(name, []).append((s["name"], req, catalysts, tag))
        HOME[name].append(s["name"])
    ce, cn, ct, cr, cpts = s["capstone"]
    catalysts = set()
    req = parse_requirements(cr, catalysts)
    RECIPES.setdefault(cn, []).append((s["name"], req, catalysts, "CAPSTONE"))
    HOME[cn].append(s["name"])

ELEMENTS = set()
for s in STATIONS:
    ELEMENTS |= set(s["dice"])

# crafting depth ("steps" -- internal simulation weight only) ------------
depth_cache = {}
def compute_depth(item, seen=frozenset()):
    if item in ELEMENTS:
        return 0
    if item in depth_cache:
        return depth_cache[item]
    if item in seen or item not in RECIPES:
        return None
    best = None
    for _, req, catalysts, _ in RECIPES[item]:
        subs = []
        ok = True
        for ing, qty in req.items():
            if ing in catalysts:
                continue
            d = 0 if ing in ELEMENTS else compute_depth(ing, seen | {item})
            if d is None:
                ok = False
                break
            subs.append(d)
        if ok:
            cand = 1 + (max(subs) if subs else 0)
            if best is None or cand < best:
                best = cand
    depth_cache[item] = best
    return best

STEPS = {item: compute_depth(item) for item in RECIPES}

# dice weighting per station (matches the printed dice key exactly) ------
STATION_DICE = {s["name"]: s["dice"] for s in STATIONS}
STATION_ITEMS = defaultdict(list)
for item, recs in RECIPES.items():
    for station, req, catalysts, tag in recs:
        STATION_ITEMS[station].append(item)

if __name__ == "__main__":
    print(f"Loaded {len(RECIPES)} items, {len(ELEMENTS)} elements, {len(ALL_STATIONS)} stations.")
    print(f"Depth resolved for {sum(1 for v in STEPS.values() if v is not None)}/{len(STEPS)} items.")
    unresolved = [i for i in RECIPES if STEPS.get(i) is None]
    if unresolved:
        print("UNRESOLVED (broken references):", unresolved)
