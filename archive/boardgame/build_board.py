# -*- coding: utf-8 -*-
"""
Generate the board game's data + art bundles from the existing sources.

The board game fork owns NO content of its own. Two upstream files stay
authoritative and are read here, never edited:

  Elementia_Handoff/handoff/pdf_generation/build_guide.py
        -- SUITS / STATIONS / TAKE / CONTENT_VERSION (per the fork handoff
           doc, this is THE source of truth for stations, recipes, points)
  game/elementia.html
        -- CORE_SET (Classic Mode's curated, closed catalog), the station
           graph (MAP_EDGES / MAP_NODE_POS), the element tables, and every
           bundled icon (Noto rasters + the bespoke PNG/SVG art)

Outputs, both regenerated wholesale and both gitignorable-if-you-want:

  boardgame/data.js   -- DATA, CORE_SET, MAP_EDGES, MAP_NODE_POS, elements
  boardgame/icons.js  -- ICONS: one emoji/token -> <img> lookup, pruned to
                         only the keys the board game can actually show

Usage:  python boardgame/build_board.py
        python boardgame/build_board.py --check     (verify only, no write)

Like game/build_game.py, this reads build_guide.py with ast.literal_eval
rather than importing it -- importing has a module-level side effect that
writes to a hardcoded Linux path.
"""
import ast
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
GUIDE = ROOT / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
GAME = ROOT / "game" / "elementia.html"
import sys as _sys
_sys.path.insert(0, str(ROOT / "game"))
from game_source import read_game_source  # noqa: E402  (page + every file it loads)
OUT_DATA = HERE / "data.js"
OUT_ICONS = HERE / "icons.js"

# Copied verbatim out of elementia.html rather than re-derived, so the
# board game's element chips read the same names/suits/colors as the
# digital game's do. Each name is a top-level `const NAME = <literal>;`.
ELEMENT_CONSTS = [
    "ELEMENT_NAMES",
    "CORE_ELEMENT_SYMS",
    "ELEMENT_SUIT",
    "ELEMENT_SUIT_LABEL",
    "ELEMENT_COLOR",
    "ELEMENT_COLOR_DARK",
    "ATOMIC_NUMBER",
]
GRAPH_CONSTS = ["MAP_EDGES", "MAP_NODE_POS"]


# ---------------------------------------------------------------- helpers

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


def js_scan(text, start, stop_at_semicolon):
    """Walk JS source from `start`, tracking strings and comments.

    Yields nothing; returns (end_index, stripped) where `stripped` is the
    span with comments blanked out. Both callers below need the comment
    handling: elementia.html's big literals are full of prose comments
    containing apostrophes, quotes and braces (CORE_SET's, for one, runs
    to ~30 lines of them), while the base64/SVG blobs those same literals
    reference contain '//' and quote characters inside strings. Only a
    scanner that knows which state it's in gets both right.
    """
    i = start
    depth = 0
    out = []
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if ch == "/" and nxt == "/":
            j = text.find("\n", i)
            j = len(text) if j == -1 else j
            out.append(" " * (j - i))
            i = j
            continue
        if ch == "/" and nxt == "*":
            j = text.find("*/", i + 2)
            j = len(text) if j == -1 else j + 2
            out.append(" " * (j - i))
            i = j
            continue
        if ch in "'\"`":
            quote = ch
            j = i + 1
            while j < len(text):
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == quote:
                    j += 1
                    break
                j += 1
            out.append(text[i:j])
            i = j
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == ";" and depth == 0 and stop_at_semicolon:
            return i, "".join(out)
        out.append(ch)
        i += 1
    if stop_at_semicolon:
        raise SystemExit(f"Unterminated value starting at offset {start}")
    return i, "".join(out)


def js_value(text, name, stripped=False):
    """The source of `const NAME = <value>;` from a JS file, up to its `;`.

    With stripped=True, comments come back blanked out (same length, so
    offsets still line up) -- use that when parsing the value, and the raw
    form when copying it into a generated file verbatim.
    """
    m = re.search(r"^const\s+" + re.escape(name) + r"\s*=\s*", text, re.M)
    if not m:
        raise SystemExit(f"Could not find `const {name} =` in {GAME}")
    end, blanked = js_scan(text, m.end(), True)
    return (blanked if stripped else text[m.end():end]).strip()


def js_string_array(src):
    """Every double-quoted string in a JS array/Set literal, in order."""
    return re.findall(r'"((?:[^"\\]|\\.)*)"', src)


# ------------------------------------------------------------------ build

def build_data():
    lit = literals_from(GUIDE, {"SUITS", "STATIONS", "TAKE", "CONTENT_VERSION"})
    game = read_game_source()

    # CORE_SET is `new Set([...])` of "Station|Item" keys.
    core = js_string_array(js_value(game, "CORE_SET", stripped=True))
    if not core:
        raise SystemExit("CORE_SET came back empty -- did elementia.html change shape?")

    data = {
        "take": lit["TAKE"],
        "version": lit["CONTENT_VERSION"],
        "suits": lit["SUITS"],
        "stations": [
            {
                "emoji": s["emoji"],
                "name": s["name"],
                "suit": s["suit"],
                "dice": s["dice"],
                "shop": s["shop"],
                "capstone": s["capstone"],
            }
            for s in lit["STATIONS"]
        ],
    }

    parts = [
        "/* GENERATED by boardgame/build_board.py -- do not edit by hand.",
        f"   Content version {lit['CONTENT_VERSION']}, sourced from",
        "   Elementia_Handoff/handoff/pdf_generation/build_guide.py and",
        "   game/elementia.html. Re-run the script instead of editing. */",
        "const DATA = " + json.dumps(data, ensure_ascii=False, indent=1) + ";",
        "const CORE_SET = new Set(" + json.dumps(core, ensure_ascii=False, indent=1) + ");",
    ]
    for name in GRAPH_CONSTS + ELEMENT_CONSTS:
        parts.append(f"const {name} = " + js_value(game, name) + ";")
    return "\n".join(parts) + "\n"


def needed_icon_keys(data, core):
    """Every emoji/token the board game can put on screen.

    That's each CORE_SET item (the tier decks and the capstone row are both
    drawn purely from CORE_SET, whose ingredient closure is itself inside
    CORE_SET) plus the 8 station icons, which show on map nodes, station
    panels and each Bingo square's corner badge.
    """
    keys = set()
    core_names = {k.split("|", 1)[1] for k in core}
    for s in data["stations"]:
        keys.add(s["emoji"])
        for row in list(s["shop"]) + [s["capstone"]]:
            if row[1] in core_names:
                keys.add(row[0])
    return keys


def build_icons(data, core):
    game = read_game_source()
    # Both lookup tables are one flat `"key": CONSTANT_NAME` object each;
    # CUSTOM_ICONS spreads NOTO_ICONS then overrides, so reading NOTO first
    # and letting CUSTOM win reproduces the live game's own precedence.
    mapping = {}
    for table in ("NOTO_ICONS", "CUSTOM_ICONS"):
        src = js_value(game, table, stripped=True)
        for key, const in re.findall(r'"((?:[^"\\]|\\.)*)"\s*:\s*([A-Za-z_][A-Za-z0-9_]*)', src):
            mapping[key.encode().decode("unicode_escape") if "\\" in key else key] = const

    wanted = needed_icon_keys(data, core)
    missing = sorted(k for k in wanted if k not in mapping)
    if missing:
        raise SystemExit(
            "No icon constant for: " + ", ".join(repr(m) for m in missing)
            + " -- add art in elementia.html first (see the fork handoff doc, section 5)."
        )

    consts = {}
    for key in sorted(wanted):
        name = mapping[key]
        if name not in consts:
            consts[name] = js_value(game, name)

    parts = [
        "/* GENERATED by boardgame/build_board.py -- do not edit by hand.",
        f"   {len(consts)} icon constants covering {len(wanted)} emoji/token keys,",
        "   lifted verbatim from game/elementia.html's NOTO_ICONS/CUSTOM_ICONS",
        "   so the board game's art is byte-identical to the digital game's. */",
    ]
    for name in sorted(consts):
        parts.append(f"const {name} = {consts[name]};")
    entries = ",\n ".join(
        json.dumps(k, ensure_ascii=False) + ": " + mapping[k] for k in sorted(wanted)
    )
    parts.append("const ICONS = {\n " + entries + "\n};")
    return "\n".join(parts) + "\n"


def write(path, text, check):
    old = path.read_text(encoding="utf-8") if path.exists() else None
    if old == text:
        print(f"  {path.name}: up to date")
        return False
    if check:
        print(f"  {path.name}: STALE -- re-run without --check")
        return True
    path.write_text(text, encoding="utf-8")
    kb = len(text.encode("utf-8")) / 1024
    print(f"  {path.name}: written ({kb:,.0f} KB)")
    return True


def main():
    check = "--check" in sys.argv
    for p in (GUIDE, GAME):
        if not p.exists():
            raise SystemExit(f"Missing source: {p}")

    data_js = build_data()
    lit = literals_from(GUIDE, {"STATIONS", "TAKE", "CONTENT_VERSION", "SUITS"})
    data = {"stations": lit["STATIONS"]}
    core = js_string_array(js_value(read_game_source(), "CORE_SET", stripped=True))
    icons_js = build_icons(data, core)

    print(f"Elementia board game build (content {lit['CONTENT_VERSION']})")
    stale = write(OUT_DATA, data_js, check) | write(OUT_ICONS, icons_js, check)
    if check and stale:
        sys.exit(1)


if __name__ == "__main__":
    main()
