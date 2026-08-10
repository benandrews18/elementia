# -*- coding: utf-8 -*-
"""
Produce an Artifact-hosting-ready copy of game/elementia.html.

Anthropic Artifacts require page content with no <!DOCTYPE>/<html>/<head>/
<body> tags of its own (the platform wraps it in its own skeleton), and run
under a CSP that blocks all external requests -- which also breaks the
game's self-registering service worker (Blob-based, requires a real origin
the sandboxed Artifact frame doesn't have).

This used to be a manual sed + hand-edit each time, which is exactly the
kind of step that silently drifts (see: the "is the published version
current?" bug from 2026-07-28). This script does the same transforms
deterministically:

  1. Strip the outer <!DOCTYPE html>/<html>/<head>/<body> wrapper tags.
  2. Strip the PWA (manifest + service worker) IIFE, replacing it with a
     one-line comment explaining the omission.
  3. Inline every tutorial/*.webp, backdrops/*.webp, and banners/*.webp
     image reference as a base64 data URI -- the Artifact is a single file
     with no sidecar assets, so the relative paths elementia.html uses for
     local/file:// testing won't resolve there. Run build_tutorial_assets.py
     and/or build_campaign_art.py first if the source images changed.

Usage:
    python game/build_artifact.py
Then publish game/build/elementia_artifact.html via the Artifact tool,
same file path every time so it updates the existing share link.
"""
import base64
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE / "elementia.html"
OUT = HERE / "build" / "elementia_artifact.html"

PWA_START = "/* ----------------------------------------------------------- PWA --- */"
BOOT_START = "/* ---------------------------------------------------------- boot --- */"
PWA_REPLACEMENT = (
    "/* PWA installability (manifest + service worker) is intentionally omitted\n"
    "   from this Artifact-hosted copy -- Blob/service-worker registration isn't\n"
    "   compatible with the sandboxed hosting here. The full version with PWA\n"
    "   support lives in game/elementia.html. */\n\n"
)

# Patterns that would violate the Artifact CSP (no external requests). The
# SVG xmlns attribute is a namespace URI, not a request, so it's excluded.
RISKY_PATTERNS = [
    r"\bfetch\(",
    r"\bXMLHttpRequest\b",
    r"\bWebSocket\(",
    r"<script\s+src=",
    r'<link[^>]+rel=["\']stylesheet["\'][^>]+href=["\']https?://',
]


def strip_document_wrapper(text):
    text, n1 = re.subn(r"\A<!DOCTYPE html>\s*<html[^>]*>\s*<head>\s*", "", text)
    text, n2 = re.subn(r"\s*</head>\s*<body>\s*", "\n", text)
    text, n3 = re.subn(r"\s*</body>\s*</html>\s*\Z", "\n", text)
    if not (n1 and n2 and n3):
        raise SystemExit(
            "Could not find the expected <!DOCTYPE>/<html>/<head>/<body> wrapper "
            "structure in elementia.html -- it may have changed shape. Update "
            "the regexes in build_artifact.py to match."
        )
    return text


def strip_pwa_block(text):
    i, j = text.find(PWA_START), text.find(BOOT_START)
    if i == -1 or j == -1 or j < i:
        raise SystemExit(
            "Could not find the PWA/boot comment markers in elementia.html -- "
            "it may have changed shape. Update build_artifact.py's markers."
        )
    return text[:i] + PWA_REPLACEMENT + text[j:]


# Matches any quoted reference to a local webp asset, wherever it appears --
# the TOUR_SLIDES array, the STATION_BG object, MINIGAME_ASSETS, or anywhere
# else one might show up later. General on purpose: adding a new tutorial
# slide, station backdrop, or mini-game sprite shouldn't require touching
# this script too.
LOCAL_IMG_RE = re.compile(r'"((?:tutorial|backdrops|banners|minigames)/[\w.\-]+\.webp)"')


def inline_local_images(text):
    paths = sorted(set(LOCAL_IMG_RE.findall(text)))
    if not paths:
        raise SystemExit(
            "No tutorial/backdrops image references found in elementia.html -- "
            "it may have changed shape. Update build_artifact.py's regex."
        )
    for rel in paths:
        p = HERE / rel
        if not p.exists():
            raise SystemExit(
                f"Referenced image not found: {p}\n"
                "Run build_tutorial_assets.py / build_campaign_art.py first."
            )
        b64 = base64.b64encode(p.read_bytes()).decode("ascii")
        text = text.replace(f'"{rel}"', f'"data:image/webp;base64,{b64}"')
    return text


def find_version(text):
    m = re.search(r'"version":\s*"([^"]+)"', text)
    return m.group(1) if m else "unknown"


def check_risky_patterns(text):
    hits = []
    for pat in RISKY_PATTERNS:
        for m in re.finditer(pat, text):
            hits.append((pat, text[max(0, m.start() - 30):m.start() + 30]))
    return hits


def main():
    src_text = SRC.read_text(encoding="utf-8")
    version = find_version(src_text)

    out_text = strip_document_wrapper(src_text)
    out_text = strip_pwa_block(out_text)
    out_text = inline_local_images(out_text)

    hits = check_risky_patterns(out_text)
    if hits:
        print("WARNING: possible CSP-violating patterns found (review before publishing):")
        for pat, ctx in hits:
            print(f"  {pat}: ...{ctx}...")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(out_text, encoding="utf-8")
    print(f"wrote {OUT}  (content v{version}, {len(out_text.splitlines())} lines)")
    print("Publish this file via the Artifact tool at the same path each time")
    print("to update the existing share link rather than minting a new one.")


if __name__ == "__main__":
    main()
