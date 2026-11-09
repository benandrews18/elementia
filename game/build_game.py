# -*- coding: utf-8 -*-
"""
Regenerate the playable game's embedded data from build_guide.py.

build_guide.py stays the single source of truth (per HANDOFF.md §2). This
script does NOT re-render the whole page -- it surgically swaps the JSON
between the __GAME_DATA_START__ / __GAME_DATA_END__ markers in
js/data.js (and simulate.html), so everything else is edited in place.

Usage:  python game/build_game.py
Then:   python game/build_game.py --check     (verify only, no write)

Note this reads build_guide.py with ast.literal_eval rather than importing
it -- importing has a module-level side effect that writes guide.html to a
hardcoded /home/claude/ path, which fails off-Linux.
"""
import ast, csv, json, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GUIDE = HERE.parent / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
REACHABILITY_CSV = HERE.parent / "Elementia_Handoff" / "handoff" / "simulation" / "reachability_grid.csv"
TARGETS = [HERE / "js" / "data.js", HERE / "simulate.html"]

START, END = "/*__GAME_DATA_START__*/", "/*__GAME_DATA_END__*/"


def literals_from(path, names):
    """Pull top-level literal assignments out of a module without importing it."""
    tree = ast.parse(path.read_text(encoding="utf-8"))
    found = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id in names:
                    found[t.id] = ast.literal_eval(node.value)
    missing = set(names) - set(found)
    if missing:
        raise SystemExit(f"Could not find {sorted(missing)} in {path}")
    return found


def avg_visits_from(csv_path, item_names):
    """Read AvgVisits per item from the reachability simulation output.

    Fails loudly rather than silently if the CSV is missing or doesn't
    cover every item in STATIONS -- this feeds a gameplay-visible reveal
    threshold, so stale/partial data must never pass silently.
    """
    if not csv_path.exists():
        raise SystemExit(
            f"{csv_path} not found -- run simulate_reachability.py then "
            f"analyze_bottlenecks.py in Elementia_Handoff/handoff/simulation/ first."
        )
    with csv_path.open(encoding="utf-8") as f:
        rows = {r["Item"]: r for r in csv.DictReader(f)}
    missing = item_names - set(rows)
    if missing:
        raise SystemExit(
            f"reachability_grid.csv is stale relative to build_guide.py -- "
            f"missing items: {sorted(missing)}. Re-run the simulation."
        )
    avg_visits = {}
    for name in item_names:
        # Items unreachable from every station in the simulation (currently
        # just Brass/Trombone/Cruise Ship, whose closure runs through Zn --
        # an element that only exists at the Island sub-zone, invisible to
        # this Python pipeline by design, see SUBZONES's own comment in
        # elementia.html) never get an AvgVisits column written at all.
        # None here matches how the game already treats missing avgVisits
        # data everywhere it's read (tierThresholds() etc. fall back to a
        # default rather than crashing).
        val = rows[name].get("AvgVisits")
        if val is None or val == "":
            avg_visits[name] = None
            continue
        try:
            avg_visits[name] = float(val)
        except ValueError:
            raise SystemExit(f"reachability_grid.csv: non-numeric AvgVisits for '{name}': {val!r}")
    return avg_visits


def main():
    check_only = "--check" in sys.argv
    src = literals_from(GUIDE, {"STATIONS", "SUITS", "TAKE", "CONTENT_VERSION"})
    item_names = set()
    for s in src["STATIONS"]:
        for _, name, *_ in s["shop"]:
            item_names.add(name)
        item_names.add(s["capstone"][1])
    avg_visits = avg_visits_from(REACHABILITY_CSV, item_names)
    data = {
        "take": src["TAKE"], "version": src["CONTENT_VERSION"],
        "suits": src["SUITS"], "stations": src["STATIONS"],
        "avgVisits": avg_visits,
    }
    payload = json.dumps(data, ensure_ascii=False, indent=1)

    stale = []
    for target in TARGETS:
        html = target.read_text(encoding="utf-8")
        a, b = html.find(START), html.find(END)
        if a < 0 or b < 0:
            raise SystemExit(f"Markers not found in {target}")

        if json.loads(html[a + len(START):b]) == data:
            print(f"{target.name}: in sync")
            continue
        stale.append(target.name)
        if check_only:
            continue
        target.write_text(html[:a + len(START)] + payload + html[b:], encoding="utf-8")
        print(f"{target.name}: updated to {len(data['stations'])} stations")

    if check_only and stale:
        raise SystemExit("OUT OF SYNC with build_guide.py: " + ", ".join(stale))


if __name__ == "__main__":
    main()
