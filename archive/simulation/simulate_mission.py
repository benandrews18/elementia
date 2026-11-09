# -*- coding: utf-8 -*-
"""Mission-card simulation: a group commits to ONE randomly-assigned mission
(a pair of capstones, exactly as offered by the digital game's mission
picker) and pursues BOTH with complete, single-minded focus for N_VISITS
station visits. This is the same "complete focus" behavior model as
simulate_capstone_focus.py (goal-directed routing, no distraction, no
wandering), generalized from one goal to two, plus two things that script
predates: the 3-per-element carry cap (now a real game rule -- see
element_stock.py) and per-mission-pair breakdown rather than a single
pooled average, since with 28 possible pairs some are structurally much
harder than others and that variance is the actual question worth asking.

Reuses model.py's item graph and the routing/crafting engine already
validated (and bug-fixed) in simulate_capstone_focus.py / element_stock.py:
  - total_needs(): DAG-correct requirement flattening under the
    permanent-unlock model (a shared ingredient is only paid for once).
  - choose_station(): scarcity-weighted, and only credits a station for an
    item if that item is ACTUALLY craftable there right now (the 2026-07-20
    routing-readiness fix -- crediting "sells a wanted item" regardless of
    whether ITS OWN ingredients are ready starves deep chains).
  - Element carry cap enforced at acquisition (2026-07-21 rule).

Usage:  python simulate_mission.py                  (prints report)
        python simulate_mission.py --json out.json   (also writes raw data)
"""
import random
import statistics
import sys
import json
from collections import Counter, defaultdict
from itertools import combinations
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS
import model as _model

N_VISITS = 20
TAKE = 5
ELEMENT_CAP = 3
TRIALS_PER_PAIR = 300
SEED = 20260729

# ------------------------------------------------------------- points ----
# model.py's RECIPES doesn't carry points (only station/req/catalysts/tag),
# so pull them straight from build_guide.py the same way build_game.py does.
bg = _model.bg
POINTS = {}
for s in bg.STATIONS:
    items = list(s["shop"])
    if s.get("farm_section"):
        items += s["farm_section"]["items"]
    for emoji, name, tag, recipe, points in items:
        POINTS[name] = points
    ce, cn, ct, cr, cpts = s["capstone"]
    POINTS[cn] = cpts

ELEM_STATIONS = defaultdict(list)
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS[e].append(s["name"])

def is_capstone(item):
    return any(tag == "CAPSTONE" for st, r, c, tag in RECIPES[item])

CAPSTONES = [i for i in RECIPES if is_capstone(i) and STEPS.get(i) is not None]
BROKEN_CAPSTONES = [i for i in RECIPES if is_capstone(i) and STEPS.get(i) is None]
MISSION_PAIRS = list(combinations(sorted(CAPSTONES), 2))  # all C(8,2)=28, matches the in-game pool

TOTAL_NEEDS_CACHE = {}
def total_needs(item):
    """DAG-correct under the permanent-unlock model: a shared non-element
    item is only ever built ONCE no matter how many parents need it, so its
    raw-element cost is only paid once too."""
    if item in TOTAL_NEEDS_CACHE:
        return TOTAL_NEEDS_CACHE[item]
    needed_items = set()
    elem_needs = Counter()
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

def combined_needs(goals):
    needs = Counter()
    for g in goals:
        for k, v in total_needs(g).items():
            needs[k] += v
    return needs

def roll_element(station_name):
    return random.choice(STATION_DICE[station_name])

def choose_station(rng, goals, crafted, inv, last_station):
    """Goal-directed routing toward BOTH mission capstones at once, ranked
    by scarcity. See simulate_capstone_focus.py for the readiness-credit
    fix this depends on."""
    tally = Counter()
    cn = combined_needs(goals)
    for item, qty in cn.items():
        if item in ELEMENTS or crafted.get(item, 0) >= qty:
            continue
        for st, req, catalysts, tag in RECIPES[item]:
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    for elem, qty in cn.items():
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

def craft_sweep(station, inv, crafted):
    """Permanent-unlock crafting: elements are spent, crafted items never
    are, deepest-available option preferred each pass."""
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

def mission_complete(goals, crafted):
    return all(crafted.get(g, 0) >= 1 for g in goals)

def run_one_trial(rng, goals):
    inv = Counter()
    crafted = Counter()
    last_station = None
    completed_at = None
    for visit in range(1, N_VISITS + 1):
        station = choose_station(rng, goals, crafted, inv, last_station)
        last_station = station

        # Carry cap enforced at acquisition -- a die showing an element the
        # group is already full on is simply returned to the pool.
        for _ in range(TAKE):
            e = roll_element(station)
            if inv.get(e, 0) < ELEMENT_CAP:
                inv[e] += 1

        craft_sweep(station, inv, crafted)

        if completed_at is None and mission_complete(goals, crafted):
            completed_at = visit

    final_score = sum(POINTS.get(item, 0) for item, cnt in crafted.items() if cnt > 0)
    return completed_at, final_score

def percentile(values, p):
    if not values:
        return None
    v = sorted(values)
    k = (len(v) - 1) * (p / 100)
    f, c = int(k), min(int(k) + 1, len(v) - 1)
    if f == c:
        return v[f]
    return v[f] + (v[c] - v[f]) * (k - f)

def main():
    rng = random.Random(SEED)

    per_pair = {}
    all_scores = []
    all_completed_turns = []
    all_scores_completed = []
    all_scores_not_completed = []
    all_trials = 0
    all_completed = 0

    for pair in MISSION_PAIRS:
        scores = []
        turns = []
        for _ in range(TRIALS_PER_PAIR):
            completed_at, score = run_one_trial(rng, pair)
            scores.append(score)
            all_scores.append(score)
            all_trials += 1
            if completed_at is not None:
                turns.append(completed_at)
                all_completed_turns.append(completed_at)
                all_completed += 1
                all_scores_completed.append(score)
            else:
                all_scores_not_completed.append(score)
        per_pair[pair] = {
            "trials": TRIALS_PER_PAIR,
            "completion_rate": len(turns) / TRIALS_PER_PAIR,
            "turns_mean": round(statistics.mean(turns), 1) if turns else None,
            "turns_median": percentile(turns, 50),
            "turns_p25": percentile(turns, 25),
            "turns_p75": percentile(turns, 75),
            "score_mean": round(statistics.mean(scores), 1),
            "score_median": percentile(scores, 50),
        }

    print(f"=== Mission-card simulation: {len(MISSION_PAIRS)} mission pairs x "
          f"{TRIALS_PER_PAIR} trials = {all_trials} total trials ===")
    print(f"    {N_VISITS} visits/session, TAKE={TAKE}, ELEMENT_CAP={ELEMENT_CAP}, "
          f"no-repeat-station, complete single-minded focus on both capstones\n")
    if BROKEN_CAPSTONES:
        print(f"EXCLUDED (structurally broken): {BROKEN_CAPSTONES}\n")

    overall_rate = all_completed / all_trials * 100
    print(f"OVERALL: {overall_rate:.1f}% of trials completed their mission within {N_VISITS} visits.")
    if all_completed_turns:
        print(f"  Turns to complete (finishers only): mean {statistics.mean(all_completed_turns):.1f}, "
              f"median {percentile(all_completed_turns, 50):.0f}, "
              f"p25 {percentile(all_completed_turns, 25):.0f}, "
              f"p75 {percentile(all_completed_turns, 75):.0f}")
    print(f"  Final score after {N_VISITS} visits: mean {statistics.mean(all_scores):.1f}, "
          f"median {percentile(all_scores, 50):.0f}")
    if all_scores_completed and all_scores_not_completed:
        print(f"    -> mean score when mission completed:     {statistics.mean(all_scores_completed):.1f}")
        print(f"    -> mean score when mission NOT completed: {statistics.mean(all_scores_not_completed):.1f}")

    print(f"\n--- Per mission pair (sorted hardest -> easiest) ---")
    print(f"{'Mission':<38}{'Complete%':<11}{'MedianTurn':<12}{'p25-p75':<12}{'MeanScore':<10}")
    for pair, r in sorted(per_pair.items(), key=lambda kv: kv[1]["completion_rate"]):
        label = f"{pair[0]} + {pair[1]}"
        median = f"{r['turns_median']:.0f}" if r["turns_median"] is not None else "--"
        spread = f"{r['turns_p25']:.0f}-{r['turns_p75']:.0f}" if r["turns_p25"] is not None else "--"
        print(f"{label:<38}{r['completion_rate']*100:<11.1f}{median:<12}{spread:<12}{r['score_mean']:<10.1f}")

    if "--json" in sys.argv:
        out_path = sys.argv[sys.argv.index("--json") + 1]
        out = {
            "n_visits": N_VISITS, "take": TAKE, "element_cap": ELEMENT_CAP,
            "trials_per_pair": TRIALS_PER_PAIR, "overall_completion_rate": overall_rate / 100,
            "pairs": {f"{a} + {b}": v for (a, b), v in per_pair.items()},
        }
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=2)
        print(f"\nwrote {out_path}")

if __name__ == "__main__":
    main()
