"""Fetches a Noto emoji image for every item / station emoji in
data/game_data.json that has no icon yet, into assets/emoji/ (where
Data.icon() looks). Run it after adding an item with a new emoji:

  python godot/tools/fetch_icons.py

Hand-made art: put the image in assets/icons/ and map its key (the emoji
or a __NAME__ marker) in assets/icons/icons.json instead.
"""
import json
import sys
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
NOTO = "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/2D/png/128/"


def file_name(emoji: str) -> str:  # Data.icon(): codepoints without FE0F
    return "emoji_u" + "_".join(f"{ord(c):x}" for c in emoji if ord(c) != 0xFE0F) + ".png"


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    data = json.loads((ROOT / "data/game_data.json").read_text(encoding="utf-8"))["DATA"]
    mapped = json.loads((ROOT / "assets/icons/icons.json").read_text(encoding="utf-8"))
    wanted = set()
    for s in data["stations"]:
        wanted.add(s["emoji"])
        for row in s["shop"] + [s["capstone"]] + s.get("unlock", []):
            wanted.add(row[0])
    missing = [e for e in sorted(wanted) if not e.startswith("__") and e not in mapped
               and e + "️" not in mapped and not (ROOT / "assets/emoji" / file_name(e)).exists()]
    for e in missing:
        name = file_name(e)
        try:
            (ROOT / "assets/emoji" / name).write_bytes(urlopen(NOTO + name, timeout=30).read())
            print(f"fetched {e} {name}")
        except OSError as err:
            print(f"MISSING {e} {name}: {err} (no Noto image; add hand-made art)")
    print(f"{len(missing)} new" if missing else "every icon is there")


if __name__ == "__main__":
    main()
