# -*- coding: utf-8 -*-
"""
Publish the game to the website (https://benandrews18.github.io/elementia/).

    python game/deploy.py "What changed"

Runs the smoke test, builds game/build/elementia_artifact.html, copies it
over ../elementia-site/index.html (a separate clone of the site repo),
commits there with the message given and pushes. Then pushes this repo's
master to the same GitHub repo's `source` branch as the source backup
(`main` there is the website; never push master to it). Stops before
changing anything if the smoke test fails or either repo has uncommitted
work.

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
    for repo in (SITE, REPO):
        dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo,
                               capture_output=True, text=True, check=True).stdout.strip()
        if dirty:
            sys.exit(f"{repo} has uncommitted changes; commit them first:\n{dirty}")

    run(["node", str(GAME / "tools" / "run_smoke.mjs")])
    run([sys.executable, str(GAME / "build_artifact.py")])
    shutil.copyfile(BUILD, SITE / "index.html")
    if subprocess.run(["git", "status", "--porcelain"], cwd=SITE,
                      capture_output=True, text=True, check=True).stdout.strip():
        run(["git", "add", "index.html"], cwd=SITE)
        run(["git", "commit", "-m", message], cwd=SITE)
        run(["git", "push", "origin", "main"], cwd=SITE)
        print("\nWebsite pushed. GitHub Pages updates in a minute or two.")
    else:
        print("Site already matches this build.")
    run(["git", "push", "origin", "master:source"])
    print("Source backed up to the source branch.")


if __name__ == "__main__":
    main()
