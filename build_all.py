# -*- coding: utf-8 -*-
"""
One-command regeneration of every derived output from build_guide.py.

build_guide.py (Elementia_Handoff/handoff/pdf_generation/) is the single
source of truth for STATIONS/SUITS/rule constants/CONTENT_VERSION. Every
other output in this project -- the 6 PDFs, the digital game's embedded
data, and the simulator -- is derived from it and must be regenerated
whenever it changes. Before this script existed, that meant remembering
and manually running ~16 commands in the right order; this runs all of
them and reports pass/fail per step so nothing gets silently skipped.

Usage:
    python build_all.py            # build + render + verify everything
    python build_all.py --skip-pdf # only regenerate the digital game
                                    # (fast path for game-only UI changes)

Note: does NOT publish the Artifact link -- that's a deliberate, separate,
manually-triggered step (see game/build_artifact.py) since publishing is
a visible action that shouldn't happen as a side effect of a content build.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PDFGEN = ROOT / "Elementia_Handoff" / "handoff" / "pdf_generation"
GAME = ROOT / "game"

# (label, working directory, script filename)
PDF_STEPS = [
    ("Build station guide HTML",       PDFGEN, "build_guide.py"),
    ("Build full card deck HTML",      PDFGEN, "build_cards_full.py"),
    ("Build print-run card HTML",      PDFGEN, "build_print_run.py"),
    ("Build element card HTML",        PDFGEN, "build_element_cards.py"),
    ("Build element print-run HTML",   PDFGEN, "build_element_print_run.py"),
    ("Build item reference HTML",      PDFGEN, "build_item_reference.py"),
    ("Render station guide PDF",       PDFGEN, "render.py"),
    ("Render full card deck PDF",      PDFGEN, "render_cards_full.py"),
    ("Render print-run PDF",           PDFGEN, "render_print_run.py"),
    ("Render element cards PDF",       PDFGEN, "render_element_cards.py"),
    ("Render element print-run PDF",   PDFGEN, "render_element_print_run.py"),
    ("Render item reference PDF",      PDFGEN, "render_item_reference.py"),
    ("Check station guide overflow",   PDFGEN, "check.py"),
    ("Check card deck overflow",       PDFGEN, "check_full.py"),
    ("Check item reference overflow",  PDFGEN, "check_item_reference.py"),
]
GAME_STEPS = [
    ("Sync digital game data",         GAME,   "build_game.py"),
]


def run_step(label, cwd, script):
    t0 = time.time()
    print(f"\n\033[1m>> {label}\033[0m  ({script})")
    result = subprocess.run([sys.executable, script], cwd=cwd)
    dt = time.time() - t0
    ok = result.returncode == 0
    status = "\033[92mOK\033[0m" if ok else "\033[91mFAILED\033[0m"
    print(f"   {status} in {dt:.1f}s")
    return ok


def main():
    skip_pdf = "--skip-pdf" in sys.argv
    steps = GAME_STEPS if skip_pdf else PDF_STEPS + GAME_STEPS

    results = []
    for label, cwd, script in steps:
        ok = run_step(label, cwd, script)
        results.append((label, ok))
        if not ok:
            break  # fail fast -- downstream steps assume this one succeeded

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for label, ok in results:
        mark = "\033[92mOK  \033[0m" if ok else "\033[91mFAIL\033[0m"
        print(f"  {mark} {label}")

    failed = [label for label, ok in results if not ok]
    ran_all = len(results) == len(steps)
    if failed:
        print(f"\n{len(failed)} step(s) failed -- stopped at \"{failed[0]}\". Fix and re-run.")
        sys.exit(1)
    elif not ran_all:
        print("\nStopped early.")
        sys.exit(1)
    else:
        print(f"\nAll {len(results)} steps passed. Everything is in sync.")
        print("Remember: this does not publish the Artifact link -- run")
        print("game/build_artifact.py + republish if you want the shared")
        print("link updated too.")


if __name__ == "__main__":
    main()
