from playwright.sync_api import sync_playwright
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
PROJECT_ROOT = HERE.parent.parent.parent


def render(html_path, pdf_path, landscape):
    url = pathlib.Path(html_path).as_uri()
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page()
        pg.goto(url, wait_until="networkidle")
        pg.pdf(path=str(pdf_path), format="Letter", landscape=landscape,
               print_background=True, margin={"top": "0", "bottom": "0", "left": "0", "right": "0"})
        b.close()
    print("wrote", pdf_path)


render(BUILD / "print_run_regular.html", BUILD / "print_run_regular.pdf", landscape=False)
render(BUILD / "print_run_capstone.html", BUILD / "print_run_capstone.pdf", landscape=True)

from pypdf import PdfReader, PdfWriter
writer = PdfWriter()
for path in [BUILD / "print_run_regular.pdf", BUILD / "print_run_capstone.pdf"]:
    reader = PdfReader(path)
    for page in reader.pages:
        writer.add_page(page)
out = PROJECT_ROOT / "Elementia_Print_Run.pdf"
with open(out, "wb") as f:
    writer.write(f)
print("merged ->", out, len(PdfReader(out).pages), "pages")
