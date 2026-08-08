from playwright.sync_api import sync_playwright
import pathlib
HERE = pathlib.Path(__file__).resolve().parent
url = (HERE / "build" / "item_reference.html").as_uri()
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page()
    pg.set_viewport_size({"width": 816, "height": 1056})  # 8.5x11in @96dpi
    pg.goto(url, wait_until="networkidle")
    data = pg.eval_on_selector_all(".sheet", """els => els.map(e => ({
        scroll: e.scrollHeight, client: e.clientHeight
    }))""")
    overflow = 0
    for i, d in enumerate(data, 1):
        over = d['scroll'] - d['client']
        flag = "  <-- OVERFLOW" if over > 2 else ""
        if over > 2:
            overflow += 1
        print(f"page {i:<3} content={d['scroll']} box={d['client']} diff={over}{flag}")
    print(f"\n{overflow} of {len(data)} pages overflow")
    b.close()
