# -*- coding: utf-8 -*-
"""Station-graph / movement-rule comparison harness -- v2.

Same topology/movement-rule questions as simulate_pathing.py (v1), but with
a real Job Board model instead of v1's borrowed "foci" abstraction:

  - Jobs are offered 3-at-a-time, PER STATION, ranked by how connected an
    item is to that station (its own dice + what it sells), mirroring
    jobOfferScore() in game/elementia.html exactly (ported by hand -- see
    that function's comment for the reasoning).
  - The board is rolled once per arrival and doesn't refresh until the
    player leaves, same as the real game (see pick_station_job_options()
    and its call site in run_one_trial()).
  - Players decide whether to TAKE a card using two signals the user asked
    for specifically: (1) do they already own/craft some of what it needs
    (partial progress), and (2) does it share ingredients with a job
    they're already holding (long-term planning / synergy) -- see
    take_score(). This replaces v1's goal-unaware-ish random picking with
    something that should produce more realistic "what actually gets
    finished" data.
  - Station CHOICE itself still uses the same tally logic as v1/
    simulate_kid.py (score_stations()/choose_station()), just fed the
    player's currently-HELD job items instead of foci -- these functions
    were already generic over "a list of target item names," so v1's code
    is reused directly (imported from simulate_pathing.py), not
    reimplemented.
  - CRAFTING is its own function here (job_aware_craft_sweep()), not v1's
    impulsive_craft_sweep() -- v1's kid-behavior model deliberately crafts
    whatever's available with no regard for what's held, which turned out
    to make actually FINISHING a specific held job vanishingly rare (see
    the TurnIn% caveat if you flip this back to reusing v1's version).
    Prerequisites of a held job are tried first here, falling back to the
    same "deepest available" heuristic for opportunistic extra crafting.

Run this directly for the topology/movement comparison (now with real job
data). Pass --pools to also print each station's own typical job pool
(useful as a first draft of what real Job Board content per station could
look like) -- see print_station_pools().
"""
import random, sys
from collections import Counter, defaultdict
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS
from simulate_pathing import (
    BASE_EDGES, PLUS2_EXTRA, DIAGONAL_EXTRA, build_adj, structural_stats,
    reachable, is_capstone, total_needs, combined_needs, score_stations,
    choose_station, ELEM_STATIONS,
)

N_PLAYERS = 13
TRIALS = 300
VISIT_RANGE = (12, 15)
TAKE = 5
JOB_MIN_CREATION_POINTS = 13
MAX_HELD_JOBS = 4

# ------------------------------------------------------ item metadata ----
# model.py doesn't carry points/home-station through RECIPES (only tag),
# so pull those straight from STATIONS the same way build_guide.py's own
# jobEligibleItems()/ENTRIES do in the digital game.
ITEM_POINTS = {}
ITEM_HOME = {}
ITEM_TAG = {}
for s in STATIONS:
    items = list(s["shop"])
    if s.get("farm_section"):
        items += s["farm_section"]["items"]
    for emoji, name, tag, recipe, points in items:
        ITEM_POINTS[name] = points
        ITEM_HOME.setdefault(name, s["name"])
        ITEM_TAG.setdefault(name, tag)
    ce, cn, ct, cr, cpts = s["capstone"]
    ITEM_POINTS[cn] = cpts
    ITEM_HOME.setdefault(cn, s["name"])
    ITEM_TAG.setdefault(cn, "CAPSTONE")

def job_eligible_items():
    return [n for n in RECIPES
            if is_capstone(n) or (ITEM_TAG.get(n) == "CREATION"
                                   and ITEM_POINTS.get(n, 0) >= JOB_MIN_CREATION_POINTS)]

JOB_ELIGIBLE = job_eligible_items()

def job_bonus(items):
    return sum(ITEM_POINTS.get(it, 0) for it in items)

# ------------------------------------------------- station connection ----
def job_offer_score(item, station, inv, crafted):
    """Direct port of jobOfferScore() in game/elementia.html: +3 if sold
    here, +2 per closure element this station's own dice can roll (+0.5
    more if the player already has some), +1 per closure item sold here
    (+1 more if the player already built it)."""
    home = ITEM_HOME.get(item)
    if home is None:
        return 0
    score = 3 if home == station else 0
    st_dice = set(STATION_DICE[station])
    needs = total_needs(item)
    for k, v in needs.items():
        if k in ELEMENTS:
            if k in st_dice:
                score += 2
            if inv.get(k, 0) > 0:
                score += 0.5
        else:
            if ITEM_HOME.get(k) == station:
                score += 1
            if crafted.get(k, 0) > 0:
                score += 1
    return score

def pick_station_job_options(rng, station, inv, crafted, taken):
    pool = [n for n in JOB_ELIGIBLE if n not in taken]
    if not pool:
        return []
    scored = sorted(pool, key=lambda n: job_offer_score(n, station, inv, crafted), reverse=True)
    if job_offer_score(scored[0], station, inv, crafted) <= 0:
        rng.shuffle(scored)  # nothing here has any real connection -- arbitrary fallback
    top_n = max(6, len(scored) // 2)
    top, rest = scored[:top_n], scored[top_n:]
    rng.shuffle(top); rng.shuffle(rest)
    names = top + rest
    cards = []
    while len(cards) < 3 and names:
        size = 2 if len(names) >= 2 and rng.random() < 0.6 else 1
        cards.append([names.pop(0) for _ in range(size)])
    return cards

# --------------------------------------------------- take-decision AI ----
def held_closure_items(held_jobs):
    s = set()
    for job in held_jobs:
        for it in job:
            s |= {k for k in total_needs(it) if k not in ELEMENTS}
    return s

def take_score(card_items, inv, crafted, held_jobs):
    """Higher = more attractive to take. Rewards (a) already owning some
    of what it needs -- elements in hand or components already built --
    and (b) overlapping with the build path of a job already held (taking
    on two jobs that share ingredients is better long-term planning than
    two unrelated ones)."""
    score = 0
    held_items = held_closure_items(held_jobs)
    for it in card_items:
        for k, v in total_needs(it).items():
            if k in ELEMENTS:
                if inv.get(k, 0) > 0:
                    score += 0.5
            else:
                if crafted.get(k, 0) > 0:
                    score += 1.5
                if k in held_items:
                    score += 1
    return score

def decide_take(rng, board, inv, crafted, held_jobs):
    if len(held_jobs) >= MAX_HELD_JOBS or not board:
        return None
    scored = sorted(range(len(board)), key=lambda i: -take_score(board[i], inv, crafted, held_jobs))
    best = scored[0]
    if take_score(board[best], inv, crafted, held_jobs) > 0 or rng.random() < 0.5:
        return best
    return None

# ------------------------------------------------------------- sim core ----
def job_done(items, crafted):
    return all(crafted.get(it, 0) > 0 for it in items)

def job_aware_craft_sweep(station, inv, crafted, held_flat):
    """v1's impulsive_craft_sweep() deliberately crafts ANYTHING available,
    preferring the deepest option, with no regard for what's actually
    held -- realistic for the kid-behavior model it was built for, but it
    means a specific 13+-point job item rarely gets deliberately finished
    (see the module docstring/TurnIn% caveat). Same mechanics here, but
    prerequisites of a currently-held job are tried FIRST -- the "long
    term planning" behavior the user asked for -- falling back to the
    deepest-available heuristic once nothing held is craftable, for the
    same opportunistic extra crafting v1 modeled."""
    held_needs = set()
    for it in held_flat:
        held_needs |= {k for k in total_needs(it) if k not in ELEMENTS}
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
        options.sort(key=lambda o: (o[0] in held_needs, STEPS.get(o[0], 0)), reverse=True)
        item, req, catalysts = options[0]
        for ing, qty in req.items():
            if ing in catalysts:
                continue
            if ing in ELEMENTS:
                inv[ing] -= qty
        inv[item] += 1
        crafted[item] += 1
        progressed = True

def run_one_trial(rng, adj, rule):
    results = []
    for p in range(N_PLAYERS):
        inv, crafted = Counter(), Counter()
        held_jobs, taken_names = [], set()
        n_visits = rng.randint(*VISIT_RANGE)
        current, visited = None, set()
        start_station = None
        wasted_visits, jobs_offered_total, jobs_taken_total, jobs_turned_in = 0, 0, 0, 0
        bonus_earned = 0
        fundamentals_by_v3 = 0
        for v in range(n_visits):
            held_flat = [it for job in held_jobs for it in job]
            candidates = reachable(adj, current, rule, visited)
            station = choose_station(rng, held_flat, crafted, inv, candidates)
            if v == 0:
                start_station = station
            visited.add(station)
            tally_before = score_stations(held_flat, crafted, inv, {station})
            if tally_before[station] == 0:
                wasted_visits += 1
            current = station
            for _ in range(TAKE):
                e = random.choice(STATION_DICE[station])
                inv[e] += 1
            job_aware_craft_sweep(station, inv, crafted, held_flat)

            # turn in anything now complete
            still_held = []
            for job in held_jobs:
                if job_done(job, crafted):
                    jobs_turned_in += 1
                    bonus_earned += job_bonus(job)
                else:
                    still_held.append(job)
            held_jobs = still_held

            # this station's own board, rolled fresh for this arrival
            board = pick_station_job_options(rng, station, inv, crafted, taken_names)
            jobs_offered_total += len(board)
            take_i = decide_take(rng, board, inv, crafted, held_jobs)
            if take_i is not None:
                items = board[take_i]
                held_jobs.append(items)
                taken_names |= set(items)
                jobs_taken_total += 1

            if v == 2:
                start_dice = set(STATION_DICE[start_station])
                have = sum(1 for e in start_dice if inv.get(e, 0) > 0)
                fundamentals_by_v3 = have / len(start_dice)

        completions = sum(1 for item, c in crafted.items() if c > 0 and not is_capstone(item))
        results.append({
            "wasted_frac": wasted_visits / n_visits,
            "fundamentals_by_v3": fundamentals_by_v3,
            "completions": completions,
            "jobs_taken": jobs_taken_total,
            "jobs_turned_in": jobs_turned_in,
            "turn_in_rate": (jobs_turned_in / jobs_taken_total) if jobs_taken_total else 0,
            "bonus_earned": bonus_earned,
        })
    return results

def run_config(rng, edges, rule, label):
    adj = build_adj(edges)
    all_results = []
    for t in range(TRIALS):
        all_results.extend(run_one_trial(rng, adj, rule))
    n = len(all_results)
    avg = lambda k: sum(r[k] for r in all_results) / n
    stats = structural_stats(edges)
    return {
        "label": label,
        "avg_degree": stats["avg_degree"], "avg_hops": stats["avg_hops"], "diameter": stats["diameter"],
        "wasted_frac": avg("wasted_frac"), "fundamentals_by_v3": avg("fundamentals_by_v3"),
        "completions": avg("completions"), "jobs_taken": avg("jobs_taken"),
        "turn_in_rate": avg("turn_in_rate"), "bonus_earned": avg("bonus_earned"),
    }

def print_station_pools():
    """A cold-start (empty inventory) snapshot of each station's top-6
    scoring items -- not a literal "this is exactly what the board will
    say" (real boards see a player's actual progress and shuffle among the
    top half, see pick_station_job_options()), but a direct answer to
    "what would these cards look like at each station.\""""
    print("=== Cold-start job-affinity top-6 per station (job_offer_score, empty inventory) ===\n")
    for s in STATIONS:
        name = s["name"]
        scored = sorted(JOB_ELIGIBLE, key=lambda n: job_offer_score(n, name, {}, {}), reverse=True)[:6]
        line = ", ".join(f"{n} ({job_offer_score(n, name, {}, {}):.1f})" for n in scored)
        print(f"{name:<20}{line}")
    print()

def main():
    rng = random.Random(2026)
    configs = [
        (BASE_EDGES, "single_hop", "BASE / single-hop (current game)"),
        (BASE_EDGES + PLUS2_EXTRA, "single_hop", "PLUS2 / single-hop (proposed +2 edges)"),
        (BASE_EDGES + DIAGONAL_EXTRA, "single_hop", "DIAGONAL / single-hop (+4 cross-row shortcuts)"),
        (BASE_EDGES, "two_hop", "BASE / two-hop movement"),
        (BASE_EDGES, "fast_travel", "BASE / fast-travel to visited"),
    ]
    rows = [run_config(rng, edges, rule, label) for edges, rule, label in configs]

    print(f"=== Pathing comparison v2 (real Job Board model): {TRIALS} trials x {N_PLAYERS} players, "
          f"{VISIT_RANGE[0]}-{VISIT_RANGE[1]} visits/player, TAKE={TAKE} ===\n")
    hdr = (f"{'Config':<48}{'AvgHops':<9}{'Diam':<6}{'Wasted%':<9}{'Fund@v3':<9}"
           f"{'AvgCompl':<9}{'JobsTkn':<9}{'TurnIn%':<9}{'AvgPts':<8}")
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        print(f"{r['label']:<48}{r['avg_hops']:<9.2f}{r['diameter']:<6}{r['wasted_frac']*100:<9.1f}"
              f"{r['fundamentals_by_v3']*100:<9.1f}{r['completions']:<9.2f}{r['jobs_taken']:<9.2f}"
              f"{r['turn_in_rate']*100:<9.1f}{r['bonus_earned']:<8.1f}")

    print("\nJobsTkn = avg jobs taken per player session. TurnIn% = of jobs taken, what\n"
          "share got turned in before the session ended (the take-decision AI now\n"
          "favors jobs with existing partial progress / shared build paths, see\n"
          "take_score() -- this should read meaningfully higher than a random-take\n"
          "policy would produce). AvgPts = avg bonus points banked from turn-ins.\n"
          "Wasted%/Fund@v3/AvgCompl are the same metrics as v1, now measured against\n"
          "real held jobs instead of v1's foci proxy.")

    if "--pools" in sys.argv:
        print()
        print_station_pools()

if __name__ == "__main__":
    main()
