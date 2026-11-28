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
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

GODOT = "C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
SITE = REPO.parent / "elementia-site"
OUT = ROOT / "build/web"
sys.stdout.reconfigure(encoding="utf-8")  # an emoji in the message crashed the Windows console print mid-publish


def run(cmd, cwd=REPO):
    print("$", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)


# The HTML prototype's service worker (still registered on devices that
# installed it) is replaced by one that clears its caches and removes itself,
# then reloads its pages: they get the current build (the user, 2026-11-28).
SW_OFF = """self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil((async () => {
  for (const k of await caches.keys()) await caches.delete(k);
  await self.registration.unregister();
  for (const c of await self.clients.matchAll({type: "window"})) c.navigate(c.url);
})()));
"""


def build() -> None:
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    run([GODOT, "--headless", "--path", str(ROOT), "--export-release", "Web", str(OUT / "index.html")])
    if not (OUT / "index.pck").exists():  # Godot can exit 0 after a failed export
        sys.exit("Export failed: no index.pck (read Godot's errors above)")
    stamp(OUT, time.strftime("%Y%m%d%H%M%S"))
    (OUT / "sw.js").write_text(SW_OFF, encoding="utf-8")
    print(f"Built {OUT} ({sum(f.stat().st_size for f in OUT.iterdir()) / 1e6:.1f} MB)")


def stamp(out: Path, v: str) -> None:
    """Every file but index.html renamed index-<v>.* and the page pointed at
    them: a device that opened an older build can't keep running its cached
    files (the user, 2026-11-28). index.html itself is re-checked by browsers
    (GitHub Pages: 10 minutes)."""
    for f in out.iterdir():
        if f.name != "index.html" and f.name.startswith("index."):
            f.rename(out / ("index-" + v + f.name[len("index"):]))
    page = (out / "index.html").read_text(encoding="utf-8")
    page = re.sub(r"""(["'])index\.""", lambda m: m.group(1) + "index-" + v + ".", page)
    page = page.replace('"executable":"index"', f'"executable":"index-{v}"')
    assert f'"executable":"index-{v}"' in page and f'src="index-{v}.js"' in page, "the export's page changed shape: check stamp()"
    (out / "index.html").write_text(page, encoding="utf-8")


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
    for old in SITE.iterdir():  # the last build's stamped (and the old unstamped) files
        if old.is_file() and old.name != "index.html" and re.fullmatch(r"index[.-].*", old.name) and old.name not in names:
            old.unlink()
    for name in names:
        shutil.copyfile(OUT / name, SITE / name)
    run(["git", "add", "-A", "--", "."], cwd=SITE)
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
