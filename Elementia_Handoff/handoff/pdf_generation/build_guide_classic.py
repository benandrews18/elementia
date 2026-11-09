# -*- coding: utf-8 -*-
"""
Elementia -- Classic Mode Station Guide: the same per-station page layout
build_guide.py already uses (reused verbatim, not re-implemented), but with
each station's shop filtered down to CORE_SET -- Classic Mode's own
simplified catalog (see elementia.html's own CORE_SET, the source of
truth this reads from, same as everything else on this reads live data
rather than a stale copy). Capstones are never filtered -- every capstone
is core by construction (CORE_SET always lists it explicitly).
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

# ---- CORE_SET, read live from elementia.html (JS is the source of truth) --
import sys as _sys
_sys.path.insert(0, str(REPO / "game"))
from game_source import read_game_source  # noqa: E402  (page + every file it loads)
html = read_game_source()
m = re.search(r"const CORE_SET = new Set\(\[(.*?)\]\);", html, re.DOTALL)
if not m:
    raise SystemExit("Could not find CORE_SET in elementia.html")
CORE_PAIRS = set(re.findall(r'"([^"|]+)\|([^"]+)"', m.group(1)))

def core_shop(station):
    return [item for item in station["shop"] if (station["name"], item[1]) in CORE_PAIRS]

CLASSIC_STATIONS = []
for s in bg.STATIONS:
    s2 = dict(s)
    s2["shop"] = core_shop(s)
    CLASSIC_STATIONS.append(s2)
    print(f"{s['name']}: {len(s2['shop'])}/{len(s['shop'])} core items + capstone")

# ---- extra __MARKER__ icons build_guide.py doesn't itself hand-draw ------
# build_guide.py only ever hand-drew SVGs for Orca/Flour/Lighthouse/Tunnel;
# every other __MARKER__ item's art was instead made straight in
# elementia.html as CUSTOM_ICONS overrides (see game/tools/
# fetch_noto_icons.py's docstring) -- reuse build_guide.py's OWN
# EXTRA_MARKERS/extract_js_const for these rather than a second copy.
MARKER_CSS = ("<style>.diamondicon,.lifeicon,.ecosystemicon,.microchip,.rubbersq,"
              ".coral,.flour,.wheelicon,.furnaceicon,.ovenicon,.bananabreadicon,.turbineicon,"
              ".steelicon,.fossilicon,.concreteicon,.fiberglassicon,.logcabinicon"
              "{width:1em;height:1em;vertical-align:-.15em;display:inline-block}</style>")

# ---- render using build_guide.py's own page()/CSS/SVGs, unmodified -------
pages_html = "".join(bg.page(s, i + 1, len(CLASSIC_STATIONS)) for i, s in enumerate(CLASSIC_STATIONS))
html_out = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{bg.CSS}</style>{MARKER_CSS}</head><body>{pages_html}</body></html>"
html_out = (html_out
            .replace("__ORCA__", bg.ORCA_SVG)
            .replace("__LIGHTHOUSE__", bg.LIGHTHOUSE_SVG)
            .replace("__TUNNEL__", bg.TUNNEL_SVG))
for token, const_name in bg.EXTRA_MARKERS.items():
    if token in html_out:
        html_out = html_out.replace(token, bg.extract_js_const(const_name))

out_path = BUILD / "guide_classic.html"
out_path.write_text(html_out, encoding="utf-8")
print(f"\nwrote {out_path}  ({len(CLASSIC_STATIONS)} station pages)")
