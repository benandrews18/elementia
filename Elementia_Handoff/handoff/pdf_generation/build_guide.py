# -*- coding: utf-8 -*-
"""Elementia Station Guide v3 — elements+dice up top, no suit badge, full capstone set."""
import re
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
BUILD = HERE / "build"
BUILD.mkdir(parents=True, exist_ok=True)

# One unique color per station, not a 4-way shared category -- each is a
# stop on the 8-color wheel that also colors the element cards (see
# build_element_cards.py's ELEMENT_SUITS): Red-Orange-Yellow-Lime-Green-
# Teal-Blue-Violet. Stations whose dice cleanly dominate one of the 4
# element-suit anchors keep that exact color (Greenhouse=Green, Deep
# Mine=Yellow, Observatory=Blue, The City=Red); the other 4 sit on a
# bridge hue between two anchors, picked by dice-pool lean plus theme
# where the dice alone don't resolve a clean lean (see the element-palette
# artifact for the full reasoning).
SUITS = {
    "ocean":      {"label": "OCEAN",       "color": "#3aa9a0", "soft": "#e1f2f0"},
    "power":      {"label": "POWER PLANT", "color": "#8a5ce0", "soft": "#ece3f9"},
    "greenhouse": {"label": "GREENHOUSE",  "color": "#3aab6d", "soft": "#e2f1e7"},
    "mine":       {"label": "DEEP MINE",   "color": "#e2a83e", "soft": "#f8ecd7"},
    "forest":     {"label": "OLD GROWTH",  "color": "#e2823a", "soft": "#f8e4d5"},
    "bakery":     {"label": "BAKERY",      "color": "#8cb43e", "soft": "#eef4dc"},
    "city":       {"label": "THE CITY",    "color": "#e2543b", "soft": "#f8e6e1"},
    "observatory":{"label": "OBSERVATORY", "color": "#4d7cf2", "soft": "#e3ebfb"},
}

# Content version — bump this (date-based) any time STATIONS/SUITS/rule
# constants below change. Every generated output (PDFs, the digital game,
# the published Artifact link) stamps this value so it's possible to tell
# at a glance whether a given PDF/game/link reflects the current content
# without diffing bytes. See CHANGELOG.md for what changed at each version.
CONTENT_VERSION = "2026.08.16"

# Table rules printed on every station page. This was previously hardcoded
# into the header string, which is how the guide came to say "TAKE 3" while
# the digital game and every simulation used 5 -- keep it here so the
# printed sheet can never silently drift from the real rules again.
TAKE = 6              # dice rolls per station visit
# No per-element carry cap: removed 2026-07-29, elements are uncapped.

STATIONS = [
    {"emoji":"🌊","name":"The Ocean","suit":"ocean",
     "dice":["C", "O", "H", "Si", "N", "Ca"],
     "shop":[("💧","Water","MATERIAL","H + O",2),
             ("🪨","Limestone","MATERIAL","Ca + C + O",2),
             ("⏳","Sand","MATERIAL","Si + O",3),
             ("🌿","Seaweed","MATERIAL","C + H + O",4),
             ("☁️","Cloud","COMPONENT","💧 Water + N + C",5),
             ("🍌","Banana","CREATION","🌳 Tree + 💧 Water + K",6),
             ("🧵","Fabric","COMPONENT","🍂 Plant Fiber + 🛠️ Tools",9),

             ("__DYEYELLOW__","Yellow Dye","COMPONENT","🍌 Banana + 💧 Water + 🫙 Glass Vial",16),


             ("⛵","Sailboat","CREATION","🛶 Canoe + 🧵 Fabric",10),
             ("🧪","Biofuel","CREATION","🌿 Seaweed + 🦴 Bone + 🌱 Soil + 🔋 Battery",11),
             ("__PEARL__","Pearl","COMPONENT","Ca + C + O + __FURNACE__ Furnace + 🕐 Clock",13),
             ("__LIGHTHOUSE__","Lighthouse","CREATION","💡 Light Bulb + __CONCRETE__ Concrete",12),
             ("__ORCA__","Orca","CREATION","🌿 Seaweed + 🐟 Salmon + 🦴 Bone",11),
             ("__LIFE__","Life","CREATION","🦴 Bone + 🧬 DNA + 💧 Water + 🕐 Clock + ⭐ Star",15),
             ("🌊","Water Turbine","CREATION","💧 Water + __CONCRETE__ Concrete + __TURBINEBLADE__ Turbine Blade + 🔋 Battery",22),

             ("🚤","Speedboat","CREATION","🛶 Canoe + ⚙️ Engine + 🧭 Compass",13),
             ("🏖️","Beach Town","CREATION","__LIGHTHOUSE__ Lighthouse + 🍣 Sushi Restaurant + 🚤 Speedboat + 🍌 Banana",25),
             ("🛳️","Cruise Ship","CREATION","🚤 Speedboat + 🧭 Compass + 🔩 Stainless Steel + 🎆 Fireworks + 🎂 Fruit Cake + 🎺 Trumpet",40)],
     "capstone":("__CORAL__","Coral Reef","CAPSTONE","__ORCA__ Orca + 🌿 Seaweed + 🪨 Limestone + 🕐 Clock",21)},

    {"emoji":"⚡","name":"The Power Plant","suit":"power",
     "dice":["Si", "Al", "Ag", "Ni", "Cu", "Fe"],
     "shop":[("🔌","Wire","MATERIAL","Cu + Al",3),
             ("🔋","Battery","MATERIAL","Ni + Fe + K",4),
             ("🎆","Fireworks","MATERIAL","C + S + K",4),
             ("🪟","Glass","COMPONENT","⏳ Sand + 🪨 Limestone",5),
             ("⚙️","Engine","COMPONENT","🛠️ Tools + 🛢️ Natural Gas + __STEEL__ Steel",6),
             ("💡","Light Bulb","COMPONENT","🪟 Glass + 🔌 Wire",6),
             ("🕐","Clock","COMPONENT","🔋 Battery + 🛠️ Tools",7),
             ("🥤","Plastic","COMPONENT","🛢️ Natural Gas + __FURNACE__ Furnace",7),
             ("🫙","Glass Vial","COMPONENT","🪟 Glass + __FURNACE__ Furnace",10),
             ("__FIBERGLASS__","Fiberglass","COMPONENT","🪟 Glass + 🥤 Plastic",9),
             ("__TURBINEBLADE__","Turbine Blade","COMPONENT","__WHEEL__ Wheel + __FIBERGLASS__ Fiberglass",14),
             ("💻","Computer","COMPONENT","🔋 Battery + 🥤 Plastic + 🔌 Wire + __MICROCHIP__ Microchip",13),
             ("🚗","Car","CREATION","⚙️ Engine + 🥤 Plastic + 🪟 Glass + __RUBBER__ Rubber + __WHEEL__ Wheel",15),
             ("🌐","Renewable Grid","CREATION","🧪 Biofuel + 𖣘 Windmill + 🌊 Water Turbine + 🌻 Sunflower + ♨️ Geothermal Pump",29)],
     "capstone":("🤖","Robot","CAPSTONE","💻 Computer + ⚙️ Engine + 🧲 Magnet + 🦾 Aluminum Alloy + 💡 Light Bulb",23)},

    {"emoji":"🌱","name":"Greenhouse","suit":"greenhouse",
     "dice":["C", "H", "O", "K", "N", "P"],
     "shop":[("🪨","Limestone","MATERIAL","Ca + C + O",2),
             ("♻️","Fertilizer","MATERIAL","N + P + K",3),
             ("🍬","Sugar","MATERIAL","C + H + O",3),
             ("🧬","DNA","MATERIAL","🍬 Sugar + P + N",3),
             ("🌱","Soil","COMPONENT","🏺 Clay + ⏳ Sand",4),
             ("🍎","Apple","CREATION","🌳 Tree + 💧 Water",6),
             ("🧑‍🌾","Farm","CREATION","🌱 Soil + 🛠️ Tools + 💧 Water",7),
             ("🌾","Grain","COMPONENT","🧑‍🌾 Farm + ♻️ Fertilizer",7),
             ("🔆","Solar Panel","COMPONENT","Si + 🔌 Wire + 🪟 Glass + 🔋 Battery",7),
             ("🌻","Sunflower","CREATION","⭐ Star + 🌾 Grain",20),
             ("🚜","Tractor","CREATION","🧑‍🌾 Farm + ⚙️ Engine + __WHEEL__ Wheel + __RUBBER__ Rubber",9),
             ("__OPAL__","Opal","COMPONENT","Si + O + __FURNACE__ Furnace + 🕐 Clock",11),
             ("🐔","Chicken","CREATION","🧑‍🌾 Farm + 🥚 Egg",10),
             ("🐄","Cow","CREATION","🧑‍🌾 Farm + 🌾 Grain",9),
             ("🐑","Sheep","CREATION","🧑‍🌾 Farm + 💧 Water",8),

             ("🐝","Bee","CREATION","🧑‍🌾 Farm + 🍬 Sugar",8),
             ("🧺","Basket","COMPONENT","🍂 Plant Fiber + 🛠️ Tools",9),

             ("🤍","Wool","COMPONENT","🐑 Sheep + 🛠️ Tools",8),

             ("🍯","Honey","COMPONENT","🐝 Bee + 🍬 Sugar",9),

             ("🚲","Bicycle","CREATION","🦾 Aluminum Alloy + __WHEEL__ Wheel + __RUBBER__ Rubber",15),
             ("𖣘","Windmill","CREATION","☁️ Cloud + __CONCRETE__ Concrete + __TURBINEBLADE__ Turbine Blade + 🔋 Battery",20)],
     "capstone":("🏡","Homestead","CAPSTONE","🚜 Tractor + 🐔 Chicken + 🌾 Grain + 🧑‍🌾 Farm + __LOGCABIN__ Log Cabin + 🔆 Solar Panel",20)},

    {"emoji":"💎","name":"Deep Mine","suit":"mine",
     "dice":["Ni", "Si", "Al", "Fe", "C", "Mg"],
     "shop":[("🛢️","Natural Gas","MATERIAL","C + H",2),
             ("__STEEL__","Steel","MATERIAL","Fe + C",2),
             ("🏺","Clay","MATERIAL","Al + Si + Mg",2),
             ("🛠️","Tools","CREATION","__STEEL__ Steel + Ti + Al",3),
             ("__FURNACE__","Furnace","CREATION","🏺 Clay + C",4),
             ("__RUBBER__","Rubber","COMPONENT","🛢️ Natural Gas + S",5),
             ("🔩","Stainless Steel","MATERIAL","__STEEL__ Steel + Ni + __FURNACE__ Furnace",4),
             ("🦾","Aluminum Alloy","MATERIAL","Al + Mg + __FURNACE__ Furnace",5),
             ("🛡️","Titanium Alloy","MATERIAL","Ti + Al + __FURNACE__ Furnace",5),
             ("__BRASSBAR__","Brass","MATERIAL","Cu + Zn + __FURNACE__ Furnace",10),
             ("♨️","Geothermal Pump","CREATION","🌋 Volcano + 💧 Water + 🔋 Battery",10),
             ("__DIAMOND__","Diamond","COMPONENT","C + __FURNACE__ Furnace + 🕐 Clock",11),
             ("🌋","Volcano","CREATION","🌎 Planet + __FURNACE__ Furnace",14),
             ("__GEMCOLLECTION__","Gemstone Collection","CREATION","__PEARL__ Pearl + __RUBY__ Ruby + __OPAL__ Opal + __TURQUOISE__ Turquoise + __AMBER__ Amber + __DIAMOND__ Diamond",19)],
     "capstone":("🚄","Maglev Train","CAPSTONE","⚙️ Engine + 🪟 Glass + 🧲 Magnet + 🌉 Bridge + 🦾 Aluminum Alloy",20)},

    {"emoji":"🌲","name":"Old Growth Forest","suit":"forest",
     "dice":["C", "O", "Si", "Al", "Mg", "S"],
     "shop":[("💧","Water","MATERIAL","H + O",2),
             ("⏳","Sand","MATERIAL","Si + O",3),
             ("🏺","Clay","MATERIAL","Al + Si + Mg",2),
             ("🦴","Bone","MATERIAL","C + Ca + P",4),
             ("🌱","Soil","COMPONENT","🏺 Clay + ⏳ Sand",4),
             ("🍓","Strawberries","MATERIAL","🍬 Sugar + Ca + 🧺 Basket",11),

             ("🍄","Mushroom","COMPONENT","🌱 Soil + 💧 Water + N",6),
             ("🌳","Tree","COMPONENT","🌱 Soil + C + O",4),
             ("🛶","Canoe","COMPONENT","🌳 Tree + 💧 Water",5),
             ("🦌","Deer","CREATION","🌳 Tree + 💧 Water + 🦴 Bone",6),
             ("🍂","Plant Fiber","MATERIAL","🌳 Tree + 🛠️ Tools",7),

             ("🪢","Rope","COMPONENT","🍂 Plant Fiber + 🛠️ Tools",8),

             ("__LOGCABIN__","Log Cabin","CREATION","🌳 Tree + 🛠️ Tools + __FURNACE__ Furnace",6),
             ("__AMBER__","Amber","COMPONENT","🌳 Tree + C + 🕐 Clock",11),
             ("__DYERED__","Red Dye","COMPONENT","🍓 Strawberries + 💧 Water + 🫙 Glass Vial",16),


             ("🐟","Salmon","CREATION","🌿 Seaweed + 💧 Water + 🥚 Egg",10),
             ("__FOSSIL__","Fossil","COMPONENT","🏺 Clay + 🦴 Bone + 🕐 Clock",10),

             ("🦖","Dinosaur","CREATION","__AMBER__ Amber + 🧬 DNA + __FOSSIL__ Fossil",13)],
     "capstone":("__ECOSYSTEM__","Ecosystem","CAPSTONE","🦌 Deer + 🐟 Salmon + 🌳 Tree + __ORCA__ Orca + 🌈 Rainbow",27)},

    {"emoji":"🍞","name":"The Bakery","suit":"bakery",
     "dice":["O", "H", "P", "S", "Ca", "Mg"],
     "shop":[("💧","Water","MATERIAL","H + O",2),
             ("🛢️","Natural Gas","MATERIAL","C + H",2),
             ("🍬","Sugar","MATERIAL","C + H + O",3),
             ("🦠","Yeast","COMPONENT","🍬 Sugar + 💧 Water",4),
             ("🥚","Egg","COMPONENT","🧬 DNA + Ca + C + O",5),
             ("🍫","Chocolate","COMPONENT","🍬 Sugar + __FURNACE__ Furnace",9),

             ("__FLOUR__","Flour","COMPONENT","🌾 Grain + 🛠️ Tools",8),

             ("🥛","Milk","COMPONENT","🐄 Cow + 💧 Water",10),
             ("🫓","Dough","COMPONENT","__FLOUR__ Flour + 💧 Water",8),
             ("__OVEN__","Oven","CREATION","__FURNACE__ Furnace + 🕐 Clock",10),


             ("🥨","Pretzel","CREATION","🫓 Dough + K + __OVEN__ Oven",23),

             ("🍞","Bread","CREATION","🫓 Dough + 🦠 Yeast + __OVEN__ Oven",11),

             ("🍰","Cake","CREATION","🫓 Dough + 🍬 Sugar + 🥚 Egg + __OVEN__ Oven",12),

             ("🍶","Cream","COMPONENT","🥛 Milk + 🕐 Clock",13),
             ("🧈","Butter","MATERIAL","🍶 Cream + 🛠️ Tools",13),
             ("🥧","Apple Pie","CREATION","🫓 Dough + 🍎 Apple + __OVEN__ Oven",23),

             ("🍰","Chocolate Cake","CREATION","🍰 Cake + 🍫 Chocolate",25),

             ("🥐","Croissant","CREATION","🫓 Dough + 🧈 Butter + __OVEN__ Oven",24),


             ("🍩","Éclair","CREATION","🫓 Dough + 🥚 Egg + 🍶 Cream + 🍫 Chocolate + __OVEN__ Oven",25),


             ("__BANANABREAD__","Banana Bread","CREATION","🍞 Bread + 🍌 Banana",16),

             ("🧁","Berry Cupcakes","CREATION","🍰 Cake + 🫐 Blueberries + 🍓 Strawberries + 🍇 Blackberries",28),


             ("🍽️","Grand Banquet","CREATION","🍎 Apple + 🍌 Banana + 🍣 Sushi Restaurant + 🍰 Cake + 🎆 Fireworks",28)],
     "capstone":("🎂","Fruit Cake","CAPSTONE","🍰 Cake + 🍎 Apple + 🍌 Banana",24)},

    {"emoji":"🏗️","name":"The City","suit":"city",
     "dice":["Ca", "C", "O", "Al", "Si", "Mg"],
     "shop":[("🪨","Limestone","MATERIAL","Ca + C + O",2),
             ("__STEEL__","Steel","MATERIAL","Fe + C",2),
             ("🏺","Clay","MATERIAL","Al + Si + Mg",2),
             ("🍇","Blackberries","MATERIAL","🍬 Sugar + Mg + 🧺 Basket",12),

             ("🪟","Glass","COMPONENT","⏳ Sand + 🪨 Limestone",5),
             ("__CONCRETE__","Concrete","COMPONENT","🏺 Clay + 🪨 Limestone",5),
             ("🗿","Statue","COMPONENT","🪨 Limestone + 🛠️ Tools",6),
             ("📄","Paper","COMPONENT","🍂 Plant Fiber + 💧 Water",12),

             ("__DYEBLACK__","Black Dye","COMPONENT","🍇 Blackberries + 💧 Water + 🫙 Glass Vial",18),


             ("🌉","Bridge","CREATION","__STEEL__ Steel + __CONCRETE__ Concrete + 💧 Water",6),
             ("🏢","Building","CREATION","__CONCRETE__ Concrete + 🪟 Glass + __STEEL__ Steel",7),
             ("📕","Book","COMPONENT","📄 Paper + 🛠️ Tools",13),
             ("🧶","Yarn","COMPONENT","🤍 Wool + __WHEEL__ Wheel",14),
             ("🧣","Knit Scarf","CREATION","🧶 Yarn + __DYERED__ Red Dye + __DYEBLUE__ Blue Dye",22),
             ("🎺","Trumpet","CREATION","__BRASSBAR__ Brass + 🛠️ Tools",18),


             ("__RUBY__","Ruby","COMPONENT","Al + O + __FURNACE__ Furnace + 🕐 Clock",13),
             ("📚","Library","CREATION","🏢 Building + 📕 Book",15),
             ("🚁","Helicopter","CREATION","⚙️ Engine + 🪟 Glass + 🔩 Stainless Steel + __TURBINEBLADE__ Turbine Blade",18),
             ("🗼","Skyscraper","CREATION","🏢 Building + ☁️ Cloud + 📡 Satellite Dish",14),
             ("🏍️","Motorcycle","CREATION","🚲 Bicycle + ⚙️ Engine",18),
             ("🍣","Sushi Restaurant","CREATION","🌿 Seaweed + 🐟 Salmon + 🏢 Building",19),
             ("🏛️","Museum","CREATION","🏢 Building + 🔭 Telescope + __FOSSIL__ Fossil",16),
             ("🚉","Central Station","CREATION","🚁 Helicopter + 🚄 Maglev Train + 🚗 Car + 🚤 Speedboat",25)],
     "capstone":("🌆","Metropolis","CAPSTONE","🌉 Bridge + 🗼 Skyscraper + 🚁 Helicopter + 🚗 Car + 💡 Light Bulb",27)},

    {"emoji":"🔭","name":"The Observatory","suit":"observatory",
     "dice":["Ni", "Al", "Fe", "Ag", "Ti", "Si"],
     "shop":[("🛠️","Tools","CREATION","__STEEL__ Steel + Ti + Al",3),
             ("🪟","Glass","COMPONENT","⏳ Sand + 🪨 Limestone",5),
             ("🫐","Blueberries","MATERIAL","🍬 Sugar + K + 🧺 Basket",14),

             ("__DYEBLUE__","Blue Dye","COMPONENT","🫐 Blueberries + 💧 Water + 🫙 Glass Vial",19),


             ("__MICROCHIP__","Microchip","COMPONENT","🔌 Wire + Si + Ag",8),
             ("🌎","Planet","CREATION","C + H + N + O + S + K + Ca + Si + Al + Mg + P + Fe + Ti + Cu + Ag + Ni",8),
             ("🧲","Magnet","COMPONENT","Fe + Ni",4),
             ("🧭","Compass","COMPONENT","🧲 Magnet + 💧 Water + 🪟 Glass",6),
             ("__WHEEL__","Wheel","MATERIAL","🌳 Tree + 🛠️ Tools",9),
             ("📡","Satellite Dish","COMPONENT","🦾 Aluminum Alloy + 🔌 Wire",10),
             ("🔭","Telescope","CREATION","🪟 Glass + 🦾 Aluminum Alloy + Ag",10),
             ("__TURQUOISE__","Turquoise","COMPONENT","Cu + Al + P + __FURNACE__ Furnace + 🕐 Clock",14),
             ("⭐","Star","CREATION","__FURNACE__ Furnace + H + 🕐 Clock",13),
             ("🌈","Rainbow","CREATION","☁️ Cloud + ⭐ Star",13),
             ("☀️","Solar System","CREATION","⭐ Star + 🌎 Planet",18),
             ("🚀","Rocket","CREATION","💻 Computer + 🔆 Solar Panel + 🛡️ Titanium Alloy",19)],
     "capstone":("🛰️","Space Station","CAPSTONE","🚀 Rocket + 🍎 Apple + ⭐ Star + 📡 Satellite Dish",29)},
]

PIPS = {1:[4],2:[0,8],3:[0,4,8],4:[0,2,6,8],5:[0,2,4,6,8],6:[0,2,3,5,6,8]}

def die_face(val):
    cells = "".join(f'<span class="pip {"on" if i in PIPS[val] else ""}"></span>' for i in range(9))
    return f'<div class="die">{cells}</div>'

def gather_html(dice, color):
    """6 columns, one per element -- one die face each (faces 1-6, in pool
    order). Every station now gathers exactly 6 distinct elements with
    uniform odds, so there's no more 'champion' face-doubling."""
    cols = []
    for i, sym in enumerate(dice, start=1):
        cols.append(f"""
      <div class="gcol">
        <div class="chip" style="background:{color}">{sym}</div>
        <div class="diestack">
          <div class="dcell">{die_face(i)}</div>
        </div>
      </div>""")
    return "".join(cols)

def render_recipe(r):
    r = r.replace("*", '<span class="farmstar">*</span>')
    tokens = r.split(" + ")
    # Elements before items, always (matches sortIngredientTokens() in the
    # digital game) -- a stable partition, each group keeping its own
    # original relative order, not a full re-sort.
    def is_elem(tok):
        return re.fullmatch(r"[A-Z][a-z]?", tok.strip()) is not None
    tokens = [t for t in tokens if is_elem(t)] + [t for t in tokens if not is_elem(t)]
    out = []
    for tok in tokens:
        bare = tok.strip()
        if is_elem(tok):
            out.append(f'<span class="elem-badge">{bare}</span>')
        else:
            # Keep each ingredient's icon+name together so a multi-word name
            # (e.g. "Natural Gas") never splits across the line break -- the
            # line can still wrap at the " + " between tokens, just not
            # inside one.
            out.append(f'<span class="rtok">{tok}</span>')
    return " + ".join(out)

def shop_html(shop):
    out = []
    for e, n, t, r, pts in shop:
        out.append(f"""
      <div class="item"><div class="item-emoji">{e}</div><div class="item-body">
        <div class="item-top"><span class="item-name">{n}</span><span class="tier">{t}</span></div>
        <div class="recipe">{render_recipe(r)}</div></div></div>""")
    return "".join(out)

# Same 16-element set/atomic numbers as build_element_cards.py's own
# ELEMENTS list -- kept here too since gather_html's dice order needs it
# and that script's card order isn't imported by this one (or vice versa).
ATOMIC_NUM = {"H":1,"C":6,"N":7,"O":8,"Mg":12,"Al":13,"Si":14,"P":15,"S":16,
              "K":19,"Ca":20,"Ti":22,"Fe":26,"Ni":28,"Cu":29,"Ag":47}

def page(s, idx, total):
    su = SUITS[s["suit"]]

    cap_e, cap_n, cap_t, cap_r, cap_pts = s["capstone"]
    cap = f"""
      <div class="capstone"><div class="cap-emoji">{cap_e}</div><div class="cap-body">
        <div class="cap-top"><span class="cap-name">{cap_n}</span><span class="cap-tag">{cap_t}</span></div>
        <div class="recipe">{render_recipe(cap_r)}</div>
      </div></div>"""

    return f"""
    <section class="page"><div class="card" style="--suit:{su['color']};--suit-soft:{su['soft']}">
      <header class="head">
        <span class="st-emoji">{s['emoji']}</span>
        <div class="st-titles"><h1>{s['name']}</h1></div>
        <div class="draw">PLAY ▸ ROLL {TAKE} DICE</div>
      </header>

      <div class="gatherblock">{gather_html(sorted(s['dice'], key=lambda e: ATOMIC_NUM[e]), su['color'])}</div>

      <div class="makewrap">
        <div class="col-label">MAKE HERE</div>
        <div class="shop">{shop_html(s['shop'])}</div>
        {cap}
      </div>
      <footer class="foot">
        <span>Elementia · Station Guide · v{CONTENT_VERSION}</span>
        <span>{idx} / {total}</span></footer>
    </div></section>"""

CSS = """
@page { size: 11in 8.5in; margin: 0; }
* { box-sizing: border-box; margin:0; padding:0; }
body { font-family:'Helvetica Neue',Arial,'Noto Color Emoji',sans-serif; color:#1f2733;
  -webkit-print-color-adjust:exact; print-color-adjust:exact; }
.page { width:11in; height:8.5in; padding:0.34in; page-break-after:always; }
.card { width:100%; height:100%; border-radius:22px; overflow:hidden; border:1px solid #e4e7ec;
  display:flex; flex-direction:column; border-top:9px solid var(--suit);
  background:linear-gradient(180deg,var(--suit-soft) 0%,#ffffff 26%); }

.head { display:flex; align-items:center; gap:20px; padding:24px 34px 12px; }
.st-emoji { font-size:56px; line-height:1; }
.st-titles { flex:1; }
.st-titles h1 { font-size:40px; font-weight:800; letter-spacing:-0.5px; }
.draw { font-size:14px; font-weight:800; letter-spacing:1.2px; color:#6b7280; white-space:nowrap; }

.gatherblock { margin:4px 34px 0; padding:8px 20px; background:#fbfcfd;
  border:1.5px solid #eef1f4; border-radius:16px; display:flex; gap:11px; justify-content:center; }
.gcol { flex:1; max-width:142px; display:flex; flex-direction:column; align-items:center; gap:10px; }
.chip { width:100%; color:#fff; font-size:26px; font-weight:800; text-align:center;
  padding:12px 0; border-radius:12px; position:relative; }
.diestack { display:flex; flex-direction:row; gap:6px; align-items:center; justify-content:center; }
.die { width:42px; height:42px; background:#fff; border:2px solid #d6dbe2; border-radius:9px;
  display:grid; grid-template-columns:repeat(3,1fr); grid-template-rows:repeat(3,1fr); padding:6px; }
.pip { width:7px; height:7px; border-radius:50%; margin:auto; }
.pip.on { background:#3a4250; }

.makewrap { padding:6px 34px 4px; flex:1; display:flex; flex-direction:column; min-height:0; }
.col-label { font-size:13px; font-weight:800; letter-spacing:1.6px; color:#98a2b3;
  padding-bottom:5px; border-bottom:2px solid #eceff3; margin-bottom:7px; }
/* space-between (not center) so the rows spread out to fill the whole
   makewrap gap themselves -- .shop is already flex:1 between .col-label
   and .capstone, so this makes the item rows evenly occupy that entire
   span rather than clumping together in its middle. */
.shop { display:grid; grid-template-columns:1fr 1fr; gap:6px 50px; align-content:space-between; flex:1; }
.item { display:flex; gap:14px; align-items:flex-start; border:1px solid #e4e7ec;
  border-radius:10px; padding:6px 10px; }
.item-emoji { font-size:30px; line-height:1.1; width:36px; text-align:center; }
.item-body { flex:1; min-width:0; }
.item-top { display:flex; align-items:center; gap:10px; flex-wrap:wrap; }
.item-name { font-size:19px; font-weight:800; line-height:1; margin-top:-2px; }
.tier { font-size:11px; font-weight:800; letter-spacing:.6px; color:#667085; background:#f2f4f7;
  padding:2px 8px; border-radius:6px; }
.recipe { font-size:17px; color:#475467; margin-top:0; line-height:1.15; }
.rtok { white-space:nowrap; }

.capstone { grid-column:1/-1; margin-top:8px; display:flex; gap:14px; align-items:center;
  background:linear-gradient(90deg,#fff8ec,#fffdf8); border:2px solid #f0d9a8; border-radius:14px; padding:13px 18px; }
.cap-emoji { font-size:36px; }
.cap-top { display:flex; align-items:center; gap:10px; }
.cap-name { font-size:21px; font-weight:800; }
.cap-tag { font-size:10.5px; font-weight:800; letter-spacing:.8px; color:#b7791f; background:#fbecc8; padding:3px 9px; border-radius:6px; }

.footnote { font-size:12px; color:#667085; padding:2px 34px 0; font-style:italic; }

/* Custom item art pulled live from elementia.html's own CUSTOM_ICONS (see
   EXTRA_MARKERS/extract_js_const below) -- those <img> tags carry a class
   but no inline size, relying on a CSS selector this file doesn't
   otherwise have (the original hand-drawn __ORCA__/__FLOUR__-style SVGs
   above size themselves inline instead). One rule here covers all of them. */
.coral,.flour,.rubbersq,.wheelicon,.furnaceicon,.ovenicon,.bananabreadicon,.turbineicon,
.steelicon,.fossilicon,.concreteicon,.fiberglassicon,.logcabinicon,
.diamondicon,.lifeicon,.ecosystemicon,.microchip,.noto,.brassbar,.alcan,
.gemcollectionicon,.pearlicon,.rubyicon,.opalicon,.turquoiseicon,.ambericon
{ width:1em; height:1em; vertical-align:-0.15em; display:inline-block; }
.stnote { font-size:16px; color:#5a6472; padding:2px 34px 0; font-style:italic; font-weight:600; }
.farmstar { font-size:1.5em; color:#c79a2e; font-weight:800; font-style:normal; vertical-align:-0.05em; }
.elem-badge { display:inline-block; font-weight:800; border:2px solid #3a4250; border-radius:6px;
  padding:0px 6px; margin:0 1px; color:#1f2733; }
.foot { margin-top:auto; display:flex; justify-content:space-between; align-items:center; gap:14px;
  padding:10px 34px 14px; font-size:11px; color:#98a2b3; border-top:1px solid #f2f4f7; }
"""

ORCA_SVG = '''<svg viewBox="0 0 128 128" style="width:1em;height:1em;vertical-align:-0.15em" xmlns="http://www.w3.org/2000/svg"><path style="fill:#5E6367;" d="M46.1,52.5c0,0,2.5,6.5,6.8,12.6c4.8,6.7,10.8,12.4,14.6,10.9s0.2-8.5-1.5-13.8
	c-2.4-7.4-0.9-9.8-0.9-9.8L46.1,52.5z"/>
<path style="fill:#464C4F;" d="M91.7,84.2L84.9,90L83,91.3c0,0-5.1,0.2-11.3-0.9c-6.2-1.1-9-1.8-10.2-1.7c-1.1,0.1-1.4,1.5-1,3.3
	s0.5,5.6,4.1,9.6c3.7,4,6.4,5.1,6.4,5.1s-0.9,5.1,1,9.3c1.9,4.1,5.5,8.3,6.9,8.2c1.4-0.2,1.6-1.8,2.5-4.4c0.9-2.5,4.1-10.9,4.7-13
	s2-5.5,2-5.5s23.2-6.2,27.3-31.8c4-25.6-13.1-38.9-13.1-42.8s4.5-11.5,6.9-14.3s5.1-6,2.9-7.5c-2.1-1.6-9.7,1.1-15.2,5.8
	s-6.7,5.9-8.7,5.7c-2-0.2-25.6-13.6-52.4-5.1C11.6,19,13.5,36.4,13.5,36.4s-3.2,2.2-3.9,5.9c-0.9,4.5-0.1,5.4-0.1,5.4l49.4,0.5
	l24.4,11.5l10,13.6L91.7,84.2z"/>
<path style="fill:#F4F0EF;" d="M27.9,33.8c0.7,0.2,1.6,0.7,3.5-0.4c1.9-1.1,6.3-2.7,9.2-3.6c3.3-0.9,8-4,7-8.1s-7-5-12.6-2.1
	C28.5,23,27.6,30,27.6,30L27.9,33.8z"/>
<path style="fill:#131314;" d="M26.3,30.2c-1.7,1.3-2,3.9-0.6,5.5s3.1,1.6,4.6,0.8c1.4-0.8,2.2-3.3,0.8-5.3
	C29.7,29.3,27.8,29.1,26.3,30.2z"/>
<path style="fill:#CDCDCE;" d="M64.3,91.9c-1.4,0.9,1.1,5.9,3.8,8.6c2.9,2.9,5.5,3.9,5.5,3.9s-0.7,4.3,0.5,8
	c0.9,2.7,2.6,5.2,3.6,5.3c1.7,0.3,4.2-8.3,5.6-11.9s3-8.8,1.3-10.8c-1.5-1.8-5.7-0.8-11-1.2C68.5,93.3,65.4,91.2,64.3,91.9z"/>
<path style="fill:#696F75;" d="M91.6,29.9c-0.5,1.6,1.8,3.3,4.8,4.2c5.5,1.8,11.2,0.9,11.2,0.9s-2.9-3.9-3.4-4.7
	c-0.5-0.8-1.8-3.2-1.8-3.2s-6,0.5-7.5,0.8C93.4,28.1,92.1,28.5,91.6,29.9z"/>
<path style="fill:#F4F0EF;" d="M88,74.8l0.1,8.9l-3.2,7c0,0,1.3,0.7,3.8-1.2c2.5-1.9,8.6-9,8.3-18s-4.7-12.8-2.9-14.4
	c1.8-1.5,4.4,0.8,5.6,1.5c1.1,0.8,2.8,2.7,4.3,1.2s1.5-7.4-2.8-10.4c-4.3-3-8.8-2.3-12.9-1.5s-7.4,1.8-11.8,0.4
	c-4.4-1.5-8.9-2.9-11.8-4.6S55.8,36,45,35.5s-18.1,5.7-18.1,5.7L12.8,48l3.9,3.6l26.9,0.3l19.6,2.7l13.4,5.9l8.9,7.9L88,74.8z"/>
<g>
	<path style="fill:#CDCDCE;" d="M84.9,90.7c-0.7-0.8,3.1-5.9,2.2-14.1c-0.7-6.4-7.6-14.9-21.5-19.6c-6.6-2.2-14.1-3.1-21.8-3.4
		c-5.5-0.2-21.6,0.9-28-1c-3.3-1-5.6-3.3-5.7-4.1l3.7-0.2c0,0,1.7,2.9,12.9,2.5c6.1-0.2,27.4-1.2,39.1,2.8
		c6.5,2.2,11.4,4.9,15.2,8.2c5.5,4.9,8.3,10.6,8.8,14.6C90.9,85.5,85.6,91.5,84.9,90.7z"/>
</g>
<path style="fill:#131314;" d="M9.3,46.7c-0.1,0.4,0.1,1.6,0.9,2.1c0.8,0.6,3.3,1.2,10.3-2.4c6.7-3.6,7.8-5.2,6.8-6.9
	c-0.8-1.4-3.5,0.6-4.9,1.4c-1.5,0.8-5.2,3-7.5,3.9S9.3,46.7,9.3,46.7z"/>
<path style="fill:#464C4F;" d="M67,36.5c0,0,3.6-1.3,10.2-7.4c8.8-8.1,11.1-15.5,8-17.7c-3.1-2.2-8.2-1.7-17,4
	c-8.3,5.4-15,14.5-15,14.5L67,36.5z"/>
<g>
	<path style="fill:#252829;" d="M63.8,38.2c-0.8-1.1,3.2-3.4,6.3-5.8c1.6-1.3,3.7-2.9,6-4.9c6.8-5.9,10.7-12.6,8.3-14.9
		c-2.4-2.3-8.8-0.2-16.4,4.8c-3,2-5.9,4.6-8.2,6.9c-2.5,2.6-4.3,5.9-5.8,7.4c-0.7,0.7-1.6,0.9-2,0.5c-1.6-1.5,1.5-5.5,4.6-9
		c2.4-2.7,5.8-5.8,9.5-8.2c8.9-5.8,16.3-7.4,20.1-4.7c1.2,0.9,1.7,2.3,1.8,3.9c0.2,4.2-3.5,9.8-10,15.5c-1.8,1.5-4.6,4.1-6,5.2
		C68,37.9,64.7,39.3,63.8,38.2z"/>
</g></svg>'''



# Custom lighthouse: no standard emoji exists for this at all (closest options
# are generic tower/beacon glyphs that don't read as "lighthouse"), so this
# is original rather than a font-coverage workaround like Orca/Coral/Flour.
LIGHTHOUSE_SVG = '''<svg viewBox="0 0 128 128" style="width:1em;height:1em;vertical-align:-0.15em" xmlns="http://www.w3.org/2000/svg">
<ellipse cx="64" cy="120" rx="36" ry="7" fill="#8a8f98"/>
<path fill="#9aa0a8" d="M28 118 L 44 94 L 84 94 L 100 118 Z"/>
<path fill="#eef0f2" d="M48 94 L 55 38 L 73 38 L 80 94 Z"/>
<path fill="#e0483a" d="M55 38 L 58 22 L 70 22 L 73 38 Z"/>
<path fill="#e0483a" d="M51 62 L 77 62 L 75 74 L 53 74 Z"/>
<rect x="53" y="14" width="22" height="10" rx="2" fill="#30343c"/>
<path fill="#ffe27a" opacity="0.55" d="M64 12 L 16 4 L 64 20 Z"/>
<path fill="#ffe27a" opacity="0.55" d="M64 12 L 112 4 L 64 20 Z"/>
<circle cx="64" cy="13" r="8" fill="#ffe27a"/>
</svg>'''

# Custom tunnel: a bore through a mountain, distinct from Maglev Train's 🚄
# and Deep Mine's other icons -- no emoji covers this concept at all.
TUNNEL_SVG = '''<svg viewBox="0 0 128 128" style="width:1em;height:1em;vertical-align:-0.15em" xmlns="http://www.w3.org/2000/svg">
<path fill="#8a7860" d="M6 110 L 44 8 L 64 46 L 84 8 L 122 110 Z"/>
<path fill="#9c8a70" d="M64 46 L 84 8 L 122 110 L 64 110 Z"/>
<path fill="#5c7a4a" d="M6 110 L 44 8 L 52 24 L 18 110 Z"/>
<path fill="#6b8a56" d="M84 8 L 76 24 L 108 110 L 122 110 Z"/>
<ellipse cx="64" cy="111" rx="38" ry="9" fill="#7a6a54"/>
<path fill="#20232a" d="M44 110 C 44 88, 54 76, 64 76 C 74 76, 84 88, 84 110 Z"/>
</svg>'''

# Newer custom-art items never got a hand-drawn SVG here the way Orca/
# Flour/Lighthouse/Tunnel did -- their art was made straight in
# elementia.html as CUSTOM_ICONS overrides instead (see
# game/tools/fetch_noto_icons.py's own docstring). Pulled live from there
# at build time rather than duplicated into this file, same as
# build_cards_classic.py's own EXTRA_MARKERS already does.
EXTRA_MARKERS = {
    "__CORAL__": "CORAL_SVG", "__RUBBER__": "RUBBER_SVG", "__FLOUR__": "FLOUR_SVG",
    "__WHEEL__": "WHEEL_IMG", "__FURNACE__": "FURNACE_IMG", "__OVEN__": "OVEN_IMG",
    "__BANANABREAD__": "BANANABREAD_IMG", "__TURBINEBLADE__": "TURBINEBLADE_IMG",
    "__STEEL__": "STEEL_IMG", "__FOSSIL__": "FOSSIL_IMG", "__CONCRETE__": "CONCRETE_IMG",
    "__FIBERGLASS__": "FIBERGLASS_IMG", "__LOGCABIN__": "LOGCABIN_IMG",
    "__DIAMOND__": "DIAMOND_IMG", "__ECOSYSTEM__": "ECOSYSTEM_IMG",
    "__LIFE__": "LIFE_IMG", "__MICROCHIP__": "MICROCHIP_IMG",
    "__DYEYELLOW__": "DYE_YELLOW_IMG", "__DYERED__": "DYE_RED_IMG",
    "__DYEBLUE__": "DYE_BLUE_IMG", "__DYEBLACK__": "DYE_BLACK_IMG",
    "__BRASSBAR__": "BRASS_BAR_SVG", "__GOLEM__": "GOLEM_IMG", "__ALCAN__": "ALCAN_SVG",
    "__GEMCOLLECTION__": "GEMCOLLECTION_IMG", "__PEARL__": "PEARL_IMG",
    "__RUBY__": "RUBY_IMG", "__OPAL__": "OPAL_IMG", "__TURQUOISE__": "TURQUOISE_IMG",
    "__AMBER__": "AMBER_IMG",
}
_GAME_HTML = (HERE.parent.parent.parent / "game" / "elementia.html").read_text(encoding="utf-8")

def extract_js_const(name):
    m = re.search(r"const " + name + r" = '(.*?)';", _GAME_HTML)
    if not m:
        raise SystemExit(f"Could not find const {name} in elementia.html")
    return m.group(1)

pages = "\n".join(page(s, i+1, len(STATIONS)) for i, s in enumerate(STATIONS))
html = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{pages}</body></html>"""
html = (html.replace("__ORCA__", ORCA_SVG)
        .replace("__LIGHTHOUSE__", LIGHTHOUSE_SVG).replace("__TUNNEL__", TUNNEL_SVG))
for token, const_name in EXTRA_MARKERS.items():
    if token in html:
        html = html.replace(token, extract_js_const(const_name))
(BUILD / "guide.html").write_text(html, encoding="utf-8")
print("wrote", BUILD / "guide.html")
