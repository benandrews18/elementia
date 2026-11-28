"""Makes assets/icons/suit_disc_<suit>.png: a suit's icon on its coloured
circle with a dark rim, as the item cards' suit pips draw it (ItemCard), for
text that can only show images ({suit:x} in ParchDialog.emojify).

  python godot/tools/suit_discs.py
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
N, SS = 96, 4  # size, supersampling for smooth edges


def main() -> None:
    colors = json.loads((ROOT / "data/game_data.json").read_text(encoding="utf-8"))["SUIT_COLOR"]
    for suit, hexc in colors.items():
        big = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        rim = round(N * SS * 1.5 / 26)  # the pip's 1.5px rim on 26px
        d.ellipse((0, 0, N * SS - 1, N * SS - 1), fill=(0, 0, 0, 255))
        d.ellipse((rim, rim, N * SS - 1 - rim, N * SS - 1 - rim), fill=hexc)
        g = Image.open(ROOT / f"assets/icons/suit_{suit}.png").convert("RGBA").resize((round(N * SS * 0.6),) * 2, Image.LANCZOS)
        off = (N * SS - g.width) // 2
        big.alpha_composite(g, (off, off))
        big.resize((N, N), Image.LANCZOS).save(ROOT / f"assets/icons/suit_disc_{suit}.png")
        print("made", suit)


if __name__ == "__main__":
    main()
