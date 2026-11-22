"""Build the web version and publish it as the website
(https://benandrews18.github.io/elementia/).

  python godot/tools/web.py "What changed"   check, build, publish
  python godot/tools/web.py build            build only (build/web/)

Publishing is public: the user's OK first (CLAUDE.md). It copies the export
over the root of ../elementia-site (a clone of the site repo, branch main),
commits there with the message given and pushes; then pushes this repo's
master to the same GitHub repo's `source` branch as the source backup
(never master to main). Stops before changing anything if the checks fail
or either repo has uncommitted work.
"""
import shutil
import subprocess
import sys
from pathlib import Path

GODOT = "C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
SITE = REPO.parent / "elementia-site"
OUT = ROOT / "build/web"


def run(cmd, cwd=REPO):
    print("$", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)


def build() -> None:
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    run([GODOT, "--headless", "--path", str(ROOT), "--export-release", "Web", str(OUT / "index.html")])
    if not (OUT / "index.pck").exists():  # Godot can exit 0 after a failed export
        sys.exit("Export failed: no index.pck (read Godot's errors above)")
    print(f"Built {OUT} ({sum(f.stat().st_size for f in OUT.iterdir()) / 1e6:.1f} MB)")


def publish(message: str) -> None:
    if not (SITE / ".git").exists():
        sys.exit(f"Site repo not found at {SITE}")
    for repo in (SITE, REPO):
        dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo,
                               capture_output=True, text=True, check=True).stdout.strip()
        if dirty:
            sys.exit(f"{repo} has uncommitted changes; commit them first:\n{dirty}")
    run([sys.executable, str(ROOT / "tools/check.py"), "fast"])
    build()
    names = [f.name for f in OUT.iterdir()]
    for name in names:
        shutil.copyfile(OUT / name, SITE / name)
    shutil.rmtree(SITE / "godot", ignore_errors=True)  # the old preview, now the root
    run(["git", "add", "-A", "--", *names, "godot"], cwd=SITE)
    if subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=SITE).returncode:
        run(["git", "commit", "-m", message], cwd=SITE)
        run(["git", "push", "origin", "main"], cwd=SITE)
        print("\nWebsite pushed. GitHub Pages updates in a minute or two.")
    else:
        print("Site already matches this build.")
    run(["git", "push", "origin", "master:source"])
    print("Source backed up to the source branch.")


if __name__ == "__main__":
    if sys.argv[1:] == ["build"]:
        build()
    elif len(sys.argv) == 2 and sys.argv[1].strip():
        publish(sys.argv[1].strip())
    else:
        sys.exit('Usage: python godot/tools/web.py build | "What changed"')
