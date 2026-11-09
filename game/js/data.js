/* =====================================================================
   data.js -- Game data: DATA (stations, shops, recipes, suits) plus the hand-drawn
   item SVGs (LIGHTHOUSE_SVG, BRASS_BAR_SVG, ...).

   THE SOURCE OF TRUTH for game content: dice per roll ("take"), the
   content version, station suits, each station's dice and shop (rows are
   [emoji, name, tier, recipe, points]) and its capstone. Edit it here by
   hand. The print pipeline (print/) reads it via game_source.py's
   read_game_data(), so the block between the markers must stay plain JSON.
   Classic's item set (CORE_SET) and suit costs (ITEM_SUIT_COST_TABLE) live
   in js/model.js.
   ===================================================================== */
const DATA = /*__GAME_DATA_START__*/{
 "take": 3,
 "version": "2026.08.16",
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
     "CREATION",
     "🌳 Tree + 💧 Water + K",
     11
    ],
    [
     "🧵",
     "Fabric",
     "COMPONENT",
     "🍂 Plant Fiber + 🛠️ Tools",
     9
    ],
    [
     "__DYEYELLOW__",
     "Yellow Dye",
     "COMPONENT",
     "🍌 Banana + 💧 Water + 🫙 Glass Vial",
     16
    ],
    [
     "⛵",
     "Sailboat",
     "CREATION",
     "🛶 Canoe + 🧵 Fabric",
     10
    ],
    [
     "🧪",
     "Biofuel",
     "CREATION",
     "🌿 Seaweed + 🦴 Bone + 🌱 Soil + 🔋 Battery",
     11
    ],
    [
     "__PEARL__",
     "Pearl",
     "COMPONENT",
     "Ca + C + O + __FURNACE__ Furnace + 🕐 Clock",
     13
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
     "🌊",
     "Water Turbine",
     "CREATION",
     "💧 Water + __CONCRETE__ Concrete + __TURBINEBLADE__ Turbine Blade + 🔋 Battery",
     22
    ],
    [
     "🚤",
     "Speedboat",
     "CREATION",
     "🛶 Canoe + ⚙️ Engine + 🧭 Compass + __TURBINEBLADE__ Turbine Blade",
     26
    ],
    [
     "🏖️",
     "Beach Town",
     "CREATION",
     "__LIGHTHOUSE__ Lighthouse + 🍣 Sushi Restaurant + 🚤 Speedboat + 🍌 Banana",
     25
    ],
    [
     "🛳️",
     "Cruise Ship",
     "CREATION",
     "🚤 Speedboat + 🧭 Compass + 🔩 Stainless Steel + 🎆 Fireworks + 🎂 Fruit Cake + 🎺 Trumpet",
     40
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
     "🎆",
     "Fireworks",
     "MATERIAL",
     "C + S + K",
     4
    ],
    [
     "🪟",
     "Glass",
     "COMPONENT",
     "⏳ Sand + 🪨 Limestone",
     4
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
     "🫙",
     "Glass Vial",
     "COMPONENT",
     "🪟 Glass + __FURNACE__ Furnace",
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
     "COMPONENT",
     "__WHEEL__ Wheel + __FIBERGLASS__ Fiberglass",
     21
    ],
    [
     "💻",
     "Computer",
     "COMPONENT",
     "🔋 Battery + 🥤 Plastic + 🔌 Wire + __MICROCHIP__ Microchip",
     20
    ],
    [
     "🚗",
     "Car",
     "CREATION",
     "⚙️ Engine + 🥤 Plastic + 🪟 Glass + __RUBBER__ Rubber + __WHEEL__ Wheel",
     22
    ],
    [
     "🌐",
     "Renewable Grid",
     "CREATION",
     "🧪 Biofuel + 𖣘 Windmill + 🌊 Water Turbine + 🌻 Sunflower + ♨️ Geothermal Pump",
     29
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
     "🪨",
     "Limestone",
     "MATERIAL",
     "Ca + C + O",
     1
    ],
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
     "COMPONENT",
     "🏺 Clay + ⏳ Sand",
     6
    ],
    [
     "🍎",
     "Apple",
     "CREATION",
     "🌳 Tree + 💧 Water",
     11
    ],
    [
     "🧑‍🌾",
     "Farm",
     "CREATION",
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
     "🌻",
     "Sunflower",
     "CREATION",
     "⭐ Star + 🌾 Grain",
     20
    ],
    [
     "__OPAL__",
     "Opal",
     "COMPONENT",
     "Si + O + __FURNACE__ Furnace + 🕐 Clock",
     11
    ],
    [
     "🐔",
     "Chicken",
     "CREATION",
     "🧑‍🌾 Farm + 🥚 Egg",
     14
    ],
    [
     "🐄",
     "Cow",
     "CREATION",
     "🧑‍🌾 Farm + 🌾 Grain",
     9
    ],
    [
     "🐑",
     "Sheep",
     "CREATION",
     "🧑‍🌾 Farm + 💧 Water",
     8
    ],
    [
     "🐝",
     "Bee",
     "CREATION",
     "🧑‍🌾 Farm + 🍬 Sugar",
     8
    ],
    [
     "🧺",
     "Basket",
     "COMPONENT",
     "🍂 Plant Fiber + 🛠️ Tools",
     9
    ],
    [
     "🤍",
     "Wool",
     "COMPONENT",
     "🐑 Sheep + 🛠️ Tools",
     8
    ],
    [
     "🍯",
     "Honey",
     "COMPONENT",
     "🐝 Bee + 🍬 Sugar",
     9
    ],
    [
     "🚲",
     "Bicycle",
     "CREATION",
     "🦾 Aluminum Alloy + __WHEEL__ Wheel + __RUBBER__ Rubber",
     20
    ],
    [
     "𖣘",
     "Windmill",
     "CREATION",
     "☁️ Cloud + __CONCRETE__ Concrete + __TURBINEBLADE__ Turbine Blade + 🔋 Battery",
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
     "COMPONENT",
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
     "CREATION",
     "Ti + Al + Fe",
     3
    ],
    [
     "__FURNACE__",
     "Furnace",
     "CREATION",
     "🏺 Clay + C",
     4
    ],
    [
     "__RUBBER__",
     "Rubber",
     "COMPONENT",
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
     "🛡️",
     "Titanium Alloy",
     "MATERIAL",
     "Ti + Al + __FURNACE__ Furnace",
     4
    ],
    [
     "__BRASSBAR__",
     "Brass",
     "MATERIAL",
     "Cu + Zn + __FURNACE__ Furnace",
     10
    ],
    [
     "♨️",
     "Geothermal Pump",
     "CREATION",
     "🌋 Volcano + 💧 Water + 🔋 Battery",
     10
    ],
    [
     "__DIAMOND__",
     "Diamond",
     "COMPONENT",
     "C + __FURNACE__ Furnace + 🕐 Clock",
     20
    ],
    [
     "🌋",
     "Volcano",
     "CREATION",
     "🌎 Planet + __FURNACE__ Furnace",
     14
    ],
    [
     "🚜",
     "Tractor",
     "CREATION",
     "⚙️ Engine + __WHEEL__ Wheel + __RUBBER__ Rubber + __STEEL__ Steel",
     21
    ],
    [
     "__GEMCOLLECTION__",
     "Gemstone Collection",
     "CREATION",
     "__PEARL__ Pearl + __RUBY__ Ruby + __OPAL__ Opal + __TURQUOISE__ Turquoise + __AMBER__ Amber + __DIAMOND__ Diamond",
     19
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
     "💧",
     "Water",
     "MATERIAL",
     "H + O",
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
     "COMPONENT",
     "🏺 Clay + ⏳ Sand",
     6
    ],
    [
     "🍓",
     "Strawberries",
     "MATERIAL",
     "🍬 Sugar + Ca + 🧺 Basket",
     11
    ],
    [
     "🍄",
     "Mushroom",
     "COMPONENT",
     "🌱 Soil + 💧 Water + N",
     6
    ],
    [
     "🌳",
     "Tree",
     "COMPONENT",
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
     "CREATION",
     "🌳 Tree + 💧 Water + 🦴 Bone",
     12
    ],
    [
     "🍂",
     "Plant Fiber",
     "MATERIAL",
     "🌳 Tree + 🛠️ Tools",
     7
    ],
    [
     "🪢",
     "Rope",
     "COMPONENT",
     "🍂 Plant Fiber + 🛠️ Tools",
     8
    ],
    [
     "__LOGCABIN__",
     "Log Cabin",
     "CREATION",
     "🌳 Tree + 🛠️ Tools + __FURNACE__ Furnace",
     12
    ],
    [
     "__AMBER__",
     "Amber",
     "COMPONENT",
     "🌳 Tree + C + 🕐 Clock",
     11
    ],
    [
     "__DYERED__",
     "Red Dye",
     "COMPONENT",
     "🍓 Strawberries + 💧 Water + 🫙 Glass Vial",
     16
    ],
    [
     "🐟",
     "Salmon",
     "CREATION",
     "🌿 Seaweed + 💧 Water + 🥚 Egg",
     15
    ],
    [
     "__FOSSIL__",
     "Fossil",
     "COMPONENT",
     "🏺 Clay + 🦴 Bone + 🕐 Clock",
     17
    ],
    [
     "🦖",
     "Dinosaur",
     "CREATION",
     "__AMBER__ Amber + 🧬 DNA + __FOSSIL__ Fossil",
     13
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
     "🛢️",
     "Natural Gas",
     "MATERIAL",
     "C + H",
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
     "COMPONENT",
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
     "🍫",
     "Chocolate",
     "COMPONENT",
     "🍬 Sugar + __FURNACE__ Furnace",
     9
    ],
    [
     "__FLOUR__",
     "Flour",
     "COMPONENT",
     "🌾 Grain + 🛠️ Tools",
     18
    ],
    [
     "🥛",
     "Milk",
     "COMPONENT",
     "🐄 Cow + 💧 Water",
     10
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
     "🥨",
     "Pretzel",
     "CREATION",
     "🫓 Dough + K + __OVEN__ Oven",
     23
    ],
    [
     "🍥",
     "Fish Cakes",
     "CREATION",
     "🐟 Salmon + __FLOUR__ Flour + 🥚 Egg",
     21
    ],
    [
     "🍰",
     "Cake",
     "CREATION",
     "🫓 Dough + 🍬 Sugar + 🥚 Egg + __OVEN__ Oven",
     12
    ],
    [
     "🍶",
     "Cream",
     "COMPONENT",
     "🥛 Milk + 🕐 Clock",
     13
    ],
    [
     "🧈",
     "Butter",
     "MATERIAL",
     "🍶 Cream + 🛠️ Tools",
     13
    ],
    [
     "🥧",
     "Apple Pie",
     "CREATION",
     "🫓 Dough + 🍎 Apple + __OVEN__ Oven",
     24
    ],
    [
     "🍰",
     "Chocolate Cake",
     "CREATION",
     "🍰 Cake + 🍫 Chocolate",
     25
    ],
    [
     "🥐",
     "Croissant",
     "CREATION",
     "🫓 Dough + 🧈 Butter + __OVEN__ Oven",
     24
    ],
    [
     "🍩",
     "Éclair",
     "CREATION",
     "🫓 Dough + 🥚 Egg + 🍶 Cream + 🍫 Chocolate + __OVEN__ Oven",
     25
    ],
    [
     "__BANANABREAD__",
     "Banana Bread",
     "CREATION",
     "🫓 Dough + 🦠 Yeast + __OVEN__ Oven + 🍌 Banana",
     24
    ],
    [
     "🧁",
     "Berry Cupcakes",
     "CREATION",
     "🍰 Cake + 🫐 Blueberries + 🍓 Strawberries + 🍇 Blackberries",
     28
    ],
    [
     "🍽️",
     "Grand Banquet",
     "CREATION",
     "🍎 Apple + 🍌 Banana + 🍣 Sushi Restaurant + 🍰 Cake + 🎆 Fireworks",
     28
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
     "COMPONENT",
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
     "🍇",
     "Blackberries",
     "MATERIAL",
     "🍬 Sugar + Mg + 🧺 Basket",
     12
    ],
    [
     "🪟",
     "Glass",
     "COMPONENT",
     "⏳ Sand + 🪨 Limestone",
     4
    ],
    [
     "__CONCRETE__",
     "Concrete",
     "COMPONENT",
     "🏺 Clay + 🪨 Limestone",
     3
    ],
    [
     "🗿",
     "Statue",
     "COMPONENT",
     "🪨 Limestone + 🛠️ Tools",
     6
    ],
    [
     "📄",
     "Paper",
     "COMPONENT",
     "🍂 Plant Fiber + 💧 Water",
     12
    ],
    [
     "__DYEBLACK__",
     "Black Dye",
     "COMPONENT",
     "🍇 Blackberries + 💧 Water + 🫙 Glass Vial",
     18
    ],
    [
     "🌉",
     "Bridge",
     "CREATION",
     "🔩 Stainless Steel + 🛠️ Tools + 🌳 Tree + 💧 Water",
     12
    ],
    [
     "🏢",
     "Building",
     "CREATION",
     "🌳 Tree + __STEEL__ Steel + 🪟 Glass + __CONCRETE__ Concrete",
     13
    ],
    [
     "📕",
     "Book",
     "COMPONENT",
     "📄 Paper + 🛠️ Tools",
     13
    ],
    [
     "🧶",
     "Yarn",
     "COMPONENT",
     "🤍 Wool + __WHEEL__ Wheel",
     14
    ],
    [
     "🧣",
     "Knit Scarf",
     "CREATION",
     "🧶 Yarn + __DYERED__ Red Dye + __DYEBLUE__ Blue Dye",
     22
    ],
    [
     "🎺",
     "Trumpet",
     "CREATION",
     "__BRASSBAR__ Brass + 🛠️ Tools",
     18
    ],
    [
     "__RUBY__",
     "Ruby",
     "COMPONENT",
     "Al + O + __FURNACE__ Furnace + 🕐 Clock",
     13
    ],
    [
     "📚",
     "Library",
     "CREATION",
     "🏢 Building + 📕 Book",
     15
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
     "🏍️",
     "Motorcycle",
     "CREATION",
     "🚲 Bicycle + ⚙️ Engine + __FIBERGLASS__ Fiberglass",
     18
    ],
    [
     "🍣",
     "Sushi Restaurant",
     "CREATION",
     "🌿 Seaweed + 🐟 Salmon + 🏢 Building",
     19
    ],
    [
     "🏛️",
     "Museum",
     "CREATION",
     "🏢 Building + 🔭 Telescope + __FOSSIL__ Fossil",
     25
    ],
    [
     "🚉",
     "Central Station",
     "CREATION",
     "🚁 Helicopter + 🚄 Maglev Train + 🚗 Car + 🚤 Speedboat",
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
     "CREATION",
     "Ti + Al + Fe",
     3
    ],
    [
     "🪟",
     "Glass",
     "COMPONENT",
     "⏳ Sand + 🪨 Limestone",
     4
    ],
    [
     "🫐",
     "Blueberries",
     "MATERIAL",
     "🍬 Sugar + K + 🧺 Basket",
     14
    ],
    [
     "__DYEBLUE__",
     "Blue Dye",
     "COMPONENT",
     "🫐 Blueberries + 💧 Water + 🫙 Glass Vial",
     19
    ],
    [
     "__MICROCHIP__",
     "Microchip",
     "COMPONENT",
     "🔌 Wire + Si + Ag",
     10
    ],
    [
     "🌎",
     "Planet",
     "CREATION",
     "C + H + N + O + S + K + Ca + Si + Al + Mg + P + Fe + Ti + Cu + Ag + Ni",
     8
    ],
    [
     "🧲",
     "Magnet",
     "COMPONENT",
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
     "COMPONENT",
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
     "__TURQUOISE__",
     "Turquoise",
     "COMPONENT",
     "Cu + Al + P + __FURNACE__ Furnace + 🕐 Clock",
     14
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
     "☀️",
     "Solar System",
     "CREATION",
     "⭐ Star + 🌎 Planet",
     18
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
/* Custom brass bar: a plain metal ingot reads as the raw material Brass
   actually is (the crafted Trumpet is what gets the real 🎺 emoji now). */
const BRASS_BAR_SVG = '<svg viewBox="0 0 128 128" class="brassbar" xmlns="http://www.w3.org/2000/svg"><path fill="#8a6d2e" d="M24 102 L104 102 L90 64 L38 64 Z"/><path fill="#d9b45c" d="M38 64 L90 64 L104 38 L52 38 Z"/><path fill="#6b5326" d="M90 64 L104 38 L118 76 L104 102 Z"/><path fill="#f2dd9a" opacity="0.55" d="M56 42 L100 42 L96 46 L60 46 Z"/></svg>';

/* Custom tunnel: a bore through a mountain -- no emoji for this either. */
const TUNNEL_SVG = '<svg viewBox="0 0 128 128" class="tunnel" xmlns="http://www.w3.org/2000/svg"><path fill="#8a7860" d="M6 110 L 44 8 L 64 46 L 84 8 L 122 110 Z"/><path fill="#9c8a70" d="M64 46 L 84 8 L 122 110 L 64 110 Z"/><path fill="#5c7a4a" d="M6 110 L 44 8 L 52 24 L 18 110 Z"/><path fill="#6b8a56" d="M84 8 L 76 24 L 108 110 L 122 110 Z"/><ellipse cx="64" cy="111" rx="38" ry="9" fill="#7a6a54"/><path fill="#20232a" d="M44 110 C 44 88, 54 76, 64 76 C 74 76, 84 88, 84 110 Z"/></svg>';
