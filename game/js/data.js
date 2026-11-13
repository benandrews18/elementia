/* =====================================================================
   data.js -- Game data: DATA (stations, shops, recipes, suits) plus the hand-drawn
   item SVG (LIGHTHOUSE_SVG).

   THE SOURCE OF TRUTH for game content: dice per roll ("take"), the
   content version, station suits, each station's dice and shop (rows are
   [emoji, name, tier, recipe, points]) and its capstone. Edit it here by
   hand. The print pipeline (print/) reads it via game_source.py's
   read_game_data(), so the block between the markers must stay plain JSON.
   Every row here is in the game (Classic). An item sold at several
   stations appears once per station, with the same recipe; its first
   listing (station order) is its home. Suit costs (ITEM_SUIT_COST_TABLE)
   live in js/model.js.
   ===================================================================== */
const DATA = /*__GAME_DATA_START__*/{
 "take": 3,
 "version": "2026.11.13",
 "suits": {
  "ocean": {
   "label": "OCEAN",
   "color": "#3aa9a0",
   "soft": "#e1f2f0"
  },
  "power": {
   "label": "POWER PLANT",
   "color": "#8a5ce0",
   "soft": "#ece3f9"
  },
  "greenhouse": {
   "label": "GREENHOUSE",
   "color": "#3aab6d",
   "soft": "#e2f1e7"
  },
  "mine": {
   "label": "DEEP MINE",
   "color": "#e2a83e",
   "soft": "#f8ecd7"
  },
  "forest": {
   "label": "OLD GROWTH",
   "color": "#e2823a",
   "soft": "#f8e4d5"
  },
  "bakery": {
   "label": "BAKERY",
   "color": "#8cb43e",
   "soft": "#eef4dc"
  },
  "city": {
   "label": "THE CITY",
   "color": "#e2543b",
   "soft": "#f8e6e1"
  },
  "observatory": {
   "label": "OBSERVATORY",
   "color": "#4d7cf2",
   "soft": "#e3ebfb"
  }
 },
 "stations": [
  {
   "emoji": "🌊",
   "name": "The Ocean",
   "suit": "ocean",
   "dice": [
    "C",
    "O",
    "H",
    "Si",
    "N",
    "Ca"
   ],
   "shop": [
    [
     "💧",
     "Water",
     "MATERIAL",
     "H + O",
     1
    ],
    [
     "🪨",
     "Limestone",
     "MATERIAL",
     "Ca + C + O",
     1
    ],
    [
     "⏳",
     "Sand",
     "MATERIAL",
     "Si + O",
     1
    ],
    [
     "🌿",
     "Seaweed",
     "MATERIAL",
     "C + 💧 Water",
     2
    ],
    [
     "☁️",
     "Cloud",
     "COMPONENT",
     "__FURNACE__ Furnace + 💧 Water",
     10
    ],
    [
     "🍌",
     "Banana",
     "COMPONENT",
     "🌳 Tree + 💧 Water + K",
     11
    ],
    [
     "__LIGHTHOUSE__",
     "Lighthouse",
     "CREATION",
     "💡 Light Bulb + __CONCRETE__ Concrete + 🪟 Glass",
     20
    ],
    [
     "__ORCA__",
     "Orca",
     "CREATION",
     "🌿 Seaweed + 🐟 Salmon + 🦴 Bone + 💧 Water",
     20
    ],
    [
     "__LIFE__",
     "Life",
     "CREATION",
     "🦴 Bone + 🧬 DNA + 💧 Water + 🕐 Clock + ⭐ Star",
     23
    ],
    [
     "🚤",
     "Speedboat",
     "CREATION",
     "🛶 Canoe + ⚙️ Engine + 🧭 Compass + __TURBINEBLADE__ Turbine Blade",
     26
    ]
   ],
   "capstone": [
    "__CORAL__",
    "Coral Reef",
    "CAPSTONE",
    "__ORCA__ Orca + 🌿 Seaweed + 🪨 Limestone + 🕐 Clock + __LIFE__ Life",
    34
   ]
  },
  {
   "emoji": "⚡",
   "name": "The Power Plant",
   "suit": "power",
   "dice": [
    "Si",
    "Al",
    "Ni",
    "Cu",
    "Fe",
    "K"
   ],
   "shop": [
    [
     "🔌",
     "Wire",
     "MATERIAL",
     "Cu + Al",
     1
    ],
    [
     "🔋",
     "Battery",
     "MATERIAL",
     "Ni + Fe + K",
     2
    ],
    [
     "⚙️",
     "Engine",
     "COMPONENT",
     "🛠️ Tools + 🛢️ Natural Gas + __STEEL__ Steel",
     10
    ],
    [
     "💡",
     "Light Bulb",
     "COMPONENT",
     "🪟 Glass + 🔌 Wire",
     10
    ],
    [
     "🕐",
     "Clock",
     "COMPONENT",
     "🔋 Battery + 🛠️ Tools",
     10
    ],
    [
     "🥤",
     "Plastic",
     "COMPONENT",
     "🛢️ Natural Gas + __FURNACE__ Furnace",
     10
    ],
    [
     "__FIBERGLASS__",
     "Fiberglass",
     "COMPONENT",
     "🪟 Glass + 🥤 Plastic",
     15
    ],
    [
     "__TURBINEBLADE__",
     "Turbine Blade",
     "CREATION",
     "__WHEEL__ Wheel + __FIBERGLASS__ Fiberglass",
     21
    ],
    [
     "💻",
     "Computer",
     "CREATION",
     "🔋 Battery + 🥤 Plastic + 🔌 Wire + __MICROCHIP__ Microchip",
     20
    ],
    [
     "🚗",
     "Car",
     "CREATION",
     "⚙️ Engine + 🥤 Plastic + 🪟 Glass + __RUBBER__ Rubber + __WHEEL__ Wheel",
     22
    ]
   ],
   "capstone": [
    "🤖",
    "Robot",
    "CAPSTONE",
    "💻 Computer + ⚙️ Engine + 🧲 Magnet + 🦾 Aluminum Alloy + 💡 Light Bulb",
    34
   ]
  },
  {
   "emoji": "🌻",
   "name": "Greenhouse",
   "suit": "greenhouse",
   "dice": [
    "C",
    "H",
    "O",
    "K",
    "N",
    "P"
   ],
   "shop": [
    [
     "♻️",
     "Fertilizer",
     "MATERIAL",
     "N + P + K",
     1
    ],
    [
     "🍬",
     "Sugar",
     "MATERIAL",
     "C + H + O",
     1
    ],
    [
     "🧬",
     "DNA",
     "MATERIAL",
     "🍬 Sugar + P + N",
     3
    ],
    [
     "🌱",
     "Soil",
     "MATERIAL",
     "🏺 Clay + ⏳ Sand",
     6
    ],
    [
     "🍎",
     "Apple",
     "COMPONENT",
     "🌳 Tree + 💧 Water",
     11
    ],
    [
     "🧑‍🌾",
     "Farm",
     "COMPONENT",
     "🌱 Soil + 🛠️ Tools + 💧 Water",
     10
    ],
    [
     "🌾",
     "Grain",
     "COMPONENT",
     "🧑‍🌾 Farm + ♻️ Fertilizer",
     13
    ],
    [
     "🔆",
     "Solar Panel",
     "COMPONENT",
     "Si + 🔌 Wire + 🪟 Glass + 🔋 Battery",
     11
    ],
    [
     "🐔",
     "Chicken",
     "COMPONENT",
     "🧑‍🌾 Farm + 🥚 Egg",
     14
    ],
    [
     "🚲",
     "Bicycle",
     "CREATION",
     "🦾 Aluminum Alloy + __WHEEL__ Wheel + __RUBBER__ Rubber",
     20
    ]
   ],
   "capstone": [
    "🏡",
    "Homestead",
    "CAPSTONE",
    "🚜 Tractor + 🐔 Chicken + 🥧 Apple Pie + __LOGCABIN__ Log Cabin + 🔆 Solar Panel",
    39
   ]
  },
  {
   "emoji": "💎",
   "name": "Deep Mine",
   "suit": "mine",
   "dice": [
    "Al",
    "Fe",
    "C",
    "S",
    "H",
    "Ti"
   ],
   "shop": [
    [
     "🛢️",
     "Natural Gas",
     "MATERIAL",
     "C + H",
     1
    ],
    [
     "__STEEL__",
     "Steel",
     "MATERIAL",
     "Fe + C + __FURNACE__ Furnace",
     1
    ],
    [
     "🏺",
     "Clay",
     "MATERIAL",
     "Al + Si + Mg",
     1
    ],
    [
     "🛠️",
     "Tools",
     "MATERIAL",
     "Ti + Al + Fe",
     2
    ],
    [
     "__FURNACE__",
     "Furnace",
     "MATERIAL",
     "🏺 Clay + C",
     4
    ],
    [
     "__RUBBER__",
     "Rubber",
     "MATERIAL",
     "🛢️ Natural Gas + S",
     5
    ],
    [
     "🔩",
     "Stainless Steel",
     "MATERIAL",
     "__STEEL__ Steel + Ni + __FURNACE__ Furnace",
     8
    ],
    [
     "🦾",
     "Aluminum Alloy",
     "MATERIAL",
     "Al + Mg + __FURNACE__ Furnace",
     7
    ],
    [
     "__DIAMOND__",
     "Diamond",
     "CREATION",
     "C + __FURNACE__ Furnace + 🕐 Clock",
     20
    ],
    [
     "🚜",
     "Tractor",
     "CREATION",
     "⚙️ Engine + __WHEEL__ Wheel + __RUBBER__ Rubber + __STEEL__ Steel",
     21
    ]
   ],
   "capstone": [
    "🚄",
    "Maglev Train",
    "CAPSTONE",
    "⚙️ Engine + 🪟 Glass + 🧲 Magnet + 🌉 Bridge + 🦾 Aluminum Alloy",
    34
   ]
  },
  {
   "emoji": "🌲",
   "name": "Old Growth Forest",
   "suit": "forest",
   "dice": [
    "C",
    "O",
    "Si",
    "Al",
    "Mg",
    "P"
   ],
   "shop": [
    [
     "⏳",
     "Sand",
     "MATERIAL",
     "Si + O",
     1
    ],
    [
     "🏺",
     "Clay",
     "MATERIAL",
     "Al + Si + Mg",
     1
    ],
    [
     "🦴",
     "Bone",
     "MATERIAL",
     "C + Ca + P",
     2
    ],
    [
     "🌱",
     "Soil",
     "MATERIAL",
     "🏺 Clay + ⏳ Sand",
     6
    ],
    [
     "🌳",
     "Tree",
     "MATERIAL",
     "🌱 Soil + 💧 Water + C + O",
     9
    ],
    [
     "🛶",
     "Canoe",
     "COMPONENT",
     "🌳 Tree + 💧 Water + 🛠️ Tools",
     11
    ],
    [
     "🦌",
     "Deer",
     "COMPONENT",
     "🌳 Tree + 💧 Water + 🦴 Bone",
     12
    ],
    [
     "__LOGCABIN__",
     "Log Cabin",
     "COMPONENT",
     "🌳 Tree + 🛠️ Tools + __FURNACE__ Furnace",
     12
    ],
    [
     "🐟",
     "Salmon",
     "COMPONENT",
     "🌿 Seaweed + 💧 Water + 🥚 Egg",
     15
    ],
    [
     "__FOSSIL__",
     "Fossil",
     "COMPONENT",
     "🏺 Clay + 🦴 Bone + 🕐 Clock",
     17
    ]
   ],
   "capstone": [
    "__ECOSYSTEM__",
    "Ecosystem",
    "CAPSTONE",
    "🦌 Deer + 🐟 Salmon + 🌳 Tree + __ORCA__ Orca + 🌈 Rainbow",
    34
   ]
  },
  {
   "emoji": "🍞",
   "name": "The Bakery",
   "suit": "bakery",
   "dice": [
    "O",
    "H",
    "C",
    "S",
    "Ca",
    "Mg"
   ],
   "shop": [
    [
     "💧",
     "Water",
     "MATERIAL",
     "H + O",
     1
    ],
    [
     "🍬",
     "Sugar",
     "MATERIAL",
     "C + H + O",
     1
    ],
    [
     "🦠",
     "Yeast",
     "MATERIAL",
     "🍬 Sugar + 💧 Water",
     6
    ],
    [
     "🥚",
     "Egg",
     "COMPONENT",
     "🧬 DNA + Ca + C + O",
     10
    ],
    [
     "__FLOUR__",
     "Flour",
     "COMPONENT",
     "🌾 Grain + 🛠️ Tools",
     18
    ],
    [
     "🫓",
     "Dough",
     "COMPONENT",
     "__FLOUR__ Flour + 💧 Water",
     19
    ],
    [
     "__OVEN__",
     "Oven",
     "CREATION",
     "__FURNACE__ Furnace + 🕐 Clock",
     20
    ],
    [
     "🍥",
     "Fish Cakes",
     "CREATION",
     "🐟 Salmon + __FLOUR__ Flour + 🥚 Egg",
     21
    ],
    [
     "🥧",
     "Apple Pie",
     "CREATION",
     "🫓 Dough + 🍎 Apple + __OVEN__ Oven",
     24
    ],
    [
     "__BANANABREAD__",
     "Banana Bread",
     "CREATION",
     "🫓 Dough + 🦠 Yeast + __OVEN__ Oven + 🍌 Banana",
     24
    ]
   ],
   "capstone": [
    "🎂",
    "Fruit Cake",
    "CAPSTONE",
    "🫓 Dough + 🍬 Sugar + 🥚 Egg + __OVEN__ Oven + 🍎 Apple + 🍌 Banana",
    36
   ]
  },
  {
   "emoji": "🏗️",
   "name": "The City",
   "suit": "city",
   "dice": [
    "Ca",
    "C",
    "O",
    "Al",
    "Si",
    "Mg"
   ],
   "shop": [
    [
     "🪨",
     "Limestone",
     "MATERIAL",
     "Ca + C + O",
     1
    ],
    [
     "__STEEL__",
     "Steel",
     "MATERIAL",
     "Fe + C + __FURNACE__ Furnace",
     1
    ],
    [
     "🏺",
     "Clay",
     "MATERIAL",
     "Al + Si + Mg",
     1
    ],
    [
     "🪟",
     "Glass",
     "MATERIAL",
     "⏳ Sand + 🪨 Limestone",
     4
    ],
    [
     "__CONCRETE__",
     "Concrete",
     "MATERIAL",
     "🏺 Clay + 🪨 Limestone",
     4
    ],
    [
     "🌉",
     "Bridge",
     "COMPONENT",
     "🔩 Stainless Steel + 🛠️ Tools + 🌳 Tree + 💧 Water",
     12
    ],
    [
     "🏢",
     "Building",
     "COMPONENT",
     "🌳 Tree + __STEEL__ Steel + 🪟 Glass + __CONCRETE__ Concrete",
     13
    ],
    [
     "🚁",
     "Helicopter",
     "CREATION",
     "⚙️ Engine + 🪟 Glass + 🔩 Stainless Steel + __TURBINEBLADE__ Turbine Blade",
     28
    ],
    [
     "🗼",
     "Skyscraper",
     "CREATION",
     "🏢 Building + ☁️ Cloud + 📡 Satellite Dish",
     21
    ],
    [
     "🏛️",
     "Museum",
     "CREATION",
     "🏢 Building + 🔭 Telescope + __FOSSIL__ Fossil",
     25
    ]
   ],
   "capstone": [
    "🌆",
    "Metropolis",
    "CAPSTONE",
    "🌉 Bridge + 🗼 Skyscraper + 🚲 Bicycle + 🚗 Car + 💡 Light Bulb",
    37
   ]
  },
  {
   "emoji": "🔭",
   "name": "The Observatory",
   "suit": "observatory",
   "dice": [
    "Ni",
    "Al",
    "Fe",
    "Ag",
    "Ti",
    "Si"
   ],
   "shop": [
    [
     "🛠️",
     "Tools",
     "MATERIAL",
     "Ti + Al + Fe",
     2
    ],
    [
     "__MICROCHIP__",
     "Microchip",
     "COMPONENT",
     "🔌 Wire + Si + Ag",
     10
    ],
    [
     "🧲",
     "Magnet",
     "MATERIAL",
     "Fe + Ni",
     2
    ],
    [
     "🧭",
     "Compass",
     "COMPONENT",
     "🧲 Magnet + 💧 Water + 🪟 Glass",
     10
    ],
    [
     "__WHEEL__",
     "Wheel",
     "COMPONENT",
     "🌳 Tree + 🛠️ Tools",
     16
    ],
    [
     "📡",
     "Satellite Dish",
     "CREATION",
     "🦾 Aluminum Alloy + 🔌 Wire",
     20
    ],
    [
     "🔭",
     "Telescope",
     "CREATION",
     "🪟 Glass + 🦾 Aluminum Alloy + Ag",
     20
    ],
    [
     "⭐",
     "Star",
     "CREATION",
     "__FURNACE__ Furnace + H + 🕐 Clock",
     20
    ],
    [
     "🌈",
     "Rainbow",
     "CREATION",
     "☁️ Cloud + ⭐ Star",
     21
    ],
    [
     "🚀",
     "Rocket",
     "CREATION",
     "💻 Computer + __FIBERGLASS__ Fiberglass + __FURNACE__ Furnace + Ti",
     28
    ]
   ],
   "capstone": [
    "🛰️",
    "Space Station",
    "CAPSTONE",
    "🚀 Rocket + 🍎 Apple + ⭐ Star + 📡 Satellite Dish + 🔆 Solar Panel",
    35
   ]
  }
 ]
}/*__GAME_DATA_END__*/;


/* Custom coral art: 🪸/🪼 are Unicode 14 glyphs with no font coverage in
   the PDF pipeline's Chromium on Windows. */

/* Custom flour sack: 🌾 is already Grain's icon. */
// "Sack filled with wheat.svg" by OSeveno, Wikimedia Commons, CC BY-SA 4.0
// -- credit required if redistributed.
// https://commons.wikimedia.org/wiki/File:Sack_filled_with_wheat.svg

/* Custom lighthouse: no emoji covers this concept at all. */
const LIGHTHOUSE_SVG = '<svg viewBox="0 0 128 128" class="lighthouse" xmlns="http://www.w3.org/2000/svg"><ellipse cx="64" cy="120" rx="36" ry="7" fill="#8a8f98"/><path fill="#9aa0a8" d="M28 118 L 44 94 L 84 94 L 100 118 Z"/><path fill="#eef0f2" d="M48 94 L 55 38 L 73 38 L 80 94 Z"/><path fill="#e0483a" d="M55 38 L 58 22 L 70 22 L 73 38 Z"/><path fill="#e0483a" d="M51 62 L 77 62 L 75 74 L 53 74 Z"/><rect x="53" y="14" width="22" height="10" rx="2" fill="#30343c"/><path fill="#ffe27a" opacity="0.55" d="M64 12 L 16 4 L 64 20 Z"/><path fill="#ffe27a" opacity="0.55" d="M64 12 L 112 4 L 64 20 Z"/><circle cx="64" cy="13" r="8" fill="#ffe27a"/></svg>';

