# -*- coding: utf-8 -*-
"""
Elementia — printable Item Reference sheet: every item in the game as a
table (name, tier, made from, built at), grouped by tier. The print
equivalent of the in-game "Item Reference" screen (elementia.html's
renderCodex()) -- keep the two in visual/content sync if either changes.
"""
import importlib.util, sys, re, pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
BUILD.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("bg", HERE / "build_guide.py")
bg = importlib.util.module_from_spec(spec)
sys.modules["bg"] = bg
spec.loader.exec_module(bg)
STATIONS = bg.STATIONS
SUITS = bg.SUITS

TIER_ORDER = ["MATERIAL", "COMPONENT", "CREATION", "CAPSTONE"]
TIER_COLORS = {
    "MATERIAL":  "#8a94a6",
    "COMPONENT": "#3b7fc4",
    "CREATION":  "#3fa66b",
    "CAPSTONE":  "#c79a2e",
}
TIER_SOFT = {
    "MATERIAL":  "#f2f3f5",
    "COMPONENT": "#eaf1fb",
    "CREATION":  "#eaf7ef",
    "CAPSTONE":  "#fdf6e6",
}

CSS = """
@page { size: 8.5in 11in; margin: 0; }
* { box-sizing:border-box; margin:0; padding:0; }
body { font-family:'Helvetica Neue',Arial,sans-serif; color:#1f2733;
  -webkit-print-color-adjust:exact; print-color-adjust:exact; }
.page { width:8.5in; height:11in; padding:0.35in; page-break-after:always; }
.sheet { width:100%; height:100%; border-radius:16px; border:1px solid #e4e7ec;
  display:flex; flex-direction:column; overflow:hidden; }

.colhead { display:grid; grid-template-columns:1.1fr 0.65fr 0.5fr 1.95fr 1.25fr;
  gap:10px; padding:12px 18px; font-size:10px; font-weight:800; letter-spacing:1px;
  color:#98a2b3; border-bottom:1.5px solid #eceff3; }

.rows { flex:1; padding:2px 14px 8px; overflow:hidden; }
.row { display:grid; grid-template-columns:1.1fr 0.65fr 0.5fr 1.95fr 1.25fr;
  gap:10px; align-items:center; padding:6px 4px; border-bottom:1px solid #f2f4f7; }
.cItem { display:flex; align-items:center; gap:7px; min-width:0; }
.iem { font-size:17px; flex:none; width:22px; text-align:center; }
.iname { font-size:13.5px; font-weight:800; }
.tierbadge { display:inline-block; font-size:8.5px; font-weight:800; letter-spacing:.5px;
  color:#fff; padding:2px 6px; border-radius:5px; }
.ptsbadge { display:inline-block; font-size:10px; font-weight:800; color:#946200;
  background:#fdf1d6; border:1px solid #f0d9a8; border-radius:999px; padding:2px 8px;
  white-space:nowrap; }
.cMake { display:flex; flex-wrap:wrap; gap:3px; align-items:center; }
.tok { display:inline-flex; align-items:center; font-weight:700; font-size:10.5px;
  padding:2px 6px; border-radius:5px; }
.tok.elem { border:1.5px solid #3a4250; font-weight:800; }
.tok.item { background:#eef1f4; }
.plus { color:#a8b0bc; font-weight:700; font-size:10px; }
.notspent { font-size:7.5px; font-weight:800; letter-spacing:.3px; color:#b7791f; }
.cWhere { display:flex; flex-wrap:wrap; gap:3px; }
.whereChip { font-size:9.5px; font-weight:700; color:#475467; background:#f7f8fa;
  border:1px solid #eceff3; border-radius:5px; padding:2px 6px; white-space:nowrap; }

.sectionhead { display:flex; justify-content:space-between; align-items:center;
  margin:8px 0 3px; padding:5px 10px; border-radius:7px; border-left:5px solid;
  font-size:11.5px; font-weight:800; letter-spacing:.7px; }
.scount { font-size:9.5px; font-weight:700; color:#667085; letter-spacing:.3px; }

.sfoot { margin-top:auto; display:flex; justify-content:space-between; align-items:center;
  padding:8px 18px 10px; font-size:10px; color:#98a2b3; border-top:1px solid #f2f4f7; }
"""


def parse_token(tok):
    """Return (kind, emoji_or_None, name) for one '+'-joined recipe token."""
    tok = tok.strip()
    if re.fullmatch(r"[A-Z][a-z]?", tok):
        return "element", None, tok
    parts = tok.split(" ", 1)
    if len(parts) == 2:
        return "item", parts[0], parts[1]
    return "item", None, tok


def collect_items():
    """One row per unique item name, tier-first then station-appearance
    order, each carrying every station it's sold at."""
    rows, order, homes = {}, [], {}

    def visit(emoji, name, tier, recipe, points, station_name):
        if name not in rows:
            rows[name] = {"emoji": emoji, "name": name, "tier": tier, "recipe": recipe, "points": points}
            order.append(name)
            homes[name] = []
        homes[name].append(station_name)

    for s in STATIONS:
        for emoji, name, tier, recipe, points in s["shop"]:
            visit(emoji, name, tier, recipe, points, s["name"])
        if s.get("farm_section"):   # legacy shape; removed 2026-07-29
            for emoji, name, tier, recipe, points in s["farm_section"]["items"]:
                visit(emoji, name, tier, recipe, points, s["name"])
        ce, cn, ct, cr, cpts = s["capstone"]
        visit(ce, cn, ct, cr, cpts, s["name"])

    out = []
    for name in order:
        r = rows[name]
        r["homes"] = sorted(set(homes[name]), key=lambda h: [s["name"] for s in STATIONS].index(h))
        out.append(r)
    return out


def recipe_html(entry):
    tokens = [parse_token(t) for t in entry["recipe"].split("+")]
    # Elements before items, always (matches sortIngredientTokens() in the
    # digital game) -- Python's sort is stable, so this is a partition,
    # each group keeping its own original relative order.
    tokens.sort(key=lambda t: 0 if t[0] == "element" else 1)
    seen, pills = set(), []
    for kind, emoji, name in tokens:
        key = (kind, name)
        if key in seen:
            continue
        seen.add(key)
        if kind == "element":
            pills.append(f'<span class="tok elem">{name}</span>')
        else:
            pills.append(f'<span class="tok item">{emoji or ""} {name}</span>')
    return '<span class="plus">+</span>'.join(pills)


def where_html(entry):
    return "".join(
        f'<span class="whereChip">{s["emoji"]} {s["name"]}</span>'
        for st in entry["homes"] for s in STATIONS if s["name"] == st
    )


def row_html(entry):
    color = TIER_COLORS[entry["tier"]]
    return f"""
    <div class="row">
      <div class="cItem"><span class="iem">{entry['emoji']}</span>
        <span class="iname">{entry['name']}</span></div>
      <div class="cTier"><span class="tierbadge" style="background:{color}">{entry['tier']}</span></div>
      <div class="cPoints"><span class="ptsbadge">⭐ {entry['points']}</span></div>
      <div class="cMake">{recipe_html(entry)}</div>
      <div class="cWhere">{where_html(entry)}</div>
    </div>"""


def section_header(tier, count):
    return f"""
    <div class="sectionhead" style="background:{TIER_SOFT[tier]};border-color:{TIER_COLORS[tier]}">
      <span>{tier}</span><span class="scount">{count} item{'s' if count != 1 else ''}</span>
    </div>"""


ITEMS = collect_items()
ITEMS.sort(key=lambda r: (TIER_ORDER.index(r["tier"]), r["name"]))

blocks = []
for tier in TIER_ORDER:
    group = [r for r in ITEMS if r["tier"] == tier]
    blocks.append(("head", tier, len(group)))
    for r in group:
        blocks.append(("row", r, None))


def block_html(b):
    kind, a, c = b
    return section_header(a, c) if kind == "head" else row_html(a)


# ---- paginate against REAL rendered heights, not a guessed row budget -----
# A fixed "N rows per page" estimate has no way to know some recipes wrap to
# two lines and others don't, so it has to leave slack to stay safe -- which
# is exactly the blank space at the bottom of pages this replaces. Instead:
# render every block once in the exact final width, measure each one's true
# on-screen height (offsetTop deltas, so sibling margin-collapsing is
# captured correctly rather than guessed), then bin-pack pages against the
# real per-page budget. Only the last page can be less than full, which is
# unavoidable -- there just aren't enough rows left to fill it.
from playwright.sync_api import sync_playwright

DPI = 96
PAGE_W_IN, PAGE_H_IN, PAD_IN = 8.5, 11, 0.35
SHEET_W_PX = (PAGE_W_IN - 2 * PAD_IN) * DPI
SHEET_H_PX = (PAGE_H_IN - 2 * PAD_IN) * DPI
ROWS_W_PX = SHEET_W_PX - 2 * 14   # .rows horizontal padding is 14px each side

measure_body = "".join(f'<div class="mblock">{block_html(b)}</div>' for b in blocks)
# CSS is a plain-text blob full of literal braces -- concatenate it, don't
# run it through another .format()/f-string pass or those braces collide.
extra_css = f".mrows{{width:{ROWS_W_PX}px}}"
full_css = CSS + extra_css
measure_html = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>{full_css}</style></head><body>
<div class="colhead" id="mColhead"><div>ITEM</div><div>TIER</div><div>PTS</div><div>MADE FROM</div><div>BUILD AT</div></div>
<footer class="sfoot" id="mFoot"><span>Elementia</span><span>1 / 1</span></footer>
<div class="rows mrows" id="mRows" style="overflow:visible">{measure_body}</div>
</body></html>"""

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": int(ROWS_W_PX) + 60, "height": 3000})
    (BUILD / "_measure.html").write_text(measure_html, encoding="utf-8")
    page.goto((BUILD / "_measure.html").as_uri(), wait_until="networkidle")
    tops = page.eval_on_selector_all(
        "#mRows > .mblock", "els => els.map(e => e.offsetTop)")
    rows_total = page.eval_on_selector("#mRows", "e => e.scrollHeight")
    colhead_h = page.eval_on_selector("#mColhead", "e => e.getBoundingClientRect().height")
    foot_h = page.eval_on_selector("#mFoot", "e => e.getBoundingClientRect().height")
    browser.close()
(BUILD / "_measure.html").unlink()

# consumed height of block i = distance to the next block's top (last block
# runs to the container's true bottom, i.e. scrollHeight)
heights = [(tops[i + 1] if i + 1 < len(tops) else rows_total) - tops[i]
           for i in range(len(tops))]

ROWS_BUDGET_PX = SHEET_H_PX - colhead_h - foot_h


def paginate(blocks, heights, budget):
    pages, cur, cur_h = [], [], 0
    for b, h in zip(blocks, heights):
        if cur and cur_h + h > budget:
            pages.append(cur); cur, cur_h = [], 0
        cur.append(b); cur_h += h
    if cur:
        pages.append(cur)
    return pages


PAGES = paginate(blocks, heights, ROWS_BUDGET_PX)


def page_html(blocks_on_page, idx, total):
    body = []
    for kind, a, b in blocks_on_page:
        body.append(section_header(a, b) if kind == "head" else row_html(a))
    return f"""
    <section class="page"><div class="sheet">
      <div class="colhead">
        <div>ITEM</div><div>TIER</div><div>PTS</div><div>MADE FROM</div><div>BUILD AT</div>
      </div>
      <div class="rows">{"".join(body)}</div>
      <footer class="sfoot"><span>Elementia · v{bg.CONTENT_VERSION}</span><span>{idx} / {total}</span></footer>
    </div></section>"""


pages_html = "\n".join(page_html(p, i + 1, len(PAGES)) for i, p in enumerate(PAGES))
html = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{pages_html}</body></html>"""
html = html.replace("__ORCA__", bg.ORCA_SVG).replace("__CORAL__", bg.CORAL_SVG).replace("__FLOUR__", bg.FLOUR_SVG)

(BUILD / "item_reference.html").write_text(html, encoding="utf-8")
print(f"item reference: {len(ITEMS)} items across {len(PAGES)} pages")
