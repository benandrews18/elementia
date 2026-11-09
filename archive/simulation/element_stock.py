# -*- coding: utf-8 -*-
"""
Element-card stock planner.

Unlike crafted items, raw elements are SPENT (consumed on crafting) and, per
the physical game's design, RECYCLED -- a spent element's card returns to a
shared discard/supply pool that gets reshuffled back into circulation. So the
question here isn't "how many groups will ever want one" (that's unbounded
and irrelevant thanks to recycling) -- it's "what's the largest number of
copies of element X that are ever simultaneously out of the pool at once",
i.e. sitting in some group's hand as rolled-but-not-yet-crafted inventory.
That peak, plus a small safety margin, is exactly how many physical cards
must exist for the pool to never run dry mid-round.

Since the 3-per-element carry cap became a real rule, that peak is also
bounded above by N_GROUPS * ELEMENT_CAP no matter how the dice fall, so
these numbers are a guarantee rather than an estimate.

Behavior model: the same kid-realistic multi-focus engine as
print_quantities.py (13 groups, 12-15 visits/group, 66% goal-aware,
impulsive crafting, capstones included as pickable foci, TAKE=5), with the
routing-readiness fix from the 2026-07-20 finding already applied. The one
structural difference: groups are stepped in synchronized ROUNDS (round 1
for every group, then round 2 for every group, ...) instead of one group's
entire session before the next, so we can snapshot "how much of element X
is out across ALL 13 groups right now" after every round and track the
running peak. Per-group behavior is identical either way; only the
bookkeeping needed to observe cross-group concurrency changes.

Usage:  python element_stock.py                  (prints a table)
        python element_stock.py --json out.json   (also writes the data)
"""
import math
import random
import sys
import json
from collections import Counter
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS

N_GROUPS = 13
TRIALS = 500
VISIT_RANGE = (12, 15)
GOAL_AWARE_CHANCE = 0.66
N_FOCI_CHOICES = [2, 3]
TAKE = 5
STOCK_PERCENTILE = 95   # size the pool to cover this % of simulated peak moments
BUFFER = 3              # +3 extra cards on top of the percentile peak

# 2026-07-21: the carry cap is now an ACTUAL GAME RULE, not a modelling
# assumption -- a group may never hold more than ELEMENT_CAP of any single
# element, and anything rolled past that goes straight back to the pool.
# Verified in simulation before adopting: capping at 3 costs ~0.5pp of
# capstone completion (statistical noise) while capping at 2 costs ~11pp.
#
# Because it's a hard rule, peak concurrent demand for any one element has
# a PROVABLE ceiling of N_GROUPS * ELEMENT_CAP, independent of how the dice
# fall. The simulation below finds the realistic peak; that ceiling is the
# absolute worst case the print run can ever need.
ELEMENT_CAP = 3
HARD_CEILING = N_GROUPS * ELEMENT_CAP

ELEM_STATIONS = {}
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS.setdefault(e, []).append(s["name"])

TOTAL_NEEDS_CACHE = {}


def total_needs(item):
    if item in TOTAL_NEEDS_CACHE:
        return TOTAL_NEEDS_CACHE[item]
    needed_items, elem_needs = set(), Counter()

    def visit(it):
        if it in ELEMENTS or it in needed_items:
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


def combined_needs(foci):
    needs = Counter()
    for f in foci:
        for k, v in total_needs(f).items():
            needs[k] += v
    return needs


INTEREST_POOL = [i for i, s in STEPS.items() if s is not None and s >= 1]
INTEREST_WEIGHTS = [1.3 ** STEPS[i] for i in INTEREST_POOL]


def pick_interest(rng, exclude=()):
    pool, weights = [], []
    for i, w in zip(INTEREST_POOL, INTEREST_WEIGHTS):
        if i not in exclude:
            pool.append(i)
            weights.append(w)
    return rng.choices(pool, weights=weights, k=1)[0]


def roll_element(station_name):
    return random.choice(STATION_DICE[station_name])


def outstanding_elements_combined(foci, inv):
    need = Counter()
    for elem, qty in combined_needs(foci).items():
        if elem in ELEMENTS:
            short = qty - inv.get(elem, 0)
            if short > 0:
                need[elem] = short
    return need


def choose_station(rng, foci, crafted, inv):
    if rng.random() >= GOAL_AWARE_CHANCE or not foci:
        return rng.choice(ALL_STATIONS)
    tally = Counter()
    cn = combined_needs(foci)
    for item, qty in cn.items():
        if item in ELEMENTS or crafted.get(item, 0) >= qty:
            continue
        for st, req, catalysts, tag in RECIPES[item]:
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    for elem, amt in outstanding_elements_combined(foci, inv).items():
        for st in ELEM_STATIONS[elem]:
            tally[st] += 1
    if not tally:
        return rng.choice(ALL_STATIONS)
    best = max(tally.values())
    return rng.choice([s for s, c in tally.items() if c == best])


def impulsive_craft_sweep(station, inv, crafted, foci):
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
        crafted[item] += 1
        progressed = True


def focus_satisfied(focus, crafted, inv):
    tn = total_needs(focus)
    for item, qty in tn.items():
        have = inv.get(item, 0) if item in ELEMENTS else crafted.get(item, 0)
        if have < qty:
            return False
    return True


def run_one_trial_peaks(rng):
    """Steps all N_GROUPS in synchronized rounds so cross-group concurrency
    can be observed, and returns the peak total (summed over all groups) of
    each element ever outstanding at once during this trial."""
    group_inv = [Counter() for _ in range(N_GROUPS)]
    group_foci = [[pick_interest(rng) for _ in range(rng.choice(N_FOCI_CHOICES))]
                  for _ in range(N_GROUPS)]
    group_crafted = [Counter() for _ in range(N_GROUPS)]
    n_visits = [rng.randint(*VISIT_RANGE) for _ in range(N_GROUPS)]
    max_visits = max(n_visits)

    peak_held = Counter()

    for round_idx in range(max_visits):
        for g in range(N_GROUPS):
            if round_idx >= n_visits[g]:
                continue
            inv = group_inv[g]
            crafted = group_crafted[g]
            foci = group_foci[g]
            station = choose_station(rng, foci, crafted, inv)

            # Carry cap enforced at acquisition: a die showing an element the
            # group is already full on is simply returned to the pool.
            # (Crafting only ever spends, so nothing can exceed the cap later.)
            for _ in range(TAKE):
                e = roll_element(station)
                if inv.get(e, 0) < ELEMENT_CAP:
                    inv[e] += 1

            impulsive_craft_sweep(station, inv, crafted, foci)

            still_active = []
            for f in foci:
                if focus_satisfied(f, crafted, inv):
                    still_active.append(pick_interest(rng, exclude=foci))
                else:
                    still_active.append(f)
            group_foci[g] = still_active

        totals = Counter()
        for g in range(N_GROUPS):
            for el in ELEMENTS:
                v = group_inv[g].get(el, 0)
                if v:
                    totals[el] += v
        for el in ELEMENTS:
            if totals[el] > peak_held[el]:
                peak_held[el] = totals[el]

    return peak_held


def percentile(values, p):
    v = sorted(values)
    k = (len(v) - 1) * (p / 100)
    f, c = math.floor(k), math.ceil(k)
    if f == c:
        return v[int(k)]
    return v[f] + (v[c] - v[f]) * (k - f)


def main():
    rng = random.Random(2024)
    per_trial = {el: [] for el in ELEMENTS}

    for _ in range(TRIALS):
        peaks = run_one_trial_peaks(rng)
        for el in ELEMENTS:
            per_trial[el].append(peaks.get(el, 0))

    rows = []
    for el in sorted(ELEMENTS):
        vals = per_trial[el]
        mean = sum(vals) / len(vals)
        p = percentile(vals, STOCK_PERCENTILE)
        worst = max(vals)
        n_sources = len(ELEM_STATIONS[el])
        # never print more than the rule makes it possible to hold at once
        qty = min(HARD_CEILING, math.ceil(p) + BUFFER)
        rows.append({
            "element": el, "sources": n_sources,
            "mean_peak": round(mean, 2), "p95_peak": round(p, 2),
            "worst_peak": worst, "stock_qty": qty,
        })

    rows.sort(key=lambda r: -r["stock_qty"])

    print(f"=== Element stock plan: {TRIALS} trials, {N_GROUPS} groups/session, "
          f"carry cap={ELEMENT_CAP}/element, target=P{STOCK_PERCENTILE} peak concurrent "
          f"hold +{BUFFER} buffer, hard ceiling={HARD_CEILING} ===\n")
    print(f"{'Element':<10}{'Sources':<9}{'MeanPeak':<10}{'P95Peak':<10}{'WorstPeak':<11}{'STOCK':<7}")
    for r in rows:
        print(f"{r['element']:<10}{r['sources']:<9}{r['mean_peak']:<10}"
              f"{r['p95_peak']:<10}{r['worst_peak']:<11}{r['stock_qty']:<7}")

    total = sum(r["stock_qty"] for r in rows)
    print(f"\nTotal physical element cards to print: {total}")

    if "--json" in sys.argv:
        out_path = sys.argv[sys.argv.index("--json") + 1]
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=2)
        print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
