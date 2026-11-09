/* =====================================================================
   model.js -- Rules and catalog: visit/dice limits, element and suit tables, suit
   costs, recipe parsing, the Classic item set (CORE_SET, ENTRIES), item
   points and scoreOf().

   Derived model — mirrors simulation/model.py's parse_requirements().
   Raw elements are consumed; crafted items are PERMANENT UNLOCKS.
   ===================================================================== */
/* Dice per roll: 3, +1 once the player owns a Tractor
   (prefs.expTractorHarvest). Guarded because loadAll() calls this before
   state exists. Re-run whenever the Tractor could have changed (craft(), a
   save loading). */
let TAKE = 3;
function applyDiceCount(){
  const tractorBonus = prefs.expTractorHarvest && state && state.items && state.items.includes("Tractor") ? 1 : 0;
  TAKE = 3 + tractorBonus;
}
/* The run's hard stop (also the visits pill's denominator). Lines up with
   LOCKIN_ROUND_ANCHORS ending at visit 40. */
const DEFAULT_MAX_VISITS = 40;
const MAX_VISITS = DEFAULT_MAX_VISITS;
function visitLimitLabel(){ return String(MAX_VISITS); }
/* Classic: from this visit on, missing the first Quark breakpoint at a
   sunset check ends the run (see confirmLockIn()). */
const BREAKPOINT_GATE_VISIT = 9;
/* Classic days are MAT_CHECK_EVERY visits long (see renderDayCycle()). The
   first Display Mat check is on leaving visit 3 (the first sunset); after
   that the mat is checked on every trip. Before the first check each roll
   is MAT_PRE_CHECK_DICE dice; after it, TAKE plus the latest check's bonus
   dice (state.matBonusDice, see doRoll()). Game Over is only at stake on a
   sunset check from BREAKPOINT_GATE_VISIT on (isSunsetVisit()/
   confirmLockIn()). */
const MAT_CHECK_EVERY = 3;
const MAT_PRE_CHECK_DICE = 4;
function isMatCheckVisit(){
  return state.visits >= MAT_CHECK_EVERY;
}
function isSunsetVisit(){
  return state.visits > 0 && state.visits % MAT_CHECK_EVERY === 0;
}
/* Carry cap: max of any ONE raw element held; extra rolls go back to the
   pool. Simulation (2026-07-21): a cap of 3 costs ~0.5pp of capstone
   completion, a cap of 2 ~11pp. No recipe needs 2 of one element. */
const EL_RE = /^[A-Z][a-z]?$/;
const PIPS = {1:[4],2:[0,8],3:[0,4,8],4:[0,2,6,8],5:[0,2,4,6,8],6:[0,2,3,5,6,8]};
/* Matches ELEMENTS in build_element_cards.py -- kept in sync by hand since
   this list almost never changes (new elements are rare, unlike recipes). */
const ELEMENT_NAMES = {
  H:"Hydrogen", C:"Carbon", N:"Nitrogen", O:"Oxygen", P:"Phosphorus",
  S:"Sulfur", K:"Potassium", Ca:"Calcium",
  Si:"Silicon", Al:"Aluminum", Mg:"Magnesium",
  Fe:"Iron", Ti:"Titanium", Cu:"Copper", Ag:"Silver", Ni:"Nickel",
  Zn:"Zinc",
};
/* The 16 core elements taught in the tutorial ("just 16 of them make up
   nearly everything", see #tutIntro). Zn is a bonus element found only on
   the Island sub-zone, so it's left out here; it works everywhere else. */
const CORE_ELEMENT_SYMS = ["H","C","N","O","P","S","K","Ca","Si","Al","Mg","Ni","Fe","Ti","Cu","Ag"];
/* Matches ELEMENT_SUITS/ELEMENTS in build_element_cards.py -- the suit
   pill shown on the element-card popup (see showElCardPop()). */
const ELEMENT_SUIT = {
  C:"organic", H:"organic", N:"organic", O:"organic",
  S:"reactive", K:"reactive", Ca:"reactive", P:"reactive",
  Si:"earth", Al:"earth", Mg:"earth", Ni:"earth",
  Fe:"metal", Ti:"metal", Cu:"metal", Ag:"metal", Zn:"metal",
};
const ELEMENT_SUIT_LABEL = {organic:"ORGANIC", reactive:"REACTIVE", earth:"EARTH", metal:"METAL"};
// Suit colours keyed by suit (same palette as ELEMENT_COLOR); used for an
// item's icon slot, since an item mixes several elements.
const SUIT_COLOR = {organic:"#3aab6d", reactive:"#e2543b", earth:"#e2a83e", metal:"#4d7cf2"};
// Each suit's four core elements (Zn, metal's fifth, isn't core). The
// suit-spend balloon always lists all four.
const SUIT_CORE_ELEMENTS = {};
Object.keys(ELEMENT_SUIT_LABEL).forEach(suit => {
  SUIT_CORE_ELEMENTS[suit] = CORE_ELEMENT_SYMS.filter(sym => ELEMENT_SUIT[sym] === suit);
});
/* Each item's single suit, derived from its recipe: tally the suits of its
   raw elements (item ingredients recurse into their own suit, memoized)
   and take the most common. Lazy, so it runs after ENTRIES is built. */
const ITEM_SUIT = {};
function itemSuitOf(name){
  if (name in ITEM_SUIT) return ITEM_SUIT[name];
  ITEM_SUIT[name] = "organic"; // cycle guard while resolving, and the final fallback if nothing below ever fires
  const entry = ENTRIES.find(e => e.name === name);
  if (!entry) return ITEM_SUIT[name];
  const counts = {organic:0, reactive:0, earth:0, metal:0};
  entry.reqs.forEach(r => {
    const suit = r.kind === "element" ? ELEMENT_SUIT[r.name] : itemSuitOf(r.name);
    if (suit) counts[suit]++;
  });
  // Ties are common at the base of the recipe graph (e.g. Steel = Fe + C),
  // and always picking the first suit snowballed up the tree. Ties are
  // broken by a hash of the item name instead: stable, but spread evenly.
  const max = Math.max(...Object.values(counts));
  const tied = Object.keys(counts).filter(k => counts[k] === max);
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) | 0;
  const best = tied[Math.abs(hash) % tied.length];
  ITEM_SUIT[name] = best;
  return best;
}
/* Suit costs: crafting an item worth 5+ points also spends extra elements
   of specific suits on top of its recipe (gated/spent via
   suitCostPayable()/craftWithSuitCost()). Hand-curated from a real-world
   "what is this made of" pass over the Classic set: 5-9 points cost one
   suit, 10-19 usually two (sometimes different suits), and every CAPSTONE
   costs three; 4 points or under costs nothing. Fossil (one suit) and
   Apple Pie/Bicycle (two, despite high points) are deliberate. Shown as
   badges by the item name (suitCostBadgesHTML()) and on the inspection
   card (showCardPop()). Source: Elementia_Handoff/
   classic_mode_element_suits.csv. */
const ITEM_SUIT_COST_TABLE = {
  Canoe: ["earth"], Egg: ["organic"], Cloud: ["organic"], Apple: ["organic"],
  Deer: ["earth"], "Log Cabin": ["earth"], Bridge: ["metal"], Compass: ["metal"],
  Banana: ["organic"], Engine: ["metal"], "Light Bulb": ["reactive"], Grain: ["earth"],
  "Solar Panel": ["reactive"], Farm: ["earth"], Building: ["earth"], Clock: ["reactive"],
  Plastic: ["reactive"], Flour: ["organic"], Dough: ["organic"], Microchip: ["metal"],
  Wheel: ["earth"], Fiberglass: ["reactive"], Chicken: ["organic"], Fossil: ["earth"],
  Salmon: ["organic"],

  Oven: ["metal", "reactive"], "Satellite Dish": ["metal", "reactive"], Telescope: ["metal", "metal"],
  Diamond: ["earth", "earth"], Orca: ["organic", "organic"],
  Lighthouse: ["earth", "reactive"], Star: ["organic", "reactive"],
  Rainbow: ["organic", "reactive"], Speedboat: ["metal", "metal"], Computer: ["metal", "reactive"],
  Tractor: ["metal", "earth"], Bicycle: ["metal", "earth"], Skyscraper: ["earth", "metal"], "Turbine Blade": ["metal", "reactive"],
  Life: ["organic", "earth"], Car: ["metal", "reactive"], "Banana Bread": ["organic", "organic"],
  Museum: ["earth", "metal"], Helicopter: ["metal", "metal"], Rocket: ["metal", "reactive"],
  "Fish Cakes": ["organic", "organic"], "Apple Pie": ["organic", "organic"],

  "Maglev Train": ["metal", "earth", "reactive"], Homestead: ["organic", "earth", "metal"],
  "Coral Reef": ["organic", "organic", "organic"], Robot: ["metal", "metal", "reactive"],
  "Fruit Cake": ["organic", "organic", "reactive"], Ecosystem: ["earth", "earth", "organic"],
  Metropolis: ["metal", "earth", "reactive"], "Space Station": ["metal", "reactive", "organic"],
};
const NO_SUIT_COST = [];
function itemSuitCosts(name){
  return ITEM_SUIT_COST_TABLE[name] || NO_SUIT_COST;
}
// Tally of a craft's suit cost by suit -- e.g. Fossil (earth+reactive) ->
// {earth:1, reactive:1}; Coral Reef (organic x3) -> {organic:3}. Empty for
// anything with no cost.
function suitCostNeed(entry){
  const need = {};
  itemSuitCosts(entry.name).forEach(s => { need[s] = (need[s] || 0) + 1; });
  return need;
}
// Elements of `suit` still free after reserving what the recipe itself
// needs; the suit-spend balloon only offers this much, so paying a suit
// cost never eats into the recipe. Counts only the suit's core elements --
// the same ones the balloon offers -- so a leftover Zn can't make a cost
// look payable that the balloon can't actually pay.
function suitSurplusOfSuit(suit, reserved){
  return (SUIT_CORE_ELEMENTS[suit] || [])
    .reduce((sum, el) => sum + Math.max(0, count(el) - (reserved[el] || 0)), 0);
}
// True when every suit the cost demands has enough surplus beyond the
// recipe's needs. Gates Craft and the badge's tappability; spends nothing.
function suitCostPayable(entry){
  const need = suitCostNeed(entry);
  if (!Object.keys(need).length) return true;
  const {els: reserved} = needsOf(entry.reqs);
  return Object.keys(need).every(s => suitSurplusOfSuit(s, reserved) >= need[s]);
}
/* Suit-cost badges using SUIT_ICON's glyphs. The Nth badge of a suit lights
   once the SURPLUS of that suit (suitSurplusOfSuit() -- held minus what the
   recipe needs) exceeds N, so 1 of 2 shows one lit and one grey. Counting
   raw holdings instead made items look affordable when the recipe had
   already claimed those elements. */
function suitCostBadgesHTML(entry, interactive){
  const costs = itemSuitCosts(entry.name);
  if (!costs.length) return "";
  const {els: reserved} = needsOf(entry.reqs);
  const seenCount = {};
  // When the recipe and suit cost are both payable (itemHTML()'s "can"), the
  // badge opens the suit-spend balloon (handleScreenClick()'s .isuit-costs
  // branch).
  return `<span class="isuit-costs${interactive ? " interactive" : ""}">${costs.map(s => {
    const idx = seenCount[s] || 0;
    seenCount[s] = idx + 1;
    const have = suitSurplusOfSuit(s, reserved) > idx;
    return `<span class="isuit-badge${have ? "" : " need"}" data-suit="${s}" style="--suit:${SUIT_COLOR[s]}" title="${ELEMENT_SUIT_LABEL[s]} suit cost${have ? "" : " (not enough held yet)"}">${SUIT_ICON[s]}</span>`;
  }).join("")}</span>`;
}
/* Small corner badge with an element square's suit, the same look as
   .isuit-badge, corner-mounted because element boxes have no spare room
   (see .el-suit-badge). */
function elSuitBadgeHTML(sym){
  const suit = ELEMENT_SUIT[sym];
  if (!suit) return "";
  return `<span class="el-suit-badge" style="--suit:${SUIT_COLOR[suit]}" title="${ELEMENT_SUIT_LABEL[suit]}">${SUIT_ICON[suit]}</span>`;
}
/* Small black glyph per suit (leaf/flame/anvil/mountain), used as the two
   icon corner-bubbles on the element-card popup -- see showElCardPop(). */
const SUIT_ICON = {
  organic: `<img src="data:image/png;base64,${ORGANIC_ICON_B64}" alt="">`,
  reactive: `<img src="data:image/png;base64,${REACTIVE_ICON_B64}" alt="">`,
  metal: `<img src="data:image/png;base64,${METAL_ICON_B64}" alt="">`,
  earth: `<img src="data:image/png;base64,${EARTH_ICON_B64}" alt="">`,
};
// Raw base64, for tinting the glyph with CSS mask-image (.refsuit).
const SUIT_ICON_B64 = { organic: ORGANIC_ICON_B64, reactive: REACTIVE_ICON_B64, metal: METAL_ICON_B64, earth: EARTH_ICON_B64 };
/* One short, flavorful line per element -- shown italicized on the
   element-card popup, same spirit as a real periodic-table poster. */
const ELEMENT_DESC = {
  H:"Fuels every star in the sky.",
  C:"The backbone of every living thing.",
  N:"Fills the air, but rarely reacts.",
  O:"The reactive half of the air we breathe.",
  S:"The smell of rotten eggs, the strength of rubber.",
  K:"Vital to cells, reactive as sodium.",
  Ca:"Builds bones, shells, and stone.",
  Si:"The heart of glass and sand.",
  Al:"Light, rust-proof, and everywhere.",
  Mg:"Burns with a blinding white light.",
  P:"Found in DNA and matchsticks alike.",
  Fe:"Forged in the hearts of dying stars.",
  Ti:"Strong as steel, light as aluminum.",
  Cu:"One of the only metals with real color.",
  Ag:"The best conductor there is.",
  Ni:"Turns steel stainless, batteries rechargeable.",
};
/* Real periodic-table atomic numbers, for sorting -- purely a display
   nicety (there's no in-game concept of atomic number otherwise). */
const ATOMIC_NUMBER = {
  C:6, H:1, N:7, O:8, S:16, K:19, Ca:20,
  Si:14, Al:13, Mg:12, P:15, Fe:26, Ti:22, Cu:29, Ag:47, Ni:28, Zn:30,
};
// Every element a Classic player can actually roll (the 8 real stations;
// Zn only appears on the Island sub-zone). Keeps Zn out of Convert's TO
// list in Classic (renderConvertPicker()).
const CLASSIC_ELEMENTS = [...new Set(DATA.stations.flatMap(s => s.dice))];

/* Element suit palette ("Chemical Role", Palette A), matching the printed
   element cards (build_element_cards.py): organic (CHON) green, reactive
   salts red, earth minerals yellow, metals blue. */
const ELEMENT_COLOR = {
  C:"#3aab6d", H:"#3aab6d", N:"#3aab6d", O:"#3aab6d",
  S:"#e2543b", K:"#e2543b", Ca:"#e2543b", P:"#e2543b",
  Si:"#e2a83e", Al:"#e2a83e", Mg:"#e2a83e", Ni:"#e2a83e",
  Fe:"#4d7cf2", Ti:"#4d7cf2", Cu:"#4d7cf2", Ag:"#4d7cf2", Zn:"#4d7cf2",
};
/* Darker suit palette, only for element tokens inside recipes
   (tokenHTML()), dark enough that the green "owned" border (.tok.el.have)
   stays visible -- organic is shifted to olive for that reason. */
const ELEMENT_COLOR_DARK = {
  C:"#3d4a1f", H:"#3d4a1f", N:"#3d4a1f", O:"#3d4a1f",
  S:"#6b2338", K:"#6b2338", Ca:"#6b2338", P:"#6b2338",
  Si:"#6b4518", Al:"#6b4518", Mg:"#6b4518", Ni:"#6b4518",
  Fe:"#22366b", Ti:"#22366b", Cu:"#22366b", Ag:"#22366b", Zn:"#22366b",
};
/* Applies (or clears, with no sym) an element's colours to a box (Convert
   boxes and picker). */
function paintElement(el, sym){
  if (sym && ELEMENT_COLOR[sym]){
    el.style.background = "#fff";
    el.style.borderColor = ELEMENT_COLOR[sym];
    el.style.color = "#221f1a";
  } else {
    el.style.background = "";
    el.style.borderColor = "";
    el.style.color = "";
  }
}
/* The same colours as an inline style string, for template-built HTML. */
function elementColorAttr(sym){
  if (!ELEMENT_COLOR[sym]) return "";
  return `style="background:#fff;border-color:${ELEMENT_COLOR[sym]}"`;
}

/* A station's dice in order, sorted by atomic number. Both the die-face
   legend and doRoll() read this, so face N always means the same element. */
function sortedDice(s){
  return [...s.dice].sort((a, b) => (ATOMIC_NUMBER[a] || 999) - (ATOMIC_NUMBER[b] || 999));
}

const ELEMENTS = new Set();
DATA.stations.forEach(s => s.dice.forEach(d => ELEMENTS.add(d)));

function parseRecipe(str){
  return str.split("+").map(t => t.trim()).filter(Boolean).map(tok => {
    const catalyst = tok.endsWith("*");
    tok = tok.replace(/\*/g, "").trim();
    if (EL_RE.test(tok)) return {name:tok, kind:"element", emoji:"", catalyst};
    const sp = tok.indexOf(" ");
    const emoji = sp >= 0 ? tok.slice(0, sp) : "";
    const name  = sp >= 0 ? tok.slice(sp + 1).trim() : tok;
    return {name, kind:"item", emoji, catalyst};
  });
}

/* Classic's curated catalog, keyed "Station|Name" (a few items have two
   homes). Based on the original "core 72" set, plus the few items needed so
   every current recipe stays closed (Wheel, Log Cabin) and Fossil for its
   cross-station links. Each station has 10 regular items + 1 capstone;
   multi-home materials are trimmed to one home where needed. Every item's
   full ingredient closure is inside this set. */
const CORE_SET = new Set([
  // The Ocean (10 + capstone)
  "The Ocean|Water","The Ocean|Limestone","The Ocean|Sand","The Ocean|Seaweed",
  "The Ocean|Life","The Ocean|Banana","The Ocean|Cloud","The Ocean|Lighthouse",
  "The Ocean|Orca","The Ocean|Speedboat","The Ocean|Coral Reef",
  // The Power Plant. Glass's core listing lives at The City.
  "The Power Plant|Battery","The Power Plant|Wire","The Power Plant|Clock",
  "The Power Plant|Engine","The Power Plant|Light Bulb",
  "The Power Plant|Plastic","The Power Plant|Car",
  "The Power Plant|Computer","The Power Plant|Fiberglass","The Power Plant|Turbine Blade",
  "The Power Plant|Robot",
  // Greenhouse. Solar Panel lives here (a real recipe-data move from Power
  // Plant); Bicycle replaced Tractor (moved to Deep Mine), and Homestead's
  // recipe uses Bicycle accordingly.
  "Greenhouse|Fertilizer","Greenhouse|Sugar","Greenhouse|DNA",
  "Greenhouse|Soil","Greenhouse|Farm","Greenhouse|Chicken","Greenhouse|Apple",
  "Greenhouse|Grain","Greenhouse|Solar Panel","Greenhouse|Bicycle","Greenhouse|Homestead",
  // Deep Mine. Tractor (from Greenhouse) replaced Titanium Alloy; Rocket
  // uses the raw Ti element instead.
  "Deep Mine|Clay","Deep Mine|Natural Gas","Deep Mine|Steel","Deep Mine|Tools",
  "Deep Mine|Furnace","Deep Mine|Aluminum Alloy","Deep Mine|Stainless Steel",
  "Deep Mine|Diamond","Deep Mine|Tractor","Deep Mine|Rubber","Deep Mine|Maglev Train",
  // Old Growth Forest (10 + capstone, Water trimmed, +Log Cabin +Fossil)
  "Old Growth Forest|Clay","Old Growth Forest|Sand","Old Growth Forest|Bone",
  "Old Growth Forest|Soil","Old Growth Forest|Salmon","Old Growth Forest|Tree",
  "Old Growth Forest|Canoe","Old Growth Forest|Deer","Old Growth Forest|Log Cabin",
  "Old Growth Forest|Fossil","Old Growth Forest|Ecosystem",
  // The Bakery. Oven is here (Banana Bread and Fruit Cake need it); Natural
  // Gas is core at Deep Mine. Bread and Cake aren't core -- Banana Bread's
  // and Fruit Cake's recipes inline their ingredients.
  "The Bakery|Sugar","The Bakery|Water","The Bakery|Yeast",
  "The Bakery|Egg","The Bakery|Flour","The Bakery|Dough","The Bakery|Oven",
  "The Bakery|Apple Pie","The Bakery|Fish Cakes","The Bakery|Banana Bread","The Bakery|Fruit Cake",
  // The City. Glass (from Power Plant) replaced Statue; Museum (Building +
  // Telescope + Fossil) replaced Sushi Restaurant. "Motorcycle" and "Sushi
  // Restaurant" exist only as collection names, not items.
  "The City|Clay","The City|Limestone","The City|Steel","The City|Concrete",
  "The City|Bridge","The City|Building","The City|Helicopter","The City|Museum",
  "The City|Skyscraper","The City|Glass","The City|Metropolis",
  // The Observatory (10 + capstone, Glass trimmed, +Wheel)
  "The Observatory|Microchip","The Observatory|Tools","The Observatory|Magnet",
  "The Observatory|Compass","The Observatory|Satellite Dish","The Observatory|Telescope",
  "The Observatory|Star","The Observatory|Rainbow","The Observatory|Rocket",
  "The Observatory|Wheel","The Observatory|Space Station",
]);
const isCoreEntry = entry => CORE_SET.has(entry.station + "|" + entry.name);

/* Flatten every station into a list of craftable entries. */
const ENTRIES = [];       // {station, emoji, name, tier, recipe, points, reqs, farm}
const ITEM_EMOJI = {};    // name -> emoji, for inventory display
const ITEM_TIER  = {};
const ITEM_POINTS = {};
// Classic: a one-time score bonus for visiting every station, shown on the
// stations-visited card (stationsVisitedBonusBadgeHTML()).
const STATIONS_VISITED_BONUS = 15;
// Parameterized so the mode-select screen can score every OTHER mode's
// saved state too (see modeSummary()) without swapping the live `state`
// global out and back in just to reuse this math.
function scoreOf(st){
  const base = st.items.reduce((sum, n) => sum + (ITEM_POINTS[n] || 0), 0);
  const stationsBonus = Object.keys(MAP_NODE_POS).every(name => st.visitedStations[name])
    ? STATIONS_VISITED_BONUS : 0;
  const bingoBonus = (st.bingoLinesCompleted || []).length * BINGO_LINE_BONUS;
  return base + stationsBonus + bingoBonus;
}
function score(){ return scoreOf(state); }

DATA.stations.forEach(s => {
  const push = row => {
    const [emoji, name, tier, recipe, points] = row;
    ENTRIES.push({station:s.name, emoji, name, tier, recipe, points, reqs:parseRecipe(recipe)});
    ITEM_EMOJI[name] = emoji;
    ITEM_TIER[name]  = tier;
    ITEM_POINTS[name] = points;
  };
  s.shop.forEach(push);
  push(s.capstone);
});

const STATION_BY_NAME = {};
DATA.stations.forEach(s => STATION_BY_NAME[s.name] = s);
const CAPSTONES = DATA.stations.map(s => s.capstone[1]);

// Item NAMES (not station|item pairs), so membership checks work whichever
// station a caller is looking at -- unlike isCoreEntry(), which needs the
// specific station.
const CORE_ITEM_NAMES = new Set([...CORE_SET].map(s => s.split("|")[1]));
// Item name -> its one canonical CORE_SET station, for single "where it
// comes from" badges (card inspection, BINGO). The FIRST CORE_SET listing
// wins, which is each item's primary home (Water -> The Ocean, not The
// Bakery). MAT_CARDS' `stations` holds the full multi-station list.
const CORE_ITEM_STATION = {};
[...CORE_SET].forEach(s => {
  const [station, name] = s.split("|");
  if (!(name in CORE_ITEM_STATION)) CORE_ITEM_STATION[name] = station;
});
