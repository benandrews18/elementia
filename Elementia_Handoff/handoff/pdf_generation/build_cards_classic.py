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

TAG_COLORS = {
    "MATERIAL":  "#8a94a6",
    "COMPONENT": "#3b7fc4",
    "CREATION":  "#3fa66b",
    "CAPSTONE":  "#c79a2e",
}

# ---- CORE_SET, read live from elementia.html -------------------------------
html = (REPO / "game" / "elementia.html").read_text(encoding="utf-8")
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
                  "__RUBBER__": "RUBBER_SVG"}

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

def card_html(item, big=False):
    cls = "card big" if big else "card"
    icon_size = "120px" if big else "94px"
    badge_size = "80px" if big else "54px"
    return f"""
    <div class="{cls}" style="--suit:{item['color']};--suit-soft:{item['soft']}">
      <div class="cstation-badge" style="width:{badge_size};height:{badge_size}">{item['station_emoji']}</div>
      <div class="cpoints-badge" style="width:{badge_size};height:{badge_size}"><span class="cp-num">{item['points']}</span><span class="cp-lbl">PTS</span></div>
      <div class="chead">
        <span class="ctitle">{item['name']}</span>
      </div>
      <div class="cicon-wrap"><div class="cicon-bg" style="width:{icon_size};height:{icon_size}">
        <span class="cicon">{item['emoji']}</span></div></div>
      <div class="ctag" style="background:{TAG_COLORS.get(item['tag'],'#8a94a6')}">{item['tag']}</div>
      <div class="cdivider"></div>
      <div class="clabel">MADE FROM</div>
      <div class="cingredients">{ingredients_html(item['recipe'])}</div>
    </div>"""

CSS = """
@page { margin: 0; }
* { box-sizing:border-box; margin:0; padding:0; }
body { font-family:'Helvetica Neue',Arial,'Noto Color Emoji',sans-serif; color:#1f2733;
  -webkit-print-color-adjust:exact; print-color-adjust:exact; }

.page-portrait { width:8.5in; height:11in; padding:0.25in 0.5in; page-break-after:always;
  display:grid; grid-template-columns:repeat(3,2.5in); grid-template-rows:repeat(3,3.5in);
  gap:0; justify-content:center; align-content:start; }
.page-landscape { width:11in; height:8.5in; padding:0.55in 0.5in; page-break-after:always;
  display:grid; grid-template-columns:repeat(2,5in); grid-template-rows:repeat(2,3.5in);
  gap:0.2in 0; justify-content:center; align-content:center; }

.card {
  width:2.5in; height:3.5in; background:#f2f3f5; border-radius:16px;
  border-top:6px solid var(--suit); padding:14px 14px 12px;
  display:flex; flex-direction:column; position:relative;
  box-shadow: inset 0 0 0 1px #e2e5ea;
}
.card.big { width:5in; height:3.5in; padding:10px 22px 8px; border-radius:20px; }

.chead { display:flex; align-items:flex-start; justify-content:center; gap:6px; padding:0 58px; }
.card.big .chead { padding:0 86px; }
.ctitle { font-size:21px; font-weight:800; line-height:1.15; text-align:center; }
.card.big .ctitle { font-size:32px; }

/* Points badge (top-right, unchanged position) and the station badge that
   mirrors it on the top-left -- same overhanging-circle language the
   digital game's own #cardPop uses (.pc-badge/.pc-station-badge), which
   this deck was missing entirely before. */
.cpoints-badge {
  position:absolute; top:12px; right:12px; border-radius:50%;
  background:#fdf1d6; border:2px solid #f0d9a8; color:#946200;
  display:flex; flex-direction:column; align-items:center; justify-content:center; line-height:1;
  box-shadow:0 1px 3px rgba(0,0,0,.12);
}
.cpoints-badge .cp-num { font-size:19px; font-weight:800; }
.cpoints-badge .cp-lbl { font-size:7px; font-weight:800; letter-spacing:.5px; margin-top:1px; }
.card.big .cpoints-badge .cp-num { font-size:26px; }
.card.big .cpoints-badge .cp-lbl { font-size:9.5px; }
.cstation-badge {
  position:absolute; top:12px; left:12px; border-radius:50%;
  background:#fff; border:2px solid var(--suit); color:#2b2822;
  display:flex; align-items:center; justify-content:center; font-size:24px; line-height:1;
  box-shadow:0 1px 3px rgba(0,0,0,.12);
}
.card.big .cstation-badge { font-size:34px; top:10px; left:16px; }

.cicon-wrap { flex:1; display:flex; align-items:center; justify-content:center; min-height:0; }
.cicon-bg { display:flex; align-items:center; justify-content:center; }
.cicon { font-size:48px; }
.card.big .cicon { font-size:64px; }

.ctag { align-self:center; font-size:10px; font-weight:800; letter-spacing:.5px; color:#fff;
  border-radius:999px; padding:2px 9px; white-space:nowrap; margin-bottom:4px; }
.card.big .ctag { font-size:13px; padding:2px 11px; margin-bottom:3px; }

.cdivider { border-top:1.5px dashed #cfd4dc; margin:3px 0 6px; }
.card.big .cdivider { margin:2px 0 4px; }
.clabel { font-size:10px; font-weight:800; letter-spacing:1px; color:#9aa3b2; margin-bottom:6px; }
.card.big .clabel { font-size:12px; margin-bottom:5px; }

.cingredients { display:flex; flex-wrap:wrap; align-items:center; gap:4px; }
.ping { display:inline-flex; align-items:center; gap:4px; background:#e7e9ed; border-radius:7px;
  padding:5px 8px; font-size:15px; font-weight:700; color:#333; }
.ping.elem { background:#fff; border:2px solid #3a4250; font-weight:800; }
.ping-icon { font-size:17px; }
.card.big .ping { font-size:18px; padding:4px 11px; border-radius:10px; }
.card.big .cingredients { gap:4px 6px; }
.card.big .ping-icon { font-size:22px; }
.pplus { font-size:15px; color:#a8b0bc; font-weight:700; }
.card.big .pplus { font-size:19px; }

.pagefoot { position:absolute; }

.diamondicon,.lifeicon,.ecosystemicon,.microchip,.rubbersq
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
                 .replace("__CORAL__", bg.CORAL_SVG)
                 .replace("__FLOUR__", bg.FLOUR_SVG)
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
