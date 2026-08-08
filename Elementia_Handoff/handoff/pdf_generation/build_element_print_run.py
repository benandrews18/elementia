# -*- coding: utf-8 -*-
"""
Elementia -- the element-card PRINT RUN: each of the 16 raw elements,
repeated as many times as simulation/element_stock.py says the pool needs
to never run dry in a session, under the "spent and recycled" economy
(elements only return to the shared pool when crafted away; groups are
assumed to spend down surplus rather than hoard it -- see element_stock.py's
HAND_CAP for that assumption).

Quantities come from simulation/element_stock.json (regenerate it with
`python simulation/element_stock.py --json element_stock.json` after any
dice-pool change). Reuses build_element_cards.py's card markup/CSS so this
looks identical to the existing reference sheet -- just with repeats.
"""
import importlib.util, sys, json, pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
BUILD.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("bg", HERE / "build_guide.py")
bg = importlib.util.module_from_spec(spec)
sys.modules["bg"] = bg
spec.loader.exec_module(bg)
STATIONS = bg.STATIONS

# Element roster, suit palette, card markup, and CSS all live in
# build_element_cards.py -- imported rather than duplicated here, since a
# second hand-kept copy is exactly how this file drifted out of sync with
# the real 16-element roster before (it listed Tin/Gold, which haven't
# existed in the game for a while, and was missing Magnesium/Titanium).
ec_spec = importlib.util.spec_from_file_location("build_element_cards", HERE / "build_element_cards.py")
ec = importlib.util.module_from_spec(ec_spec)
ec_spec.loader.exec_module(ec)
ELEMENTS = ec.ELEMENTS
elem_card_html = ec.elem_card_html
CSS = ec.CSS

QTY_JSON = HERE.parent / "simulation" / "element_stock.json"

with open(QTY_JSON, encoding="utf-8") as f:
    QTY_ROWS = json.load(f)
QTY = {r["element"]: r["stock_qty"] for r in QTY_ROWS}


def chunk(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


run = []
for e in ELEMENTS:
    symbol = e[0]
    n = QTY.get(symbol)
    if n is None:
        raise SystemExit(f"No stock quantity found for '{symbol}' -- is "
                          f"element_stock.json stale relative to build_guide.py?")
    run.extend([e] * n)

cards_html = [elem_card_html(*e) for e in run]
pages = "".join(
    f'<div class="page-portrait">{"".join(page_cards)}</div>'
    for page_cards in chunk(cards_html, 9)
)
html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{pages}</body></html>"
(BUILD / "element_print_run.html").write_text(html, encoding="utf-8")
print(f"element print run: {len(run)} cards ({len(ELEMENTS)} unique) "
      f"across {len(list(chunk(cards_html, 9)))} pages")
