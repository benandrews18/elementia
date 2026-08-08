# -*- coding: utf-8 -*-
"""
Elementia -- the actual PRINT RUN: every card, repeated as many times as
simulation/print_quantities.py says a single session is likely to need,
under the permanent-unlock economy (every group that ever crafts item X
keeps its own physical copy, so N copies must exist for N groups to each
hold one at once).

Quantities come from simulation/print_quantities.json (regenerate it with
`python simulation/print_quantities.py --json print_quantities.json` after
any recipe change). Capstones are floored at CAPSTONE_FLOOR regardless of
their computed number: that simulation models diffuse, casual multi-goal
play, which will always understate deliberate capstone-chasing (the whole
point of this game's design), and with only 8 unique capstone cards the
cost of printing a few extra is trivial next to running out mid-camp.

Reuses build_cards_full.py's card markup/CSS so the print run looks
identical to the reference deck -- just with repeats.
"""
import importlib.util, sys, re, json, pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
BUILD.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("bg", HERE / "build_guide.py")
bg = importlib.util.module_from_spec(spec)
sys.modules["bg"] = bg
spec.loader.exec_module(bg)
STATIONS = bg.STATIONS
SUITS = bg.SUITS

QTY_JSON = HERE.parent / "simulation" / "print_quantities.json"
CAPSTONE_FLOOR = 4

TAG_COLORS = {
    "MATERIAL":  "#8a94a6",
    "COMPONENT": "#3b7fc4",
    "CREATION":  "#3fa66b",
    "CAPSTONE":  "#c79a2e",
}


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


def collect_deck():
    regular, capstones, seen = [], [], set()
    for s in STATIONS:
        suit_color = SUITS[s["suit"]]["color"]
        suit_soft = SUITS[s["suit"]]["soft"]
        all_items = list(s["shop"])
        if s.get("farm_section"):
            all_items += s["farm_section"]["items"]
        for emoji, name, tag, recipe, points in all_items:
            if name in seen:
                continue
            seen.add(name)
            regular.append({"emoji": emoji, "name": name, "tag": tag, "recipe": recipe, "points": points,
                             "color": suit_color, "soft": suit_soft})
        ce, cn, ct, cr, cpts = s["capstone"]
        capstones.append({"emoji": ce, "name": cn, "tag": ct, "recipe": cr, "points": cpts,
                           "color": suit_color, "soft": suit_soft})
    return regular, capstones


REGULAR, CAPSTONES = collect_deck()

with open(QTY_JSON, encoding="utf-8") as f:
    QTY_ROWS = json.load(f)
QTY = {r["item"]: r["print_qty"] for r in QTY_ROWS}


def print_qty_for(item, is_cap):
    q = QTY.get(item)
    if q is None:
        raise SystemExit(f"No print quantity found for '{item}' -- is "
                          f"print_quantities.json stale relative to build_guide.py?")
    return max(q, CAPSTONE_FLOOR) if is_cap else q


def card_html(item, big=False):
    cls = "card big" if big else "card"
    icon_size = "120px" if big else "94px"
    return f"""
    <div class="{cls}" style="--suit:{item['color']};--suit-soft:{item['soft']}">
      <div class="cpoints-badge"><span class="cp-num">{item['points']}</span><span class="cp-lbl">PTS</span></div>
      <div class="chead">
        <span class="ctitle">{item['name']}</span>
      </div>
      <div class="cicon-wrap"><div class="cicon-bg" style="width:{icon_size};height:{icon_size}">
        <span class="cicon">{item['emoji']}</span></div></div>
      <div class="ctag" style="background:{TAG_COLORS.get(item['tag'],'#8a94a6')}">{item['tag']}</div>
      <div class="cdivider"></div>
      <div class="clabel">COST — MADE FROM</div>
      <div class="cingredients">{ingredients_html(item['recipe'])}</div>
    </div>"""


CSS = """
@page { margin: 0; }
* { box-sizing:border-box; margin:0; padding:0; }
body { font-family:'Helvetica Neue',Arial,sans-serif; color:#1f2733;
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

.chead { display:flex; align-items:flex-start; gap:6px; padding-right:58px; }
.card.big .chead { padding-right:86px; }
.ctitle { font-size:21px; font-weight:800; line-height:1.15; }
.card.big .ctitle { font-size:32px; }

.cpoints-badge {
  position:absolute; top:12px; right:12px; width:54px; height:54px; border-radius:50%;
  background:#fdf1d6; border:2px solid #f0d9a8; color:#946200;
  display:flex; flex-direction:column; align-items:center; justify-content:center; line-height:1;
  box-shadow:0 1px 3px rgba(0,0,0,.12);
}
.cpoints-badge .cp-num { font-size:19px; font-weight:800; }
.cpoints-badge .cp-lbl { font-size:7px; font-weight:800; letter-spacing:.5px; margin-top:1px; }
.card.big .cpoints-badge { width:80px; height:80px; top:10px; right:16px; }
.card.big .cpoints-badge .cp-num { font-size:26px; }
.card.big .cpoints-badge .cp-lbl { font-size:9.5px; }

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
"""


def chunk(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def expand(items, is_cap):
    """Repeat each card's HTML by its print quantity, in stable item order
    (all N copies of item A, then all copies of item B, ...) so cut sheets
    stay easy to sort and count against the plan."""
    out = []
    for item in items:
        n = print_qty_for(item["name"], is_cap)
        out.extend([item] * n)
    return out


reg_run = expand(REGULAR, is_cap=False)
cap_run = expand(CAPSTONES, is_cap=True)

reg_pages = "".join(
    f'<div class="page-portrait">{"".join(card_html(c) for c in page)}</div>'
    for page in chunk(reg_run, 9)
)
cap_pages = "".join(
    f'<div class="page-landscape">{"".join(card_html(c, big=True) for c in page)}</div>'
    for page in chunk(cap_run, 4)
)

reg_html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{reg_pages}</body></html>"
cap_html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{cap_pages}</body></html>"

ORCA_SVG = '''<svg viewBox="0 0 128 128" style="width:1em;height:1em;vertical-align:-0.15em" xmlns="http://www.w3.org/2000/svg"><path style="fill:#5E6367;" d="M46.1,52.5c0,0,2.5,6.5,6.8,12.6c4.8,6.7,10.8,12.4,14.6,10.9s0.2-8.5-1.5-13.8c-2.4-7.4-0.9-9.8-0.9-9.8L46.1,52.5z"/><path style="fill:#464C4F;" d="M91.7,84.2L84.9,90L83,91.3c0,0-5.1,0.2-11.3-0.9c-6.2-1.1-9-1.8-10.2-1.7c-1.1,0.1-1.4,1.5-1,3.3s0.5,5.6,4.1,9.6c3.7,4,6.4,5.1,6.4,5.1s-0.9,5.1,1,9.3c1.9,4.1,5.5,8.3,6.9,8.2c1.4-0.2,1.6-1.8,2.5-4.4c0.9-2.5,4.1-10.9,4.7-13s2-5.5,2-5.5s23.2-6.2,27.3-31.8c4-25.6-13.1-38.9-13.1-42.8s4.5-11.5,6.9-14.3s5.1-6,2.9-7.5c-2.1-1.6-9.7,1.1-15.2,5.8s-6.7,5.9-8.7,5.7c-2-0.2-25.6-13.6-52.4-5.1C11.6,19,13.5,36.4,13.5,36.4s-3.2,2.2-3.9,5.9c-0.9,4.5-0.1,5.4-0.1,5.4l49.4,0.5l24.4,11.5l10,13.6L91.7,84.2z"/><path style="fill:#F4F0EF;" d="M27.9,33.8c0.7,0.2,1.6,0.7,3.5-0.4c1.9-1.1,6.3-2.7,9.2-3.6c3.3-0.9,8-4,7-8.1s-7-5-12.6-2.1C28.5,23,27.6,30,27.6,30L27.9,33.8z"/><path style="fill:#131314;" d="M26.3,30.2c-1.7,1.3-2,3.9-0.6,5.5s3.1,1.6,4.6,0.8c1.4-0.8,2.2-3.3,0.8-5.3C29.7,29.3,27.8,29.1,26.3,30.2z"/><path style="fill:#CDCDCE;" d="M64.3,91.9c-1.4,0.9,1.1,5.9,3.8,8.6c2.9,2.9,5.5,3.9,5.5,3.9s-0.7,4.3,0.5,8c0.9,2.7,2.6,5.2,3.6,5.3c1.7,0.3,4.2-8.3,5.6-11.9s3-8.8,1.3-10.8c-1.5-1.8-5.7-0.8-11-1.2C68.5,93.3,65.4,91.2,64.3,91.9z"/><path style="fill:#696F75;" d="M91.6,29.9c-0.5,1.6,1.8,3.3,4.8,4.2c5.5,1.8,11.2,0.9,11.2,0.9s-2.9-3.9-3.4-4.7c-0.5-0.8-1.8-3.2-1.8-3.2s-6,0.5-7.5,0.8C93.4,28.1,92.1,28.5,91.6,29.9z"/><path style="fill:#F4F0EF;" d="M88,74.8l0.1,8.9l-3.2,7c0,0,1.3,0.7,3.8-1.2c2.5-1.9,8.6-9,8.3-18s-4.7-12.8-2.9-14.4c1.8-1.5,4.4,0.8,5.6,1.5c1.1,0.8,2.8,2.7,4.3,1.2s1.5-7.4-2.8-10.4c-4.3-3-8.8-2.3-12.9-1.5s-7.4,1.8-11.8,0.4c-4.4-1.5-8.9-2.9-11.8-4.6S55.8,36,45,35.5s-18.1,5.7-18.1,5.7L12.8,48l3.9,3.6l26.9,0.3l19.6,2.7l13.4,5.9l8.9,7.9L88,74.8z"/><path style="fill:#CDCDCE;" d="M84.9,90.7c-0.7-0.8,3.1-5.9,2.2-14.1c-0.7-6.4-7.6-14.9-21.5-19.6c-6.6-2.2-14.1-3.1-21.8-3.4c-5.5-0.2-21.6,0.9-28-1c-3.3-1-5.6-3.3-5.7-4.1l3.7-0.2c0,0,1.7,2.9,12.9,2.5c6.1-0.2,27.4-1.2,39.1,2.8c6.5,2.2,11.4,4.9,15.2,8.2c5.5,4.9,8.3,10.6,8.8,14.6C90.9,85.5,85.6,91.5,84.9,90.7z"/><path style="fill:#131314;" d="M9.3,46.7c-0.1,0.4,0.1,1.6,0.9,2.1c0.8,0.6,3.3,1.2,10.3-2.4c6.7-3.6,7.8-5.2,6.8-6.9c-0.8-1.4-3.5,0.6-4.9,1.4c-1.5,0.8-5.2,3-7.5,3.9S9.3,46.7,9.3,46.7z"/><path style="fill:#464C4F;" d="M67,36.5c0,0,3.6-1.3,10.2-7.4c8.8-8.1,11.1-15.5,8-17.7c-3.1-2.2-8.2-1.7-17,4c-8.3,5.4-15,14.5-15,14.5L67,36.5z"/><path style="fill:#252829;" d="M63.8,38.2c-0.8-1.1,3.2-3.4,6.3-5.8c1.6-1.3,3.7-2.9,6-4.9c6.8-5.9,10.7-12.6,8.3-14.9c-2.4-2.3-8.8-0.2-16.4,4.8c-3,2-5.9,4.6-8.2,6.9c-2.5,2.6-4.3,5.9-5.8,7.4c-0.7,0.7-1.6,0.9-2,0.5c-1.6-1.5,1.5-5.5,4.6-9c2.4-2.7,5.8-5.8,9.5-8.2c8.9-5.8,16.3-7.4,20.1-4.7c1.2,0.9,1.7,2.3,1.8,3.9c0.2,4.2-3.5,9.8-10,15.5c-1.8,1.5-4.6,4.1-6,5.2C68,37.9,64.7,39.3,63.8,38.2z"/></svg>'''
CORAL_SVG = '''<svg viewBox="0 0 128 128" style="width:1em;height:1em;vertical-align:-0.15em" xmlns="http://www.w3.org/2000/svg"><ellipse cx="64" cy="112" rx="30" ry="8" fill="#c9836a"/><path fill="#ff8a5c" d="M64 108 C 60 90, 62 70, 58 50 C 56 40, 60 32, 58 20 C 57 14, 60 8, 63 6 C 66 8, 68 14, 66 20 C 64 32, 68 40, 65 50 C 68 70, 66 90, 68 108 Z"/><path fill="#ff9d6e" d="M50 106 C 44 92, 46 78, 38 66 C 33 58, 34 48, 28 40 C 24 35, 25 28, 29 24 C 33 27, 34 34, 32 40 C 37 48, 37 58, 42 66 C 48 78, 48 92, 56 106 Z"/><path fill="#ff9d6e" d="M78 106 C 84 92, 82 78, 90 66 C 95 58, 94 48, 100 40 C 104 35, 103 28, 99 24 C 95 27, 94 34, 96 40 C 91 48, 91 58, 86 66 C 80 78, 80 92, 72 106 Z"/><path fill="#ffb489" d="M56 108 C 50 98, 48 88, 40 82 C 35 78, 33 70, 27 66 C 23 63, 22 57, 25 53 C 29 56, 30 62, 28 66 C 33 70, 35 78, 41 82 C 47 88, 49 98, 58 108 Z"/><path fill="#ffb489" d="M72 108 C 78 98, 80 88, 88 82 C 93 78, 95 70, 101 66 C 105 63, 106 57, 103 53 C 99 56, 98 62, 100 66 C 95 70, 93 78, 87 82 C 81 88, 79 98, 70 108 Z"/><circle cx="63" cy="14" r="3.5" fill="#ffcaa8"/><circle cx="31" cy="30" r="3" fill="#ffcaa8"/><circle cx="97" cy="30" r="3" fill="#ffcaa8"/><circle cx="26" cy="58" r="2.5" fill="#ffcaa8"/><circle cx="102" cy="58" r="2.5" fill="#ffcaa8"/></svg>'''
FLOUR_SVG = '''<svg viewBox="0 0 128 128" style="width:1em;height:1em;vertical-align:-0.15em" xmlns="http://www.w3.org/2000/svg"><path fill="#d9b98c" d="M30 50 C 25 74, 24 96, 33 116 C 44 126, 84 126, 95 116 C 104 96, 103 74, 98 50 C 92 44, 36 44, 30 50 Z"/><path fill="#c7a578" d="M33 116 C 44 126, 84 126, 95 116 C 98 108, 99 100, 100 92 C 88 103, 40 103, 28 92 C 29 100, 30 108, 33 116 Z"/><path fill="#a9835a" d="M40 42 C 44 34, 84 34, 88 42 C 84 48, 44 48, 40 42 Z"/><path fill="#8a6a48" d="M52 30 L 58 42 L 50 42 Z"/><path fill="#faf6ea" d="M35 46 C 39 32, 89 32, 93 46 C 89 55, 39 55, 35 46 Z"/><circle cx="46" cy="44" r="2" fill="#e8d9b8"/><circle cx="64" cy="41" r="2" fill="#e8d9b8"/><circle cx="82" cy="44" r="2" fill="#e8d9b8"/><rect x="24" y="74" width="80" height="17" fill="#4a90d9"/><rect x="24" y="74" width="80" height="5" fill="#7ab6ec"/><circle cx="64" cy="82.5" r="10.5" fill="#f2c14e"/><path fill="#ffffff" d="M64 76 C 62 78, 62 82, 64 84 C 66 82, 66 78, 64 76 Z M64 78 C 60 80, 59 84, 61 88 C 63 86, 65 82, 64 78 Z M64 78 C 68 80, 69 84, 67 88 C 65 86, 63 82, 64 78 Z"/></svg>'''
reg_html = reg_html.replace("__ORCA__", ORCA_SVG).replace("__CORAL__", CORAL_SVG).replace("__FLOUR__", FLOUR_SVG)
cap_html = cap_html.replace("__ORCA__", ORCA_SVG).replace("__CORAL__", CORAL_SVG).replace("__FLOUR__", FLOUR_SVG)

(BUILD / "print_run_regular.html").write_text(reg_html, encoding="utf-8")
(BUILD / "print_run_capstone.html").write_text(cap_html, encoding="utf-8")

reg_total = len(reg_run)
cap_total = len(cap_run)
print(f"regular print run: {reg_total} cards ({len(REGULAR)} unique) across {len(list(chunk(reg_run, 9)))} pages")
print(f"capstone print run: {cap_total} cards ({len(CAPSTONES)} unique, "
      f"floor={CAPSTONE_FLOOR}) across {len(list(chunk(cap_run, 4)))} pages")
print(f"TOTAL cards to print: {reg_total + cap_total}")
