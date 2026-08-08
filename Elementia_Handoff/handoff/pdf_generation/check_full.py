from playwright.sync_api import sync_playwright
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"

overflow_count = 0
for html, ctx in [(BUILD / "full_cards_regular.html", "regular"), (BUILD / "full_cards_capstone.html", "capstone")]:
    url = pathlib.Path(html).as_uri()
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page()
        pg.goto(url, wait_until="networkidle")
        cards = pg.query_selector_all(".card")
        print(f"--- {ctx}: {len(cards)} cards ---")
        for c in cards:
            name = c.query_selector(".ctitle").inner_text()
            card_box = c.bounding_box()
            ing_box = c.query_selector(".cingredients").bounding_box()
            card_bottom = card_box["y"] + card_box["height"]
            ing_bottom = ing_box["y"] + ing_box["height"]
            diff = ing_bottom - card_bottom
            if diff > 1:
                overflow_count += 1
                print(f"  {name:<20} OVERFLOW diff={diff:.1f}")
        b.close()
print("total overflowing cards:", overflow_count)
