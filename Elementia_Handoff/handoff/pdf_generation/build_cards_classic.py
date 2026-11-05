# -*- coding: utf-8 -*-
"""
Elementia -- Classic Mode single card deck: one copy of every CORE_SET
item + every capstone (capstones are always core), not a print run.

Reuses build_cards_full.py's page/grid layout and asset handling, but the
card face itself is updated to match the digital game's CURRENT .pc-card
design (see elementia.html's #cardPop markup), which has drifted from this
file since it was first written:
  - a station badge (top-left corner, that item's home station's emoji)
    now sits opposite the points badge -- the full deck never had one.
  - the ingredients label reads "MADE FROM", not "COST — MADE FROM".
"""
import importlib.util, sys, re, pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
BUILD.mkdir(parents=True, exist_ok=True)
REPO = HERE.parent.parent.parent

spec = importlib.util.spec_from_file_location("bg", HERE / "build_guide.py")
bg = importlib.util.module_from_spec(spec)
sys.modules["bg"] = bg
spec.loader.exec_module(bg)
STATIONS = bg.STATIONS
SUITS = bg.SUITS

# ---- CORE_SET, read live from elementia.html -------------------------------
# Icon consts moved to game/assets/images.js (2026-11-05); read both files.
html = ((REPO / "game" / "elementia.html").read_text(encoding="utf-8")
        + (REPO / "game" / "assets" / "images.js").read_text(encoding="utf-8"))
m = re.search(r"const CORE_SET = new Set\(\[(.*?)\]\);", html, re.DOTALL)
if not m:
    raise SystemExit("Could not find CORE_SET in elementia.html")
CORE_PAIRS = set(re.findall(r'"([^"|]+)\|([^"]+)"', m.group(1)))

# ---- extra __MARKER__ icons build_guide.py doesn't itself resolve --------
# See build_guide_classic.py's matching comment: build_guide.py only hand-
# drew SVGs for Orca/Coral/Flour/Lighthouse/Tunnel. Newer __MARKER__ items
# (Diamond, Ecosystem, Life, Microchip, Rubber, ...) got their art made
# straight in elementia.html as CUSTOM_ICONS overrides instead -- pull those
# same consts out of the live game file so cards render with the game's
# actual art rather than literal "__LIFE__" placeholder text.
EXTRA_MARKERS = {"__DIAMOND__": "DIAMOND_IMG", "__ECOSYSTEM__": "ECOSYSTEM_IMG",
                  "__LIFE__": "LIFE_IMG", "__MICROCHIP__": "MICROCHIP_IMG",
                  "__RUBBER__": "RUBBER_SVG", "__CORAL__": "CORAL_SVG", "__FLOUR__": "FLOUR_SVG",
                  "__WHEEL__": "WHEEL_IMG", "__FURNACE__": "FURNACE_IMG", "__OVEN__": "OVEN_IMG",
                  "__BANANABREAD__": "BANANABREAD_IMG", "__TURBINEBLADE__": "TURBINEBLADE_IMG",
                  "__STEEL__": "STEEL_IMG", "__FOSSIL__": "FOSSIL_IMG", "__CONCRETE__": "CONCRETE_IMG",
                  "__FIBERGLASS__": "FIBERGLASS_IMG", "__LOGCABIN__": "LOGCABIN_IMG"}

def extract_js_const(src, name):
    m2 = re.search(r"const " + name + r" = '(.*?)';", src)
    if not m2:
        raise SystemExit(f"Could not find const {name} in elementia.html")
    return m2.group(1)

def parse_ingredient(token):
    token = token.strip()
    if re.fullmatch(r"[A-Z][a-z]?", token):
        return None, token
    parts = token.split(" ", 1)
    if len(parts) == 2:
        return parts[0], parts[1]
    return None, token

def ingredients_html(recipe):
    tokens = [t.strip() for t in recipe.split("+")]
    # Elements before items, always (matches sortIngredientTokens() in the
    # digital game) -- Python's sort is stable, so this is a partition,
    # each group keeping its own original relative order.
    tokens.sort(key=lambda t: 0 if re.fullmatch(r"[A-Z][a-z]?", t) else 1)
    pills = []
    for i, t in enumerate(tokens):
        icon, name = parse_ingredient(t)
        icon_html = f'<span class="ping-icon">{icon}</span>' if icon else ""
        cls = "ping" if icon else "ping elem"
        pills.append(f'<span class="{cls}">{icon_html}<span class="ping-name">{name}</span></span>')
        if i < len(tokens) - 1:
            pills.append('<span class="pplus">+</span>')
    return "".join(pills)

def collect_classic_deck():
    regular, capstones, seen = [], [], set()
    for s in STATIONS:
        suit_color = SUITS[s["suit"]]["color"]
        suit_soft = SUITS[s["suit"]]["soft"]
        for emoji, name, tag, recipe, points in s["shop"]:
            if (s["name"], name) not in CORE_PAIRS or name in seen:
                continue
            seen.add(name)
            regular.append({"emoji": emoji, "name": name, "tag": tag, "recipe": recipe, "points": points,
                             "color": suit_color, "soft": suit_soft, "station": s["name"],
                             "station_emoji": s["emoji"]})
        ce, cn, ct, cr, cpts = s["capstone"]
        capstones.append({"emoji": ce, "name": cn, "tag": ct, "recipe": cr, "points": cpts,
                           "color": suit_color, "soft": suit_soft, "station": s["name"],
                           "station_emoji": s["emoji"]})
    return regular, capstones

REGULAR, CAPSTONES = collect_classic_deck()
for s in STATIONS:
    n = sum(1 for it in REGULAR if it["station"] == s["name"])
    print(f"{s['name']}: {n} core cards")
print(f"total: {len(REGULAR)} regular + {len(CAPSTONES)} capstone")

# A handful of items' own art reads small next to the rest of the deck
# (their source image has more empty padding baked in than the other
# custom icons) -- bump just their card art by 50%, rather than the
# shared .cicon font-size every card inherits.
ENLARGED_ICONS = {"Ecosystem", "Fruit Cake", "Coral Reef", "Banana Bread", "Concrete", "Fiberglass"}

def card_html(item, big=False):
    cls = "card big" if big else "card"
    icon_size = "163px" if big else "160px"
    badge_size = "104px" if big else "51px"
    icon_font = "123px" if big else "153px"
    icon_style = f' style="font-size:{icon_font}"' if item["name"] in ENLARGED_ICONS else ""
    return f"""
    <div class="{cls}" style="--suit:{item['color']};--suit-soft:{item['soft']}">
      <div class="cstation-badge" style="width:{badge_size};height:{badge_size}">{item['station_emoji']}</div>
      <div class="cpoints-badge" style="width:{badge_size};height:{badge_size}"><span class="cp-num">{item['points']}</span><span class="cp-lbl">PTS</span></div>
      <div class="chead">
        <span class="ctitle">{item['name']}</span>
      </div>
      <div class="cicon-wrap"><div class="cicon-bg" style="width:{icon_size};height:{icon_size}">
        <span class="cicon"{icon_style}>{item['emoji']}</span></div></div>
      <div class="cdivider"></div>
      <div class="clabel">MADE FROM</div>
      <div class="cingredients">{ingredients_html(item['recipe'])}</div>
    </div>"""

# Every dimension below is scaled up from the previous (validated) card
# size by kR = 2.5/2.35 (regular) or kC = 5.1/4.7 (capstone) -- the exact
# factor needed to grow the card, aspect-locked, until neighboring cards'
# boundaries touch with zero grid gap. Scaling every dimension by the same
# k keeps every ratio established earlier (border == badge offset, border-
# radius == badge radius, capstone title/label matching regular's) intact
# at the new size -- only .cicon (the big center image) breaks from k,
# since regular cards additionally double it per an explicit request.
CSS = """
@page { margin: 0; }
* { box-sizing:border-box; margin:0; padding:0; }
body { font-family:'Helvetica Neue',Arial,'Noto Color Emoji',sans-serif; color:#1f2733;
  -webkit-print-color-adjust:exact; print-color-adjust:exact; }

/* Zero gap: badges sit flush with the card's own edge (see .card's
   comment below), not overhanging past it, so neighboring cards can
   touch boundary-to-boundary without their badges colliding. */
.page-portrait { width:8.5in; height:11in; padding:0.25in 0.4in; page-break-after:always;
  display:grid; grid-template-columns:repeat(3,2.5in); grid-template-rows:repeat(3,3.5in);
  gap:0; justify-content:center; align-content:start; }
.page-landscape { width:11in; height:8.5in; padding:0.4in; page-break-after:always;
  display:grid; grid-template-columns:repeat(2,5.1in); grid-template-rows:repeat(2,3.57in);
  gap:0; justify-content:center; align-content:center; }

/* Border width equals the badges' own overhang offset and border-radius
   equals their radius -- that makes the card's outer edge land exactly
   on the badge's own edge (flush, no gap, no clipping) and puts the
   card's rounded-corner arc and the badge's circle at the same center
   point and radius, so the corner curve and the circle trace the same
   arc instead of two unrelated curves colliding. */
.card {
  width:2.5in; height:3.5in; background:#f2f3f5; border-radius:26px;
  border:12px solid var(--suit); padding:16px 16px 13px;
  display:flex; flex-direction:column; position:relative;
  box-shadow: inset 0 0 0 1px #e2e5ea;
}
.card.big { width:5.1in; height:3.57in; border-width:23px;
  padding:0 33px 18px; border-radius:52px; }

.chead { display:flex; align-items:flex-start; justify-content:center; gap:6px; padding:0 57px; }
.card.big .chead { padding:0 117px; }
.ctitle { font-size:19px; font-weight:800; line-height:1.15; text-align:center; }
/* Nudged down by half its own line height, per request -- capstone only. */
.card.big .ctitle { font-size:20px; margin-top:10px; }

/* Straddles the card's own corner rather than sitting inset from it, same
   overhang language as the digital .pc-badge/.pc-station-badge -- negative
   offset, not a width/height change, so it stays clear of .ctitle (padded
   above) without clipping past the card's rounded corner. */
.cpoints-badge {
  position:absolute; top:-12px; right:-12px; border-radius:50%;
  background:#fdf1d6; border:3px solid #f0d9a8; color:#946200;
  display:flex; flex-direction:column; align-items:center; justify-content:center; line-height:1;
  box-shadow:0 1px 3px rgba(0,0,0,.12);
}
.cpoints-badge .cp-num { font-size:18px; font-weight:800; }
.cpoints-badge .cp-lbl { font-size:6px; font-weight:800; letter-spacing:.5px; margin-top:1px; }
.card.big .cpoints-badge { top:-23px; right:-23px; border-width:7px; }
.card.big .cpoints-badge .cp-num { font-size:36px; }
.card.big .cpoints-badge .cp-lbl { font-size:13px; }
.cstation-badge {
  position:absolute; top:-12px; left:-12px; border-radius:50%;
  background:#fff; border:3px solid var(--suit); color:#2b2822;
  display:flex; align-items:center; justify-content:center; font-size:22px; line-height:1;
  box-shadow:0 1px 3px rgba(0,0,0,.12);
}
.card.big .cstation-badge { font-size:46px; top:-23px; left:-23px; border-width:7px; }

.cicon-wrap { flex:1; display:flex; align-items:center; justify-content:center; min-height:0; }
.cicon-bg { display:flex; align-items:center; justify-content:center; }
/* Doubled per request (non-capstone cards only) -- both the glyph's own
   font-size and its centering box (icon_size, in card_html) are doubled
   together so the extra room around the icon scales with it. */
.cicon { font-size:102px; }
.card.big .cicon { font-size:82px; }

.cdivider { border-top:1.5px dashed #cfd4dc; margin:3px 0 6px; }
.card.big .cdivider { margin:0 0 2px; }
.clabel { font-size:9px; font-weight:800; letter-spacing:1px; color:#9aa3b2; margin-bottom:6px; }
.card.big .clabel { margin-bottom:4px; }

.cingredients { display:flex; flex-wrap:wrap; align-items:center; gap:5px; }
.ping { display:inline-flex; align-items:center; gap:4px; background:#e7e9ed; border-radius:7px;
  padding:5px 9px; font-size:12px; font-weight:700; color:#333; }
.ping.elem { background:#fff; border:2px solid #3a4250; font-weight:800; }
.ping-icon { font-size:14px; }
.card.big .ping { font-size:15px; padding:4px 12px; border-radius:11px; }
.card.big .cingredients { gap:4px 10px; }
.card.big .ping-icon { font-size:18px; }
.pplus { font-size:12px; color:#a8b0bc; font-weight:700; }
.card.big .pplus { font-size:15px; }

.pagefoot { position:absolute; }

.diamondicon,.lifeicon,.ecosystemicon,.microchip,.rubbersq,.coral,.flour,
.wheelicon,.furnaceicon,.ovenicon,.bananabreadicon,.turbineicon,
.steelicon,.fossilicon,.concreteicon,.fiberglassicon,.logcabinicon
{ width:1em; height:1em; vertical-align:-.15em; display:inline-block; }
"""

def chunk(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

reg_pages = "".join(
    f'<div class="page-portrait">{"".join(card_html(c) for c in page)}</div>'
    for page in chunk(REGULAR, 9)
)
cap_pages = "".join(
    f'<div class="page-landscape">{"".join(card_html(c, big=True) for c in page)}</div>'
    for page in chunk(CAPSTONES, 4)
)

reg_html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{reg_pages}</body></html>"
cap_html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{cap_pages}</body></html>"

def resolve_markers(page_html):
    page_html = (page_html
                 .replace("__ORCA__", bg.ORCA_SVG)
                 .replace("__LIGHTHOUSE__", bg.LIGHTHOUSE_SVG)
                 .replace("__TUNNEL__", bg.TUNNEL_SVG))
    for token, const_name in EXTRA_MARKERS.items():
        if token in page_html:
            page_html = page_html.replace(token, extract_js_const(html, const_name))
    return page_html

reg_html = resolve_markers(reg_html)
cap_html = resolve_markers(cap_html)

(BUILD / "classic_cards_regular.html").write_text(reg_html, encoding="utf-8")
(BUILD / "classic_cards_capstone.html").write_text(cap_html, encoding="utf-8")
print(f"\nregular cards: {len(REGULAR)} across {len(list(chunk(REGULAR,9)))} pages")
print(f"capstone cards: {len(CAPSTONES)} across {len(list(chunk(CAPSTONES,4)))} pages")
