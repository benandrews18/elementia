# -*- coding: utf-8 -*-
"""
Process the hand-illustrated campaign art in images/ into the optimized
assets the game actually loads:

  - images/Welcome Screen.png -> game/tutorial/0.webp
    Prepended to the guided tour as its opening slide (same treatment as
    the other tour slides -- see build_tutorial_assets.py, which this
    doesn't replace: that script still owns tutorial/N.png -> game/tutorial/N.webp
    if/when there's a tutorial/ source folder to regenerate from again).
  - images/<Station>.png -> game/backdrops/<slug>.webp, one per station
    Shown faded behind that station's own screen -- elementia.html applies
    the fade/wash at render time; this script only resizes/compresses.
  - images/<Station> Banner.png -> game/banners/<slug>.webp, one per station
    Shown behind that station's card on the map screen, same
    resize/compress-only split of responsibility as the backdrops above.

images/Elementia Logo.png is intentionally skipped -- reference art only,
not used anywhere in the game.

Usage:
    python game/build_campaign_art.py
"""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    raise SystemExit("Pillow is required: pip install Pillow")

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "images"
TOUR_OUT = HERE / "tutorial"
BACKDROP_OUT = HERE / "backdrops"
BANNER_OUT = HERE / "banners"

WELCOME_SRC = "Welcome Screen.png"
WELCOME_WIDTH, WELCOME_QUALITY = 800, 80   # matches build_tutorial_assets.py

BACKDROP_WIDTH, BACKDROP_QUALITY = 700, 75  # shown faded -- lower fidelity is fine
# Source filename -> (station name, output slug). Filenames don't consistently
# match station names (e.g. "Power Plant.png" for "The Power Plant", "Bakery.png"
# for "The Bakery"), so this mapping is explicit rather than derived -- it's also
# the one place that pairs each station with its art, so elementia.html's
# STATION_BG map should mirror it.
BACKDROPS = {
    "The Ocean.png":         ("The Ocean",        "ocean"),
    "Power Plant.png":       ("The Power Plant",   "power-plant"),
    "Greenhouse.png":        ("Greenhouse",        "greenhouse"),
    "Deep Mine.png":         ("Deep Mine",         "deep-mine"),
    "Old Growth Forest.png": ("Old Growth Forest", "old-growth-forest"),
    "Bakery.png":            ("The Bakery",        "bakery"),
    "The Quarry.png":        ("The Quarry",        "quarry"),
    "Observatory.png":       ("The Observatory",   "observatory"),
}

BANNER_WIDTH, BANNER_QUALITY = 700, 78  # wide/short station-card art, shown faded too
# Same stations as BACKDROPS (and the same output slugs, deliberately, so
# elementia.html's per-station lookups share one slug per station) but a
# differently-irregular set of source filenames -- kept as its own explicit
# mapping rather than derived from BACKDROPS, since neither set of filenames
# is mechanically derivable from the other.
BANNERS = {
    "Ocean Banner.png":             ("The Ocean",        "ocean"),
    "Power Plant Banner.png":       ("The Power Plant",   "power-plant"),
    "Greenhouse Banner.png":        ("Greenhouse",        "greenhouse"),
    "Deep Mine Banner.png":         ("Deep Mine",         "deep-mine"),
    "Old Growth Forest Banner.png": ("Old Growth Forest", "old-growth-forest"),
    "Bakery Banner.png":            ("The Bakery",        "bakery"),
    "Quarry Banner.png":            ("The Quarry",        "quarry"),
    "Observatory Banner.png":       ("The Observatory",   "observatory"),
}


def save_webp(src_path, dest_path, width, quality):
    im = Image.open(src_path).convert("RGB")
    w = min(width, im.width)
    h = round(im.height * w / im.width)
    im.resize((w, h), Image.LANCZOS).save(dest_path, "WEBP", quality=quality, method=6)
    return src_path.stat().st_size / 1024, dest_path.stat().st_size / 1024


def process_set(mapping, out_dir, width, quality):
    out_dir.mkdir(parents=True, exist_ok=True)
    for fname, (station, slug) in mapping.items():
        src = SRC / fname
        if not src.exists():
            raise SystemExit(f'Missing {src} (expected art for "{station}")')
        dest = out_dir / f"{slug}.webp"
        in_kb, out_kb = save_webp(src, dest, width, quality)
        print(f"  {fname} -> {out_dir.name}/{slug}.webp  {in_kb:.0f}KB -> {out_kb:.0f}KB")


def main():
    if not SRC.is_dir():
        raise SystemExit(f"No source folder at {SRC}")

    TOUR_OUT.mkdir(parents=True, exist_ok=True)
    welcome_src = SRC / WELCOME_SRC
    if not welcome_src.exists():
        raise SystemExit(f"Missing {welcome_src}")
    dest = TOUR_OUT / "0.webp"
    in_kb, out_kb = save_webp(welcome_src, dest, WELCOME_WIDTH, WELCOME_QUALITY)
    print(f"  {WELCOME_SRC} -> tutorial/0.webp  {in_kb:.0f}KB -> {out_kb:.0f}KB")

    process_set(BACKDROPS, BACKDROP_OUT, BACKDROP_WIDTH, BACKDROP_QUALITY)
    process_set(BANNERS, BANNER_OUT, BANNER_WIDTH, BANNER_QUALITY)

    print('Done. Update elementia.html\'s TOUR_SLIDES / STATION_BG / STATION_BANNER '
          "if station names or the slide order changed.")


if __name__ == "__main__":
    main()
