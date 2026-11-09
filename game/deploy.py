# -*- coding: utf-8 -*-
"""
Publish the game to the website (https://benandrews18.github.io/elementia/).

    python game/deploy.py "What changed"

Runs the smoke test, builds game/build/elementia_artifact.html, copies it
over ../elementia-site/index.html (a separate clone of the site repo),
commits there with the message given and pushes. Stops before changing
anything if the smoke test fails or the site repo has uncommitted work.

The shared claude.ai link is published separately, with the Artifact tool,
from the same build file (see CLAUDE.md).
"""
import shutil
import subprocess
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parent
REPO = GAME.parent
SITE = REPO.parent / "elementia-site"
BUILD = GAME / "build" / "elementia_artifact.html"


def run(cmd, cwd=REPO):
    print("$", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        sys.exit('Usage: python game/deploy.py "What changed"')
    message = sys.argv[1].strip()
    if not (SITE / ".git").exists():
        sys.exit(f"Site repo not found at {SITE}")
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=SITE,
                           capture_output=True, text=True, check=True).stdout.strip()
    if dirty:
        sys.exit(f"{SITE} has uncommitted changes; sort them out first:\n{dirty}")

    run(["node", str(GAME / "tools" / "run_smoke.mjs")])
    run([sys.executable, str(GAME / "build_artifact.py")])
    shutil.copyfile(BUILD, SITE / "index.html")
    if not subprocess.run(["git", "status", "--porcelain"], cwd=SITE,
                          capture_output=True, text=True, check=True).stdout.strip():
        print("Site already matches this build; nothing to publish.")
        return
    run(["git", "add", "index.html"], cwd=SITE)
    run(["git", "commit", "-m", message], cwd=SITE)
    run(["git", "push", "origin", "main"], cwd=SITE)
    print("\nPushed. GitHub Pages updates in a minute or two.")


if __name__ == "__main__":
    main()
