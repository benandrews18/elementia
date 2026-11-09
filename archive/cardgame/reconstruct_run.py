# -*- coding: utf-8 -*-
"""
Reconstruct the element pool behind a recorded 20-round run.

Input is a log of (round, station visited, items crafted). From that this
works backwards to the element pool the player must have been holding at
the start of each round -- which is exactly the mana pool the card game
needs handed to it (see cardgame/README.md, "The loop").

What an item costs to craft, in elements:

  * the elements NAMED in its recipe (item ingredients are not spent --
    once built, a card keeps working as an ingredient forever), plus
  * its SUIT COST: the pips in `classic set suits 0904.csv`, each payable
    with any element of that suit. Only items worth 5+ points carry one;
    the 25 items at 4 or under are free. That split is exact -- every
    pip-less item is <=4 points and every pip-bearing item is >=5.

Each station visit rolls TAKE (6) dice, each landing on one of that
station's own six elements, so a round's income is 6 tokens drawn from a
known pool. The reconstruction picks the most favourable legal roll each
round -- the dice a player would need to have got -- and reports any
round where even the best roll falls short. Those shortfalls are the
interesting output: they are rounds that can only be explained by the
3-for-1 element conversion, or by a stock the log does not show.

Usage:  python cardgame/reconstruct_run.py            (markdown table)
        python cardgame/reconstruct_run.py --terse    (one line per round)
"""
import ast
import csv
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
GUIDE = ROOT / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
PIPS_CSV = HERE / "classic set suits 0904.csv"

EL_RE = re.compile(r"^[A-Z][a-z]?$")
CONVERT_RATE = 3          # 3 of one element -> 1 of any other
SUIT_OF = {
    "C": "organic", "H": "organic", "N": "organic", "O": "organic",
    "S": "reactive", "K": "reactive", "Ca": "reactive", "P": "reactive",
    "Si": "earth", "Al": "earth", "Mg": "earth", "Ni": "earth",
    "Fe": "metal", "Ti": "metal", "Cu": "metal", "Ag": "metal",
}

# (round, station, [items crafted that round])
RUN = [
    (1,  "Deep Mine",         []),
    (2,  "The Ocean",         ["Sand"]),
    (3,  "Old Growth Forest", ["Clay", "Soil", "Tree"]),
    (4,  "The Ocean",         ["Water"]),
    (5,  "Deep Mine",         ["Natural Gas", "Steel", "Tools"]),
    (6,  "The Power Plant",   ["Engine", "Wire"]),
    (7,  "The City",          ["Limestone", "Glass", "Concrete", "Bridge", "Building"]),
    (8,  "The Observatory",   ["Magnet", "Compass", "Microchip", "Wheel"]),
    (9,  "The Bakery",        []),
    (10, "The Power Plant",   ["Battery", "Clock", "Light Bulb"]),
    (11, "Deep Mine",         ["Furnace", "Aluminum Alloy", "Titanium Alloy", "Rubber",
                               "Stainless Steel", "Maglev Train"]),
    (12, "Greenhouse",        ["Sugar", "DNA", "Apple", "Farm", "Tractor"]),
    (13, "The Power Plant",   ["Plastic", "Fiberglass", "Computer", "Turbine Blade",
                               "Car", "Robot"]),
    (14, "Greenhouse",        ["Fertilizer", "Grain", "Solar Panel"]),
    (15, "The Bakery",        ["Yeast", "Egg", "Flour", "Dough", "Oven", "Bread", "Cake"]),
    (16, "The Observatory",   ["Satellite Dish", "Telescope", "Star", "Rocket", "Space Station"]),
    (17, "The City",          ["Helicopter"]),
    (18, "Old Growth Forest", ["Bone", "Canoe", "Deer", "Log Cabin", "Fossil"]),
    (19, "The Ocean",         ["Seaweed", "Cloud", "Banana", "Lighthouse", "Life", "Speedboat"]),
    (20, "The City",          ["Skyscraper", "Museum", "Metropolis"]),
]


# ------------------------------------------------------------------ data

def load_guide():
    tree = ast.parse(GUIDE.read_text(encoding="utf-8"))
    out = {}
    for n in tree.body:
        if isinstance(n, ast.Assign):
            for t in n.targets:
                if isinstance(t, ast.Name) and t.id in ("STATIONS", "TAKE"):
                    out[t.id] = ast.literal_eval(n.value)
    return out["STATIONS"], out["TAKE"]


def load_pips():
    fix = {"oragnic": "organic"}
    out = {}
    with PIPS_CSV.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.reader(f):
            if len(row) < 2 or not row[0].strip():
                continue
            name, raw = row[0].strip(), row[1].strip()
            if not raw or raw.startswith("-"):
                out[name] = []
                continue
            out[name] = [fix.get(p.strip().lower().split(" - ")[0].strip(),
                                 p.strip().lower().split(" - ")[0].strip())
                         for p in raw.split("+")]
    return out


def build_items(stations, pips):
    items = {}
    for s in stations:
        for emoji, name, tier, recipe, points in list(s["shop"]) + [s["capstone"]]:
            if name in items:
                continue
            els, ings = Counter(), []
            for tok in recipe.split("+"):
                tok = tok.strip().replace("*", "")
                if EL_RE.match(tok):
                    els[tok] += 1
                else:
                    ings.append(tok.split(" ", 1)[1].strip() if " " in tok else tok)
            items[name] = {"elements": els, "ingredients": ings, "points": points,
                           "pips": Counter(pips.get(name, [])), "tier": tier}
    return items


# --------------------------------------------------------- reconstruction

def pay(inv, need_els, need_suits, scarcity):
    """Spend from inv. Returns (spent, missing_elements, missing_suits).

    Named elements come first and are inflexible. Suit pips are then paid
    with whatever of that suit is left, spending the most plentiful first
    so that genuinely scarce tokens (Ti, Cu, K) survive for recipes that
    name them outright.
    """
    spent, missing = Counter(), Counter()
    for e, n in need_els.items():
        take = min(n, inv[e])
        inv[e] -= take
        spent[e] += take
        if take < n:
            missing[e] += n - take
    missing_suits = Counter()
    for suit, n in need_suits.items():
        for _ in range(n):
            cands = [e for e in inv if inv[e] > 0 and SUIT_OF[e] == suit]
            if not cands:
                missing_suits[suit] += 1
                continue
            # most plentiful, then least scarce across the map
            e = max(cands, key=lambda x: (inv[x], scarcity[x]))
            inv[e] -= 1
            spent[e] += 1
    return spent, missing, missing_suits


def assign_dice(RUN, items, dice, take, scarcity):
    """Work out which die, in which round, paid for what.

    This is a scheduling problem, not a per-round one: a die rolled in
    round r can pay for anything from round r onwards, never earlier. So
    every round contributes `take` slots, each able to produce any of its
    station's six elements, and every craft contributes demands pinned to
    the round it happened in.

    Demands are matched in chronological order, each taking the LATEST
    feasible slot at or before its own round. Latest-first matters:
    early rounds have the fewest slots to draw on, so leaving them free
    for the demands that can only reach them is what keeps the assignment
    from failing artificially. Anything left unmatched is a real shortfall
    -- the dice genuinely could not have covered it.
    """
    slots = []                       # one entry per die, in round order
    for i, (_, station, _) in enumerate(RUN):
        for _ in range(take):
            slots.append({"round": i, "pool": dice[station], "element": None})

    demands = []                     # (round index, kind, what)
    for i, (_, _, crafts) in enumerate(RUN):
        for c in crafts:
            it = items.get(c)
            if not it:
                continue
            for e, n in it["elements"].items():
                for _ in range(n):
                    demands.append((i, "element", e, c))
            for s, n in it["pips"].items():
                for _ in range(n):
                    demands.append((i, "suit", s, c))
    # Named elements before suit costs within the same round: a named
    # element has exactly one way to be paid, a suit pip has four.
    demands.sort(key=lambda d: (d[0], d[1] != "element"))

    unmet = []
    for rnd, kind, what, item in demands:
        pick = None
        for s in range(len(slots) - 1, -1, -1):
            sl = slots[s]
            if sl["element"] is not None or sl["round"] > rnd:
                continue
            if kind == "element":
                if what in sl["pool"]:
                    pick = (s, what)
                    break
            else:
                cands = [e for e in sl["pool"] if SUIT_OF[e] == what]
                if cands:
                    # spend the least scarce element of that suit
                    pick = (s, max(cands, key=lambda e: scarcity[e]))
                    break
        if pick:
            slots[pick[0]]["element"] = pick[1]
            slots[pick[0]]["spent_on"] = (rnd, item)
        else:
            unmet.append((rnd, kind, what, item))

    # Idle dice still landed on something. Spread them round-robin across
    # their station's six faces rather than piling every spare die on one
    # element -- six dice are six dice, and a reconstructed roll of "Fe x5"
    # is not a roll anyone actually made.
    by_round = {}
    for i, sl in enumerate(slots):
        if sl["element"] is None:
            by_round.setdefault(sl["round"], []).append(i)
    for rnd, idxs in by_round.items():
        pool = slots[idxs[0]]["pool"]
        # start the cycle past whatever the assigned dice already took, so
        # the spare faces fill in the gaps instead of doubling up
        taken = Counter(s["element"] for s in slots
                        if s["round"] == rnd and s["element"] is not None)
        order = sorted(pool, key=lambda e: (taken[e], -scarcity[e]))
        for k, i in enumerate(idxs):
            slots[i]["element"] = order[k % len(order)]
            slots[i]["idle"] = True
    return slots, unmet


def reconstruct():
    stations, take = load_guide()
    pips = load_pips()
    items = build_items(stations, pips)
    dice = {s["name"]: s["dice"] for s in stations}
    scarcity = Counter()
    for s in stations:
        for d in s["dice"]:
            scarcity[d] += 1

    slots, unmet = assign_dice(RUN, items, dice, take, scarcity)

    rolls = [Counter() for _ in RUN]
    idle = [0] * len(RUN)
    for sl in slots:
        rolls[sl["round"]][sl["element"]] += 1
        if sl.get("idle"):
            idle[sl["round"]] += 1

    unmet_by_round = {}
    for rnd, kind, what, item in unmet:
        unmet_by_round.setdefault(rnd, []).append((kind, what, item))

    inv = Counter()
    owned = set()
    rows = []
    for idx, (rnd, station, crafts) in enumerate(RUN):
        carried = Counter(inv)
        need_els, need_suits = Counter(), Counter()
        unknown, premature = [], []
        for c in crafts:
            it = items.get(c)
            if not it:
                unknown.append(c)
                continue
            need_els += it["elements"]
            need_suits += it["pips"]
            for ing in it["ingredients"]:
                if ing not in owned and ing not in crafts:
                    premature.append((c, ing))

        roll = rolls[idx]
        available = Counter(inv) + roll
        inv = Counter(available)
        spent, miss_e, miss_s = pay(inv, need_els, need_suits, scarcity)
        owned.update(crafts)
        rows.append({
            "round": rnd, "station": station, "crafts": crafts,
            "carried": carried, "roll": roll, "available": available,
            "spent": spent, "left": Counter({k: v for k, v in inv.items() if v > 0}),
            "missing_els": miss_e, "missing_suits": miss_s,
            "unmet": unmet_by_round.get(idx, []), "idle": idle[idx],
            "unknown": unknown, "premature": premature,
            "points": sum(items[c]["points"] for c in crafts if c in items),
        })
    return rows, items, len(unmet)


def uniform_shortfall(RUN, items, dice, scarcity):
    """The same run, but with average dice instead of best-case ones.

    Every visit is assumed to land exactly one of each of the station's six
    faces -- the expected roll. Comparing this against the optimiser's
    answer brackets how much of the run was skill/planning and how much was
    luck: the optimiser says what the dice COULD have delivered, this says
    what they would deliver on average.
    """
    slots = []
    for i, (_, station, _) in enumerate(RUN):
        for e in dice[station]:
            slots.append({"round": i, "element": e, "used": False})
    demands = []
    for i, (_, _, crafts) in enumerate(RUN):
        for c in crafts:
            it = items.get(c)
            if not it:
                continue
            for e, n in it["elements"].items():
                demands += [(i, "element", e)] * n
            for s, n in it["pips"].items():
                demands += [(i, "suit", s)] * n
    demands.sort(key=lambda d: (d[0], d[1] != "element"))

    unmet = 0
    for rnd, kind, what in demands:
        hit = None
        for s in range(len(slots) - 1, -1, -1):
            sl = slots[s]
            if sl["used"] or sl["round"] > rnd:
                continue
            if (kind == "element" and sl["element"] == what) or                (kind == "suit" and SUIT_OF[sl["element"]] == what):
                hit = s
                break
        if hit is None:
            unmet += 1
        else:
            slots[hit]["used"] = True
    return unmet


ORDER = ["C", "H", "N", "O", "S", "K", "Ca", "P", "Si", "Al", "Mg", "Ni", "Fe", "Ti", "Cu", "Ag"]
fmt = lambda c: " ".join(f"{e}{c[e]}" for e in ORDER if c.get(e)) or "—"


def emit_js(rows):
    """Write cardgame/run.js so the card game can be played as this run.

    Per round: the station visited, the items crafted, and three views of
    the element pool. `pool` (what you were holding once that round's dice
    were in) is what the card game uses as its mana store -- see
    RUN_POOL_FIELD in cards.js if you would rather it were `carried`, the
    pool as the round opened, before rolling.
    """
    out = [
        "/* GENERATED by cardgame/reconstruct_run.py --emit-js -- do not edit.",
        "   The recorded 20-round run, reconstructed. `pool` is the element",
        "   store for that round's card game; `crafted` are the cards that",
        "   entered the deck that round. */",
        "const RECORDED_RUN = [",
    ]
    for r in rows:
        d = lambda c: "{" + ", ".join(f'"{k}": {v}' for k, v in sorted(c.items()) if v) + "}"
        out.append(
            f'  {{ round: {r["round"]}, station: {json_str(r["station"])},'
            f' crafted: [{", ".join(json_str(c) for c in r["crafts"])}],'
            f' pool: {d(r["available"])}, carried: {d(r["carried"])},'
            f' rolled: {d(r["roll"])}, points: {r["points"]} }},'
        )
    out.append("];")
    path = HERE / "run.js"
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"wrote {path.name}: {len(rows)} rounds, "
          f"{sum(len(r['crafts']) for r in rows)} cards, "
          f"pools {min(sum(r['available'].values()) for r in rows)}-"
          f"{max(sum(r['available'].values()) for r in rows)} tokens")


def json_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    # Windows consoles default to cp1252 and would mangle the em dashes.
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    rows, items, conversions = reconstruct()
    if "--emit-js" in sys.argv:
        emit_js(rows)
        return
    terse = "--terse" in sys.argv

    if terse:
        for r in rows:
            print(f"{r['round']:2}  {r['station']:18} carried {fmt(r['carried']):40} "
                  f"roll {fmt(r['roll']):22} left {fmt(r['left'])}")
        return

    print("# Reconstructed element pool, 20-round run\n")
    print("`carried in` is what you were holding when the round began, before")
    print("rolling. `rolled` is the 6 dice at that station. `spent` covers both")
    print("named recipe elements and suit costs.\n")
    print("| # | Station | Carried in | Rolled (6) | Spent | Carried out | Pts |")
    print("|---|---|---|---|---|---|---|")
    for r in rows:
        print(f"| {r['round']} | {r['station']} | `{fmt(r['carried'])}` | "
              f"`{fmt(r['roll'])}` | `{fmt(r['spent'])}` | `{fmt(r['left'])}` | {r['points']} |")

    print("\n## What the dice cannot cover\n")
    any_gap = False
    for r in rows:
        if r["unmet"]:
            any_gap = True
            named = [w for k, w, _ in r["unmet"] if k == "element"]
            suit = [w for k, w, _ in r["unmet"] if k == "suit"]
            items_hit = sorted({i for _, _, i in r["unmet"]})
            bits = []
            if named:
                bits.append("named " + ", ".join(f"{n}x {e}" for e, n in Counter(named).items()))
            if suit:
                bits.append("suit cost " + ", ".join(f"{n}x {s}" for s, n in Counter(suit).items()))
            print(f"- **Round {r['round']} ({r['station']})** — {'; '.join(bits)}"
                  f"  (for {', '.join(items_hit)})")
    if not any_gap:
        print("Nothing — every craft in the run is payable from the dice alone.")

    print(f"\n**{conversions}** tokens in the whole run cannot come from dice. At the "
          f"{CONVERT_RATE}:1 conversion rate that is {conversions * CONVERT_RATE} spare "
          f"tokens burned to cover them.\n")

    bad = [(r["round"], r["premature"]) for r in rows if r["premature"]]
    if bad:
        print("## Ingredient-order problems\n")
        for rnd, pl in bad:
            for c, ing in pl:
                print(f"- Round {rnd}: `{c}` needs `{ing}`, not crafted yet")
    unknown = [(r["round"], r["unknown"]) for r in rows if r["unknown"]]
    if unknown:
        print("\n## Unrecognised item names\n")
        for rnd, u in unknown:
            print(f"- Round {rnd}: {', '.join(u)}")

    peak = max(sum(r["available"].values()) for r in rows)
    end = sum(rows[-1]["left"].values())
    print(f"\n## Summary\n")
    # `items` spans every station's full shop, not just the Classic set the
    # card deck is built from, so quote the deck size rather than len(items).
    print(f"- Items crafted: **{sum(len(r['crafts']) for r in rows)}** of the 79 Classic items")
    print(f"- Points: **{sum(r['points'] for r in rows)}**")
    print(f"- Largest pool held at once: **{peak}** tokens")
    print(f"- Left over at the end: **{end}** tokens")
    avg = sum(sum(r["carried"].values()) for r in rows) / len(rows)
    print(f"- Mean pool carried into a round: **{avg:.1f}** tokens")

    stations, take = load_guide()
    dice = {s["name"]: s["dice"] for s in stations}
    scar = Counter()
    for s in stations:
        for d in s["dice"]:
            scar[d] += 1
    uni = uniform_shortfall(RUN, items, dice, scar)
    print("\n### How lucky was this run?\n")
    print("The table above is the **best case**: the dice arranged as favourably as")
    print(f"the stations allow, leaving **{conversions}** tokens uncoverable.")
    print("With **average dice** — one of each of a station's six faces per visit —")
    print(f"the same run comes up **{uni}** tokens short instead.")
    print(f"\nSo between {conversions} and {uni} tokens had to come from conversions or")
    print("from luckier-than-average rolls. The real run sits somewhere in that band.")


if __name__ == "__main__":
    main()
