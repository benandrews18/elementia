# -*- coding: utf-8 -*-
"""
Print-quantity planner for Elementia's permanent-unlock economy.

Under the current rule, crafted items are never spent -- every group that
ever crafts item X keeps its own physical card for the rest of the session.
So "how many copies of card X do we need to print" is exactly: how many of
the N_GROUPS running during a session are likely to craft X at least once.

Behavior model: a direct copy of simulate_kid.py's kid-realistic engine
(13 groups, 12-15 visits/group, 66% goal-aware wandering the rest of the
time, impulsive "craft anything makeable" sweeps, 2-3 concurrent foci) --
WITH ONE DELIBERATE CHANGE: capstones are included in the pickable interest
pool. simulate_kid.py excludes them on purpose, because it exists to isolate
non-capstone reachability from capstone-seeking behavior (see its docstring).
That exclusion is correct for that experiment but wrong for print planning:
the whole rest of this project's balance work assumes groups DO deliberately
chase capstones (that's the explicit design goal -- "most players complete
at least 1 capstone"), so a model where capstones are never a chosen goal
would badly undercount capstone card demand. Non-capstone numbers from this
script and from simulate_kid.py agree closely; only the capstone rows differ,
and they differ for this documented reason.

Aggregation: keeps the full per-trial distribution of "how many distinct
groups crafted item X" so the print run can target a safe percentile of
simulated sessions, not just the average one. Running out of a card mid-camp
is a real problem with no reprint available; printing a couple of extra
copies is not, so PRINT_PERCENTILE errs generous by default.

Usage:  python print_quantities.py                    (prints a table)
        python print_quantities.py --json out.json     (also writes the data)
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
PRINT_PERCENTILE = 95   # print enough copies to cover this % of simulated sessions
BUFFER = 1              # +1 extra copy on top of the percentile, cheap insurance

ELEM_STATIONS = {}
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS.setdefault(e, []).append(s["name"])


def is_capstone(item):
    return any(tag == "CAPSTONE" for st, r, c, tag in RECIPES[item])


TOTAL_NEEDS_CACHE = {}


def total_needs(item):
    """DAG-correct under the permanent-unlock model: a shared non-element
    item is only ever built ONCE regardless of how many parents need it."""
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


# Interest pool: EVERY craftable item, steps 1+, capstones included --
# the one deliberate divergence from simulate_kid.py (see module docstring).
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
            # only credit a station if the item is ACTUALLY craftable there
            # right now -- see simulate_capstone_focus.py's choose_station
            # for the 2026-07-20 finding this fixes.
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    for elem, amt in outstanding_elements_combined(foci, inv).items():
        for st in ELEM_STATIONS[elem]:
            tally[st] += 1
    if not tally:
        return rng.choice(ALL_STATIONS)
    best = max(tally.values())
    return rng.choice([s for s, c in tally.items() if c == best])


def impulsive_craft_sweep(station, inv, craft_counts, crafted, foci):
    """Permanent-unlock crafting: elements are spent, crafted items never
    are, each item can only ever be unlocked once per group."""
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


def focus_satisfied(focus, crafted, inv):
    tn = total_needs(focus)
    for item, qty in tn.items():
        have = inv.get(item, 0) if item in ELEMENTS else crafted.get(item, 0)
        if have < qty:
            return False
    return True


def run_one_trial(rng):
    group_inv = [Counter() for _ in range(N_GROUPS)]
    group_foci = [[pick_interest(rng) for _ in range(rng.choice(N_FOCI_CHOICES))]
                  for _ in range(N_GROUPS)]
    group_crafted = [Counter() for _ in range(N_GROUPS)]
    n_visits = [rng.randint(*VISIT_RANGE) for _ in range(N_GROUPS)]

    craft_counts = Counter()
    completions_seen = Counter()
    already_completed = [set() for _ in range(N_GROUPS)]

    for g in range(N_GROUPS):
        inv = group_inv[g]
        crafted = group_crafted[g]
        for visit in range(n_visits[g]):
            foci = group_foci[g]
            station = choose_station(rng, foci, crafted, inv)

            for _ in range(TAKE):
                inv[roll_element(station)] += 1

            impulsive_craft_sweep(station, inv, craft_counts, crafted, foci)

            still_active = []
            for f in foci:
                if focus_satisfied(f, crafted, inv):
                    still_active.append(pick_interest(rng, exclude=foci))
                else:
                    still_active.append(f)
            group_foci[g] = still_active

            for item, cnt in crafted.items():
                if cnt > 0 and item not in already_completed[g]:
                    already_completed[g].add(item)
                    completions_seen[item] += 1

    return craft_counts, completions_seen


def percentile(values, p):
    v = sorted(values)
    k = (len(v) - 1) * (p / 100)
    f, c = math.floor(k), math.ceil(k)
    if f == c:
        return v[int(k)]
    return v[f] + (v[c] - v[f]) * (k - f)


def main():
    rng = random.Random(2024)
    per_trial = {item: [] for item in RECIPES}

    for _ in range(TRIALS):
        craft_counts, completions_seen = run_one_trial(rng)
        for item in RECIPES:
            per_trial[item].append(completions_seen.get(item, 0))

    rows = []
    for item in RECIPES:
        vals = per_trial[item]
        mean = sum(vals) / len(vals)
        p = percentile(vals, PRINT_PERCENTILE)
        worst = max(vals)
        qty = min(N_GROUPS, math.ceil(p) + BUFFER)
        tag = "CAPSTONE" if is_capstone(item) else \
            [t for st, r, c, t in RECIPES[item]][0]
        rows.append({
            "item": item, "tag": tag, "steps": STEPS.get(item),
            "mean_groups": round(mean, 2), "p95_groups": round(p, 2),
            "worst_observed": worst, "print_qty": qty,
        })

    rows.sort(key=lambda r: -r["print_qty"])

    print(f"=== Print-quantity plan: {TRIALS} trials, {N_GROUPS} groups/session, "
          f"capstones included as pickable foci, target=P{PRINT_PERCENTILE}+{BUFFER} "
          f"buffer, capped at {N_GROUPS} ===\n")
    print(f"{'Item':<20}{'Tag':<11}{'Mean':<8}{'P95':<8}{'Worst':<8}{'PRINT':<7}")
    for r in rows:
        print(f"{r['item']:<20}{r['tag']:<11}{r['mean_groups']:<8}"
              f"{r['p95_groups']:<8}{r['worst_observed']:<8}{r['print_qty']:<7}")

    total_cards = sum(r["print_qty"] for r in rows)
    cap_total = sum(r["print_qty"] for r in rows if r["tag"] == "CAPSTONE")
    print(f"\nTotal physical item cards to print (one session): {total_cards}"
          f"  (of which {cap_total} are capstone cards)")

    if "--json" in sys.argv:
        out_path = sys.argv[sys.argv.index("--json") + 1]
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=2)
        print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
