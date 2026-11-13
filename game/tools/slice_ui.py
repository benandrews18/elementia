# -*- coding: utf-8 -*-
"""
Cut the UI sprite sheets into one WebP per sprite in game/ui/.

    python game/tools/slice_ui.py

Sheets live in images/ (ui_sheet_v1.webp: transparent background;
ui_sheet_v2.webp: magenta background, keyed out here). Each sprite is a
named box (x, y, w, h) on its sheet, found once by hand from the sheet and
listed in SPRITES below. To change the art: replace a sheet, adjust its
boxes, rerun.

Edges: near-clear pixels become fully clear and near-solid fully solid (the
WebP sheets store "solid" as alpha ~253). Magenta is removed by un-mixing:
a pixel that is part sprite, part magenta gets its sprite colour back and
a matching alpha, so no pink fringe.
"""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "game" / "ui"
SHEETS = {"v1": REPO / "images" / "ui_sheet_v1.webp", "v2": REPO / "images" / "ui_sheet_v2.webp"}
PAD = 4

# name: (sheet, x, y, w, h)
SPRITES = {
    # Hub
    "hub_frame":        ("v1", 23, 23, 226, 211),
    "hub_frame_active": ("v1", 265, 23, 226, 211),
    "icon_todo":        ("v1", 535, 38, 147, 177),
    "icon_inventory":   ("v1", 716, 44, 171, 171),
    "icon_map":         ("v1", 919, 47, 186, 166),
    "icon_items":       ("v1", 1133, 46, 158, 173),
    "icon_market":      ("v1", 1329, 46, 169, 175),
    # Round buttons
    "btn_search":       ("v1", 53, 252, 160, 160),
    "btn_settings":     ("v1", 238, 251, 161, 160),
    "btn_quark":        ("v1", 431, 254, 158, 155),
    "btn_sort":         ("v1", 610, 254, 157, 155),
    "btn_filter":       ("v1", 790, 252, 159, 158),
    "btn_help":         ("v1", 967, 250, 158, 159),
    "btn_plus":         ("v1", 1148, 250, 158, 160),
    "btn_minus":        ("v1", 1327, 251, 159, 160),
    # Pills, windows
    "pill_long":        ("v1", 15, 639, 447, 134),
    "pill_short":       ("v1", 476, 651, 298, 111),
    "panel_parchment":  ("v1", 978, 632, 444, 264),
    "btn_close":        ("v1", 1423, 629, 107, 108),
    "banner_wood":      ("v1", 18, 836, 798, 152),
    # Station medallions (sheet 2, so all 8 match)
    "st_greenhouse":    ("v2", 18, 422, 173, 182),
    "st_forest":        ("v2", 193, 422, 168, 182),
    "st_deepmine":      ("v2", 364, 427, 163, 173),
    "st_powerplant":    ("v2", 530, 423, 166, 181),
    "st_ocean":         ("v2", 697, 423, 166, 181),
    "st_bakery":        ("v2", 1034, 423, 163, 181),
    "st_city":          ("v2", 1198, 422, 158, 182),
    "st_observatory":   ("v2", 1364, 422, 160, 182),
    "clock_rim":        ("v2", 776, 609, 213, 223),
}
MAGENTA = (250, 4, 250)


def clean_alpha(im):
    """Snap near-clear to clear and near-solid to solid."""
    a = im.getchannel("A").point(lambda v: 0 if v < 10 else 255 if v > 240 else v)
    im.putalpha(a)
    return im


def unkey_magenta(im):
    """Magenta background -> transparent, un-mixing the edge pixels."""
    px = im.load()
    w, h = im.size
    mr, mg, mb = MAGENTA
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            m = min(r, b) - g                       # how magenta it looks
            a = 1.0 if m <= 40 else 0.0 if m >= 200 else 1 - (m - 40) / 160
            if a <= 0:
                px[x, y] = (0, 0, 0, 0)
                continue
            if a < 1:  # observed = a*sprite + (1-a)*magenta
                r = (r - (1 - a) * mr) / a
                g = (g - (1 - a) * mg) / a
                b = (b - (1 - a) * mb) / a
            px[x, y] = (max(0, min(255, round(r))), max(0, min(255, round(g))),
                        max(0, min(255, round(b))), round(a * 255))
    return im


def keep_main_shape(im):
    """Clear everything not connected to the sprite's centre (slivers of a
    neighbour that touches it on the sheet)."""
    from collections import deque
    w, h = im.size
    a = im.getchannel("A").load()
    keep = bytearray(w * h)
    start = (w // 2, h // 2)
    # the centre can be clear (an empty ring): start from the nearest solid pixel to it
    if a[start] < 10:
        start = min(((x, y) for y in range(h) for x in range(w) if a[x, y] >= 10),
                    key=lambda p: (p[0] - w // 2) ** 2 + (p[1] - h // 2) ** 2)
    q = deque([start]); keep[start[1] * w + start[0]] = 1
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not keep[ny * w + nx] and a[nx, ny] >= 10:
                keep[ny * w + nx] = 1; q.append((nx, ny))
    px = im.load()
    for y in range(h):
        for x in range(w):
            if not keep[y * w + x]: px[x, y] = (0, 0, 0, 0)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {k: Image.open(p).convert("RGBA") for k, p in SHEETS.items()}
    total = 0
    for name, (sheet, x, y, w, h) in SPRITES.items():
        src = sheets[sheet]
        box = (max(0, x - PAD), max(0, y - PAD), min(src.width, x + w + PAD), min(src.height, y + h + PAD))
        im = src.crop(box)
        im = keep_main_shape(unkey_magenta(im) if sheet == "v2" else clean_alpha(im))
        out = OUT / f"{name}.webp"
        im.save(out, "WEBP", quality=88, method=6)
        total += out.stat().st_size
        print(f"{name:18} {im.size[0]}x{im.size[1]}  {out.stat().st_size // 1024} KB")
    print(f"{len(SPRITES)} sprites, {total // 1024} KB total -> {OUT}")


if __name__ == "__main__":
    sys.exit(main())
