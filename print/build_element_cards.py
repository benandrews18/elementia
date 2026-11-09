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
SUITS_DIR = HERE.parent / "game" / "suits"
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
    ("P",  "Phosphorus", 15, "reactive"),
    ("Fe", "Iron",       26, "metal"),
    ("Ti", "Titanium",   22, "metal"),
    ("Cu", "Copper",     29, "metal"),
    ("Ag", "Silver",     47, "metal"),
    ("Ni", "Nickel",     28, "earth"),
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
    # Metal's own suit glyph, 50% bigger than the other three suits' --
    # deliberately allowed to spill past the bubble's own circular edge
    # (no clipping) rather than get shrunk back down to fit inside it.
    icon_cls = "num-bubble big-icon" if suit == "metal" else "num-bubble"
    return f"""
    <div class="card" style="--suit:{color}">
      <span class="num-bubble tl">{atomic_num}</span>
      <span class="num-bubble br">{atomic_num}</span>
      <span class="{icon_cls} tr">{icon}</span>
      <span class="{icon_cls} bl">{icon}</span>
      <div class="mid">
        <span class="symbol">{symbol}</span>
        <span class="name">{name}</span>
      </div>
      <span class="suit-pill">{label}</span>
    </div>"""

# Every dimension below is the digital game's own .el-pop-card value (see
# elementia.html ~2210-2253) scaled by k = 2.35in-card-width / 300px-digital-
# reference-width, so the printed card is a faithful scale copy -- same
# border-to-width ratio, same badge overhang, same type sizes relative to
# the card, same alignment (symbol+name centered as a group in the space
# between the top padding and the bottom pill, not top-anchored).
CSS = """
@page { margin: 0; }
* { box-sizing:border-box; margin:0; padding:0; }
body { font-family:'Helvetica Neue',Arial,'Noto Color Emoji',sans-serif; color:#1f2733;
  -webkit-print-color-adjust:exact; print-color-adjust:exact; }
/* Zero gap: the bubble offset equals the border width (see .card below),
   so bubbles sit flush with the card's own edge rather than overhanging
   past it -- neighboring cards can touch boundary-to-boundary without
   their bubbles colliding. Card size grows (aspect-locked, every
   dimension scaled by the same k) until 3 columns/rows fill the page
   with no gap left over. */
.page-portrait { width:8.5in; height:11in; padding:0.34in 0.47in; page-break-after:always;
  display:grid; grid-template-columns:repeat(3,2.457in); grid-template-rows:repeat(3,3.44in);
  gap:0; justify-content:center; align-content:start; }

/* White face, black type, thick suit-colored border, atomic number in a
   white bubble straddling the top-right corner of the border -- the
   locked element-card design, aspect-ratio-for-aspect-ratio identical to
   the digital .el-pop-card (5:7, same as .pc-card). */
.card {
  width:2.457in; height:3.44in; background:#ffffff; border-radius:20px;
  border:15px solid var(--suit); padding:21px 17px 17px;
  display:flex; flex-direction:column; align-items:center;
  position:relative; box-shadow:0 2px 8px rgba(0,0,0,.18);
}
/* Bubble SIZE can grow freely without affecting how far it overhangs past
   the card's outer edge -- overhang is set purely by the -15px offset
   below (equal to the border width, so it lands exactly flush), not by
   width/height. */
.num-bubble {
  position:absolute; width:64px; height:64px; border-radius:50%;
  background:#fff; border:9px solid var(--suit); box-shadow:0 2px 6px rgba(0,0,0,.22);
  display:flex; align-items:center; justify-content:center;
  font-size:33px; font-weight:800; color:#2b2822;
}
/* Atomic number sits top-left and, mirrored, bottom-right; the suit's own
   glyph sits in the two corners left over -- top-right and bottom-left --
   so the two symbol types sit on opposite diagonals from each other. */
.num-bubble.tr { top:-15px; right:-15px; }
.num-bubble.bl { bottom:-15px; left:-15px; }
.num-bubble.tl { top:-15px; left:-15px; }
.num-bubble.br { bottom:-15px; right:-15px; }
.num-bubble img { width:58%; height:58%; object-fit:contain; }
.num-bubble.big-icon img { width:87%; height:87%; }
/* Grows to fill the space between the top padding and the pill (pinned to
   the bottom edge via margin-top:auto on itself), then centers the symbol
   + name as a group within that space -- the same .el-pop-mid alignment
   the digital card popup uses, instead of the symbol sitting fixed near
   the top with leftover space dumped above the pill. */
.mid { flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center; min-height:0; }
.symbol {
  font-size:81px; font-weight:800; color:#1f1c17; line-height:1;
  letter-spacing:-.01em; text-align:center;
}
.name {
  margin-top:12px; font-size:21px; font-weight:700; color:#3a362f; text-align:center;
}
.suit-pill {
  margin-top:auto; font-size:10px; font-weight:800; letter-spacing:.08em;
  text-transform:uppercase; color:#fff; background:var(--suit);
  padding:4px 12px; border-radius:999px; white-space:nowrap;
}
"""

def chunk(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

cards_html = [elem_card_html(*e) for e in sorted(ELEMENTS, key=lambda e: e[2])]
pages = "".join(
    f'<div class="page-portrait">{"".join(page_cards)}</div>'
    for page_cards in chunk(cards_html, 9)
)
html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{pages}</body></html>"
(BUILD / "element_cards.html").write_text(html, encoding="utf-8")
print(f"element cards: {len(ELEMENTS)} across {len(list(chunk(cards_html,9)))} pages")
