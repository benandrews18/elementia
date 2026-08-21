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
html = (REPO / "game" / "elementia.html").read_text(encoding="utf-8")
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

# ---- extra __MARKER__ icons build_guide.py doesn't itself resolve --------
# build_guide.py only ever hand-drew SVGs for Orca/Coral/Flour/Lighthouse/
# Tunnel; every newer __MARKER__ item (Diamond, Ecosystem, Life, Microchip,
# Rubber, ...) instead got its art made straight in elementia.html as
# CUSTOM_ICONS overrides (see game/tools/fetch_noto_icons.py's docstring).
# Pull those same consts out of the live game file so Classic Mode's core
# items that use them (Diamond, Ecosystem, Life, Microchip, Rubber) render
# with the game's actual art instead of literal "__LIFE__" placeholder text.
EXTRA_MARKERS = {"__DIAMOND__": "DIAMOND_IMG", "__ECOSYSTEM__": "ECOSYSTEM_IMG",
                  "__LIFE__": "LIFE_IMG", "__MICROCHIP__": "MICROCHIP_IMG",
                  "__RUBBER__": "RUBBER_SVG"}

def extract_js_const(src, name):
    m = re.search(r"const " + name + r" = '(.*?)';", src)
    if not m:
        raise SystemExit(f"Could not find const {name} in elementia.html")
    return m.group(1)

MARKER_CSS = ("<style>.diamondicon,.lifeicon,.ecosystemicon,.microchip,.rubbersq"
              "{width:1em;height:1em;vertical-align:-.15em;display:inline-block}</style>")

# ---- render using build_guide.py's own page()/CSS/SVGs, unmodified -------
pages_html = "".join(bg.page(s, i + 1, len(CLASSIC_STATIONS)) for i, s in enumerate(CLASSIC_STATIONS))
html_out = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{bg.CSS}</style>{MARKER_CSS}</head><body>{pages_html}</body></html>"
html_out = (html_out
            .replace("__ORCA__", bg.ORCA_SVG)
            .replace("__CORAL__", bg.CORAL_SVG)
            .replace("__FLOUR__", bg.FLOUR_SVG)
            .replace("__LIGHTHOUSE__", bg.LIGHTHOUSE_SVG)
            .replace("__TUNNEL__", bg.TUNNEL_SVG))
for token, const_name in EXTRA_MARKERS.items():
    if token in html_out:
        html_out = html_out.replace(token, extract_js_const(html, const_name))

out_path = BUILD / "guide_classic.html"
out_path.write_text(html_out, encoding="utf-8")
print(f"\nwrote {out_path}  ({len(CLASSIC_STATIONS)} station pages)")
