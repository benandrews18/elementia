"""Professor Mouse's Quick Rules poses: art_reference/mouse_poses/*.png (the
user's 32 crops) -> assets/mouse_qr/<name>.webp, cleaned for the game:
stray bits of the neighbouring poses (small pieces touching the crop's edge)
removed, trimmed to the mouse, 360 px tall.

  python godot/tools/mouse_poses.py
"""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT.parent / "art_reference/mouse_poses"
OUT = ROOT / "assets/mouse_qr"
H = 360


def clean(im: Image.Image) -> Image.Image:
    a = np.array(im)
    solid = a[:, :, 3] > 24
    lab, n = ndimage.label(solid, structure=np.ones((3, 3)))
    if n == 0:
        return im
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    big = sizes.max()
    keep = np.zeros(n + 1, bool)
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        edge = ys.min() == 0 or xs.min() == 0 or ys.max() == a.shape[0] - 1 or xs.max() == a.shape[1] - 1
        # a piece of another pose: touching the crop's edge and much smaller than the mouse
        keep[i] = not (edge and sizes[i - 1] < big * 0.15) and sizes[i - 1] > 12
    mask = keep[lab]
    # soft edges next to kept pixels stay (anti-aliasing), the rest goes
    near = ndimage.binary_dilation(mask, iterations=2)
    a[:, :, 3] = np.where(near, a[:, :, 3], 0)
    # The ground smudge under his feet: pale, greyish, partly see-through, low down.
    ys = np.where(a[:, :, 3] > 24)[0]
    if ys.size:
        top, bot = ys.min(), ys.max()
        low = np.zeros(a.shape[:2], bool)
        low[int(bot - (bot - top) * 0.14):, :] = True
        rgb = a[:, :, :3].astype(float)
        pale = (rgb.mean(axis=2) > 150) & (rgb.max(axis=2) - rgb.min(axis=2) < 40) & (a[:, :, 3] < 235)
        a[:, :, 3] = np.where(low & pale, 0, a[:, :, 3])

    # The background removal left the white coat half see-through: inside the
    # silhouette (not its soft outer edge), anything partly there is put on white.
    inside = ndimage.binary_erosion(ndimage.binary_fill_holes(a[:, :, 3] > 24), iterations=1) & (a[:, :, 3] >= 12)
    al = a[:, :, 3:4].astype(float) / 255
    flat = (a[:, :, :3] * al + 255 * (1 - al)).astype(np.uint8)
    a[:, :, :3] = np.where(inside[:, :, None], flat, a[:, :, :3])
    a[:, :, 3] = np.where(inside, 255, a[:, :, 3])
    # The old background's pale halo round his outline (the coat is solid by now)
    sil = ndimage.binary_fill_holes(a[:, :, 3] > 24)
    band = sil & ~ndimage.binary_erosion(sil, iterations=4)
    rgb = a[:, :, :3].astype(float)
    halo = (rgb.mean(axis=2) > 170) & (rgb.max(axis=2) - rgb.min(axis=2) < 40) & (a[:, :, 3] < 200)
    a[:, :, 3] = np.where(band & halo, 0, a[:, :, 3])
    out = Image.fromarray(a)
    return out.crop(out.getbbox())


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for p in sorted(SRC.glob("*.png")):
        im = clean(Image.open(p).convert("RGBA"))
        im = im.resize((round(im.width * H / im.height), H), Image.LANCZOS)
        im.save(OUT / (p.stem + ".webp"), quality=90)
    print("saved", len(list(OUT.glob("*.webp"))), "poses to", OUT)


if __name__ == "__main__":
    main()
