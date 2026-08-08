# -*- coding: utf-8 -*-
"""Kid-realistic behavior model (ages 8-12), replacing the idealized
'efficient adult planner' from earlier runs. Changes from that model:

  1. Station choice is only ~50% goal-aware (was 92%) -- kids wander,
     follow friends, or go wherever looks free/interesting.
  2. DISTRACTION: ~20% chance per visit the group's current "thing they
     want to make" resets to something else that catches their eye,
     even mid-build.
  3. IMPULSIVE crafting: groups craft ANYTHING currently makeable the
     moment they arrive (no holding reserves "just in case"), preferring
     whichever available option is most impressive -- matching how an
     8-12 year old actually plays, not how an optimizer would.
  4. Session length varies 12-15 visits per group, not a fixed 12.
  5. Goal pool is weighted toward the mid/high tier (steps 1-5),
     explicitly EXCLUDING capstones, since that's what's being tested.
"""
import random
from collections import Counter, defaultdict
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS

N_GROUPS = 13
TRIALS = 400
VISIT_RANGE = (12, 15)
DISTRACT_CHANCE = 0.20
GOAL_AWARE_CHANCE = 0.66

ELEM_STATIONS = defaultdict(list)
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS[e].append(s["name"])

# -*- coding: utf-8 -*-
"""Kid-realistic behavior model v2 (ages 8-12).

Changes from v1:
  - NO random "distraction" resets. Instead each group commits to 2-3
    FIXED foci for the whole session (realistic: kids have a couple of
    things they want to make, not one single-minded target and not an
    ever-shifting whim). Station choice and crafting consider ALL active
    foci at once, so some visits naturally advance multiple foci together
    (when they share a station/ingredient) and some only advance one.
  - Station choice is 66% goal-aware (kids wander the rest of the time).
  - Anti-hoarding: a group won't keep re-making something it already has
    unless one of its active foci genuinely needs more copies.
  - TAKE 5 dice per visit.
  - Farm/Grain recipes reflect the proposed simplification (see model.py).
"""
import random
from collections import Counter, defaultdict
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS

N_GROUPS = 13
TRIALS = 400
VISIT_RANGE = (12, 15)
GOAL_AWARE_CHANCE = 0.66
N_FOCI_CHOICES = [2, 3]
TAKE = 5

ELEM_STATIONS = defaultdict(list)
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS[e].append(s["name"])

def is_capstone(item):
    return any(tag == "CAPSTONE" for st, r, c, tag in RECIPES[item])

TOTAL_NEEDS_CACHE = {}
def total_needs(item):
    """DAG-correct under the permanent-unlock model: a shared non-element
    item (e.g. Water, Tree, Clay) is only ever built ONCE no matter how
    many different parent recipes reference it, so its own raw-element
    cost is only paid once too -- NOT once per parent that needs it.
    (This replaced a buggy tree-style flatten_needs that multiplicatively
    over-counted shared ingredients -- see SIMULATION_METHODOLOGY.md.)"""
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

def combined_needs(foci):
    """Total demand across ALL active foci -- if two foci both need a
    Water, the group genuinely needs two, since crafting consumes it."""
    needs = Counter()
    for f in foci:
        for k, v in total_needs(f).items():
            needs[k] += v
    return needs

# interest pool: mid/high tier only, steps 1-5, no capstones
INTEREST_POOL = [i for i, s in STEPS.items() if s is not None and 1 <= s <= 5
                  and not is_capstone(i)]
INTEREST_WEIGHTS = [1.3 ** STEPS[i] for i in INTEREST_POOL]

def pick_interest(rng, exclude=()):
    pool, weights = [], []
    for i, w in zip(INTEREST_POOL, INTEREST_WEIGHTS):
        if i not in exclude:
            pool.append(i); weights.append(w)
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
        return rng.choice(ALL_STATIONS)   # wander / follow friends / whatever's free
    tally = Counter()
    cn = combined_needs(foci)
    for item, qty in cn.items():
        if item in ELEMENTS or crafted.get(item, 0) >= qty:
            continue
        for st, req, catalysts, tag in RECIPES[item]:
            # only credit a station if the item is ACTUALLY craftable there
            # right now -- see simulate_capstone_focus.py's choose_station
            # for the 2026-07-20 finding this fixes (deep chains were being
            # starved by routing credit toward not-yet-ready stations).
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    for elem, amt in outstanding_elements_combined(foci, inv).items():
        for st in ELEM_STATIONS[elem]:
            tally[st] += 1
    if not tally:
        return rng.choice(ALL_STATIONS)
    best = max(tally.values())
    return rng.choice([s for s, c in tally.items() if c == best])

def impulsive_craft_sweep(station, inv, craft_counts, crafted_by_item, foci):
    """Craft currently-possible recipes at this station.

    UNLOCK MODEL: crafted (non-element) items are never spent once made --
    they join a permanent library and stay available forever as ingredients
    for anything else. Only raw ELEMENTS are consumed/depleted. A recipe
    can never be re-crafted once it's in the library (cap=1), so any
    recipe requiring 2+ of a non-element item (Flour, Galaxy) is simply
    unreachable now -- accepted as a known consequence, not fixed here.
    """
    progressed = True
    while progressed:
        progressed = False
        options = []
        for item, recs in RECIPES.items():
            if inv.get(item, 0) >= 1:
                continue   # already permanently unlocked -- nothing more to do
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
                inv[ing] -= qty          # elements are still spent
            # non-element ingredients: NOT decremented -- permanent unlock
        inv[item] += 1
        craft_counts[item] += 1
        crafted_by_item[item] += 1
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
                e = roll_element(station)
                inv[e] += 1

            impulsive_craft_sweep(station, inv, craft_counts, crafted, foci)

            # a satisfied focus gets replaced with a fresh one (sustained
            # engagement, not random abandonment mid-build)
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


def main():
    rng = random.Random(2024)
    total_craft = Counter()
    total_completions = Counter()   # item -> number of GROUPS that ever made >=1, summed over trials
    craft_trials = defaultdict(list)

    for t in range(TRIALS):
        c, comp = run_one_trial(rng)
        for k in RECIPES:
            v = c.get(k, 0)
            total_craft[k] += v
            craft_trials[k].append(v)
        for k, v in comp.items():
            total_completions[k] += v

    print(f"=== Multi-focus kid model: {TRIALS} trials, {N_GROUPS} groups, {VISIT_RANGE[0]}-{VISIT_RANGE[1]} visits/group, TAKE={TAKE} ===\n")
    print(f"{'Item':<20}{'Steps':<7}{'%Groups reaching>=1':<22}{'AvgCraftsPerSession':<22}")
    for item in sorted(RECIPES.keys(), key=lambda i: -total_completions[i]):
        if is_capstone(item):
            continue
        pct_groups = total_completions[item] / (TRIALS * N_GROUPS) * 100
        avg = total_craft[item] / TRIALS
        print(f"{item:<20}{STEPS.get(item,'?'):<7}{pct_groups:<22.1f}{avg:<22.2f}")

if __name__ == "__main__":
    main()
