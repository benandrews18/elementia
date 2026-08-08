# -*- coding: utf-8 -*-
"""
Regenerate the playable game's embedded data from build_guide.py.

build_guide.py stays the single source of truth (per HANDOFF.md §2). This
script does NOT re-render the whole page -- it surgically swaps the JSON
between the __GAME_DATA_START__ / __GAME_DATA_END__ markers in
elementia.html, so all the game's HTML/CSS/JS is edited in place as normal.

Usage:  python game/build_game.py
Then:   python game/build_game.py --check     (verify only, no write)

Note this reads build_guide.py with ast.literal_eval rather than importing
it -- importing has a module-level side effect that writes guide.html to a
hardcoded /home/claude/ path, which fails off-Linux.
"""
import ast, json, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GUIDE = HERE.parent / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
TARGETS = [HERE / "elementia.html", HERE / "simulate.html"]

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


def main():
    check_only = "--check" in sys.argv
    src = literals_from(GUIDE, {"STATIONS", "SUITS", "TAKE", "CONTENT_VERSION"})
    data = {
        "take": src["TAKE"], "version": src["CONTENT_VERSION"],
        "suits": src["SUITS"], "stations": src["STATIONS"],
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
