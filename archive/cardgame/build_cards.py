# -*- coding: utf-8 -*-
"""
Generate the solo card game's data bundle.

Three upstream sources, none of them edited here:

  Elementia_Handoff/handoff/pdf_generation/build_guide.py
        -- item names, tiers, point values, recipes (the source of truth)
  Elementia_Handoff/classic_item_element_suits.csv
        -- the hand-curated "Proposed Real-World Suit": exactly ONE suit
           per item, for all 79. Deliberately NOT elementia.html's
           itemSuitOf(), which derives a suit algorithmically from the
           recipe; this is the real-world override and 32 of the 79
           disagree with the derived value (Furnace organic->metal, Bone
           reactive->organic, Diamond organic->earth, ...).
  cardgame/classic set suits 0904.csv
        -- THE authority on card suits: the per-slot suit list, 0-3 suits
           per item with repeats allowed (Coral Reef is organic x3,
           Diamond earth x2, and 25 items have none at all). Cross-checked
           against elementia.html's ITEM_SUIT_COST_TABLE on every build,
           which warns rather than fails if the two drift -- the CSV wins.
  game/elementia.html
        -- the suit palette, suit symbol art, and element tables

Both suit models are emitted, because they describe different things --
one canonical suit per card vs. a multiset of suit pips -- and the card
game can be played either way (see SUIT_MODEL in cards.js).

Art is NOT duplicated: the page loads ../boardgame/icons.js, which already
carries every CORE_SET item icon. Only the four suit symbols are pulled in
here, since the board game had no use for them.

Usage:  python cardgame/build_cards.py
        python cardgame/build_cards.py --check
"""
import ast
import csv
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
GUIDE = ROOT / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
SUITS_CSV = ROOT / "Elementia_Handoff" / "classic_item_element_suits.csv"
PIPS_CSV = HERE / "classic set suits 0904.csv"
GAME = ROOT / "game" / "elementia.html"
import sys as _sys
_sys.path.insert(0, str(ROOT / "game"))
from game_source import read_game_source  # noqa: E402  (page + every file it loads)
BOARD_ICONS = ROOT / "boardgame" / "icons.js"
OUT = HERE / "data.js"

# Reuse the board game's comment-aware JS literal scanner rather than
# re-deriving it -- elementia.html's constants are full of prose comments
# and base64 blobs that a regex cannot safely walk.
sys.path.insert(0, str(ROOT / "boardgame"))
from build_board import js_value, js_string_array  # noqa: E402


VALID_SUITS = {"organic", "reactive", "earth", "metal"}


def read_pips():
    """Card suits from the CSV: item name -> list of suit pips.

    Column 1 is either "-" for no suit cost or a "+"-joined list, and
    either half may carry a free-text rationale after a dash ("earth -
    tilling the earth"). Case and the odd typo are normalised, since the
    file is hand-maintained.
    """
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
            pips = []
            for part in raw.split("+"):
                s = part.strip().lower().split(" - ")[0].strip()
                s = fix.get(s, s)
                if s not in VALID_SUITS:
                    raise SystemExit(f"{PIPS_CSV.name}: unknown suit {s!r} for {name!r}")
                pips.append(s)
            out[name] = pips
    if not out:
        raise SystemExit(f"{PIPS_CSV.name} parsed to nothing -- has its shape changed?")
    return out


def suit_cost_table(game):
    """ITEM_SUIT_COST_TABLE from elementia.html, for cross-checking only.

    Keys are a mix of bare identifiers and quoted strings ("Log Cabin"),
    so both forms are matched.
    """
    src = js_value(game, "ITEM_SUIT_COST_TABLE", stripped=True)
    out = {}
    for m in re.finditer(r'(?:"([^"]+)"|([A-Za-z][A-Za-z0-9]*))\s*:\s*\[([^\]]*)\]', src):
        name = m.group(1) or m.group(2)
        out[name] = [s.strip().strip('"') for s in m.group(3).split(",") if s.strip()]
    return out

COPIED = [
    "SUIT_COLOR",
    "ELEMENT_SUIT",
    "ELEMENT_SUIT_LABEL",
    "ELEMENT_NAMES",
    "ELEMENT_DESC",
    "CORE_ELEMENT_SYMS",
    "ELEMENT_COLOR",
    "ATOMIC_NUMBER",
]
SUIT_ART = {
    "organic": "ORGANIC_ICON_B64",
    "reactive": "REACTIVE_ICON_B64",
    "metal": "METAL_ICON_B64",
    "earth": "EARTH_ICON_B64",
}


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


def read_suits():
    """item name -> curated suit, from the CSV's Proposed column."""
    with SUITS_CSV.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    out = {}
    for r in rows:
        name = r["Item"].strip()
        suit = r["Proposed Real-World Suit"].strip()
        if not name:
            continue
        if suit not in SUIT_ART:
            raise SystemExit(f"{SUITS_CSV.name}: unknown suit {suit!r} for {name!r}")
        out[name] = suit
    return out


def build():
    lit = literals_from(GUIDE, {"STATIONS", "SUITS", "CONTENT_VERSION"})
    game = read_game_source()
    suits = read_suits()
    pips = read_pips()

    # The digital game carries the same table; if the two ever disagree,
    # say so loudly but let the CSV win -- it is the design document.
    live = suit_cost_table(game)
    drift = sorted(n for n in set(pips) | set(live)
                   if pips.get(n, []) != live.get(n, []))
    if drift:
        print(f"  NOTE: {len(drift)} item(s) differ from elementia.html's "
              f"ITEM_SUIT_COST_TABLE; the CSV wins: {', '.join(drift[:6])}"
              + (" ..." if len(drift) > 6 else ""))
    core = set(js_string_array(js_value(game, "CORE_SET", stripped=True)))

    # One card per unique Classic item, exactly the set the CSV covers.
    items, seen = [], set()
    for s in lit["STATIONS"]:
        for emoji, name, tier, recipe, points in list(s["shop"]) + [s["capstone"]]:
            if s["name"] + "|" + name not in core or name in seen:
                continue
            seen.add(name)
            # The card face shows its recipe as icons, not text (see the
            # Card Design Reference), so each ingredient carries the icon
            # key the art bundle is looked up by. Elements have no icon --
            # they render as their own letter box.
            comps = []
            for tok in recipe.split("+"):
                tok = tok.strip().replace("*", "")
                if re.fullmatch(r"[A-Z][a-z]?", tok):
                    comps.append({"kind": "element", "name": tok})
                else:
                    key, _, nm = tok.partition(" ")
                    comps.append({"kind": "item", "name": nm.strip() or tok, "emoji": key})
            items.append({
                "name": name,
                "emoji": emoji,
                "tier": tier,
                "points": points,
                "station": s["name"],
                "stationColor": lit["SUITS"][s["suit"]]["color"],
                "stationEmoji": s["emoji"],
                "suit": suits.get(name),
                "pips": pips.get(name, []),
                "components": comps,
            })

    unsuited = [i["name"] for i in items if not i["suit"]]
    if unsuited:
        raise SystemExit(
            f"{SUITS_CSV.name} has no suit for: {', '.join(sorted(unsuited))}"
        )
    stray = sorted(set(pips) - seen)
    if stray:
        raise SystemExit(
            f"{PIPS_CSV.name} names items outside CORE_SET: {', '.join(stray)}"
        )
    nopips = sorted(seen - set(pips))
    if nopips:
        raise SystemExit(
            f"{PIPS_CSV.name} is missing rows for: {', '.join(nopips)}"
        )
    extra = sorted(set(suits) - seen)
    if extra:
        raise SystemExit(
            f"{SUITS_CSV.name} lists items that are not in CORE_SET: {', '.join(extra)}"
        )

    if not BOARD_ICONS.exists():
        raise SystemExit(
            f"{BOARD_ICONS} is missing -- run `python boardgame/build_board.py` first; "
            "the card game reuses that bundle rather than duplicating 2.8 MB of art."
        )

    parts = [
        "/* GENERATED by cardgame/build_cards.py -- do not edit by hand.",
        f"   Content version {lit['CONTENT_VERSION']}. Item suits come from",
        "   cardgame/classic set suits 0904.csv -- the per-slot suit list is",
        "   the authority, cross-checked against elementia.html each build.",
        "   The single `suit` field is the older one-suit-per-item CSV, kept",
        "   for reference and not used for play. Card art is loaded",
        "   separately from ../boardgame/icons.js. */",
        f'const CONTENT_VERSION = {json.dumps(lit["CONTENT_VERSION"])};',
        "const ITEM_CARDS = " + json.dumps(items, ensure_ascii=False, indent=1) + ";",
    ]
    for name in COPIED:
        parts.append(f"const {name} = " + js_value(game, name) + ";")
    for suit, const in SUIT_ART.items():
        parts.append(f"const {const} = " + js_value(game, const) + ";")
    parts.append(
        "const SUIT_ART = {\n"
        + ",\n".join(f'  {k}: "data:image/png;base64," + {v}' for k, v in SUIT_ART.items())
        + "\n};"
    )
    return "\n".join(parts) + "\n", items


def main():
    check = "--check" in sys.argv
    text, items = build()
    from collections import Counter
    dist = Counter(i["suit"] for i in items)
    pipn = Counter(len(i["pips"]) for i in items)
    pipsuit = Counter(s for i in items for s in i["pips"])
    print(f"Elementia card game build -- {len(items)} item cards")
    print("  single-suit model : " + ", ".join(f"{k} {v}" for k, v in sorted(dist.items())))
    print("  pip model, cards by pip count : "
          + ", ".join(f"{k} pips x{v}" for k, v in sorted(pipn.items())))
    print("  pip model, total pips by suit : "
          + ", ".join(f"{k} {v}" for k, v in sorted(pipsuit.items())))

    old = OUT.read_text(encoding="utf-8") if OUT.exists() else None
    if old == text:
        print("  data.js: up to date")
        return
    if check:
        print("  data.js: STALE -- re-run without --check")
        sys.exit(1)
    OUT.write_text(text, encoding="utf-8")
    print(f"  data.js: written ({len(text.encode('utf-8'))/1024:,.0f} KB)")


if __name__ == "__main__":
    main()
