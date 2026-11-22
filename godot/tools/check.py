"""Runs the Godot checks and says plainly whether they passed. A test only
passes when it exits 0 AND prints its pass line with no script error: a run
cut short by --quit-after prints nothing and must never count.

  python godot/tools/check.py fast [--only <section>] [--screens]
      rules parity, rule tests, the play-test section named (none without
      --only), and every screen against build/before (one Godot run, drawn
      off-screen) -- skipped when nothing that can change a screen has
      changed since the screens last passed; --screens forces them
  python godot/tools/check.py full
      all of fast and the whole play test (screens still skipped when nothing
      visual changed)
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
STAMP = ROOT / "build/screens_ok"  # the exact files the screens last passed with (a commit, or a stash-like snapshot of uncommitted work)
# What can't change a screen: docs, tools, and the tests that aren't screenshots.
NOT_VISUAL = re.compile(r"^godot/(tools/|.*\.md$|tests/(ui_play|rules_test|parity)\.|tests/goldens/|tests/tmp/)|^(?!godot/)")


def git(*args) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout


def snapshot() -> str:
    """The files as they are now: HEAD, or a snapshot commit of the uncommitted
    changes (so committing them afterwards doesn't count as a change)."""
    return git("stash", "create").strip() or git("rev-parse", "HEAD").strip()


def screens_needed() -> str:
    """Why the screens must run, or "" when nothing visual changed since they last passed."""
    if not STAMP.exists() or not BEFORE.exists():
        return "no record of a pass"
    since = STAMP.read_text().strip()
    changed = git("diff", "--name-only", since).split() + git("ls-files", "--others", "--exclude-standard", "--full-name").split()
    if git("cat-file", "-t", since).strip() != "commit":
        return "unknown last pass"
    visual = [f for f in changed if not NOT_VISUAL.match(f)]
    return f"{len(visual)} changed: {', '.join(visual[:3])}{' ...' if len(visual) > 3 else ''}" if visual else ""


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
    if ok:
        STAMP.write_text(snapshot())
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
        STAMP.write_text(snapshot())
        print(f"{n} screens are the new before")
        return 0
    if mode not in ("fast", "full"):
        print(__doc__)
        return 2
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    ok = godot_test("rules parity", "res://tests/parity.tscn", r"^parity: (\d+)/\1 steps match, 0 differ", 600)
    ok &= godot_test("rule tests", "res://tests/rules_test.tscn", r"^rules_test: PASS", 600)
    why = "--screens" if "--screens" in sys.argv else screens_needed()
    if why:
        print(f"      (screens: {why})")
        ok &= screens()
    else:
        print("SKIP  screens: nothing that can change one has changed since they last passed")
    if mode == "full" or only:
        label = "play test" + (f" ({only})" if only and mode == "fast" else "")
        ok &= godot_test(label, "res://tests/ui_play.tscn", r"^ui_play: PASS", 20000,
                         ["--", "--only", only] if only and mode == "fast" else [])
    print("ALL PASSED" if ok else "SOMETHING FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
