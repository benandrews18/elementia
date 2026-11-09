from playwright.sync_api import sync_playwright
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
PDF_DIR = HERE / "pdf"

url = (BUILD / "guide_classic.html").as_uri()
out = str(PDF_DIR / "Elementia_Classic_Station_Guide.pdf")

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page()
    pg.goto(url, wait_until="networkidle")
    pg.pdf(path=out, width="11in", height="8.5in", landscape=True,
           print_background=True, margin={"top":"0","bottom":"0","left":"0","right":"0"})
    b.close()
print("wrote", out)
