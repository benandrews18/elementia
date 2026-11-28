"""The user's icon sheet (art_reference/icon_sheet_v2.png, 2026-11-27) cut
into the game's icons: assets/icons/v2/<name>.png, 160 px, transparent.
Each icon has a dark outline: everything outside it (the sheet's dark
background and its glow) is cleared by filling in from the crop's edges
through anything that isn't outline.

  python godot/tools/sheet_icons.py
"""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SHEET = ROOT.parent / "art_reference/icon_sheet_v2.png"
OUT = ROOT / "assets/icons/v2"
PX = 160

# name: (left, top, right, bottom) on the 1536x1024 sheet
BOXES = {
    "suit_organic": (68, 10, 272, 212), "suit_reactive": (316, 10, 520, 212),
    "suit_earth": (552, 10, 756, 212), "suit_metal": (786, 10, 990, 212),
    "st_ocean": (38, 228, 238, 410), "st_power": (250, 228, 410, 410), "st_greenhouse": (420, 222, 592, 418),
    "st_mine": (596, 228, 768, 410), "st_forest": (760, 216, 932, 418), "st_bakery": (932, 236, 1120, 412),
    "st_city": (1124, 222, 1318, 410), "st_observatory": (1322, 214, 1510, 410),
    "card_discard": (38, 428, 268, 608), "card_goal": (284, 428, 514, 608), "card_pass": (530, 428, 760, 608),
    "card_deck": (782, 428, 1012, 608), "card_draw": (1030, 428, 1252, 608), "card_hand": (1274, 428, 1502, 608),
    "quark": (308, 618, 482, 790), "dice": (556, 618, 736, 790), "unknown": (806, 618, 970, 785),
    "pin": (1058, 606, 1232, 790), "track": (1298, 612, 1500, 800),
}


def cut(im: Image.Image) -> Image.Image:
    a = np.array(im.convert("RGBA")).astype(float)
    lum = a[:, :, :3] @ [0.299, 0.587, 0.114]
    outline = lum < 46  # the icons' dark outlines (and the deepest shadows)
    free = ~outline
    lab, n = ndimage.label(free)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    # the outline's own outer rim is background-dark too: grow the icon one pixel back into it
    keep = ndimage.binary_dilation(~bg, iterations=1) & ~(bg & (lum > 46))
    # a dark outline pixel counts only next to the icon (not the dark background around it)
    keep &= ndimage.binary_dilation(~bg, iterations=3)
    lab2, n2 = ndimage.label(keep)
    if n2:
        sizes = ndimage.sum(keep, lab2, range(1, n2 + 1))
        keep = lab2 == (1 + int(np.argmax(sizes)))
        keep = ndimage.binary_fill_holes(keep)
    alpha = ndimage.gaussian_filter(keep.astype(float), 0.7) * 255
    a[:, :, 3] = np.minimum(a[:, :, 3], alpha)
    out = Image.fromarray(a.astype(np.uint8))
    return out.crop(out.getbbox())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SHEET)
    for name, box in BOXES.items():
        ic = cut(sheet.crop(box))
        s = PX / max(ic.size)
        ic = ic.resize((max(1, round(ic.width * s)), max(1, round(ic.height * s))), Image.LANCZOS)
        sq = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
        sq.alpha_composite(ic, ((PX - ic.width) // 2, (PX - ic.height) // 2))
        sq.save(OUT / f"{name}.png")
    print("saved", len(BOXES), "icons to", OUT)


if __name__ == "__main__":
    main()
