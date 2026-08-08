from playwright.sync_api import sync_playwright
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
PROJECT_ROOT = HERE.parent.parent.parent

url = (BUILD / "element_print_run.html").as_uri()
out = str(PROJECT_ROOT / "Elementia_Element_Print_Run.pdf")

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page()
    pg.goto(url, wait_until="networkidle")
    pg.pdf(path=out, format="Letter", landscape=False,
           print_background=True, margin={"top": "0", "bottom": "0", "left": "0", "right": "0"})
    b.close()
print("wrote", out)
