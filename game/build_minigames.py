# -*- coding: utf-8 -*-
"""
Inline the 8 station mini-games (game/minigames/*.js) into the landscape
edition (elementia_landscape.html).

The portrait game (elementia.html) loads them with <script src> tags
instead, and build_artifact.py inlines those for the Artifact build; this
script only serves the landscape file, which rewrites the mini-games'
viewport units for its fixed stage.

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
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TARGETS = [HERE / "elementia_landscape.html"]
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
    "cake-middle-brown.webp": "minigames/cake-middle-brown.webp",
    "cake-middle-pink.webp": "minigames/cake-middle-pink.webp",
    "cake-middle-white.webp": "minigames/cake-middle-white.webp",
}


# The landscape edition renders inside a fixed 915x412 stage, so viewport units
# in the inlined mini-game CSS are rewritten to the stage's own --vw/--vh vars
# (same rewrite applied to the landscape file's own CSS).
_VU = re.compile(r"(?<![A-Za-z0-9_.-])([0-9]*[.]?[0-9]+)(vh|vw)")


def stage_units(src):
    return _VU.sub(lambda m: f"calc({m.group(1)} * var(--{m.group(2)}))", src)


def build_block(landscape=False):
    lines = [START, "<script>", "window.MINIGAME_ASSETS = {"]
    for k, v in ASSETS.items():
        lines.append(f'  "{k}": "{v}",')
    lines += ["};", "window.MINIGAMES = {};", "</script>"]
    for station, fname in STATION_FILES:
        path = MINIGAMES_DIR / fname
        if not path.exists():
            raise SystemExit(f"Missing mini-game source: {path}")
        src = path.read_text(encoding="utf-8")
        if landscape:
            src = stage_units(src)
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


def sync_one(target, check_only):
    html = target.read_text(encoding="utf-8")
    a, b = html.find(START), html.find(END)
    if a < 0 or b < 0:
        raise SystemExit(f"Markers {START}/{END} not found in {target}")
    block = build_block(landscape=target.name == "elementia_landscape.html")
    current = html[a:b + len(END)]
    if current == block:
        print(f"{target.name}: mini-games in sync")
        return
    if check_only:
        raise SystemExit(f"{target.name}: mini-games OUT OF SYNC -- run without --check to fix")
    target.write_text(html[:a] + block + html[b + len(END):], encoding="utf-8")
    print(f"{target.name}: inlined {len(STATION_FILES)} mini-games")


def main():
    check_only = "--check" in sys.argv
    for t in TARGETS:
        sync_one(t, check_only)


if __name__ == "__main__":
    main()
