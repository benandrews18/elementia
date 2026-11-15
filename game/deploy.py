# -*- coding: utf-8 -*-
"""
Publish the game to the website (https://benandrews18.github.io/elementia/).

    python game/deploy.py "What changed"

Runs the smoke test, builds game/build/elementia_artifact.html, copies it
over ../elementia-site/index.html (a separate clone of the site repo, with
js/pwa.js added back and the installed-app files beside it),
commits there with the message given and pushes. Then pushes this repo's
master to the same GitHub repo's `source` branch as the source backup
(`main` there is the website; never push master to it). Stops before
changing anything if the smoke test fails or either repo has uncommitted
work.

The shared claude.ai link is published separately, with the Artifact tool,
from the same build file (see CLAUDE.md).

    python game/deploy.py --preview "What changed"

publishes the current build (any branch) to the site's preview/ page
(https://benandrews18.github.io/elementia/preview/) for trying out work in
progress; the main page, and the source backup, are left alone.
"""
import shutil
import subprocess
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parent
REPO = GAME.parent
SITE = REPO.parent / "elementia-site"
BUILD = GAME / "build" / "elementia_artifact.html"
APP_FILES = ["manifest.webmanifest", "sw.js", "icons/apple-touch-icon.png",
             "icons/icon-192.png", "icons/icon-512.png", "icons/icon-512-maskable.png"]


def run(cmd, cwd=REPO):
    print("$", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)


def main():
    args = sys.argv[1:]
    preview = "--preview" in args
    args = [a for a in args if a != "--preview"]
    if not args or not args[0].strip():
        sys.exit('Usage: python game/deploy.py [--preview] "What changed"')
    message = args[0].strip()
    if not (SITE / ".git").exists():
        sys.exit(f"Site repo not found at {SITE}")
    for repo in (SITE, REPO):
        dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo,
                               capture_output=True, text=True, check=True).stdout.strip()
        if dirty:
            sys.exit(f"{repo} has uncommitted changes; commit them first:\n{dirty}")

    run(["node", str(GAME / "tools" / "run_smoke.mjs")])
    run([sys.executable, str(GAME / "build_artifact.py")])
    if preview:
        (SITE / "preview").mkdir(exist_ok=True)
        shutil.copyfile(BUILD, SITE / "preview" / "index.html")
        run(["git", "add", "preview/index.html"], cwd=SITE)
        run(["git", "commit", "-m", "Preview: " + message], cwd=SITE)
        run(["git", "push", "origin", "main"], cwd=SITE)
        print("Preview pushed: https://benandrews18.github.io/elementia/preview/ (in a minute or two).")
        return
    # The website is also an installable app: the build leaves js/pwa.js out
    # (the claude.ai link can't use it), so it's added back here, with the
    # manifest, service worker and icons it needs beside the page.
    page = BUILD.read_text(encoding="utf-8")
    pwa = (GAME / "js" / "pwa.js").read_text(encoding="utf-8")
    # The build has no </body> (build_artifact.py strips the wrapper): append.
    (SITE / "index.html").write_text(page + f"<script>{pwa}</script>\n", encoding="utf-8")
    for name in APP_FILES:
        (SITE / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(GAME / name, SITE / name)
    if subprocess.run(["git", "status", "--porcelain"], cwd=SITE,
                      capture_output=True, text=True, check=True).stdout.strip():
        run(["git", "add", "index.html", *APP_FILES], cwd=SITE)
        run(["git", "commit", "-m", message], cwd=SITE)
        run(["git", "push", "origin", "main"], cwd=SITE)
        print("\nWebsite pushed. GitHub Pages updates in a minute or two.")
    else:
        print("Site already matches this build.")
    run(["git", "push", "origin", "master:source"])
    print("Source backed up to the source branch.")


if __name__ == "__main__":
    main()
