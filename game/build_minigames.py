# -*- coding: utf-8 -*-
"""
Inline the 8 station mini-games (game/minigames/*.js) into elementia.html.

Each mini-game file is a self-contained IIFE that assigns
`window.runMinigame` (the shared contract documented at the top of any file
in game/minigames/: runMinigame(container, onComplete), onComplete gets a
single 0..1 score). To run all 8 in one page without them clobbering each
other, each file is inlined as its own <script> tag immediately followed by
a tiny capture script that files the just-assigned `window.runMinigame` away
under `window.MINIGAMES[<station name>]` before the next file loads and
overwrites it.

The Artifact build (build_artifact.py) forbids <script src=""> tags (CSP
blocks the request), so this inlines file contents directly rather than
referencing them -- the same reasoning as why elementia.html is a single
file to begin with.

Usage:  python game/build_minigames.py
Then:   python game/build_minigames.py --check     (verify only, no write)
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TARGET = HERE / "elementia.html"
MINIGAMES_DIR = HERE / "minigames"

START, END = "<!--__MINIGAMES_START__-->", "<!--__MINIGAMES_END__-->"

# Station name (must match the "name" field in build_guide.py's STATIONS) ->
# its mini-game source file.
STATION_FILES = [
    ("The Ocean", "ocean-bubbles.js"),
    ("The Power Plant", "power-plant.js"),
    ("Greenhouse", "greenhouse.js"),
    ("Deep Mine", "deep-mine.js"),
    ("Old Growth Forest", "old-growth-forest.js"),
    ("The Bakery", "bakery.js"),
    ("The City", "the-city.js"),
    ("The Observatory", "observatory.js"),
]

# Backdrop/sprite paths the mini-games look up via window.MINIGAME_ASSETS
# (see backdropURL()/spriteURL() in any game/minigames/*.js). Using the same
# quoted "backdrops/<name>.webp" literal that build_artifact.py already
# scans for means the Artifact build inlines these as data URIs for free.
# "minigames/deep-mine-rock.webp" needs that script's LOCAL_IMG_RE extended
# with a "minigames" prefix to get the same treatment (see build_artifact.py).
ASSETS = {
    "ocean.webp": "backdrops/ocean.webp",
    "power-plant.webp": "backdrops/power-plant.webp",
    "greenhouse.webp": "backdrops/greenhouse.webp",
    "deep-mine.webp": "backdrops/deep-mine.webp",
    "old-growth-forest.webp": "backdrops/old-growth-forest.webp",
    "bakery.webp": "backdrops/bakery.webp",
    "quarry.webp": "backdrops/quarry.webp",
    "observatory.webp": "backdrops/observatory.webp",
    "deep-mine-rock.webp": "minigames/deep-mine-rock.webp",
}


def build_block():
    lines = [START, "<script>", "window.MINIGAME_ASSETS = {"]
    for k, v in ASSETS.items():
        lines.append(f'  "{k}": "{v}",')
    lines += ["};", "window.MINIGAMES = {};", "</script>"]
    for station, fname in STATION_FILES:
        path = MINIGAMES_DIR / fname
        if not path.exists():
            raise SystemExit(f"Missing mini-game source: {path}")
        src = path.read_text(encoding="utf-8")
        if "</script" in src.lower():
            raise SystemExit(f"{path} contains a literal '</script' -- cannot inline safely")
        lines.append(f"<script>\n{src}\n</script>")
        esc = station.replace('"', '\\"')
        lines.append(
            f'<script>window.MINIGAMES["{esc}"] = window.runMinigame; '
            f'window.runMinigame = null;</script>'
        )
    lines.append(END)
    return "\n".join(lines)


def main():
    check_only = "--check" in sys.argv
    html = TARGET.read_text(encoding="utf-8")
    a, b = html.find(START), html.find(END)
    if a < 0 or b < 0:
        raise SystemExit(f"Markers {START}/{END} not found in {TARGET}")
    block = build_block()
    current = html[a:b + len(END)]
    if current == block:
        print("elementia.html: mini-games in sync")
        return
    if check_only:
        raise SystemExit("elementia.html: mini-games OUT OF SYNC -- run without --check to fix")
    new_html = html[:a] + block + html[b + len(END):]
    TARGET.write_text(new_html, encoding="utf-8")
    print(f"elementia.html: inlined {len(STATION_FILES)} mini-games")


if __name__ == "__main__":
    main()
