"""The breakpoint tuner: plays simulated runs (tests/sim.tscn, the game's own
rules), then shows each board check's scores next to the breakpoints and
your runs (tests/sim_guide/runs_*.json from 2026-11-26 on: the hand checks).

  python godot/tools/sim.py [--runs 200] [--seed 1] [--clear 95,60,30,10] [--write] [--rounds 2]

--clear: the share of simulated runs each breakpoint should let through
(first to fourth). --write puts the proposed breakpoints into
data/game_data.json (LOCKIN_ROUND_ANCHORS: a row per check round, the
rounds between interpolate; Overtime's rows scale with round 24's) and,
with --rounds N, plays again on them N times in all (the dice a check pays
change the runs that follow, so a second pass settles it).
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/game_data.json"
OUT = ROOT / "build/sim_runs.json"
GODOT = r"C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"


def play(runs, seed):
    r = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "res://tests/sim.tscn", "--",
                        "--runs", str(runs), "--seed", str(seed), "--out", str(OUT)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=3600)
    if r.returncode != 0 or "SCRIPT ERROR" in r.stdout + r.stderr or not OUT.exists():
        sys.exit("the simulator failed:\n" + (r.stdout + r.stderr)[-3000:])
    return json.loads(OUT.read_text(encoding="utf-8"))


def pct(xs, p):
    """The p-th percentile (0-100), linear between the sorted scores."""
    xs = sorted(xs)
    k = (len(xs) - 1) * p / 100
    i = int(k)
    return xs[i] + (xs[min(i + 1, len(xs) - 1)] - xs[i]) * (k - i)


def tiers(anchors, rnd):
    """Orders.base_tiers(): the row's breakpoints, linear between rows."""
    if rnd <= anchors[0][0]:
        return anchors[0][1:]
    for lo, hi in zip(anchors, anchors[1:]):
        if lo[0] <= rnd <= hi[0]:
            f = (rnd - lo[0]) / (hi[0] - lo[0])
            return [a + (b - a) * f for a, b in zip(lo[1:], hi[1:])]
    return anchors[-1][1:]


def by_round(sims):
    out = {}
    for r in sims:
        for c in r["checks"]:
            out.setdefault(int(c["v"]), []).append(c["q"])
    return out


def your_runs():
    runs = []
    for f in sorted((ROOT / "tests/sim_guide").glob("runs_2*.json")):
        runs += json.loads(f.read_text(encoding="utf-8"))
    return runs


def report(sims, anchors, clear):
    rounds = by_round(sims)
    yours = your_runs()
    print(f"\n{len(sims)} simulated runs; capstones made: "
          f"{sum(len(r['capstones']) for r in sims) / len(sims):.1f} a run (yours: "
          f"{', '.join(str(len(r['capstones'])) for r in yours)})")
    print("round | sim scores: p10   p25   p50   p75   p90 | breakpoints now (share through) | yours")
    proposed = {}
    for v in sorted(rounds):
        q = rounds[v]
        now = tiers(anchors, v)
        through = [sum(x >= t for x in q) / len(q) for t in now]
        you = [c["q"] for r in yours for c in r["checks"] if int(c["v"]) == v]
        line = f"{v:5} | " + " ".join(f"{pct(q, p):5.0f}" for p in (10, 25, 50, 75, 90))
        if v < 24:  # the final check pays no dice
            line += " | " + " ".join(f"{t:5.0f}({s:3.0%})" for t, s in zip(now, through))
            prop = [round(pct(q, 100 - c) / 5) * 5 for c in clear]
            for i in range(1, 4):  # each breakpoint above the last
                prop[i] = max(prop[i], prop[i - 1] + 5)
            proposed[v] = prop
        else:
            line += " | " + " " * 39
        print(line + " | " + ", ".join(f"{x:.0f}" for x in you))
    print("\nproposed (" + "/".join(f"{c}%" for c in clear) + " through):")
    for v, p in proposed.items():
        print(f"  round {v:2}: {p}")
    return proposed


def write(proposed, anchors):
    rows = [[v] + p for v, p in sorted(proposed.items())]
    old24 = tiers(anchors, 24)
    # Round 24 (only Overtime's quiet checks use it): the last check's growth again.
    a, b = rows[-2], rows[-1]
    new24 = [round((y + (y - x) * (24 - b[0]) / (b[0] - a[0])) / 5) * 5 for x, y in zip(a[1:], b[1:])]
    rows.append([24] + new24)
    for r in anchors:  # Overtime: its rows scaled by round 24's change
        if r[0] > 24:
            rows.append([r[0]] + [round(x * n / o / 5) * 5 if o else n for x, n, o in zip(r[1:], new24, old24)])
    text = DATA.read_text(encoding="utf-8")
    body = ",\n".join("  [\n" + ",\n".join(f"   {x}" for x in r) + "\n  ]" for r in rows)
    new, n = re.subn(r'"LOCKIN_ROUND_ANCHORS": \[\n.*?\n \]', '"LOCKIN_ROUND_ANCHORS": [\n' + body + "\n ]",
                     text, count=1, flags=re.S)
    assert n == 1, "LOCKIN_ROUND_ANCHORS not found"
    DATA.write_text(new, encoding="utf-8", newline="\n")
    print(f"wrote {len(rows)} rows to {DATA.name}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=200)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--clear", default="95,60,30,10")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--rounds", type=int, default=1)
    a = ap.parse_args()
    clear = [int(x) for x in a.clear.split(",")]
    for i in range(a.rounds if a.write else 1):
        anchors = json.loads(DATA.read_text(encoding="utf-8"))["LOCKIN_ROUND_ANCHORS"]
        proposed = report(play(a.runs, a.seed), anchors, clear)
        if a.write:
            write(proposed, anchors)


if __name__ == "__main__":
    main()
