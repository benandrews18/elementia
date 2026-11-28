"""The check's Collections button tile (the user, 2026-11-28): the Draw tile
(assets/icons/v2/card_draw.png) with its card painted out in the tile's own
navy, and a gold star in the icon sheet's style (dark outline, one
highlight) -> assets/icons/v2/card_collections.png.

  python godot/tools/star_tile.py
"""
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
V2 = ROOT / "assets/icons/v2"


def star(cx: float, cy: float, r: float, k: float = 0.48) -> list:
    return [(cx + (r if i % 2 == 0 else r * k) * math.sin(i * math.pi / 5),
             cy - (r if i % 2 == 0 else r * k) * math.cos(i * math.pi / 5)) for i in range(10)]


def main() -> None:
    a = np.array(Image.open(V2 / "card_draw.png").convert("RGBA"))
    for y in range(26, 134):  # the card and its shadow: each row's own navy (taken left of the card)
        a[y, 26:134, :3] = a[y, 22, :3]
    im = Image.fromarray(a)
    d = ImageDraw.Draw(im)
    pts = star(80, 82, 46)
    d.polygon(pts, fill=(43, 26, 8, 255))  # the outline: the star drawn fat, dark
    d.line(pts + [pts[0]], fill=(43, 26, 8, 255), width=11, joint="curve")
    d.polygon(star(80, 82, 41), fill=(255, 201, 60, 255))
    d.polygon(star(76, 76, 20), fill=(255, 231, 140, 255))  # the highlight, top left
    im.save(V2 / "card_collections.png")
    print("saved", V2 / "card_collections.png")


if __name__ == "__main__":
    main()
