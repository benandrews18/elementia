# -*- coding: utf-8 -*-
"""Capstone-focus simulation: each group commits to ONE randomly-assigned
capstone at the start and pursues it with complete, single-minded focus for
all 15 visits. Fully random dice (TAKE 5, no guaranteed pick). The one hard
rule: a group can never visit the same station twice in a row.

Uses the same permanent-unlock crafting model as simulate_kid.py (only raw
elements are consumed; crafted items are unlocked once and stay forever)."""
import random
from collections import Counter, defaultdict
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS

N_GROUPS = 13
TRIALS = 500
N_VISITS = 15
TAKE = 5

ELEM_STATIONS = defaultdict(list)
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS[e].append(s["name"])

def is_capstone(item):
    return any(tag == "CAPSTONE" for st, r, c, tag in RECIPES[item])

CAPSTONES = [i for i in RECIPES if is_capstone(i) and STEPS.get(i) is not None]
BROKEN_CAPSTONES = [i for i in RECIPES if is_capstone(i) and STEPS.get(i) is None]

TOTAL_NEEDS_CACHE = {}
def total_needs(item):
    """DAG-correct under the permanent-unlock model: a shared non-element
    item (e.g. Water, Tree, Clay) is only ever built ONCE no matter how
    many different parent recipes reference it, so its own raw-element
    cost is only paid once too -- NOT once per parent that needs it."""
    if item in TOTAL_NEEDS_CACHE:
        return TOTAL_NEEDS_CACHE[item]
    needed_items = set()
    elem_needs = Counter()
    def visit(it):
        if it in ELEMENTS:
            return
        if it in needed_items:
            return
        needed_items.add(it)
        recs = RECIPES.get(it)
        if not recs:
            return
        station, req, catalysts, tag = recs[0]
        for ing, qty in req.items():
            if ing in catalysts:
                continue
            if ing in ELEMENTS:
                elem_needs[ing] += qty
            else:
                visit(ing)
    visit(item)
    result = Counter(elem_needs)
    for it in needed_items:
        result[it] = 1
    TOTAL_NEEDS_CACHE[item] = result
    return result

def roll_element(station_name):
    return random.choice(STATION_DICE[station_name])

def choose_station(rng, goal, crafted, inv, last_station):
    """Fully goal-directed (complete focus): rank stations by how much they
    help the goal, pick the best -- but never repeat the immediately-prior
    station.

    Element contributions are weighted by SCARCITY: a station that's the
    ONLY source of a still-needed element must outweigh a station that just
    happens to host several craftable items, or a rare single-source
    ingredient (like Sn, only at Power Plant) never gets visited at all."""
    tally = Counter()
    tn = total_needs(goal)
    for item, qty in tn.items():
        if item in ELEMENTS or crafted.get(item, 0) >= 1:
            continue
        for st, req, catalysts, tag in RECIPES[item]:
            # only credit a station if the item is ACTUALLY craftable there
            # right now -- crediting "sells a wanted item" regardless of
            # whether its own ingredients are ready dilutes routing toward
            # premature stations and silently strangles deep capstone chains
            # (see 2026-07-20 finding: this alone took City's given-assigned
            # completion from 2% to 28%, Multi-Layer Cake from 0% to 52%).
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    for elem, qty in tn.items():
        if elem not in ELEMENTS:
            continue
        short = qty - inv.get(elem, 0)
        if short > 0:
            n_sources = len(ELEM_STATIONS[elem])
            weight = 10 if n_sources == 1 else (5 if n_sources == 2 else 1)
            for st in ELEM_STATIONS[elem]:
                tally[st] += weight

    candidates = {s: c for s, c in tally.items() if s != last_station}
    if not candidates:
        candidates = {s: 0 for s in ALL_STATIONS if s != last_station}
    best = max(candidates.values())
    return rng.choice([s for s, c in candidates.items() if c == best])

def craft_sweep(station, inv, craft_counts, crafted):
    """Permanent-unlock crafting: elements are spent, crafted items never
    are, and each item can only ever be unlocked once."""
    progressed = True
    while progressed:
        progressed = False
        options = []
        for item, recs in RECIPES.items():
            if inv.get(item, 0) >= 1:
                continue
            for st, req, catalysts, tag in recs:
                if st != station:
                    continue
                if all(inv.get(ing, 0) >= qty for ing, qty in req.items()):
                    options.append((item, req, catalysts))
        if not options:
            break
        options.sort(key=lambda o: STEPS.get(o[0], 0), reverse=True)
        item, req, catalysts = options[0]
        for ing, qty in req.items():
            if ing in catalysts:
                continue
            if ing in ELEMENTS:
                inv[ing] -= qty
        inv[item] += 1
        craft_counts[item] += 1
        crafted[item] += 1
        progressed = True

def goal_complete(goal, crafted, inv):
    tn = total_needs(goal)
    for item, qty in tn.items():
        have = inv.get(item, 0) if item in ELEMENTS else crafted.get(item, 0)
        if have < qty:
            return False
    return True

def run_one_trial(rng):
    group_inv = [Counter() for _ in range(N_GROUPS)]
    group_crafted = [Counter() for _ in range(N_GROUPS)]
    group_goal = [rng.choice(CAPSTONES) for _ in range(N_GROUPS)]
    last_station = [None] * N_GROUPS

    craft_counts = Counter()
    completions_seen = Counter()
    already_completed = [set() for _ in range(N_GROUPS)]
    capstone_finished = Counter()

    for visit in range(N_VISITS):
        for g in range(N_GROUPS):
            inv = group_inv[g]
            crafted = group_crafted[g]
            goal = group_goal[g]

            station = choose_station(rng, goal, crafted, inv, last_station[g])
            last_station[g] = station

            for _ in range(TAKE):
                inv[roll_element(station)] += 1

            craft_sweep(station, inv, craft_counts, crafted)

            for item, cnt in crafted.items():
                if cnt > 0 and item not in already_completed[g]:
                    already_completed[g].add(item)
                    completions_seen[item] += 1

            if goal_complete(goal, crafted, inv) and goal not in already_completed[g]:
                pass  # goal's own completion is already captured via completions_seen

    for g in range(N_GROUPS):
        if group_goal[g] in already_completed[g]:
            capstone_finished[group_goal[g]] += 1

    return craft_counts, completions_seen, capstone_finished, group_goal


def main():
    rng = random.Random(4242)
    total_craft = Counter()
    total_completions = Counter()
    total_capstone_finish = Counter()
    goal_assigned = Counter()

    for t in range(TRIALS):
        c, comp, cap_fin, goals = run_one_trial(rng)
        for k in RECIPES:
            total_craft[k] += c.get(k, 0)
        for k, v in comp.items():
            total_completions[k] += v
        for k, v in cap_fin.items():
            total_capstone_finish[k] += v
        for g in goals:
            goal_assigned[g] += 1

    print(f"=== Capstone-focus sim: {TRIALS} trials, {N_GROUPS} groups, {N_VISITS} visits, "
          f"TAKE={TAKE} fully random, no-repeat-station rule ===")
    if BROKEN_CAPSTONES:
        print(f"EXCLUDED (structurally broken, missing element source): {BROKEN_CAPSTONES}\n")
    else:
        print()

    print(f"{'Item':<20}{'Tag':<12}{'Steps':<7}{'% groups crafting >=1':<24}")
    for item in sorted(RECIPES.keys(), key=lambda i: -total_completions[i]):
        tag = [tag for st, r, c, tag in RECIPES[item]][0]
        pct = total_completions[item] / (TRIALS * N_GROUPS) * 100
        steps_display = STEPS.get(item, '?')
        steps_display = steps_display if steps_display is not None else 'N/A'
        print(f"{item:<20}{tag:<12}{steps_display:<7}{pct:<24.1f}")

    print("\n--- Capstone completion rate GIVEN it was the assigned goal ---")
    for cs in sorted(CAPSTONES, key=lambda i: -total_capstone_finish[i]):
        assigned = goal_assigned[cs]
        finished = total_capstone_finish[cs]
        pct = finished / assigned * 100 if assigned else 0
        print(f"  {cs:<18} assigned {assigned:>4}x, completed {finished:>4}x  ({pct:.1f}%)")

if __name__ == "__main__":
    main()
