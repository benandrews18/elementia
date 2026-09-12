# -*- coding: utf-8 -*-
"""Full-session simulator for the CURRENT single-player Classic Mode.

Every other multi-goal script in this folder (simulate_kid.py,
simulate_mission.py, simulate_pathing.py, simulate_pathing_v2.py,
simulate_capstone_focus.py) models the OLD physical summer-camp version of
this game -- 13 groups of kids, TAKE=5, 12-15 visits, no permanent-unlock
economy assumptions baked in consistently. None of that matches today's
game: one player, TAKE=6, a 20-visit Classic Mode run, and a curated
79-item CORE_SET (not the full ~159-item catalog every other script here
draws from). This script is a from-scratch replacement for those, built
directly against real play-session exports (see CALIBRATION_NOTES.md in
this same folder) rather than adapted from the camp-era heuristics.

PLAYER MODEL -- "opportunistic", not single-goal:
  - Every visit: roll TAKE dice at the current station, rebalance surplus
    elements into shortfalls via 3-for-1 conversion (rebalance_elements()),
    then craft EVERY core item now possible here, repeating both until
    nothing more can happen (craft_all_possible()) -- this is what
    produces the real logs' bursty "0 items this turn, 6 items that turn"
    pattern for free, rather than needing it modeled explicitly.
  - No single fixed goal item. Station choice is scored by how many
    currently-blocked core items it would unlock plus a scarcity-weighted
    bonus for stations that are the only (or one of few) sources of a
    still-needed element (see score_station(), same scarcity-bonus shape
    HANDOFF.md's Bug A fix used) -- then picked with SOME randomness
    (GOAL_AWARE_CHANCE) rather than always taking the top score, since a
    real player doesn't compute this exhaustively either.
  - Helicopter (a real core item, The City) unlocks free-roam travel once
    crafted, matching canReachStation() in elementia.html.

KNOWN LIMITATION -- read before trusting these numbers for anything but
pacing/aggregate shape: **this cannot see a player's Bingo card.** Real
Classic Mode runs are steered by a hidden 5x5 grid of item goals that
materially changes which items a real player prioritizes and when --
that's very likely why the reference runs favor certain items over
similarly-reachable alternatives. This simulator has no equivalent signal
and doesn't try to fake one; it targets realistic AGGREGATE pacing (items
crafted per visit, score trajectory, how many capstones a 20-visit run
typically finishes, which stations get revisited how often) rather than
reproducing the exact item choices in either reference run.
"""
import random, statistics, sys
from collections import Counter, defaultdict
from model import STATIONS

TAKE = 6
DEFAULT_MAX_VISITS = 20
TRIALS = 500
GOAL_AWARE_CHANCE = 0.9  # see module docstring -- not a perfectly optimal player
START_STATION = "The Ocean"

# ------------------------------------------------------- core-set data ----
# Transcribed from CORE_SET in game/elementia.html -- the single source of
# truth for which (station, item) pairs actually exist in Classic Mode.
# Keep this in sync by hand if that list changes; there is no shared file
# to import it from (see that constant's own comment for why).
CORE_SET = {
    ("The Ocean", "Water"), ("The Ocean", "Limestone"), ("The Ocean", "Sand"),
    ("The Ocean", "Seaweed"), ("The Ocean", "Life"), ("The Ocean", "Banana"),
    ("The Ocean", "Cloud"), ("The Ocean", "Lighthouse"), ("The Ocean", "Orca"),
    ("The Ocean", "Speedboat"), ("The Ocean", "Coral Reef"),

    ("The Power Plant", "Battery"), ("The Power Plant", "Wire"), ("The Power Plant", "Clock"),
    ("The Power Plant", "Engine"), ("The Power Plant", "Light Bulb"),
    ("The Power Plant", "Plastic"), ("The Power Plant", "Car"),
    ("The Power Plant", "Computer"), ("The Power Plant", "Fiberglass"),
    ("The Power Plant", "Turbine Blade"), ("The Power Plant", "Robot"),

    ("Greenhouse", "Fertilizer"), ("Greenhouse", "Sugar"), ("Greenhouse", "DNA"),
    ("Greenhouse", "Soil"), ("Greenhouse", "Farm"), ("Greenhouse", "Chicken"),
    ("Greenhouse", "Apple"), ("Greenhouse", "Grain"), ("Greenhouse", "Solar Panel"),
    ("Greenhouse", "Bicycle"), ("Greenhouse", "Homestead"),

    ("Deep Mine", "Clay"), ("Deep Mine", "Natural Gas"), ("Deep Mine", "Steel"),
    ("Deep Mine", "Tools"), ("Deep Mine", "Furnace"), ("Deep Mine", "Aluminum Alloy"),
    ("Deep Mine", "Stainless Steel"), ("Deep Mine", "Diamond"),
    ("Deep Mine", "Tractor"), ("Deep Mine", "Rubber"), ("Deep Mine", "Maglev Train"),

    ("Old Growth Forest", "Clay"), ("Old Growth Forest", "Sand"), ("Old Growth Forest", "Bone"),
    ("Old Growth Forest", "Soil"), ("Old Growth Forest", "Salmon"), ("Old Growth Forest", "Tree"),
    ("Old Growth Forest", "Canoe"), ("Old Growth Forest", "Deer"), ("Old Growth Forest", "Log Cabin"),
    ("Old Growth Forest", "Fossil"), ("Old Growth Forest", "Ecosystem"),

    ("The Bakery", "Sugar"), ("The Bakery", "Water"), ("The Bakery", "Yeast"),
    ("The Bakery", "Egg"), ("The Bakery", "Flour"), ("The Bakery", "Dough"),
    ("The Bakery", "Oven"), ("The Bakery", "Apple Pie"), ("The Bakery", "Fish Cakes"),
    ("The Bakery", "Banana Bread"), ("The Bakery", "Fruit Cake"),

    ("The City", "Clay"), ("The City", "Limestone"), ("The City", "Steel"),
    ("The City", "Concrete"), ("The City", "Bridge"), ("The City", "Building"),
    ("The City", "Helicopter"), ("The City", "Museum"), ("The City", "Skyscraper"),
    ("The City", "Glass"), ("The City", "Metropolis"),

    ("The Observatory", "Microchip"), ("The Observatory", "Tools"), ("The Observatory", "Magnet"),
    ("The Observatory", "Compass"), ("The Observatory", "Satellite Dish"),
    ("The Observatory", "Telescope"), ("The Observatory", "Star"), ("The Observatory", "Rainbow"),
    ("The Observatory", "Rocket"), ("The Observatory", "Wheel"), ("The Observatory", "Space Station"),
}
CORE_ITEM_NAMES = {name for _, name in CORE_SET}

# Map graph -- transcribed from MAP_EDGES in game/elementia.html (NOT the
# same as simulate_reachability.py's CUSTOM_EDGES, which is missing the
# City<->Power Plant and Power Plant<->Deep Mine edges the live game
# actually has -- this one matches the real game exactly).
MAP_EDGES = [
    ("The Ocean", "Old Growth Forest"), ("The Ocean", "Deep Mine"), ("The Ocean", "The Observatory"),
    ("Old Growth Forest", "Deep Mine"), ("Old Growth Forest", "The Power Plant"), ("Old Growth Forest", "Greenhouse"),
    ("Greenhouse", "Deep Mine"), ("Greenhouse", "The Power Plant"), ("Greenhouse", "The City"), ("Greenhouse", "The Bakery"),
    ("The Bakery", "The Observatory"), ("The Bakery", "The City"), ("The Bakery", "The Power Plant"),
    ("The Observatory", "The City"),
    ("The City", "The Power Plant"), ("The Power Plant", "Deep Mine"),
]
MAP_ADJ = defaultdict(set)
for a, b in MAP_EDGES:
    MAP_ADJ[a].add(b); MAP_ADJ[b].add(a)

def edge_unlocked(a, b, visited):
    # The Ocean<->Observatory shortcut is locked until the player has
    # actually stood at The Observatory at least once via another route.
    if {a, b} == {"The Ocean", "The Observatory"}:
        return "The Observatory" in visited
    return True

def reachable_from(current, visited, has_helicopter):
    if has_helicopter:
        return [s["name"] for s in STATIONS if s["name"] != current]
    return [n for n in MAP_ADJ[current] if edge_unlocked(current, n, visited)]

# --------------------------------------------------------- recipe data ----
def parse_requirements(recipe_str, catalysts):
    req = Counter()
    for tok in recipe_str.split("+"):
        tok = tok.strip()
        is_cat = tok.endswith("*")
        tok = tok.replace("*", "").strip()
        import re
        if re.fullmatch(r"[A-Z][a-z]?", tok):
            nm = tok
        else:
            parts = tok.split(" ", 1)
            nm = parts[1] if len(parts) == 2 else tok
        req[nm] += 1
        if is_cat:
            catalysts.add(nm)
    return req

# CORE_RECIPES[item] -> list of (station, req, catalysts, tag), restricted
# to only the station(s) CORE_SET actually lists for that item -- a few
# items (Water, Limestone, Sugar, Soil, Steel, Tools, Clay) are core at
# more than one station, each with its own real recipe there.
CORE_RECIPES = defaultdict(list)
POINTS = {}
ELEMENTS = set()
STATION_DICE = {}
for s in STATIONS:
    STATION_DICE[s["name"]] = s["dice"]
    ELEMENTS |= set(s["dice"])
    all_items = list(s["shop"])
    ce, cn, ct, cr, cpts = s["capstone"]
    all_items.append((ce, cn, "CAPSTONE", cr, cpts))
    for emoji, name, tag, recipe, points in all_items:
        if (s["name"], name) not in CORE_SET:
            continue
        catalysts = set()
        req = parse_requirements(recipe, catalysts)
        CORE_RECIPES[name].append((s["name"], req, catalysts, tag))
        POINTS[name] = points

def home_stations(item):
    return [st for st, *_ in CORE_RECIPES.get(item, [])]

def req_at(item, station):
    for st, req, catalysts, tag in CORE_RECIPES.get(item, []):
        if st == station:
            return req, catalysts
    return None, None

def is_capstone(item):
    return any(tag == "CAPSTONE" for _, _, _, tag in CORE_RECIPES.get(item, []))

ELEM_STATIONS = defaultdict(list)
for s in STATIONS:
    for e in set(s["dice"]):
        ELEM_STATIONS[e].append(s["name"])

# ------------------------------------------------------- player actions ----
def craft_all_possible(station, inv, crafted):
    """Craft everything now possible AT `station`, repeating until nothing
    more can happen this visit -- produces the real logs' own bursty
    "several items in one visit" pattern rather than one-per-visit."""
    progressed = True
    while progressed:
        progressed = False
        for item, homes in list(CORE_RECIPES.items()):
            if crafted.get(item, 0) > 0:
                continue
            if station not in [st for st, *_ in homes]:
                continue
            req, catalysts = req_at(item, station)
            if all(inv.get(ing, 0) >= qty for ing, qty in req.items()):
                for ing, qty in req.items():
                    if ing in catalysts:
                        continue
                    if ing in ELEMENTS:
                        inv[ing] -= qty
                inv[item] = inv.get(item, 0) + 1
                crafted[item] = crafted.get(item, 0) + 1
                progressed = True

def remaining_element_needs(inv, crafted):
    """Element demand from the FRONTIER only -- not-yet-crafted items whose
    every ITEM ingredient is already owned, so raw elements are the only
    thing standing between the player and actually finishing them. A real
    player thinks "I have the pieces, I just need N more of this element,"
    not "here's the total element cost of my entire remaining tech tree" --
    the latter (an earlier version of this function) diluted conversion
    priority across dozens of items still several crafts away and made the
    simulated player visibly worse at finishing things than the two real
    reference runs."""
    needs = Counter()
    for item, homes in CORE_RECIPES.items():
        if crafted.get(item, 0) > 0:
            continue
        for station, req, catalysts, tag in homes:
            item_ings_ready = all(crafted.get(ing, 0) > 0
                                   for ing, qty in req.items()
                                   if ing not in ELEMENTS and ing not in catalysts)
            if not item_ings_ready:
                continue
            for ing, qty in req.items():
                if ing in catalysts or ing not in ELEMENTS:
                    continue
                needs[ing] = max(needs[ing], qty)
    return needs

def rebalance_elements(inv, remaining):
    """3-for-1 convert surplus elements (held beyond any outstanding need)
    into whichever still-short element is currently needed most -- the
    "don't sit on 12 of one element while starving for another" behavior."""
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

def score_station(station, inv, crafted):
    """How worth visiting `station` looks right now: +3 per not-yet-owned
    core item it can finish outright with current inventory, +1 per item
    it makes PROGRESS toward (holds every element ingredient already, just
    missing an item ingredient not yet built), plus a scarcity-weighted
    bonus per still-needed element only available there (1 source = 8,
    2 sources = 3, 3+ = 1) -- same scarcity-bonus shape as HANDOFF.md's
    Bug A fix, since ignoring it makes exclusive-source stations look
    permanently skippable in favor of "does a lot of stuff" stations."""
    score = 0
    for item, homes in CORE_RECIPES.items():
        if crafted.get(item, 0) > 0:
            continue
        for st, req, catalysts, tag in homes:
            if st != station:
                continue
            missing_items = [ing for ing, qty in req.items()
                              if ing not in ELEMENTS and ing not in catalysts and inv.get(ing, 0) < qty]
            missing_elems = [ing for ing, qty in req.items() if ing in ELEMENTS and inv.get(ing, 0) < qty]
            if not missing_items and not missing_elems:
                score += 3
            elif not missing_elems:
                score += 1
    remaining = remaining_element_needs(inv, crafted)
    for elem, need in remaining.items():
        if need - inv.get(elem, 0) <= 0:
            continue
        sources = ELEM_STATIONS[elem]
        if station not in sources:
            continue
        score += 8 if len(sources) == 1 else (3 if len(sources) == 2 else 1)
    return score

def choose_next_station(rng, inv, crafted, candidates):
    if not candidates:
        return None
    if rng.random() >= GOAL_AWARE_CHANCE:
        return rng.choice(candidates)
    scored = {c: score_station(c, inv, crafted) for c in candidates}
    best = max(scored.values())
    if best == 0:
        return rng.choice(candidates)
    return rng.choice([s for s, v in scored.items() if v == best])

# ------------------------------------------------------------- one run ----
def run_session(rng, max_visits=DEFAULT_MAX_VISITS):
    inv, crafted = Counter(), Counter()
    visited = set()
    current = START_STATION
    log = []
    for v in range(1, max_visits + 1):
        visited.add(current)
        for _ in range(TAKE):
            inv[rng.choice(STATION_DICE[current])] += 1
        remaining = remaining_element_needs(inv, crafted)
        rebalance_elements(inv, remaining)
        before = set(k for k in crafted if crafted[k] > 0)
        craft_all_possible(current, inv, crafted)
        after = set(k for k in crafted if crafted[k] > 0)
        log.append({"station": current, "items": sorted(after - before)})
        has_heli = crafted.get("Helicopter", 0) > 0
        candidates = reachable_from(current, visited, has_heli)
        nxt = choose_next_station(rng, inv, crafted, candidates)
        if nxt is None:
            break
        current = nxt
    score = sum(POINTS.get(name, 0) for name in crafted if crafted[name] > 0)
    capstones = sorted(name for name in crafted if crafted[name] > 0 and is_capstone(name))
    return {"score": score, "capstones": capstones, "log": log,
            "items_crafted": sum(len(t["items"]) for t in log)}

# --------------------------------------------------------------- driver ----
def main():
    rng = random.Random(2026)
    scores, capstone_counts, items_per_visit, station_visits = [], [], [], Counter()
    for _ in range(TRIALS):
        r = run_session(rng)
        scores.append(r["score"])
        capstone_counts.append(len(r["capstones"]))
        for turn in r["log"]:
            items_per_visit.append(len(turn["items"]))
            station_visits[turn["station"]] += 1

    print(f"=== {TRIALS} simulated {DEFAULT_MAX_VISITS}-visit Classic Mode runs ===")
    print(f"Score: mean {statistics.mean(scores):.0f}, median {statistics.median(scores):.0f}, "
          f"stdev {statistics.stdev(scores):.0f}, range {min(scores)}-{max(scores)}")
    print(f"Items crafted per visit: mean {statistics.mean(items_per_visit):.2f}, "
          f"visits with 0 items: {items_per_visit.count(0) / len(items_per_visit):.0%}")
    print(f"Capstones finished per run: mean {statistics.mean(capstone_counts):.2f}, "
          f"distribution {dict(sorted(Counter(capstone_counts).items()))}")
    print("Station visit share:")
    total_visits = sum(station_visits.values())
    for st, n in station_visits.most_common():
        print(f"  {st}: {n / total_visits:.0%}")

    print("\n--- reference runs (real play, provided by the user; see CALIBRATION_NOTES.md) ---")
    print("Run A: score 409, 20 visits, 1 capstone, ~2.8 items/visit")
    print("Run B: score 313, 20 visits, 2 capstones, ~2.25 items/visit")
    print("Run C: score 346, 20 visits, 1 capstone, ~2.6 items/visit")
    print("Run D: score 369, 20 visits, 2 capstones, ~2.2 items/visit")
    print("Run E: score 366, 20 visits, 1 capstone, ~2.25 items/visit")
    print("Run F: score 299, 20 visits, 3 capstones, ~1.95 items/visit")
    print("Combined mean: score 350, 1.67 capstones/run, 2.34 items/visit -- see")
    print("CALIBRATION_NOTES.md's capstone-rate writeup: sim tops out ~1.0/run even")
    print("at GOAL_AWARE_CHANCE=1.0, a real gap this constant alone can't close.")

    print("\n--- one example simulated run, full log ---")
    example = run_session(random.Random(7))
    for i, turn in enumerate(example["log"], 1):
        items = ", ".join(turn["items"]) if turn["items"] else "-"
        print(f"{i:2}. {turn['station']:<20} {items}")
    print(f"Final score: {example['score']}, capstones: {example['capstones'] or 'none'}")

if __name__ == "__main__":
    main()
