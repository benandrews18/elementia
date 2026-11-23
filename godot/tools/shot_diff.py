"""Before/after check for M5.5: every screen and window must look the same
after it's converted to a scene.

  python godot/tools/shot_diff.py shoot godot/build/before   # every state (tests/shot_states.gd)
  python godot/tools/shot_diff.py shoot godot/build/after [state ...]
  python godot/tools/shot_diff.py diff godot/build/before godot/build/after

diff prints each state's changed pixels (a pixel counts when a channel moves
by more than 8 of 255) and writes <after>/diff_<state>.png with the changes
in red over a faded copy. Exit code 1 when any state changed.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops

GODOT = r"C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ROOT = Path(__file__).resolve().parents[1]
FIX = "res://tests/fixtures/"
# Which saved run each state is shot with (the rest use the station's).
SAVES = {"map": "map_visit7", "map_card": "map_visit7", "drawer": "mat_visit18", "drawer_elements": "mat_visit18",
         "drawer_selected": "mat_visit18", "reward": "mat_visit18", "order": "mat_visit18", "end_over": "mat_visit18",
         "end_done": "mat_visit18", "order_restrict": "mat_visit18", "order_grand": "mat_visit18", "expand": "mat_visit18", "pin_tip": "map_visit7",
         "tracked_map": "map_visit7", "map_ocean": "map_visit7", "clock_info": "map_visit7", "layouts": "mat_visit18",
         "coll_run": "mat_visit18", "coll_menu": "mat_visit18", "coll_found": "mat_visit18", "clue_box": "mat_visit18", "clue_card": "mat_visit18",
         "challenge_pick": "mat_visit18", "challenge_hand": "mat_visit18", "challenge_elements": "mat_visit18"}
THRESHOLD = 8


def states():
    src = (ROOT / "tests/shot_states.gd").read_text(encoding="utf-8")
    block = re.search(r"const STATES := \[(.*?)\]", src, re.S).group(1)
    return re.findall(r'"([a-z_0-9]+)"', block)


def shoot(out: Path, only=()):
    """Every state (or just `only`) in one Godot run (tests/shot_batch.gd)."""
    out = out.resolve()  # Godot runs in godot/: a relative path would land there
    out.mkdir(parents=True, exist_ok=True)
    plan = []
    for s in only or states():
        (out / f"{s}.png").unlink(missing_ok=True)  # a failed shot must not leave an old one
        plan.append({"state": s, "save": FIX + SAVES.get(s, "station_visit7") + ".json", "out": str(out / f"{s}.png")})
    plan_file = out / "_plan.json"
    plan_file.write_text(json.dumps(plan), encoding="utf-8")
    cmd = [GODOT, "--path", str(ROOT), "--position", "-20000,-20000",  # drawn off-screen, out of the way
           "--fixed-fps", "60", "--disable-vsync", "--quit-after", str(400 * len(plan) + 600),
           "res://tests/shot_batch.tscn", "--", "--plan", str(plan_file)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    lines = r.stdout.splitlines() + r.stderr.splitlines()
    state, bad = "", {}
    for l in lines:
        if l.startswith("state "):
            state = l[6:]
        elif "SCRIPT ERROR" in l:
            bad.setdefault(state, l)
    for job in plan:
        s = job["state"]
        ok = Path(job["out"]).exists() and s not in bad
        print(f"{s:18} {'ok' if ok else 'FAILED'} {bad.get(s, '')}")
    done = any(l.startswith(f"shot_batch: {len(plan)} saved") for l in lines)
    if r.returncode != 0 or not done or bad:
        print("shot_batch did not finish cleanly")
        return 1
    return 0


def diff(a: Path, b: Path) -> int:
    changed = 0
    for s in states():
        pa, pb = a / f"{s}.png", b / f"{s}.png"
        if not pa.exists() or not pb.exists():
            print(f"{s:18} missing")
            changed += 1
            continue
        ia, ib = Image.open(pa).convert("RGB"), Image.open(pb).convert("RGB")
        if ia.size != ib.size:
            print(f"{s:18} size {ia.size} -> {ib.size}")
            changed += 1
            continue
        r, g, bl = ImageChops.difference(ia, ib).split()
        d = ImageChops.lighter(ImageChops.lighter(r, g), bl).point(lambda v: 255 if v > THRESHOLD else 0)  # the biggest channel change
        n = d.histogram()[255]
        print(f"{s:18} {'same' if n == 0 else f'{n} pixels differ'}")
        if n:
            changed += 1
            red = Image.new("RGB", ib.size, (255, 0, 0))
            Image.composite(red, Image.blend(ib, Image.new("RGB", ib.size, (255, 255, 255)), 0.6), d).save(b / f"diff_{s}.png")
    return 1 if changed else 0


if __name__ == "__main__":
    if sys.argv[1] == "shoot":
        sys.exit(shoot(Path(sys.argv[2]), sys.argv[3:]))  # optional: just these states
    else:
        sys.exit(diff(Path(sys.argv[2]), Path(sys.argv[3])))
