# -*- coding: utf-8 -*-
"""Elementia — the 16 basic element cards."""
import base64, importlib.util, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
BUILD.mkdir(parents=True, exist_ok=True)

# Suit glyphs (leaf/flame/anvil/mountain) -- cropped from the user-supplied
# images/element suit symbols.png via a one-off script, saved once as
# game/suits/*.png. Read + base64-embedded here rather than duplicated as a
# literal string, so there's exactly one copy of each icon on disk.
SUITS_DIR = HERE.parent.parent.parent / "game" / "suits"
SUIT_ICON_B64 = {
    name: base64.b64encode((SUITS_DIR / f"{name}.png").read_bytes()).decode("ascii")
    for name in ("organic", "reactive", "metal", "earth")
}

spec = importlib.util.spec_from_file_location("bg", HERE / "build_guide.py")
bg = importlib.util.module_from_spec(spec)
sys.modules["bg"] = bg
spec.loader.exec_module(bg)
STATIONS = bg.STATIONS

# Element-suit palette ("Chemical Role", Palette A) -- distinct from the
# STATION suits in build_guide.py's own SUITS dict. Four even groups of
# four, chosen for what each element DOES in the game's own recipes rather
# than strict periodic-table position; see the element-palette artifact
# for the other two candidates this was picked over.
ELEMENT_SUITS = {
    "organic":  {"label": "ORGANIC",  "color": "#3aab6d"},
    "reactive": {"label": "REACTIVE", "color": "#e2543b"},
    "earth":    {"label": "EARTH",    "color": "#e2a83e"},
    "metal":    {"label": "METAL",    "color": "#4d7cf2"},
}

ELEMENTS = [
    ("C",  "Carbon",     6,  "organic"),
    ("H",  "Hydrogen",   1,  "organic"),
    ("N",  "Nitrogen",   7,  "organic"),
    ("O",  "Oxygen",     8,  "organic"),
    ("S",  "Sulfur",     16, "reactive"),
    ("K",  "Potassium",  19, "reactive"),
    ("Ca", "Calcium",    20, "reactive"),
    ("Si", "Silicon",    14, "earth"),
    ("Al", "Aluminum",   13, "earth"),
    ("Mg", "Magnesium",  12, "earth"),
    ("P",  "Phosphorus", 15, "earth"),
    ("Fe", "Iron",       26, "metal"),
    ("Ti", "Titanium",   22, "metal"),
    ("Cu", "Copper",     29, "metal"),
    ("Ag", "Silver",     47, "metal"),
    ("Ni", "Nickel",     28, "metal"),
]

# which stations gather each element (for the "GATHERED AT" row)
elem_stations = {}
for s in STATIONS:
    for e in set(s["dice"]):
        elem_stations.setdefault(e, []).append(s["emoji"])

def elem_card_html(symbol, name, atomic_num, suit):
    color = ELEMENT_SUITS[suit]["color"]
    label = ELEMENT_SUITS[suit]["label"]
    icon = f'<img src="data:image/png;base64,{SUIT_ICON_B64[suit]}" alt="">'
    return f"""
    <div class="card" style="--suit:{color}">
      <span class="num-bubble tr">{atomic_num}</span>
      <span class="num-bubble bl">{atomic_num}</span>
      <span class="num-bubble tl">{icon}</span>
      <span class="num-bubble br">{icon}</span>
      <span class="symbol">{symbol}</span>
      <span class="name">{name}</span>
      <span class="suit-pill">{label}</span>
    </div>"""

CSS = """
@page { margin: 0; }
* { box-sizing:border-box; margin:0; padding:0; }
body { font-family:'Helvetica Neue',Arial,'Noto Color Emoji',sans-serif; color:#1f2733;
  -webkit-print-color-adjust:exact; print-color-adjust:exact; }
/* Every corner now has a bubble (atomic number top-right/bottom-left,
   suit glyph top-left/bottom-right), so column/row gaps must clear TWO
   overhangs meeting each other (this card's + the neighbor's), not just
   one against a page edge like before. Gap >= 2x the overhang (10px) with
   a small margin -- don't shrink card size or gap without re-checking
   this math against .num-bubble's offset below. */
.page-portrait { width:8.5in; height:11in; padding:0.3in 0.5in; page-break-after:always;
  display:grid; grid-template-columns:repeat(3,2.3in); grid-template-rows:repeat(3,3.28in);
  gap:0.22in; justify-content:center; align-content:start; }

/* White face, black type, thick suit-colored border, atomic number in a
   white bubble straddling the top-right corner of the border -- the
   locked element-card design (see the element-palette artifact). */
.card {
  width:2.3in; height:3.28in; background:#ffffff; border-radius:20px;
  border:18px solid var(--suit); padding:18px 10px 16px;
  display:flex; flex-direction:column; align-items:center;
  position:relative; box-shadow:0 2px 8px rgba(0,0,0,.18);
}
/* Bubble SIZE can grow freely without affecting how far it overhangs past
   the card's outer edge -- overhang is set purely by the -10px offset
   below, not by width/height, so this stays safe against the print-grid
   gap math in .page-portrait above. */
.num-bubble {
  position:absolute; width:60px; height:60px; border-radius:50%;
  background:#fff; border:8px solid var(--suit); box-shadow:0 2px 6px rgba(0,0,0,.22);
  display:flex; align-items:center; justify-content:center;
  font-size:34px; font-weight:800; color:#2b2822;
}
/* Atomic number sits top-right and, mirrored, bottom-left; the suit's own
   glyph sits in the two corners left over -- top-left and bottom-right --
   so the two symbol types sit on opposite diagonals from each other. */
.num-bubble.tr { top:-10px; right:-10px; }
.num-bubble.bl { bottom:-10px; left:-10px; }
.num-bubble.tl { top:-10px; left:-10px; }
.num-bubble.br { bottom:-10px; right:-10px; }
.num-bubble img { width:58%; height:58%; object-fit:contain; }
.symbol {
  margin-top:20px; font-size:80px; font-weight:800; color:#1f1c17; line-height:1;
  letter-spacing:-.01em;
}
.name {
  margin-top:10px; font-size:22px; font-weight:700; color:#3a362f; text-align:center;
}
.suit-pill {
  margin-top:auto; font-size:12px; font-weight:800; letter-spacing:.08em;
  text-transform:uppercase; color:#fff; background:var(--suit);
  padding:5px 14px; border-radius:999px; white-space:nowrap;
}
"""

def chunk(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

cards_html = [elem_card_html(*e) for e in ELEMENTS]
pages = "".join(
    f'<div class="page-portrait">{"".join(page_cards)}</div>'
    for page_cards in chunk(cards_html, 9)
)
html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{pages}</body></html>"
(BUILD / "element_cards.html").write_text(html, encoding="utf-8")
print(f"element cards: {len(ELEMENTS)} across {len(list(chunk(cards_html,9)))} pages")
