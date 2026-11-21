"""Runs the Godot checks and says plainly whether they passed. A test only
passes when it exits 0 AND prints its pass line with no script error: a run
cut short by --quit-after prints nothing and must never count.

  python godot/tools/check.py fast [--only run|final_score|market|todo]
      rules parity, rule tests, every screen against build/before (one Godot
      run), and the play-test section named (none without --only)
  python godot/tools/check.py full
      all of fast, the whole play test, and the HTML comparison (a report)
  python godot/tools/check.py accept
      the screens now are the new "before" (after an intended visual change)

Exit code 0 only when everything passed.
"""
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

GODOT = r"C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ROOT = Path(__file__).resolve().parents[1]
BEFORE, AFTER = ROOT / "build/before", ROOT / "build/after"


def godot_test(name: str, scene: str, pass_re: str, frames: int, extra=()) -> bool:
    t = time.time()
    cmd = [GODOT, "--headless", "--path", str(ROOT), "--quit-after", str(frames), scene, *extra]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    out = r.stdout + r.stderr
    errors = [l for l in out.splitlines() if "SCRIPT ERROR" in l or l.startswith("FAIL")]
    ok = r.returncode == 0 and re.search(pass_re, out, re.M) is not None and not errors
    print(f"{'PASS' if ok else 'FAIL'}  {name}  ({time.time() - t:.0f}s)")
    if errors:
        for l in errors[:8]:
            print("      " + l)
    elif not ok:
        print(f"      no pass line (exit {r.returncode}): it stopped early, at the frame limit or on a wait that never ended")
    return ok


def screens() -> bool:
    t = time.time()
    tool = [sys.executable, str(ROOT / "tools/shot_diff.py")]
    shot = subprocess.run(tool + ["shoot", str(AFTER)], capture_output=True, text=True)
    diff = subprocess.run(tool + ["diff", str(BEFORE), str(AFTER)], capture_output=True, text=True)
    ok = shot.returncode == 0 and diff.returncode == 0
    print(f"{'PASS' if ok else 'FAIL'}  screens vs build/before  ({time.time() - t:.0f}s)")
    if not ok:
        for l in (shot.stdout + diff.stdout).splitlines():
            if "FAILED" in l or "differ" in l or "missing" in l or "size" in l or "cleanly" in l:
                print("      " + l)
        print("      (pictures: build/after/diff_<state>.png; intended? python godot/tools/check.py accept)")
    return ok


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "fast"
    if mode == "accept":
        BEFORE.mkdir(parents=True, exist_ok=True)
        n = 0
        for p in AFTER.glob("*.png"):
            if not p.name.startswith("diff_"):
                shutil.copy2(p, BEFORE / p.name)
                n += 1
        print(f"{n} screens are the new before")
        return 0
    if mode not in ("fast", "full"):
        print(__doc__)
        return 2
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    ok = godot_test("rules parity", "res://tests/parity.tscn", r"^parity: (\d+)/\1 steps match, 0 differ", 600)
    ok &= godot_test("rule tests", "res://tests/rules_test.tscn", r"^rules_test: PASS", 600)
    ok &= screens()
    if mode == "full" or only:
        label = "play test" + (f" ({only})" if only and mode == "fast" else "")
        ok &= godot_test(label, "res://tests/ui_play.tscn", r"^ui_play: PASS", 20000,
                         ["--", "--only", only] if only and mode == "fast" else [])
    if mode == "full":  # a report of layout differences against the HTML game, not a pass/fail
        r = subprocess.run(["node", str(ROOT / "tools/compare.mjs")], capture_output=True, text=True, timeout=900)
        print("INFO  HTML comparison (godot/build/compare.html):")
        for l in r.stdout.splitlines():
            if "checked" in l or "dx dy" in l:
                print("      " + l)
    print("ALL PASSED" if ok else "SOMETHING FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
