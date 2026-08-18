# -*- coding: utf-8 -*-
"""
Download Noto Color Emoji PNGs for every native-emoji item icon in the
catalog, and splice the generated CUSTOM_ICONS overrides into
elementia.html -- so item icons render as a consistent image set instead
of whatever emoji font happens to be installed on the player's device.

Source: googlefonts/noto-emoji, png/128/emoji_u<codepoint>.png (already
alpha-transparent, no background removal needed). Fetched via jsDelivr's
CDN mirror of the GitHub repo rather than cloning it (that repo also
carries the full SVG source tree, multiple GB).

Only glyphs used as an item's own emoji in build_guide.py are touched.
Items already using a hand-made custom icon (the __MARKER__ tokens, plus
"🔘" -> the Wheel/tire artwork) are untouched -- CUSTOM_ICONS spreads
NOTO_ICONS first and lists those explicit overrides after, so hand-made
art always wins over the generic Noto fallback for the same key.

Usage:  python game/tools/fetch_noto_icons.py
Then:   python game/tools/fetch_noto_icons.py --check   (verify only)

Downloaded PNGs are cached in game/icons/noto/ -- delete that folder to
force a full re-fetch, or delete individual files to re-fetch just those.
"""
import ast, base64, json, re, sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# Windows consoles default to cp1252, which can't print most emoji --
# reconfigure stdout to UTF-8 so a miss report (which includes the raw
# glyph) never crashes the run after the actual fetch work is done.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
GUIDE = HERE.parent.parent / "Elementia_Handoff" / "handoff" / "pdf_generation" / "build_guide.py"
ICON_DIR = HERE.parent / "icons" / "noto"
TARGET_HTML = HERE.parent / "elementia.html"

CDN_BASE = "https://cdn.jsdelivr.net/gh/googlefonts/noto-emoji@main/png/128/"
START, END = "/*__NOTO_ICONS_START__*/", "/*__NOTO_ICONS_END__*/"


def literals_from(path, names):
    tree = ast.parse(path.read_text(encoding="utf-8"))
    found = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id in names:
                    found[t.id] = ast.literal_eval(node.value)
    return found


def subzone_emoji():
    """SUBZONES (planets/Island/Fictional World) lives hand-written in
    elementia.html itself, not build_guide.py -- see its own comment for
    why (not on the map, never simulated, deliberately outside the
    Python-round-tripped pipeline). Pulled out here with a regex instead
    of ast.literal_eval since it's JS, not Python."""
    html = TARGET_HTML.read_text(encoding="utf-8")
    start = html.find("const SUBZONES = [")
    end = html.find("SUBZONES.forEach(sz =>")
    if start < 0 or end < 0:
        return set()
    block = html[start:end]
    out = set()
    # Top-level {id:"...", emoji:"X", ...} entries (planets/Island/Fictional World)
    for m in re.finditer(r'emoji:"([^"]+)"', block):
        out.add(m.group(1))
    # Shop rows ["emoji","Name","TIER","recipe",pts] and the capstone tuple
    for m in re.finditer(r'\["([^"]*)","[^"]+","(?:MATERIAL|COMPONENT|CREATION|CAPSTONE)"', block):
        if not m.group(1).startswith("__"):
            out.add(m.group(1))
    return out


def item_emoji():
    """Every distinct real (non-__MARKER__) emoji used as an item icon, plus
    each station's own header emoji -- both render through the same em()
    helper in elementia.html, so both belong in the same generated set."""
    src = literals_from(GUIDE, {"STATIONS"})
    out = set()
    for s in src["STATIONS"]:
        out.add(s["emoji"])
        for e, n, tag, rec, pt in s["shop"]:
            if not e.startswith("__"):
                out.add(e)
        ce, cn, ct, cr, cpt = s["capstone"]
        if not ce.startswith("__"):
            out.add(ce)
    out |= subzone_emoji()
    return sorted(out)


def codepoint_filename(emoji):
    # Noto's filenames drop the standalone variation selector (FE0F);
    # every other codepoint in the sequence (ZWJ joins, skin tones, etc.)
    # is kept, joined with underscores, matching the repo's own convention.
    cps = [f"{ord(c):x}" for c in emoji if c != "️"]
    return "emoji_u" + "_".join(cps) + ".png"


def var_name(emoji):
    return "NOTO_" + "_".join(f"{ord(c):x}" for c in emoji)


def fetch(emoji):
    fname = codepoint_filename(emoji)
    dest = ICON_DIR / fname
    if dest.exists():
        return dest, None
    try:
        req = Request(CDN_BASE + fname, headers={"User-Agent": "elementia-icon-fetch/1.0"})
        with urlopen(req, timeout=15) as resp:
            data = resp.read()
        dest.write_bytes(data)
        return dest, None
    except (HTTPError, URLError) as e:
        return None, str(e)


def build_block(emojis):
    const_lines, map_entries, misses = [], [], []
    for e in emojis:
        path, err = fetch(e)
        if err:
            misses.append((e, codepoint_filename(e), err))
            continue
        b64 = base64.b64encode(path.read_bytes()).decode("ascii")
        var = var_name(e)
        const_lines.append(f'const {var} = \'<img class="noto-icon" src="data:image/png;base64,{b64}">\';')
        map_entries.append(f'{json.dumps(e, ensure_ascii=False)}: {var}')
    block = "\n".join(const_lines) + "\nconst NOTO_ICONS = {" + ", ".join(map_entries) + "};"
    return block, misses


def main():
    check_only = "--check" in sys.argv
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    emojis = item_emoji()
    print(f"{len(emojis)} distinct item emoji to resolve")

    block, misses = build_block(emojis)
    if misses:
        print(f"\n{len(misses)} MISS(ES) -- kept as native emoji text, not swapped:")
        for e, fname, err in misses:
            print(f"  {e!r} ({fname}): {err}")

    html = TARGET_HTML.read_text(encoding="utf-8")
    a, b = html.find(START), html.find(END)
    if a < 0 or b < 0:
        raise SystemExit(f"Markers {START}/{END} not found in {TARGET_HTML}")

    current = html[a + len(START):b].strip("\n")
    if current == block:
        print(f"\n{TARGET_HTML.name}: in sync ({len(emojis) - len(misses)} icons)")
        return

    if check_only:
        raise SystemExit(f"OUT OF SYNC with build_guide.py: {TARGET_HTML.name}")

    html = html[:a + len(START)] + "\n" + block + "\n" + html[b:]
    TARGET_HTML.write_text(html, encoding="utf-8")
    print(f"\nwrote {len(emojis) - len(misses)} icons into {TARGET_HTML.name}")


if __name__ == "__main__":
    main()
