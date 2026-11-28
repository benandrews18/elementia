"""Runs the Godot checks and says plainly whether they passed. A test only
passes when it exits 0 AND prints its pass line with no script error: a run
cut short by --quit-after prints nothing and must never count.

  python godot/tools/check.py fast [--only <section>] [--screens [names]]
      rules parity, rule tests, the play-test section named (none without
      --only). Screens only when asked (the user, 2026-11-23: they cost
      ~100s): --screens compares every screen against build/before (one
      Godot run, drawn off-screen); --screens drawer,map just the states
      whose names start with those (the part whose look changed)
  python godot/tools/check.py full [--screens [names]]
      all of fast, the whole play test and the redraw budget (tests/perf.gd)
  python godot/tools/check.py release
      full, and every screen (before a release)
  python godot/tools/check.py accept
      the screens the last run shot are the new "before" (after an intended
      visual change)

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
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)  # check lines carry emoji
    out = r.stdout + r.stderr
    # A node freed inside its own tap: a crash or freeze on phones (the to-do details, 2026-11-28)
    errors = [l for l in out.splitlines() if "SCRIPT ERROR" in l or l.startswith("FAIL") or "while a signal is being emitted" in l]
    ok = r.returncode == 0 and re.search(pass_re, out, re.M) is not None and not errors
    print(f"{'PASS' if ok else 'FAIL'}  {name}  ({time.time() - t:.0f}s)")
    if errors:
        for l in errors[:8]:
            print("      " + l)
    elif not ok:
        print(f"      no pass line (exit {r.returncode}): it stopped early, at the frame limit or on a wait that never ended")
    return ok


LAST = ROOT / "build/after/last_shot.txt"  # the states the last run shot (what accept takes)


def screens(only=()) -> bool:
    t = time.time()
    tool = [sys.executable, str(ROOT / "tools/shot_diff.py")]
    sys.path.insert(0, str(ROOT / "tools"))
    import shot_diff
    picked = [s for s in shot_diff.states() if not only or any(s.startswith(o) for o in only)]
    if not picked:
        print(f"FAIL  screens: no state starts with {', '.join(only)}")
        return False
    AFTER.mkdir(parents=True, exist_ok=True)
    LAST.write_text("\n".join(picked))
    shot = subprocess.run(tool + ["shoot", str(AFTER)] + picked, capture_output=True, text=True)
    diff = subprocess.run(tool + ["diff", str(BEFORE), str(AFTER)] + picked, capture_output=True, text=True)
    ok = shot.returncode == 0 and diff.returncode == 0
    print(f"{'PASS' if ok else 'FAIL'}  screens vs build/before: {len(picked)} {'all' if not only else 'of ' + ', '.join(only)}  ({time.time() - t:.0f}s)")
    if not ok:
        for l in (shot.stdout + diff.stdout).splitlines():
            if "FAILED" in l or "differ" in l or "missing" in l or "size" in l or "cleanly" in l or "11px" in l:
                print("      " + l)
        print("      (pictures: build/after/diff_<state>.png; intended? python godot/tools/check.py accept)")
    return ok


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "fast"
    if mode == "accept":
        BEFORE.mkdir(parents=True, exist_ok=True)
        n = 0
        last = set(LAST.read_text().split()) if LAST.exists() else None
        for p in AFTER.glob("*.png"):
            if not p.name.startswith("diff_") and (last is None or p.stem in last):
                shutil.copy2(p, BEFORE / p.name)
                n += 1
        print(f"{n} screens are the new before")
        return 0
    if mode not in ("fast", "full", "release"):
        print(__doc__)
        return 2
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    ok = godot_test("rules parity", "res://tests/parity.tscn", r"^parity: (\d+)/\1 steps match, 0 differ", 600)
    ok &= godot_test("rule tests", "res://tests/rules_test.tscn", r"^rules_test: PASS", 600)
    if mode == "release":
        ok &= screens()
    elif "--screens" in sys.argv:
        i = sys.argv.index("--screens")
        names = sys.argv[i + 1] if i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith("--") else ""
        ok &= screens(tuple(n for n in names.split(",") if n))
    else:
        print("SKIP  screens (add --screens [names] when a look changed; all of them: release)")
    if mode in ("full", "release") or only:
        label = "play test" + (f" ({only})" if only and mode == "fast" else "")  # full / release: all of it
        ok &= godot_test(label, "res://tests/ui_play.tscn", r"^ui_play: PASS", 20000,
                         ["--", "--only", only] if only and mode == "fast" else [])
    if mode in ("full", "release"):
        ok &= godot_test("redraw budget", "res://tests/perf.tscn", r"^perf: PASS", 3000)
    print("ALL PASSED" if ok else "SOMETHING FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
