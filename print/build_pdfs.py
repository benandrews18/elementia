# -*- coding: utf-8 -*-
"""
Build the printable Classic set from the game's current data.

    python print/build_pdfs.py              # HTML + PDFs into print/pdf/
    python print/build_pdfs.py --html-only  # HTML only (fast; no Playwright)

Outputs: Classic Station Guide, Classic Card Deck, Element Cards.
Content comes from game/js/data.js and game/js/model.js (see
game_source.py); nothing here holds its own copy of recipes or points.
PDF rendering needs `pip install playwright pypdf` and
`python -m playwright install chromium`.
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
HTML_STEPS = ["build_guide_classic.py", "build_cards_classic.py", "build_element_cards.py"]
PDF_STEPS = ["render_guide_classic.py", "render_cards_classic.py", "render_element_cards.py",
             "check_guide_classic.py"]

steps = HTML_STEPS + ([] if "--html-only" in sys.argv else PDF_STEPS)
(HERE / "pdf").mkdir(exist_ok=True)
for script in steps:
    print(f"\n>> {script}")
    if subprocess.run([sys.executable, script], cwd=HERE).returncode:
        sys.exit(f"FAILED: {script}")
print("\nAll steps OK.")
