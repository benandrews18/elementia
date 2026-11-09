# -*- coding: utf-8 -*-
"""
Elementia -- Classic Station Guide: one page per station, using
build_guide.py's page layout and the game's own station data.
"""
import importlib.util, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
BUILD.mkdir(parents=True, exist_ok=True)
REPO = HERE.parent

spec = importlib.util.spec_from_file_location("bg", HERE / "build_guide.py")
bg = importlib.util.module_from_spec(spec)
sys.modules["bg"] = bg
spec.loader.exec_module(bg)

CLASSIC_STATIONS = bg.STATIONS

# ---- extra __MARKER__ icons build_guide.py doesn't itself hand-draw ------
# build_guide.py only ever hand-drew SVGs for Orca/Flour/Lighthouse;
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
            .replace("__LIGHTHOUSE__", bg.LIGHTHOUSE_SVG))
for token, const_name in bg.EXTRA_MARKERS.items():
    if token in html_out:
        html_out = html_out.replace(token, bg.extract_js_const(const_name))

out_path = BUILD / "guide_classic.html"
out_path.write_text(html_out, encoding="utf-8")
print(f"\nwrote {out_path}  ({len(CLASSIC_STATIONS)} station pages)")
