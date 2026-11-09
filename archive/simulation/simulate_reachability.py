# -*- coding: utf-8 -*-
"""Full item x station reachability grid for a CUSTOM station-web proposal.

For every item in the game and every station as a starting point, runs
many single-goal trials ("build exactly this one item, nothing else") on
the graph below and records how many visits it took. Movement is strictly
single-hop along the graph edges -- no fast travel, no multi-hop. There is
no session visit cap; a trial only ends when the goal is crafted (or a
generous safety ceiling is hit, see MAX_VISITS -- this should only matter
for a handful of the deepest capstones from the worst-positioned start).

This is a DIFFERENT shape of test than simulate_pathing(_v2).py's movement-
rule/topology comparison: those simulate a whole multi-goal session and
compare aggregate outcomes; this one isolates each (item, station) pair to
build the full reachability matrix the user asked for, under a single
graph they want evaluated on its own merits.

THE GRAPH BEING TESTED -- transcribed from the user's description, cross-
checked for symmetry (every edge implied from one side's list is also
implied from the other's -- see the comment block below):

  The Ocean: Old Growth Forest, Deep Mine, The Observatory
  Old Growth Forest: The Ocean, Deep Mine, The Power Plant, Greenhouse
  Greenhouse: Old Growth Forest, Deep Mine, The Power Plant, The City, The Bakery
  The Bakery: The Observatory, The City, The Power Plant, Greenhouse
  The Observatory: The Bakery, The City, The Ocean

  (Deep Mine, The Power Plant, and The City were only given as OTHER
  stations' neighbors, never their own outbound list -- their full
  neighbor sets below are exactly what falls out of the symmetric edges,
  not an independent assumption.)

PLAYER MODEL for each trial:
  - Single goal, nothing else -- station choice is goal-focused far more
    often than the multi-goal scripts' kid-behavior model (see
    GOAL_AWARE_CHANCE below), since this is meant to measure "how many
    visits does reaching this item take a player actually working toward
    it," not casual/distracted play.
  - Every visit: roll TAKE dice, then REBALANCE surplus elements into
    shortfalls via 3-for-1 conversion (rebalance_via_conversion()) BEFORE
    crafting -- exactly the "don't sit on a surplus when you need
    something else" behavior the user asked for -- then craft everything
    now possible that's actually part of the goal's remaining build tree
    (craft_toward_goal()), repeating both until nothing more can happen
    this visit.
  - Movement is single-hop along the graph, biased toward whichever
    neighbor best serves the goal's outstanding needs (same tally logic
    as simulate_pathing.py's score_stations(), reimplemented locally here
    with its own higher goal-awareness constant rather than importing the
    multi-goal scripts' 0.66).
"""
import csv, random, sys
from collections import Counter, defaultdict
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS

TAKE = 6
TRIALS = 40
MAX_VISITS = 150
GOAL_AWARE_CHANCE = 0.9   # a focused player, not a wandering one -- see module docstring

# ---------------------------------------------------------------- graph ----
CUSTOM_EDGES = [
    ("The Ocean", "Old Growth Forest"),
    ("The Ocean", "Deep Mine"),
    ("The Ocean", "The Observatory"),
    ("Old Growth Forest", "Deep Mine"),
    ("Old Growth Forest", "The Power Plant"),
    ("Old Growth Forest", "Greenhouse"),
    ("Greenhouse", "Deep Mine"),
    ("Greenhouse", "The Power Plant"),
    ("Greenhouse", "The City"),
    ("Greenhouse", "The Bakery"),
    ("The Bakery", "The Observatory"),
    ("The Bakery", "The City"),
    ("The Bakery", "The Power Plant"),
    ("The Observatory", "The City"),
]

def build_adj(edges):
    adj = defaultdict(set)
    for a, b in edges:
        adj[a].add(b); adj[b].add(a)
    return adj

ADJ = build_adj(CUSTOM_EDGES)

# Sanity-check every station in the game actually appears in this graph --
# a typo in the edge list above would otherwise silently strand a station
# with zero neighbors instead of failing loudly.
_missing = [s for s in ALL_STATIONS if s not in ADJ or not ADJ[s]]
if _missing:
    raise SystemExit(f"CUSTOM_EDGES leaves these stations unreachable: {_missing}")

# ------------------------------------------------------------- item tree ----
# 8 items in the current catalog are sold at TWO stations (Sand, Water,
# Sugar, Limestone, Soil, Steel, Clay, Glass) -- earlier passes of this
# script only ever looked at RECIPES[item][0], silently treating every one
# of those as single-homed and picking whichever station happened to be
# listed first in build_guide.py. That understated how reachable they
# actually are (a player standing at either home can craft them) and, for
# Soil specifically, used the WRONG recipe outright -- Greenhouse's Soil
# needs Clay+Sand+Water, but Old Growth Forest's needs only Clay+Sand, and
# recs[0] always picked Greenhouse's harder version. Fixed via the two
# helpers below, used everywhere a station or requirement set matters.
def home_stations(item):
    return [r[0] for r in RECIPES.get(item, [])]

def req_at(item, station):
    """This item's OWN requirement dict at a SPECIFIC station (falls back
    to the first-listed entry if station isn't actually one of its homes
    -- callers are expected to have already checked that via
    home_stations())."""
    for st, req, catalysts, tag in RECIPES.get(item, []):
        if st == station:
            return req, catalysts
    st, req, catalysts, tag = RECIPES[item][0]
    return req, catalysts

def is_capstone(item):
    return any(tag == "CAPSTONE" for st, r, c, tag in RECIPES[item])

def closure_items_needed(goal, crafted):
    """Every NOT-YET-CRAFTED item in goal's build tree, goal included,
    stopping descent the moment a branch is already satisfied (permanent-
    unlock model -- once an intermediate item is built, its own
    ingredients are no longer anyone's concern). Where an item's homes
    disagree on ingredients (Soil), this walks the UNION of both --
    conservative/complete for "what might I need," while the actual
    crafting check in craft_toward_goal() uses the real, possibly smaller,
    per-station requirement."""
    needed, seen = [], set()
    def visit(it):
        if it in ELEMENTS or it in seen:
            return
        seen.add(it)
        if crafted.get(it, 0) > 0:
            return
        needed.append(it)
        recs = RECIPES.get(it)
        if not recs:
            return
        for station, req, catalysts, tag in recs:
            for ing, qty in req.items():
                if ing in catalysts or ing in ELEMENTS:
                    continue
                visit(ing)
    visit(goal)
    return needed

def remaining_element_needs(goal, crafted):
    """Total raw-element demand across goal's still-outstanding build
    tree (a static recipe-level total, not adjusted for what's currently
    IN inventory -- see rebalance_via_conversion(), which compares this
    against inv itself to find the actual shortfall). Unions across an
    item's multiple homes same as closure_items_needed() above."""
    elem_needs = Counter()
    seen = set()
    def visit(it):
        if it in ELEMENTS or it in seen:
            return
        seen.add(it)
        if crafted.get(it, 0) > 0:
            return
        recs = RECIPES.get(it)
        if not recs:
            return
        for station, req, catalysts, tag in recs:
            for ing, qty in req.items():
                if ing in catalysts:
                    continue
                if ing in ELEMENTS:
                    elem_needs[ing] = max(elem_needs[ing], qty)
                else:
                    visit(ing)
    visit(goal)
    return elem_needs

ELEM_STATIONS = defaultdict(list)
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS[e].append(s["name"])

# ------------------------------------------------------- player actions ----
def rebalance_via_conversion(inv, remaining):
    """3-for-1 convert surplus elements (held beyond what the goal still
    needs, or not needed at all) into whichever needed element is
    currently short by the most -- repeats until either every shortfall
    is covered or there's no more spare surplus to trade away. This is
    the "don't hoard 12 of one element while starving for another"
    behavior the user asked to have modeled explicitly."""
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

def craft_toward_goal(station, inv, crafted, goal):
    """Craft anything now possible AT `station` specifically -- for a
    dual-homed item, this checks (and consumes) THAT station's own real
    requirement, not always the first-listed home's."""
    progressed = True
    while progressed:
        progressed = False
        for item in closure_items_needed(goal, crafted):
            if station not in home_stations(item):
                continue
            req, catalysts = req_at(item, station)
            if all(inv.get(ing, 0) >= qty for ing, qty in req.items()):
                for ing, qty in req.items():
                    if ing in catalysts:
                        continue
                    if ing in ELEMENTS:
                        inv[ing] -= qty
                inv[item] += 1
                crafted[item] += 1
                progressed = True
                break  # restart the scan -- state changed, closure may have shrunk

def score_stations_for_goal(goal, crafted, inv, candidates):
    tally = Counter({c: 0 for c in candidates})
    needed_items = closure_items_needed(goal, crafted)
    for item in needed_items:
        for st in home_stations(item):
            if st not in tally:
                continue
            req, catalysts = req_at(item, st)
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    remaining = remaining_element_needs(goal, crafted)
    for elem, need in remaining.items():
        if need - inv.get(elem, 0) > 0:
            for st in ELEM_STATIONS[elem]:
                if st in tally:
                    tally[st] += 1
    return tally

def choose_next_station(rng, goal, crafted, inv, candidates):
    if rng.random() >= GOAL_AWARE_CHANCE:
        return rng.choice(list(candidates))
    tally = score_stations_for_goal(goal, crafted, inv, candidates)
    best = max(tally.values())
    if best == 0:
        return rng.choice(list(candidates))
    return rng.choice([s for s, c in tally.items() if c == best])

# ------------------------------------------------------------- one trial ----
def run_single_goal(rng, goal, start_station):
    inv, crafted = Counter(), Counter()
    current = start_station
    for v in range(1, MAX_VISITS + 1):
        for _ in range(TAKE):
            inv[random.choice(STATION_DICE[current])] += 1
        remaining = remaining_element_needs(goal, crafted)
        rebalance_via_conversion(inv, remaining)
        craft_toward_goal(current, inv, crafted, goal)
        if crafted.get(goal, 0) > 0:
            return v
        current = choose_next_station(rng, goal, crafted, inv, ADJ[current])
    return None  # DNF within MAX_VISITS

# --------------------------------------------------------------- driver ----
def main():
    rng = random.Random(2026)
    items = sorted(RECIPES.keys(), key=lambda n: (STEPS.get(n) is None, STEPS.get(n, 0), n))
    grid = {}   # (item, station) -> (avg_visits or None, dnf_count)
    total = len(items) * len(ALL_STATIONS)
    done = 0
    for item in items:
        for station in ALL_STATIONS:
            visits = []
            dnf = 0
            for t in range(TRIALS):
                r = run_single_goal(rng, item, station)
                if r is None:
                    dnf += 1
                else:
                    visits.append(r)
            avg = (sum(visits) / len(visits)) if visits else None
            grid[(item, station)] = (avg, dnf)
            done += 1
            if done % 40 == 0:
                print(f"...{done}/{total} (item,station) pairs done", file=sys.stderr)

    out_path = "reachability_grid.csv"
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Item", "Tier", "Steps"] + ALL_STATIONS)
        for item in items:
            tag = next((tag for st, r, c, tag in RECIPES[item]), "?")
            row = [item, tag, STEPS.get(item, "?")]
            for station in ALL_STATIONS:
                avg, dnf = grid[(item, station)]
                if avg is None:
                    cell = "DNF"
                elif dnf:
                    cell = f"{avg:.1f} ({dnf}xDNF)"
                else:
                    cell = f"{avg:.1f}"
                row.append(cell)
            w.writerow(row)
    print(f"\nWrote {out_path}: {len(items)} items x {len(ALL_STATIONS)} stations, "
          f"{TRIALS} trials per cell.")

if __name__ == "__main__":
    main()
