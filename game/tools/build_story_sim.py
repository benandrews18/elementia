# -*- coding: utf-8 -*-
"""
Regenerate the Story Mode simulator's embedded data from build_guide.py.

Same pattern as game/build_game.py: build_guide.py stays the single source
of truth, this script only swaps the JSON between the
__STORY_DATA_START__ / __STORY_DATA_END__ markers in story_sim.html.

Usage:  python game/tools/build_story_sim.py
Then:   python game/tools/build_story_sim.py --check     (verify only)
"""
import ast, csv, json, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GUIDE = HERE.parent.parent / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
REACHABILITY_CSV = HERE.parent.parent / "Elementia_Handoff" / "handoff" / "simulation" / "reachability_grid.csv"
TARGET = HERE / "story_sim.html"

START, END = "/*__STORY_DATA_START__*/", "/*__STORY_DATA_END__*/"


def literals_from(path, names):
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
    out = {}
    for name in item_names:
        try:
            out[name] = float(rows[name]["AvgVisits"])
        except ValueError:
            raise SystemExit(f"reachability_grid.csv: non-numeric AvgVisits for '{name}': {rows[name]['AvgVisits']!r}")
    return out


def main():
    check_only = "--check" in sys.argv
    src = literals_from(GUIDE, {"STATIONS", "SUITS", "CONTENT_VERSION"})
    item_names = set()
    for s in src["STATIONS"]:
        for _, name, *_ in s["shop"]:
            item_names.add(name)
        item_names.add(s["capstone"][1])
    avg_visits = avg_visits_from(REACHABILITY_CSV, item_names)

    data = {
        "version": src["CONTENT_VERSION"],
        "suits": src["SUITS"],
        "stations": src["STATIONS"],
        "avgVisits": avg_visits,
    }
    payload = json.dumps(data, ensure_ascii=False, indent=1)

    html = TARGET.read_text(encoding="utf-8")
    a, b = html.find(START), html.find(END)
    if a < 0 or b < 0:
        raise SystemExit(f"Markers not found in {TARGET}")

    if json.loads(html[a + len(START):b]) == data:
        print(f"{TARGET.name}: in sync")
        return

    if check_only:
        raise SystemExit(f"OUT OF SYNC with build_guide.py: {TARGET.name}")

    TARGET.write_text(html[:a + len(START)] + payload + html[b:], encoding="utf-8")
    print(f"{TARGET.name}: updated to {len(data['stations'])} stations, {len(item_names)} items")


if __name__ == "__main__":
    main()
