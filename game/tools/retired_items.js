/* The 61 items retired from Classic on 2026-11-08 (commit 51350f9),
   taken from game/js/data.js just before that commit. Read-only input for
   tools/item_workshop.html; the game does not load this file. */
const RETIRED_ITEMS = [
 {
  "station": "The Ocean",
  "emoji": "🧵",
  "name": "Fabric",
  "oldTier": "COMPONENT",
  "recipe": "🍂 Plant Fiber + 🛠️ Tools",
  "points": 9
 },
 {
  "station": "The Ocean",
  "emoji": "__DYEYELLOW__",
  "name": "Yellow Dye",
  "oldTier": "COMPONENT",
  "recipe": "🍌 Banana + 💧 Water + 🫙 Glass Vial",
  "points": 16
 },
 {
  "station": "The Ocean",
  "emoji": "⛵",
  "name": "Sailboat",
  "oldTier": "CREATION",
  "recipe": "🛶 Canoe + 🧵 Fabric",
  "points": 10
 },
 {
  "station": "The Ocean",
  "emoji": "🧪",
  "name": "Biofuel",
  "oldTier": "CREATION",
  "recipe": "🌿 Seaweed + 🦴 Bone + 🌱 Soil + 🔋 Battery",
  "points": 11
 },
 {
  "station": "The Ocean",
  "emoji": "__PEARL__",
  "name": "Pearl",
  "oldTier": "COMPONENT",
  "recipe": "Ca + C + O + __FURNACE__ Furnace + 🕐 Clock",
  "points": 13
 },
 {
  "station": "The Ocean",
  "emoji": "🌊",
  "name": "Water Turbine",
  "oldTier": "CREATION",
  "recipe": "💧 Water + __CONCRETE__ Concrete + __TURBINEBLADE__ Turbine Blade + 🔋 Battery",
  "points": 22
 },
 {
  "station": "The Ocean",
  "emoji": "🏖️",
  "name": "Beach Town",
  "oldTier": "CREATION",
  "recipe": "__LIGHTHOUSE__ Lighthouse + 🍣 Sushi Restaurant + 🚤 Speedboat + 🍌 Banana",
  "points": 25
 },
 {
  "station": "The Ocean",
  "emoji": "🛳️",
  "name": "Cruise Ship",
  "oldTier": "CREATION",
  "recipe": "🚤 Speedboat + 🧭 Compass + 🔩 Stainless Steel + 🎆 Fireworks + 🎂 Fruit Cake + 🎺 Trumpet",
  "points": 40
 },
 {
  "station": "The Power Plant",
  "emoji": "🎆",
  "name": "Fireworks",
  "oldTier": "MATERIAL",
  "recipe": "C + S + K",
  "points": 4
 },
 {
  "station": "The Power Plant",
  "emoji": "🫙",
  "name": "Glass Vial",
  "oldTier": "COMPONENT",
  "recipe": "🪟 Glass + __FURNACE__ Furnace",
  "points": 10
 },
 {
  "station": "The Power Plant",
  "emoji": "🌐",
  "name": "Renewable Grid",
  "oldTier": "CREATION",
  "recipe": "🧪 Biofuel + 𖣘 Windmill + 🌊 Water Turbine + 🌻 Sunflower + ♨️ Geothermal Pump",
  "points": 29
 },
 {
  "station": "Greenhouse",
  "emoji": "🌻",
  "name": "Sunflower",
  "oldTier": "CREATION",
  "recipe": "⭐ Star + 🌾 Grain",
  "points": 20
 },
 {
  "station": "Greenhouse",
  "emoji": "__OPAL__",
  "name": "Opal",
  "oldTier": "COMPONENT",
  "recipe": "Si + O + __FURNACE__ Furnace + 🕐 Clock",
  "points": 11
 },
 {
  "station": "Greenhouse",
  "emoji": "🐄",
  "name": "Cow",
  "oldTier": "CREATION",
  "recipe": "🧑‍🌾 Farm + 🌾 Grain",
  "points": 9
 },
 {
  "station": "Greenhouse",
  "emoji": "🐑",
  "name": "Sheep",
  "oldTier": "CREATION",
  "recipe": "🧑‍🌾 Farm + 💧 Water",
  "points": 8
 },
 {
  "station": "Greenhouse",
  "emoji": "🐝",
  "name": "Bee",
  "oldTier": "CREATION",
  "recipe": "🧑‍🌾 Farm + 🍬 Sugar",
  "points": 8
 },
 {
  "station": "Greenhouse",
  "emoji": "🧺",
  "name": "Basket",
  "oldTier": "COMPONENT",
  "recipe": "🍂 Plant Fiber + 🛠️ Tools",
  "points": 9
 },
 {
  "station": "Greenhouse",
  "emoji": "🤍",
  "name": "Wool",
  "oldTier": "COMPONENT",
  "recipe": "🐑 Sheep + 🛠️ Tools",
  "points": 8
 },
 {
  "station": "Greenhouse",
  "emoji": "🍯",
  "name": "Honey",
  "oldTier": "COMPONENT",
  "recipe": "🐝 Bee + 🍬 Sugar",
  "points": 9
 },
 {
  "station": "Greenhouse",
  "emoji": "𖣘",
  "name": "Windmill",
  "oldTier": "CREATION",
  "recipe": "☁️ Cloud + __CONCRETE__ Concrete + __TURBINEBLADE__ Turbine Blade + 🔋 Battery",
  "points": 20
 },
 {
  "station": "Deep Mine",
  "emoji": "🛡️",
  "name": "Titanium Alloy",
  "oldTier": "MATERIAL",
  "recipe": "Ti + Al + __FURNACE__ Furnace",
  "points": 4
 },
 {
  "station": "Deep Mine",
  "emoji": "__BRASSBAR__",
  "name": "Brass",
  "oldTier": "MATERIAL",
  "recipe": "Cu + Zn + __FURNACE__ Furnace",
  "points": 10
 },
 {
  "station": "Deep Mine",
  "emoji": "♨️",
  "name": "Geothermal Pump",
  "oldTier": "CREATION",
  "recipe": "🌋 Volcano + 💧 Water + 🔋 Battery",
  "points": 10
 },
 {
  "station": "Deep Mine",
  "emoji": "🌋",
  "name": "Volcano",
  "oldTier": "CREATION",
  "recipe": "🌎 Planet + __FURNACE__ Furnace",
  "points": 14
 },
 {
  "station": "Deep Mine",
  "emoji": "__GEMCOLLECTION__",
  "name": "Gemstone Collection",
  "oldTier": "CREATION",
  "recipe": "__PEARL__ Pearl + __RUBY__ Ruby + __OPAL__ Opal + __TURQUOISE__ Turquoise + __AMBER__ Amber + __DIAMOND__ Diamond",
  "points": 19
 },
 {
  "station": "Old Growth Forest",
  "emoji": "🍓",
  "name": "Strawberries",
  "oldTier": "MATERIAL",
  "recipe": "🍬 Sugar + Ca + 🧺 Basket",
  "points": 11
 },
 {
  "station": "Old Growth Forest",
  "emoji": "🍄",
  "name": "Mushroom",
  "oldTier": "COMPONENT",
  "recipe": "🌱 Soil + 💧 Water + N",
  "points": 6
 },
 {
  "station": "Old Growth Forest",
  "emoji": "🍂",
  "name": "Plant Fiber",
  "oldTier": "MATERIAL",
  "recipe": "🌳 Tree + 🛠️ Tools",
  "points": 7
 },
 {
  "station": "Old Growth Forest",
  "emoji": "🪢",
  "name": "Rope",
  "oldTier": "COMPONENT",
  "recipe": "🍂 Plant Fiber + 🛠️ Tools",
  "points": 8
 },
 {
  "station": "Old Growth Forest",
  "emoji": "__AMBER__",
  "name": "Amber",
  "oldTier": "COMPONENT",
  "recipe": "🌳 Tree + C + 🕐 Clock",
  "points": 11
 },
 {
  "station": "Old Growth Forest",
  "emoji": "__DYERED__",
  "name": "Red Dye",
  "oldTier": "COMPONENT",
  "recipe": "🍓 Strawberries + 💧 Water + 🫙 Glass Vial",
  "points": 16
 },
 {
  "station": "Old Growth Forest",
  "emoji": "🦖",
  "name": "Dinosaur",
  "oldTier": "CREATION",
  "recipe": "__AMBER__ Amber + 🧬 DNA + __FOSSIL__ Fossil",
  "points": 13
 },
 {
  "station": "The Bakery",
  "emoji": "🍫",
  "name": "Chocolate",
  "oldTier": "COMPONENT",
  "recipe": "🍬 Sugar + __FURNACE__ Furnace",
  "points": 9
 },
 {
  "station": "The Bakery",
  "emoji": "🥛",
  "name": "Milk",
  "oldTier": "COMPONENT",
  "recipe": "🐄 Cow + 💧 Water",
  "points": 10
 },
 {
  "station": "The Bakery",
  "emoji": "🥨",
  "name": "Pretzel",
  "oldTier": "CREATION",
  "recipe": "🫓 Dough + K + __OVEN__ Oven",
  "points": 23
 },
 {
  "station": "The Bakery",
  "emoji": "🍰",
  "name": "Cake",
  "oldTier": "CREATION",
  "recipe": "🫓 Dough + 🍬 Sugar + 🥚 Egg + __OVEN__ Oven",
  "points": 12
 },
 {
  "station": "The Bakery",
  "emoji": "🍶",
  "name": "Cream",
  "oldTier": "COMPONENT",
  "recipe": "🥛 Milk + 🕐 Clock",
  "points": 13
 },
 {
  "station": "The Bakery",
  "emoji": "🧈",
  "name": "Butter",
  "oldTier": "MATERIAL",
  "recipe": "🍶 Cream + 🛠️ Tools",
  "points": 13
 },
 {
  "station": "The Bakery",
  "emoji": "🍰",
  "name": "Chocolate Cake",
  "oldTier": "CREATION",
  "recipe": "🍰 Cake + 🍫 Chocolate",
  "points": 25
 },
 {
  "station": "The Bakery",
  "emoji": "🥐",
  "name": "Croissant",
  "oldTier": "CREATION",
  "recipe": "🫓 Dough + 🧈 Butter + __OVEN__ Oven",
  "points": 24
 },
 {
  "station": "The Bakery",
  "emoji": "🍩",
  "name": "Éclair",
  "oldTier": "CREATION",
  "recipe": "🫓 Dough + 🥚 Egg + 🍶 Cream + 🍫 Chocolate + __OVEN__ Oven",
  "points": 25
 },
 {
  "station": "The Bakery",
  "emoji": "🧁",
  "name": "Berry Cupcakes",
  "oldTier": "CREATION",
  "recipe": "🍰 Cake + 🫐 Blueberries + 🍓 Strawberries + 🍇 Blackberries",
  "points": 28
 },
 {
  "station": "The Bakery",
  "emoji": "🍽️",
  "name": "Grand Banquet",
  "oldTier": "CREATION",
  "recipe": "🍎 Apple + 🍌 Banana + 🍣 Sushi Restaurant + 🍰 Cake + 🎆 Fireworks",
  "points": 28
 },
 {
  "station": "The City",
  "emoji": "🍇",
  "name": "Blackberries",
  "oldTier": "MATERIAL",
  "recipe": "🍬 Sugar + Mg + 🧺 Basket",
  "points": 12
 },
 {
  "station": "The City",
  "emoji": "🗿",
  "name": "Statue",
  "oldTier": "COMPONENT",
  "recipe": "🪨 Limestone + 🛠️ Tools",
  "points": 6
 },
 {
  "station": "The City",
  "emoji": "📄",
  "name": "Paper",
  "oldTier": "COMPONENT",
  "recipe": "🍂 Plant Fiber + 💧 Water",
  "points": 12
 },
 {
  "station": "The City",
  "emoji": "__DYEBLACK__",
  "name": "Black Dye",
  "oldTier": "COMPONENT",
  "recipe": "🍇 Blackberries + 💧 Water + 🫙 Glass Vial",
  "points": 18
 },
 {
  "station": "The City",
  "emoji": "📕",
  "name": "Book",
  "oldTier": "COMPONENT",
  "recipe": "📄 Paper + 🛠️ Tools",
  "points": 13
 },
 {
  "station": "The City",
  "emoji": "🧶",
  "name": "Yarn",
  "oldTier": "COMPONENT",
  "recipe": "🤍 Wool + __WHEEL__ Wheel",
  "points": 14
 },
 {
  "station": "The City",
  "emoji": "🧣",
  "name": "Knit Scarf",
  "oldTier": "CREATION",
  "recipe": "🧶 Yarn + __DYERED__ Red Dye + __DYEBLUE__ Blue Dye",
  "points": 22
 },
 {
  "station": "The City",
  "emoji": "🎺",
  "name": "Trumpet",
  "oldTier": "CREATION",
  "recipe": "__BRASSBAR__ Brass + 🛠️ Tools",
  "points": 18
 },
 {
  "station": "The City",
  "emoji": "__RUBY__",
  "name": "Ruby",
  "oldTier": "COMPONENT",
  "recipe": "Al + O + __FURNACE__ Furnace + 🕐 Clock",
  "points": 13
 },
 {
  "station": "The City",
  "emoji": "📚",
  "name": "Library",
  "oldTier": "CREATION",
  "recipe": "🏢 Building + 📕 Book",
  "points": 15
 },
 {
  "station": "The City",
  "emoji": "🏍️",
  "name": "Motorcycle",
  "oldTier": "CREATION",
  "recipe": "🚲 Bicycle + ⚙️ Engine + __FIBERGLASS__ Fiberglass",
  "points": 18
 },
 {
  "station": "The City",
  "emoji": "🍣",
  "name": "Sushi Restaurant",
  "oldTier": "CREATION",
  "recipe": "🌿 Seaweed + 🐟 Salmon + 🏢 Building",
  "points": 19
 },
 {
  "station": "The City",
  "emoji": "🚉",
  "name": "Central Station",
  "oldTier": "CREATION",
  "recipe": "🚁 Helicopter + 🚄 Maglev Train + 🚗 Car + 🚤 Speedboat",
  "points": 25
 },
 {
  "station": "The Observatory",
  "emoji": "🫐",
  "name": "Blueberries",
  "oldTier": "MATERIAL",
  "recipe": "🍬 Sugar + K + 🧺 Basket",
  "points": 14
 },
 {
  "station": "The Observatory",
  "emoji": "__DYEBLUE__",
  "name": "Blue Dye",
  "oldTier": "COMPONENT",
  "recipe": "🫐 Blueberries + 💧 Water + 🫙 Glass Vial",
  "points": 19
 },
 {
  "station": "The Observatory",
  "emoji": "🌎",
  "name": "Planet",
  "oldTier": "CREATION",
  "recipe": "C + H + N + O + S + K + Ca + Si + Al + Mg + P + Fe + Ti + Cu + Ag + Ni",
  "points": 8
 },
 {
  "station": "The Observatory",
  "emoji": "__TURQUOISE__",
  "name": "Turquoise",
  "oldTier": "COMPONENT",
  "recipe": "Cu + Al + P + __FURNACE__ Furnace + 🕐 Clock",
  "points": 14
 },
 {
  "station": "The Observatory",
  "emoji": "☀️",
  "name": "Solar System",
  "oldTier": "CREATION",
  "recipe": "⭐ Star + 🌎 Planet",
  "points": 18
 }
];
// Their hand-made icons, removed in the same commit (assets/images.js, data.js).
const RETIRED_ICONS = {
  "__DYEYELLOW__": '<img class="noto-icon" src="data:image/webp;base64,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">',
  "__DYERED__": '<img class="noto-icon" src="data:image/webp;base64,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">',
  "__DYEBLUE__": '<img class="noto-icon" src="data:image/webp;base64,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">',
  "__DYEBLACK__": '<img class="noto-icon" src="data:image/webp;base64,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">',
  "__BRASSBAR__": '<svg viewBox="0 0 128 128" class="brassbar" xmlns="http://www.w3.org/2000/svg"><path fill="#8a6d2e" d="M24 102 L104 102 L90 64 L38 64 Z"/><path fill="#d9b45c" d="M38 64 L90 64 L104 38 L52 38 Z"/><path fill="#6b5326" d="M90 64 L104 38 L118 76 L104 102 Z"/><path fill="#f2dd9a" opacity="0.55" d="M56 42 L100 42 L96 46 L60 46 Z"/></svg>',
  "__GEMCOLLECTION__": '<img class="gemcollectionicon" src="data:image/webp;base64,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">',
  "__PEARL__": '<img class="pearlicon" src="data:image/webp;base64,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">',
  "__RUBY__": '<img class="rubyicon" src="data:image/webp;base64,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">',
  "__OPAL__": '<img class="opalicon" src="data:image/webp;base64,UklGRpwJAABXRUJQVlA4WAoAAAAQAAAAVgAAXwAAQUxQSHoCAAABkAQAjCFJOdu2bdu2bdv2y7Zt27Z9t7Zts86VSnJ8RcQEwH/xmQpUbd9v6NC+rcrnTiNGsf7L7zgHxqnvRvtaHBpTPgm/vEOvByv9yNuDs/Kqts1LYdtOzsSn5tEoZfJ9RybFd0UpwwlbMzNIN9tXEXxaklztx4qmQ21aKWaGKqpe9SnlPqcIe1SiU/atIm2Rh0pdF0X8bAoaLXwV+WkkmgUo+kHlCdTyURxPmCvuoFjG1DGV7YViejqJmWRHFNfICmZmKr4rjDSPYmSfwUBOG8W5hYGdivUavNZxvN4kx0r7RvEOK4I1UnHvjJTZjt1KpCmK/QWcbE783iVHGa/4e2TGSGchQEAejJ5KwNgyGFckiK+IUDpchMoIC5QIlfRSvpahol6VGBEii+vNUCL65dK7KINrRq0sbjK8SKpVI06GC6A9Scm4VW+/EOO1UrwSoqFWLh8ZAvNrlY6U4V1yrfpKxoOg3U+IYXrzZYitrLdJBou0entl2Ab6R2Voj3BGBPdsCKdF2AeIhyVIbIuxQwKLdBjLJJgLmKMECCqC0kKAnYBaMYZdREWc3H7sdgNu8hfcgkshwXZuywF7IDP77GhFQnn1BfSkt1mdSoYHYzm5FwaDeXz4xHcHo+v5rAOzZUK5PEhvCNYxcS4OpvO5swhpDOaHcYjsAQSTnaEX1R9I5relFtYHiNYPoeXTAcj2jKL0vjoQHhJN52guIN0nhIjX6KRAvJE1hcTjJYB+3n0Jxu62BZ7tHhuJu9UtOXBN1eNuApbjhrpJgHPSRtucEFyPds0C/DO3WXzDPjDmm/hg93dnFrXJBmKmz1+hafv2LWsWypoC/sYCVlA4IPwGAABQHwCdASpXAGAAPmEojkUkIqEYe83gQAYEtgBonCEoU6HA9/w9lf0J7ZfzEebh6Gv7p6R3Ucegn0qX97wSn+gbfdd82qvRQ9MfH6Z+zloxenP/F7g/8f/qX+57Avozfo64iEB4+ey8BZ9m+FCmS+pLxiVLTcmwX2ab4NqZ38bi96/5iLdzt+43VqYn/0J8PW/JC2FY1HZxp+X4GYZTf1dnyULxhgYxFGP8O+0ZzIBfIAYZlLOb77zdwQ26wB9eC8NR+p2laaMZVZ7I9MpBsY5qPMeWUxWdaMFDNqZnoReKfJa/lJf65L2w1Z8Gp6np3s/QEYVh6dXucvxWNx0iF4AJLJkAAP7+0B2bYSkPYH5zpf+u4J5TRZKZ6U8DgQR3cwqiVh5QXxL3xx//ZidhSAvGbv9gObtiAxe3oveYsqG9eCYPSoFx7nvdzhVrnRIiud+/+xvoqsuSpbViTiS8hhfWfiDxplUVsf/pW74aBpFg/IrRtxmmf133KjULMijMS7mZhBD/kS4RGnjPTnlpSmefSJA4RMgSdbyYDfBQVWtzYncI3ncdoleikLCHmeP//uCCYnz9FDkXVdhY5+88yuWXWYUDZe0bN8HnxEnxupUPkaBiIDJza+KYD9h0aUN3m3CIlHzUczZLeGoXKhxky2zwTubGTHqHzpI1+vOyH9IPFrvby5rz+oOeaImZKO1iSatAoRfxu/lyo1cKFvWqOkvTPRqQLWazAOw8TDC5se57eBH4hx/x4mdmBvJdmjEUBqbGvvuxMHjw4ldPEf5zn3+FuXDw6Cr5PAH8abFHnPiC7+oG10lkOiOmUEc4E7c6gtJfurvq/bq3m7T9W5w5Ck4eYzZI4AB0NUEjHsBzgjYHGnMB11QeYnx1wxNEDTzNWMt3lJOp80TBGczrD8O++KqOhtUV6YwOWIuAfK/Oof++ccH57XnIBWJ94fscL+9bS3zVg0r2FvF6jKMD/haQNmusWg39pM1zQc4kv8cBKDfBteyKRRVrNYARPmg/eK9gndLvOeNByIoxTGvETej3INqhEycadzJl+neUST7ox7RtXWLJrf8Dslx1FRZgsYUSpnCW61fX+389074pNfFc/Mxa9gZGQQu+k89gXX8sIWUk3XOHvLXaGYh/Y8PZYExjJ3LwXHyyVxaPnlzjXjnKsLNtvM9ikHuKO9GdiZBHXUbXmoyrU4KfohZCDoUoHYtD5ZY6TJWmdxRdD27G2zP+S5X89ASt5uCVvFgUjIiRAtVjP2rR3sy8mYrW63L+l/1IEepobA8NBtHLlqUGVQ3qvJGXYUgBf7Zn/t/sI2F/4+kzSrMOwYUqOWyLQCfnXZa3PP+ds+x2T9kuJH9vYPoDuha61QxewC9oWIwG0tSmITn335lRf0yjPhHdPpMihkmtDNdBwLjdVZgfliPIPKrl2a9sOxksENELjnLAWwwsWNZN0OKu0wvJgvED08u6uZpA1n8M6b4/Xwd3REyeLoYmIYW8Yz6OZ8LmXaC8jrMgAjpOp0WdrC2MMoVor0yCKi6zgddpBBX4nlos48RDpDntpLDmtV3WYQvvwr5e3iWlWBIjL2SGcg+Z/mUkd90ifqYt99x7j5Ist8t+CbLq9mXuUTZhJBu4HiEp1yrLbadWGpZwk4EPy0cJNd0gh29OocqyvdUJ3hv0rpVD+2YKso7C6J9OodZQjGrcIePyq1OEeUk/e+f8voskjF/wah8l+hwYoJne/5MjomaDSb39W2qkYI7xekw6/VPyKOIgHN24TtmTJosHlYkN9A1yYnZVUD06GV052umJV9OGoz/4or3yc2W0FTW6oeah17qbDtiT5tOj9lUqWk2Xve6zIfYGYHCXbmR3GegIlpNe6YI1LrBFVZDZ01o6k66xcmcgY8EtLQ0HtqmmpqYlgw1LSpS0Vd9gdTeipdbbVkkI1dz553qnDxmfxDbs5PxdwFYkmkI/f/fSXwEcK/BIJfBsNWVTVP2+W2rWFUO3ix4hX4hc9VL5sJfvkb8uLAwP+WwsYAZwzDPQTcJy13aPE3PfcZdD8GPgmacpBoOzT03GWRRkY9a3j0Hlhx2ydxtD9JZzTqEW+pz/mbG2YfB3D8VKnelHlEmRjh8m27bKFgrHJPU/ToG/KlH8+F+clNns9iVDPdeA9EBEqi3ktWg00OAWh0bsPQ6QiEcLEjakzeAh8w5p01nX0/PWamAACq+3pUa2IPwCE5C1A8K3IoHKCMsTFoSHjSzQS+if8ZxBREkmRoOBycIIn7pJjeSXw4Ngf254n9C4CPVaBXuPVeW/DuIh/fWVgbTNxG+Z08RkUcBmMS5ohpDus8Dk7MUAbjvCXsK8uzz12Nezb38QJu43jngOaKqn5lRYHeISqHx/j/jP1gAAAAA=">',
  "__TURQUOISE__": '<img class="turquoiseicon" src="data:image/webp;base64,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">',
  "__AMBER__": '<img class="ambericon" src="data:image/webp;base64,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">',
};
