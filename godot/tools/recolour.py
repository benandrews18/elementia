"""Changes one colour everywhere in the Godot game at once: every scene and
resource (Color(r, g, b, a) in .tscn/.tres; each copy keeps its own alpha)
and every script ("#rrggbb" in .gd, e.g. ui/theme/tokens.gd's defaults).

  python godot/tools/recolour.py "#e2b25a" "#f0c060"           # change it
  python godot/tools/recolour.py "#e2b25a" "#f0c060" --dry-run # just list

Prints each file and how many copies changed. Undo: git checkout the files.
A colour is matched by its 8-bit red, green and blue, so the scenes' rounded
floats (0.886275) and the scripts' hex both count.
"""
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLOAT = re.compile(r"Color\(\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)(,\s*[0-9.]+)?\s*\)")
HEX = re.compile(r"#([0-9a-fA-F]{6})\b")


def rgb(hex_text: str) -> tuple:
    h = hex_text.lstrip("#")
    if not re.fullmatch(r"[0-9a-fA-F]{6}", h):
        sys.exit(f"not a colour: {hex_text} (use #rrggbb)")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        return 2
    old, new = rgb(args[0]), rgb(args[1])
    dry = "--dry-run" in sys.argv
    new_floats = ", ".join(f"{c / 255:.6g}" for c in new)
    new_hex = "#%02x%02x%02x" % new
    total = 0
    changes = []
    for p in sorted(ROOT.rglob("*")):
        if p.suffix not in (".tscn", ".tres", ".gd") or ".godot" in p.parts or "build" in p.parts:
            continue
        text = p.read_text(encoding="utf-8")
        count = 0

        def floats(m):
            nonlocal count
            if tuple(round(float(x) * 255) for x in m.groups()[:3]) != old:
                return m.group(0)
            count += 1
            return f"Color({new_floats}{m.group(4) or ''})"

        def hexes(m):
            nonlocal count
            if rgb(m.group(1)) != old:
                return m.group(0)
            count += 1
            return new_hex

        out = HEX.sub(hexes, FLOAT.sub(floats, text))
        if count:
            total += count
            changes.append((p, out))
            print(f"{count:4}  {p.relative_to(ROOT).as_posix()}")
    if not dry:  # every change worked out first, then written; a file Windows holds a moment is retried
        for i, (p, out) in enumerate(changes):
            for attempt in range(20):
                try:
                    with open(p, "w", encoding="utf-8", newline="\n") as f:
                        f.write(out)
                    break
                except OSError as e:
                    err = e
                    time.sleep(0.25)
            else:
                print(f"could not write {p} ({err}); already written: {[q.name for q, _ in changes[:i]]} (git checkout to undo)")
                return 1
    print(f"{total} copies {'would change' if dry else 'changed'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
