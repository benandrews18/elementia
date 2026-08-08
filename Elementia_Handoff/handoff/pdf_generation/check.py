from playwright.sync_api import sync_playwright
import pathlib
HERE = pathlib.Path(__file__).resolve().parent
url = (HERE / "build" / "guide.html").as_uri()
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page()
    pg.set_viewport_size({"width":1056,"height":816})  # 11x8.5in @96dpi
    pg.goto(url, wait_until="networkidle")
    # measure each .card's scrollHeight vs its clientHeight (overflow => content clipped)
    data = pg.eval_on_selector_all(".card", """els => els.map(e => ({
        name: e.querySelector('h1').innerText,
        scroll: e.scrollHeight, client: e.clientHeight
    }))""")
    for d in data:
        over = d['scroll'] - d['client']
        flag = "  <-- OVERFLOW" if over > 2 else ""
        print(f"{d['name']:<20} content={d['scroll']} box={d['client']} diff={over}{flag}")
    b.close()
