# -*- coding: utf-8 -*-
"""
The game's full source as one string: elementia.html followed by every local
stylesheet and script it loads (css/*.css, assets/images.js, js/*.js,
minigames/*.js), in page order.

The PDF, card-game, board-game and tooling scripts pull constants such as
CORE_SET, ITEM_SUIT_COST_TABLE or the custom icon SVGs out of the game with
text searches. Those constants now live in separate files, so readers call
read_game_source() instead of reading elementia.html directly; a search
then works no matter which file a constant sits in.

    import sys; sys.path.insert(0, str(<repo>/"game"))
    from game_source import read_game_source
"""
import re
from pathlib import Path

GAME_DIR = Path(__file__).resolve().parent
PAGE = GAME_DIR / "elementia.html"

_LOCAL_REF = re.compile(
    r'<script src="(?!https?:)([^"]+)"></script>'
    r'|<link rel="stylesheet" href="(?!https?:)([^"]+)">'
)


def local_files(page=PAGE):
    """Every local script/stylesheet path the page loads, in order."""
    html = Path(page).read_text(encoding="utf-8")
    return [Path(page).parent / (a or b) for a, b in _LOCAL_REF.findall(html)]


def read_game_source(page=PAGE):
    """elementia.html + each loaded local file, joined in page order."""
    parts = [Path(page).read_text(encoding="utf-8")]
    for p in local_files(page):
        parts.append(f"\n/* ==== {p.relative_to(GAME_DIR).as_posix()} ==== */\n")
        parts.append(p.read_text(encoding="utf-8"))
    return "".join(parts)
