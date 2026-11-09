# -*- coding: utf-8 -*-
"""Parameterized version of the reachability simulation, factored out so
reachability_lab.py (the local web UI) can run it against a user's EDITED
station dice / item catalog (recipes, tiers, points, homes -- items can be
added and removed entirely) / graph without ever touching build_guide.py
or any other real game file.

simulate_reachability.py and analyze_bottlenecks.py (the original
command-line versions) are untouched by this -- they still read the live
game data directly and remain the "official" reference tools. This module
duplicates their core loop rather than importing from them, specifically
so a lab experiment can never accidentally write back into the real data.

The item catalog (name/tier/points/recipe/homes for every item in a run)
is fully payload-driven: build_baseline() seeds it from the real game once
at server startup, but every /api/run request rebuilds its own Catalog
from whatever the browser sends -- edited recipes, renamed/added/removed
items, all included. Element symbols (the 16-ish raw dice faces) are NOT
payload-driven -- they still come from the real game's ELEMENTS set,
since editing dice faces already covers "which elements exist."
"""
import random, re
from collections import Counter, defaultdict
from model import RECIPES, ELEMENTS, STEPS, ALL_STATIONS, STATIONS as BASE_STATIONS
from simulate_reachability import CUSTOM_EDGES as USER_CUSTOM_WEB
from simulate_pathing import BASE_EDGES as ORIGINAL_DIAMOND, PLUS2_EXTRA, DIAGONAL_EXTRA

GRAPH_PRESETS = {
    "Your custom web (Ocean/OGF/Greenhouse/Bakery/Observatory hub)": USER_CUSTOM_WEB,
    "Original diamond map (the live game today)": ORIGINAL_DIAMOND,
    "Diamond + Observatory-Ocean + Greenhouse-Power Plant": ORIGINAL_DIAMOND + PLUS2_EXTRA,
    "Diamond + 4 cross-row diagonal shortcuts": ORIGINAL_DIAMOND + DIAGONAL_EXTRA,
}

TAKE = 5
MAX_VISITS = 150
GOAL_AWARE_CHANCE = 0.9

ITEM_POINTS, ITEM_TAG = {}, {}
for s in BASE_STATIONS:
    shop_items = list(s["shop"])
    if s.get("farm_section"):
        shop_items += s["farm_section"]["items"]
    for emoji, name, tag, recipe, points in shop_items:
        ITEM_POINTS[name] = points
        ITEM_TAG.setdefault(name, tag)
    ce, cn, ct, cr, cpts = s["capstone"]
    ITEM_POINTS[cn] = cpts
    ITEM_TAG.setdefault(cn, "CAPSTONE")

ITEMS = sorted(RECIPES.keys(), key=lambda n: (STEPS.get(n) is None, STEPS.get(n, 0), n))

def is_capstone(item):
    return ITEM_TAG.get(item) == "CAPSTONE"

def base_req(item):
    """The item's ingredient requirement, taken from the real game's
    first-listed recipe for it -- used only to SEED build_baseline()'s
    starting values. Once a request comes in, everything runs off the
    payload-driven Catalog below instead."""
    st, req, catalysts, tag = RECIPES[item][0]
    return req, catalysts

def build_baseline():
    """Everything the lab UI needs to pre-fill its controls with the real
    game's current numbers -- read once at server startup, never written
    back to anywhere."""
    dice = {s["name"]: list(s["dice"]) for s in BASE_STATIONS}
    homes = {name: [r[0] for r in recs] for name, recs in RECIPES.items()}
    items = []
    for name in ITEMS:
        req, catalysts = base_req(name)
        recipe_str = " + ".join(f"{k}{'*' if k in catalysts else ''}" for k in req)
        items.append({
            "name": name, "tier": ITEM_TAG.get(name, "?"), "points": ITEM_POINTS.get(name, 0),
            "steps": STEPS.get(name), "recipe": recipe_str, "homes": homes[name],
        })
    return {
        "stations": ALL_STATIONS,
        "elements": sorted(ELEMENTS),
        "dice": dice,
        "items": items,
        "graphPresets": {name: [list(e) for e in edges] for name, edges in GRAPH_PRESETS.items()},
        "defaultGraph": "Your custom web (Ocean/OGF/Greenhouse/Bakery/Observatory hub)",
    }

# -------------------------------------------------------- payload catalog --
def parse_recipe_string(recipe_str):
    """Same token grammar build_guide.py uses (bare 1-2 letter symbol =
    element, trailing '*' = catalyst), PLUS a Lab-only convenience: an
    item token doesn't need an emoji prefix -- "Furnace + C + Clock" and
    "🔥 Furnace + C + 🕐 Clock" both parse the same way, since a human
    typing recipes in a browser shouldn't have to go hunting for emoji."""
    req, catalysts = Counter(), set()
    if not recipe_str or not recipe_str.strip():
        return req, catalysts
    for tok in recipe_str.split("+"):
        tok = tok.strip()
        if not tok:
            continue
        is_cat = tok.endswith("*")
        tok = tok.rstrip("*").strip()
        if re.fullmatch(r"[A-Z][a-z]?", tok):
            nm = tok
        else:
            parts = tok.split(" ", 1)
            # Only treat the first word as a stripped emoji prefix if it's
            # actually non-ASCII -- an ASCII first word ("Natural" in
            # "Natural Gas") is part of the name, not a prefix to drop.
            if len(parts) == 2 and not parts[0].isascii():
                nm = parts[1].strip()
            else:
                nm = tok
        req[nm] += 1
        if is_cat:
            catalysts.add(nm)
    return req, catalysts

def build_catalog(items_payload):
    """Turns the browser's edited item list -- [{name, tier, points,
    recipe, homes}], possibly with items added/removed/renamed relative
    to the real game -- into the lookup structure every simulation
    function below runs off of."""
    names, tag, points, homes, req_map, cat_map = [], {}, {}, {}, {}, {}
    for it in items_payload:
        name = it["name"]
        names.append(name)
        tag[name] = it.get("tier") or "?"
        points[name] = it.get("points") or 0
        homes[name] = list(it.get("homes") or [])
        req, catalysts = parse_recipe_string(it.get("recipe", ""))
        req_map[name] = req
        cat_map[name] = catalysts
    return {"names": names, "tag": tag, "points": points, "homes": homes,
            "req": req_map, "catalysts": cat_map}

def catalog_req(catalog, item):
    return catalog["req"].get(item, Counter()), catalog["catalysts"].get(item, set())

def compute_steps(catalog):
    """Crafting depth for every item in the catalog -- None if an item's
    recipe cycles back on itself or bottoms out on something that isn't a
    known element or catalog item (validate() turns that into an error
    message rather than letting this crash)."""
    steps = {}
    def depth(name, seen):
        if name in ELEMENTS:
            return 0
        if name in steps:
            return steps[name]
        if name in seen or name not in catalog["req"]:
            return None
        req, catalysts = catalog_req(catalog, name)
        best = None
        for ing in req:
            if ing in catalysts:
                continue
            d = 0 if ing in ELEMENTS else depth(ing, seen | {name})
            if d is None:
                return None
            best = d if best is None else max(best, d)
        result = 0 if best is None else best + 1
        steps[name] = result
        return result
    for n in catalog["names"]:
        depth(n, frozenset())
    return steps

# ------------------------------------------------------- structural facts --
def closure_items(catalog, item):
    """Every item (not itself) in item's build tree."""
    seen = set()
    def visit(it):
        if it in ELEMENTS or it in seen:
            return
        seen.add(it)
        req, catalysts = catalog_req(catalog, it)
        for ing in req:
            if ing in catalysts or ing in ELEMENTS:
                continue
            visit(ing)
    req, catalysts = catalog_req(catalog, item)
    for ing in req:
        if ing in catalysts or ing in ELEMENTS:
            continue
        visit(ing)
    return seen

def used_by_counts(catalog):
    c = Counter()
    for y in catalog["names"]:
        for x in closure_items(catalog, y):
            c[x] += 1
    return c

def closure_items_needed(catalog, goal, crafted):
    needed, seen = [], set()
    def visit(it):
        if it in ELEMENTS or it in seen:
            return
        seen.add(it)
        if crafted.get(it, 0) > 0:
            return
        needed.append(it)
        req, catalysts = catalog_req(catalog, it)
        for ing in req:
            if ing in catalysts or ing in ELEMENTS:
                continue
            visit(ing)
    visit(goal)
    return needed

def remaining_element_needs(catalog, goal, crafted):
    elem_needs = Counter()
    seen = set()
    def visit(it):
        if it in ELEMENTS or it in seen:
            return
        seen.add(it)
        if crafted.get(it, 0) > 0:
            return
        req, catalysts = catalog_req(catalog, it)
        for ing, qty in req.items():
            if ing in catalysts:
                continue
            if ing in ELEMENTS:
                elem_needs[ing] = max(elem_needs[ing], qty)
            else:
                visit(ing)
    visit(goal)
    return elem_needs

def rebalance_via_conversion(inv, remaining):
    while True:
        shortfalls = {e: need - inv.get(e, 0) for e, need in remaining.items()
                      if need - inv.get(e, 0) > 0}
        if not shortfalls:
            return
        surplus = [(e, inv[e] - remaining.get(e, 0)) for e in list(inv)
                   if e in ELEMENTS and inv[e] - remaining.get(e, 0) >= 3]
        if not surplus:
            return
        donor, _ = max(surplus, key=lambda x: x[1])
        target = max(shortfalls, key=lambda e: shortfalls[e])
        inv[donor] -= 3
        inv[target] = inv.get(target, 0) + 1

def craft_toward_goal(catalog, station, inv, crafted, goal, homes):
    progressed = True
    while progressed:
        progressed = False
        for item in closure_items_needed(catalog, goal, crafted):
            if station not in homes.get(item, []):
                continue
            req, catalysts = catalog_req(catalog, item)
            if all(inv.get(ing, 0) >= qty for ing, qty in req.items()):
                for ing, qty in req.items():
                    if ing in catalysts:
                        continue
                    if ing in ELEMENTS:
                        inv[ing] -= qty
                inv[item] += 1
                crafted[item] += 1
                progressed = True
                break

def score_stations_for_goal(catalog, goal, crafted, inv, candidates, homes, elem_stations):
    tally = Counter({c: 0 for c in candidates})
    for item in closure_items_needed(catalog, goal, crafted):
        req, catalysts = catalog_req(catalog, item)
        for st in homes.get(item, []):
            if st not in tally:
                continue
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    remaining = remaining_element_needs(catalog, goal, crafted)
    for elem, need in remaining.items():
        if need - inv.get(elem, 0) > 0:
            for st in elem_stations[elem]:
                if st in tally:
                    tally[st] += 1
    return tally

def choose_next_station(rng, catalog, goal, crafted, inv, candidates, homes, elem_stations):
    if rng.random() >= GOAL_AWARE_CHANCE:
        return rng.choice(list(candidates))
    tally = score_stations_for_goal(catalog, goal, crafted, inv, candidates, homes, elem_stations)
    best = max(tally.values())
    if best == 0:
        return rng.choice(list(candidates))
    return rng.choice([s for s, c in tally.items() if c == best])

def run_single_goal(rng, catalog, goal, start_station, adj, dice, homes, elem_stations, max_visits):
    inv, crafted = Counter(), Counter()
    current = start_station
    for v in range(1, max_visits + 1):
        for _ in range(TAKE):
            inv[random.choice(dice[current])] += 1
        remaining = remaining_element_needs(catalog, goal, crafted)
        rebalance_via_conversion(inv, remaining)
        craft_toward_goal(catalog, current, inv, crafted, goal, homes)
        if crafted.get(goal, 0) > 0:
            return v
        current = choose_next_station(rng, catalog, goal, crafted, inv, adj[current], homes, elem_stations)
    return None

# ------------------------------------------------------------------ driver --
def build_adj(edges):
    adj = defaultdict(set)
    for a, b in edges:
        adj[a].add(b); adj[b].add(a)
    return adj

def structural_stats(edges):
    adj = build_adj(edges)
    dist = {}
    for start in adj:
        d = {start: 0}
        q = [start]
        while q:
            cur = q.pop(0)
            for nb in adj[cur]:
                if nb not in d:
                    d[nb] = d[cur] + 1
                    q.append(nb)
        dist[start] = d
    hops = [h for d in dist.values() for h in d.values() if h > 0]
    degrees = [len(adj[n]) for n in adj]
    return {
        "avgDegree": sum(degrees) / len(degrees) if degrees else 0,
        "avgHops": sum(hops) / len(hops) if hops else 0,
        "diameter": max(hops) if hops else 0,
    }

def validate(catalog, dice, edges):
    errors = []
    for st in ALL_STATIONS:
        if st not in dice or len(dice[st]) != 6:
            errors.append(f"{st}: dice must have exactly 6 elements")
        elif any(e not in ELEMENTS for e in dice[st]):
            errors.append(f"{st}: unknown element in dice")
    names_set = set(catalog["names"])
    for item in catalog["names"]:
        hs = catalog["homes"].get(item, [])
        if not hs:
            errors.append(f"{item}: needs at least 1 home station")
        elif any(s not in ALL_STATIONS for s in hs):
            errors.append(f"{item}: unknown home station")
        req, catalysts = catalog_req(catalog, item)
        for ing in req:
            if ing in catalysts or ing in ELEMENTS or ing in names_set:
                continue
            errors.append(f"{item}: recipe references unknown item or element '{ing}'")
    adj = build_adj(edges)
    stranded = [s for s in ALL_STATIONS if not adj.get(s)]
    if stranded:
        errors.append(f"Stations with no connections: {', '.join(stranded)}")
    steps = compute_steps(catalog)
    for item in catalog["names"]:
        if steps.get(item) is None:
            errors.append(f"{item}: recipe forms a cycle (directly or indirectly needs itself)")
    return errors

def run_grid(items_payload, dice, edges, trials=40, max_visits=MAX_VISITS, seed=2026, progress_cb=None):
    catalog = build_catalog(items_payload)
    errors = validate(catalog, dice, edges)
    if errors:
        return {"errors": errors}

    adj = build_adj(edges)
    elem_stations = defaultdict(list)
    for st, faces in dice.items():
        for e in set(faces):
            elem_stations[e].append(st)

    steps = compute_steps(catalog)
    item_order = sorted(catalog["names"], key=lambda n: (steps.get(n, 0), n))
    homes = catalog["homes"]

    rng = random.Random(seed)
    grid = {}
    total = len(item_order) * len(ALL_STATIONS)
    done = 0
    for item in item_order:
        for station in ALL_STATIONS:
            visits, dnf = [], 0
            for t in range(trials):
                r = run_single_goal(rng, catalog, item, station, adj, dice, homes, elem_stations, max_visits)
                (visits.append(r) if r is not None else None)
                if r is None:
                    dnf += 1
            grid[(item, station)] = (sum(visits) / len(visits) if visits else None, dnf)
            done += 1
            if progress_cb and done % 40 == 0:
                progress_cb(done, total)

    used_by = used_by_counts(catalog)
    rows = []
    for item in item_order:
        vals = [grid[(item, st)][0] for st in ALL_STATIONS if grid[(item, st)][0] is not None]
        mean = sum(vals) / len(vals) if vals else None
        score = (used_by[item] * mean) if mean is not None else None
        rows.append({
            "item": item, "tier": catalog["tag"].get(item, "?"), "steps": steps.get(item),
            "usedBy": used_by[item], "avgVisits": round(mean, 1) if mean is not None else None,
            "score": round(score, 1) if score is not None else None,
            "byStation": {st: (round(grid[(item, st)][0], 1) if grid[(item, st)][0] is not None else None,
                                grid[(item, st)][1]) for st in ALL_STATIONS},
        })
    rows_scored = sorted((r for r in rows if r["score"] is not None), key=lambda r: -r["score"])
    for i, r in enumerate(rows_scored):
        r["rank"] = i + 1
    rows_unscored = [r for r in rows if r["score"] is None]
    for r in rows_unscored:
        r["rank"] = None

    elem_used_by = Counter()
    for y in item_order:
        need = remaining_element_needs(catalog, y, {})
        for e in need:
            elem_used_by[e] += 1
    elem_rows = []
    for e in sorted(ELEMENTS):
        n_st = len(elem_stations.get(e, []))
        elem_rows.append({
            "element": e, "usedBy": elem_used_by[e], "stations": n_st,
            "ratio": round(elem_used_by[e] / n_st, 2) if n_st else None,
        })
    elem_rows.sort(key=lambda r: -(r["ratio"] or 0))

    return {
        "errors": [],
        "structural": structural_stats(edges),
        "rows": rows_scored + rows_unscored,
        "elements": elem_rows,
    }
