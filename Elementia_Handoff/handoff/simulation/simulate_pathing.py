# -*- coding: utf-8 -*-
"""Station-graph / movement-rule comparison harness.

Answers two questions the digital game's diamond map (see MAP_EDGES in
game/elementia.html) raises but has never been tested against:

  1. TOPOLOGY -- does adding Observatory<->Ocean and Greenhouse<->Power
     Plant (the user's proposed extra edges) help or hurt, compared to
     the current 10-edge web? What about also allowing "diagonal"
     1-row shortcuts between the two side chains?
  2. MOVEMENT RULE -- instead of changing the graph, what if the RULE for
     how far you can move each turn changes: up to 2 hops before you're
     forced to enter a station, or fast-travel to anywhere you've already
     visited?

This is a first-pass model, not the final word -- see ASSUMPTIONS below for
every simplification made and where the real Job Board mechanic was
approximated instead of fully ported.

ASSUMPTIONS (read before trusting the numbers):
  - Goals are modeled as simulate_kid.py's "foci" (a player commits to 2-3
    target items at a time, gets a fresh one when satisfied), NOT the real
    Job Board's exact card pool / bonus-point formula. This keeps the
    comparison about MOVEMENT, not about job-selection tuning, but means
    the point totals here are not the game's real scoring.
  - "Fundamentals collected early" is measured as: of the elements the
    player's STARTING station's own dice can roll, what fraction does the
    player have at least 1 of by the end of visit 3? This is
    a proxy for "did the player get bogged down chasing a specific station
    instead of just gathering," not a literal readiness check.
  - The "diagonal" topology adds a shortcut between each pair of stations
    one row apart on OPPOSITE sides of the map (Bakery<->Power Plant,
    The City<->Greenhouse, Greenhouse<->Deep Mine, Power Plant<->Old
    Growth Forest) -- see STATION_GRID below for the row/side layout this
    is derived from. This is one reasonable reading of "1x1 diagonal";
    if a different set of shortcuts was intended, swap DIAGONAL_EXTRA.
  - "Two-hop" movement lets a player path through one intermediate station
    without it costing a visit, then must enter the second station (that
    entry costs the usual 1 visit) -- i.e. movement range doubles, visit
    cost doesn't.
  - "Fast travel" lets a player jump straight to ANY station they've
    already visited this session, in addition to normal single-hop moves,
    for the same 1-visit cost as any other move.
"""
import random
from collections import Counter, defaultdict
from model import RECIPES, ELEMENTS, STEPS, STATION_DICE, ALL_STATIONS, STATIONS

N_PLAYERS = 13
TRIALS = 300
VISIT_RANGE = (12, 15)
GOAL_AWARE_CHANCE = 0.66
N_FOCI_CHOICES = [2, 3]
TAKE = 5

# ---------------------------------------------------------------- graph ----
# Ported from game/elementia.html's MAP_NODE_POS/MAP_EDGES (2026.08.04).
STATION_GRID = {  # name -> (row 0=top..4=bottom, col -1=left/0=center/1=right)
    "The Observatory":   (0,  0),
    "The Bakery":        (1, -1),
    "The City":          (1,  1),
    "Greenhouse":        (2, -1),
    "The Power Plant":   (2,  1),
    "Old Growth Forest": (3, -1),
    "Deep Mine":         (3,  1),
    "The Ocean":         (4,  0),
}

BASE_EDGES = [
    ("The Ocean", "Old Growth Forest"), ("The Ocean", "Deep Mine"),
    ("Old Growth Forest", "Greenhouse"), ("Deep Mine", "The Power Plant"),
    ("Greenhouse", "The Bakery"), ("The Power Plant", "The City"),
    ("The Bakery", "The Observatory"), ("The City", "The Observatory"),
    ("Old Growth Forest", "The City"), ("Deep Mine", "The Bakery"),
]
PLUS2_EXTRA = [("The Observatory", "The Ocean"), ("Greenhouse", "The Power Plant")]
DIAGONAL_EXTRA = [
    ("The Bakery", "The Power Plant"), ("The City", "Greenhouse"),
    ("Greenhouse", "Deep Mine"), ("The Power Plant", "Old Growth Forest"),
]

def build_adj(edges):
    adj = defaultdict(set)
    for a, b in edges:
        adj[a].add(b); adj[b].add(a)
    return adj

TOPOLOGIES = {
    "BASE (current, 10 edges)":            BASE_EDGES,
    "PLUS2 (+Observatory-Ocean, +Greenhouse-Power Plant)": BASE_EDGES + PLUS2_EXTRA,
    "DIAGONAL (BASE + 4 cross-row shortcuts)": BASE_EDGES + DIAGONAL_EXTRA,
}

def all_pairs_hops(adj):
    """BFS from every node -- returns {a: {b: hopcount}}."""
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
    return dist

def structural_stats(edges):
    adj = build_adj(edges)
    dist = all_pairs_hops(adj)
    all_hops = [h for d in dist.values() for h in d.values() if h > 0]
    degrees = [len(adj[n]) for n in adj]
    return {
        "edges": len(edges),
        "avg_degree": sum(degrees) / len(degrees),
        "avg_hops": sum(all_hops) / len(all_hops),
        "diameter": max(all_hops),
    }

# ------------------------------------------------------------- sim core ----
def is_capstone(item):
    return any(tag == "CAPSTONE" for st, r, c, tag in RECIPES[item])

TOTAL_NEEDS_CACHE = {}
def total_needs(item):
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

def combined_needs(foci):
    needs = Counter()
    for f in foci:
        for k, v in total_needs(f).items():
            needs[k] += v
    return needs

INTEREST_POOL = [i for i, s in STEPS.items() if s is not None and 1 <= s <= 5
                  and not is_capstone(i)]
INTEREST_WEIGHTS = [1.3 ** STEPS[i] for i in INTEREST_POOL]

def pick_interest(rng, exclude=()):
    pool, weights = [], []
    for i, w in zip(INTEREST_POOL, INTEREST_WEIGHTS):
        if i not in exclude:
            pool.append(i); weights.append(w)
    return rng.choices(pool, weights=weights, k=1)[0]

ELEM_STATIONS = defaultdict(list)
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS[e].append(s["name"])

def outstanding_elements_combined(foci, inv):
    need = Counter()
    for elem, qty in combined_needs(foci).items():
        if elem in ELEMENTS:
            short = qty - inv.get(elem, 0)
            if short > 0:
                need[elem] = short
    return need

def score_stations(foci, crafted, inv, candidates):
    """Same tally logic as simulate_kid.py's choose_station, restricted to
    a caller-supplied candidate set (the movement rule decides who's
    reachable this turn)."""
    tally = Counter({c: 0 for c in candidates})
    cn = combined_needs(foci)
    for item, qty in cn.items():
        if item in ELEMENTS or crafted.get(item, 0) >= qty:
            continue
        for st, req, catalysts, tag in RECIPES[item]:
            if st not in tally:
                continue
            if all(inv.get(ing, 0) >= q for ing, q in req.items()):
                tally[st] += 2
    for elem, amt in outstanding_elements_combined(foci, inv).items():
        for st in ELEM_STATIONS[elem]:
            if st in tally:
                tally[st] += 1
    return tally

def choose_station(rng, foci, crafted, inv, candidates):
    if rng.random() >= GOAL_AWARE_CHANCE or not foci:
        return rng.choice(list(candidates))
    tally = score_stations(foci, crafted, inv, candidates)
    best = max(tally.values())
    if best == 0:
        return rng.choice(list(candidates))
    return rng.choice([s for s, c in tally.items() if c == best])

def impulsive_craft_sweep(station, inv, craft_counts, crafted, foci):
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

def reachable(adj, current, rule, visited):
    """Movement-rule-aware candidate set for the NEXT station to enter."""
    if current is None:
        return set(ALL_STATIONS)  # first move of the session: start anywhere
    if rule == "single_hop":
        return set(adj[current])
    if rule == "two_hop":
        out = set(adj[current])
        for nb in list(out):
            out |= adj[nb]
        out.discard(current)
        return out
    if rule == "fast_travel":
        return set(adj[current]) | (visited - {current})
    raise ValueError(rule)

def run_one_trial(rng, adj, rule):
    results = []
    for p in range(N_PLAYERS):
        inv = Counter()
        crafted = Counter()
        foci = [pick_interest(rng) for _ in range(rng.choice(N_FOCI_CHOICES))]
        n_visits = rng.randint(*VISIT_RANGE)
        current = None
        visited = set()
        start_station = None
        wasted_visits = 0
        for v in range(n_visits):
            candidates = reachable(adj, current, rule, visited)
            station = choose_station(rng, foci, crafted, inv, candidates)
            if v == 0:
                start_station = station
            visited.add(station)
            tally_before = score_stations(foci, crafted, inv, {station})
            if tally_before[station] == 0:
                wasted_visits += 1
            current = station
            for _ in range(TAKE):
                e = random.choice(STATION_DICE[station])
                inv[e] += 1
            impulsive_craft_sweep(station, inv, crafted, crafted, foci)
            still_active = []
            for f in foci:
                if focus_satisfied(f, crafted, inv):
                    still_active.append(pick_interest(rng, exclude=foci))
                else:
                    still_active.append(f)
            foci = still_active
            if v == 2:  # snapshot "fundamentals by visit 3" (0-indexed v==2)
                start_dice = set(STATION_DICE[start_station])
                have = sum(1 for e in start_dice if inv.get(e, 0) > 0)
                fundamentals_by_v3 = have / len(start_dice)
        completions = sum(1 for item, c in crafted.items() if c > 0 and not is_capstone(item))
        results.append({
            "wasted_frac": wasted_visits / n_visits,
            "fundamentals_by_v3": fundamentals_by_v3,
            "completions": completions,
        })
    return results

def run_config(rng, edges, rule, label):
    adj = build_adj(edges)
    all_results = []
    for t in range(TRIALS):
        all_results.extend(run_one_trial(rng, adj, rule))
    n = len(all_results)
    avg_wasted = sum(r["wasted_frac"] for r in all_results) / n
    avg_fund = sum(r["fundamentals_by_v3"] for r in all_results) / n
    avg_completions = sum(r["completions"] for r in all_results) / n
    stats = structural_stats(edges)
    return {
        "label": label,
        "avg_degree": stats["avg_degree"],
        "avg_hops": stats["avg_hops"],
        "diameter": stats["diameter"],
        "wasted_frac": avg_wasted,
        "fundamentals_by_v3": avg_fund,
        "completions": avg_completions,
    }

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

    print(f"=== Pathing comparison: {TRIALS} trials x {N_PLAYERS} players, "
          f"{VISIT_RANGE[0]}-{VISIT_RANGE[1]} visits/player, TAKE={TAKE} ===\n")
    hdr = f"{'Config':<48}{'AvgDeg':<8}{'AvgHops':<9}{'Diam':<6}{'Wasted%':<9}{'Fund@v3':<9}{'AvgCompl':<9}"
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        print(f"{r['label']:<48}{r['avg_degree']:<8.2f}{r['avg_hops']:<9.2f}{r['diameter']:<6}"
              f"{r['wasted_frac']*100:<9.1f}{r['fundamentals_by_v3']*100:<9.1f}{r['completions']:<9.2f}")

    print("\nWasted% = share of visits spent at a station that helped none of the\n"
          "player's active goals at the moment they arrived (lower = better direction).\n"
          "Fund@v3 = avg %% of the STARTING station's own 4 dice-elements the player\n"
          "already holds >=1 of by their 3rd visit (higher = fundamentals collected\n"
          "early, not just wherever the graph happened to push them).\n"
          "AvgCompl = avg distinct non-capstone items ever crafted per player session.")

if __name__ == "__main__":
    main()
