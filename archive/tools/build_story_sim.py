# -*- coding: utf-8 -*-
"""
Regenerate the Story Mode simulator's embedded data from build_guide.py.

Same pattern as game/build_game.py: build_guide.py stays the single source
of truth, this script only swaps the JSON between the
__STORY_DATA_START__ / __STORY_DATA_END__ markers in story_sim.html.

Usage:  python game/tools/build_story_sim.py
Then:   python game/tools/build_story_sim.py --check     (verify only)
"""
import ast, csv, json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GUIDE = HERE.parent.parent / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
REACHABILITY_CSV = HERE.parent.parent / "Elementia_Handoff" / "handoff" / "simulation" / "reachability_grid.csv"
TARGET = HERE / "story_sim.html"
ELEMENTIA_HTML = HERE.parent / "elementia.html"

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
    out = {}
    for name in item_names:
        # Sub-zone items (see subzone_stations() below) are never simulated
        # at all -- Zn-dependent items (Brass etc.) aren't even reachable
        # in that model -- so a missing row, or a row with no AvgVisits
        # column (build_game.py hits the same case for Brass/Trombone/
        # Cruise Ship), both just mean "no data," not a build error.
        row = rows.get(name)
        val = row.get("AvgVisits") if row else None
        if val is None or val == "":
            out[name] = None
            continue
        try:
            out[name] = float(val)
        except ValueError:
            raise SystemExit(f"reachability_grid.csv: non-numeric AvgVisits for '{name}': {val!r}")
    return out


def subzone_stations():
    """SUBZONES lives hand-written in elementia.html, not build_guide.py --
    see its own comment there for why (not on the map, never simulated).
    Reformatted here into the same {emoji,name,suit,dice,shop,capstone}
    shape as a real STATIONS entry, purely so story_sim.html's existing
    "iterate DATA.stations" graph-building code picks these up for free
    with no JS changes -- these are graph nodes with zero AvgVisits data,
    same treatment avg_visits_from() already gives Brass/Trombone/Cruise
    Ship above."""
    import sys
    sys.path.insert(0, str(HERE.parent))
    from game_source import read_game_source
    html = read_game_source()
    start = html.find("const SUBZONES = [")
    end = html.find("SUBZONES.forEach(sz =>")
    if start < 0 or end < 0:
        return []  # sub-zones were removed with Adventure mode (2026-11-05)
    block = html[start:end]

    entry_re = re.compile(
        r'\{id:"([^"]+)"(?:,\s*emoji:"([^"]*)")?,\s*suit:"([^"]+)",\s*dice:(\[[^\]]*\]),\s*shop:\[(.*?)\](?:,\s*capstone:(\[[^\]]*\]))?\}',
        re.S,
    )
    row_re = re.compile(r'\[("(?:[^"\\]|\\.)*"(?:,"(?:[^"\\]|\\.)*"){3},\d+)\]')

    stations = []
    for m in entry_re.finditer(block):
        sz_id, emoji, suit, dice_src, shop_src, capstone_src = m.groups()
        dice = ast.literal_eval(dice_src)
        shop = [ast.literal_eval(f"[{row}]") for row in row_re.findall(shop_src)]
        # Most sub-zones (every planet, Island) have no capstone at all --
        # capstone stays None rather than a fake placeholder tuple, see
        # story_sim.html's own null check for st.capstone.
        capstone = ast.literal_eval(capstone_src) if capstone_src else None
        stations.append({
            "emoji": emoji or "\U0001F30C", "name": sz_id, "suit": suit,
            "dice": dice, "shop": shop, "capstone": capstone,
        })
    return stations


def main():
    check_only = "--check" in sys.argv
    src = literals_from(GUIDE, {"STATIONS", "SUITS", "CONTENT_VERSION"})
    all_stations = src["STATIONS"] + subzone_stations()
    item_names = set()
    for s in all_stations:
        for _, name, *_ in s["shop"]:
            item_names.add(name)
        if s["capstone"]:
            item_names.add(s["capstone"][1])
    avg_visits = avg_visits_from(REACHABILITY_CSV, item_names)

    data = {
        "version": src["CONTENT_VERSION"],
        "suits": src["SUITS"],
        "stations": all_stations,
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
