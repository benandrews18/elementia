"""Reference sheets for re-drawing the game's art (the user, 2026-11-27):
art_reference/items.png (every item, by tier, with its name) and
art_reference/icons.png (the icons the cards and the card game use).
Built from the game's own images, so they match what's in the game.

  python godot/tools/art_sheet.py
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parent / "art_reference"
DATA = json.loads((ROOT / "data/game_data.json").read_text(encoding="utf-8"))
ICONS = json.loads((ROOT / "assets/icons/icons.json").read_text(encoding="utf-8"))
FONT = ROOT / "assets/fonts/Nunito-VariableFont_wght.ttf"
INK, BG, CARD = (59, 36, 18), (246, 238, 220), (243, 230, 200)
NAVY = (22, 53, 68)


def font(px, weight=800):
    f = ImageFont.truetype(str(FONT), px)
    f.set_variation_by_axes([weight])
    return f


def icon(key):
    """Data.icon(): icons.json, then the Noto image in assets/emoji."""
    for k in (key, key + "️"):
        if k in ICONS:
            p = ROOT / ICONS[k].replace("res://", "")
            if p.suffix == ".svg":  # exported by Godot first (tests/tmp/svg_png.tscn: build/svg_png/)
                p = ROOT / "build/svg_png" / (p.stem + ".png")
            return Image.open(p).convert("RGBA")
    p = ROOT / "assets/emoji" / ("emoji_u" + "_".join(f"{ord(c):x}" for c in key if ord(c) != 0xFE0F) + ".png")
    return Image.open(p).convert("RGBA") if p.exists() else None


def paste_fit(sheet, im, box):
    x, y, w, h = box
    im = im.copy()
    im.thumbnail((w, h), Image.LANCZOS)
    sheet.alpha_composite(im, (x + (w - im.width) // 2, y + (h - im.height) // 2))


def centred(d, text, cx, y, f, fill=INK, maxw=None):
    while maxw and d.textlength(text, font=f) > maxw and f.size > 12:
        f = font(f.size - 1)
    d.text((cx - d.textlength(text, font=f) / 2, y), text, font=f, fill=fill)


def items_sheet():
    rows, seen = {"MATERIAL": [], "COMPONENT": [], "CREATION": [], "CAPSTONE": []}, set()
    for s in DATA["DATA"]["stations"]:
        for r in s["shop"] + [s["capstone"]] + s.get("unlock", []):
            if r[1] not in seen:
                seen.add(r[1])
                rows[r[2]].append(r)
    title = {"MATERIAL": "TIER 1 - MATERIALS", "COMPONENT": "TIER 2 - COMPONENTS", "CREATION": "TIER 3 - CREATIONS", "CAPSTONE": "CAPSTONES"}
    cols, cw, ch, pad = 10, 180, 210, 40
    h = 160 + sum(70 + -(-len(v) // cols) * ch for v in rows.values()) + pad
    sheet = Image.new("RGBA", (cols * cw + 2 * pad, h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 40), "ELEMENTIA - every item (%d), by tier" % len(seen), font=font(52, 900), fill=INK)
    y = 160
    for tier, rs in rows.items():
        d.text((pad, y), title[tier], font=font(34, 900), fill=(181, 84, 27))
        y += 70
        for i, r in enumerate(sorted(rs, key=lambda r: r[1])):
            x, yy = pad + (i % cols) * cw, y + (i // cols) * ch
            d.rounded_rectangle((x + 10, yy, x + cw - 10, yy + 150), 22, fill=CARD, outline=(0, 0, 0), width=3)
            im = icon(r[0])
            if im:
                paste_fit(sheet, im, (x + 25, yy + 15, cw - 50, 120))
            centred(d, r[1], x + cw / 2, yy + 158, font(22), maxw=cw - 8)
        y += -(-len(rs) // cols) * ch
    sheet.convert("RGB").save(OUT / "items.png")


def icons_sheet():
    w, pad = 1800, 40
    sheet = Image.new("RGBA", (w, 2200), BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 40), "ELEMENTIA - card and card-game icons", font=font(52, 900), fill=INK)
    y = 150

    def row(label, cells, dark=False, size=130):
        nonlocal y
        d.text((pad, y), label, font=font(34, 900), fill=(181, 84, 27))
        y += 60
        step = (w - 2 * pad) // max(len(cells), 1)
        for i, (im, name) in enumerate(cells):
            x = pad + i * step
            if dark:
                d.rounded_rectangle((x + 10, y, x + step - 10, y + size + 30), 22, fill=NAVY)
            if im is not None:
                paste_fit(sheet, im, (x + 20, y + 15, step - 40, size))
            centred(d, name, x + step / 2, y + size + 40, font(24), maxw=step - 10)
        y += size + 100

    suits = DATA["ELEMENT_SUIT_LABEL"]
    row("ELEMENT SUITS (the coloured circles on cards, top right)", [(icon("suitdisc:" + s), suits[s]) for s in suits])
    st = DATA["DATA"]["stations"]
    row("STATIONS (where an item is made: badges along a card's bottom)", [(icon(s["emoji"]), s["name"].replace("The ", "")) for s in st], size=110)
    card_ui = [(Image.open(ROOT / "assets/ui/cards_scatter.png").convert("RGBA"), "Discard"), (icon("🎯"), "Goal"),
               (icon("🏁"), "Pass"), (Image.open(ROOT / "assets/ui/cards_deck.png").convert("RGBA"), "Deck"),
               (Image.open(ROOT / "assets/ui/card.png").convert("RGBA"), "Draw"), (Image.open(ROOT / "assets/ui/card_hand.png").convert("RGBA"), "Hand")]
    row("CARD GAME (the Display Mat challenge's buttons)", card_ui, dark=True)
    # A points badge and an Unknown Element, drawn as the game draws them.
    badge = Image.new("RGBA", (120, 120), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    bd.ellipse((4, 4, 116, 116), fill=(242, 201, 76), outline=(0, 0, 0), width=6)
    centred(bd, "12", 60, 26, font(54, 900), fill=(0, 0, 0))
    unk = Image.new("RGBA", (120, 120), (0, 0, 0, 0))
    ud = ImageDraw.Draw(unk)
    ud.rounded_rectangle((6, 6, 114, 114), 18, fill=(255, 255, 255), outline=(0, 0, 0), width=7)
    centred(ud, "?", 60, 18, font(66, 900), fill=(24, 22, 20))
    ud.ellipse((70, 10, 106, 46), fill=(0, 0, 0))
    row("ON THE CARDS AND AROUND THEM", [(badge, "Points"), (icon("⚛️"), "Quarks / combos"), (icon("🎲"), "Dice"),
                                        (unk, "Unknown Element"), (icon("📌"), "Pin"), (icon("🔍"), "Track")])
    row("THE HUB", [(icon("ui:todo"), "To-Do List"), (icon("ui:inventory"), "Inventory"), (icon("ui:map"), "Map"),
                    (icon("ui:market"), "Market"), (icon("ui:items"), "Items")], size=110)
    sheet.crop((0, 0, w, y + 20)).convert("RGB").save(OUT / "icons.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    items_sheet()
    icons_sheet()
    print("saved", OUT / "items.png", OUT / "icons.png")
