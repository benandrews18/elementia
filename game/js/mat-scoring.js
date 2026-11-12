/* =====================================================================
   mat-scoring.js -- Display Mat scoring: MAT_CARDS, named collections, combos, matScore(),
   and the BINGO card data/helpers.

   Display Mat (Classic only): 8 slots (a capstone takes 2) arranged by the
   player, scored as (points + collection bonuses) x combo multiplier.
   Ported from the cardgame/mat.html prototype, reading live game data
   (ENTRIES/ITEM_SUIT_COST_TABLE) -- no separate data file. The
   Quark/dice reward lives in the Lock-In section (finishLockIn()). */
const MAT_SLOTS_COLS = 4, MAT_SLOTS_ROWS = 2;
const MAT_SLOTS_TOTAL = MAT_SLOTS_COLS * MAT_SLOTS_ROWS;
const MAT_CAPSTONE_SLOTS = 2;
const MAT_COMBO_TIERS = [ {k:3, b:1}, {k:4, b:2}, {k:5, b:4}, {k:6, b:6} ];

/* One card per item, owned or not (ownership only decides what
   shows in the tray, see matInventory()). Built once at boot. */
const MAT_CARDS = [...CORE_ITEM_NAMES].map(name => {
  const station = CORE_ITEM_STATION[name];
  const entry = ENTRIES.find(e => e.name === name && e.station === station);
  // Every station that sells this item (Water, Clay, Steel, ... sell at 2-3),
  // home station first -- a card combos with all of them. A capstone shows
  // its own station twice instead, so it counts double toward that
  // station's combo.
  const stations = ITEM_TIER[name] === "CAPSTONE" ? [station, station]
    : [station, ...ENTRIES.filter(e => e.name === name).map(e => e.station)]
      .filter((s, i, arr) => s && STATION_BY_NAME[s] && arr.indexOf(s) === i);
  return {
    name,
    points: ITEM_POINTS[name],
    tier: ITEM_TIER[name],
    emoji: ITEM_EMOJI[name],
    station,
    stations,
    pips: itemSuitCosts(name),
    components: entry ? entry.reqs : [],
  };
});
const MAT_CARD_BY_NAME = {};
MAT_CARDS.forEach(c => { MAT_CARD_BY_NAME[c.name] = c; });

const matIsCapstone = c => c.tier === "CAPSTONE";
const matHas = (cards, name) => cards.some(c => c.name === name);
/* The mat's shape for these cards: Metropolis (Expansion) adds a column
   (10 slots); Maglev Train (Freight) stacks tier 1 three to a slot. */
function matLayout(cards){
  const cols = matHas(cards, "Metropolis") ? MAT_SLOTS_COLS + 1 : MAT_SLOTS_COLS;
  return { cols, slots: cols * MAT_SLOTS_ROWS, perSlot: matHas(cards, "Maglev Train") ? 3 : MAT_TIER1_PER_SLOT };
}
const matSlotsOf = c => matIsCapstone(c) ? MAT_CAPSTONE_SLOTS : 1;
const matComboTier = k => {
  let b = 0;
  MAT_COMBO_TIERS.forEach(t => { if (k >= t.k) b = t.b; });
  return b;
};

/* Tier 1 (MATERIAL) cards are small squares: up to MAT_TIER1_PER_SLOT of
   them stack in one slot. Each still scores as a full card (matScore()
   reads the card list, not the slots). */
const MAT_TIER1_PER_SLOT = 2;
const matIsTier1 = c => c.tier === "MATERIAL";
/* Mat order -> slot units: {card, idx, w} for a normal card, {stack:
   [{card, idx}], w:1} for tier 1 squares. A tier 1 card joins the first
   stack with room, else starts a new one where it sits in mat order. */
function matUnits(cards){
  const units = [], perSlot = matLayout(cards).perSlot;
  cards.forEach((c, i) => {
    if (!matIsTier1(c)){ units.push({card:c, idx:i, w:matSlotsOf(c)}); return; }
    const open = units.find(u => u.stack && u.stack.length < perSlot);
    if (open) open.stack.push({card:c, idx:i});
    else units.push({stack:[{card:c, idx:i}], w:1});
  });
  return units;
}
/* Left-to-right packing: a 2-wide capstone never straddles a row break, so a
   lone last column pads out -- and the pad still costs a slot. Occupancy
   comes from the packing, not a sum of widths. */
function matPackCells(cards){
  const cells = [], cols = matLayout(cards).cols;
  let col = 0;
  matUnits(cards).forEach(u => {
    if (col + u.w > cols){ while (col < cols){ cells.push({w:1}); col++; } col = 0; }
    cells.push(u);
    col = (col + u.w) % cols;
  });
  return cells;
}
const matOccupancy = cards => matPackCells(cards).reduce((n, c) => n + c.w, 0);
const matFits = cards => matOccupancy(cards) <= matLayout(cards).slots;

/* A card's DIRECT recipe items only; cards "share a component" when the same
   name appears on both. */
const matDirectItems = c => new Set(c.components.filter(x => x.kind === "item").map(x => x.name));

function matGroupsOf(mat){
  const st = {}, su = {}, cp = {};
  mat.forEach(c => {
    // Every station the card sells at, so it can count toward several station
    // combos at once.
    c.stations.forEach(s => { st[s] = (st[s] || 0) + 1; });
    // Every pip counts: two organic pips add 2 to organic. (matDirectItems()
    // below dedupes instead.)
    c.pips.forEach(s => { su[s] = (su[s] || 0) + 1; });
    // A card counts toward its own name's group too, so Chicken plus two items
    // made from Chicken share "Chicken".
    cp[c.name] = (cp[c.name] || 0) + 1;
    matDirectItems(c).forEach(n => { cp[n] = (cp[n] || 0) + 1; });
  });
  return { st, su, cp };
}
/* Every group of 3+ counts, not just the biggest -- they all stack into
   one multiplier. */
function matAllGroups(map){
  return Object.keys(map)
    .map(name => ({ name, k: map[name], bonus: matComboTier(map[name]) }))
    .filter(g => g.bonus > 0)
    .sort((a, b) => b.k - a.k || a.name.localeCompare(b.name));
}
/* A card whose whole direct recipe is also on the mat scores double. Pure-
   element cards never qualify (every() on an empty set would be true). */
function matIsComplete(c, mat){
  const need = matDirectItems(c);
  if (!need.size) return false;
  const names = new Set(mat.map(m => m.name));
  return [...need].every(n => names.has(n));
}

/* Named collections: the 69 the player reviewed (originally
   archive/handoff/mat_collections_approved.csv), plus later additions
   below. Each was checked against MAT_CARD_BY_NAME/matOccupancy().
   "Motorcycle"/"Sushi Restaurant" are collection themes made of existing
   items, not item cards. Collections are discovered, not shown up front --
   see prefs.everUnlockedMatCollections and renderMatTop(). */
const MAT_COLLECTIONS_RAW = [
  { id:"fruits",                  name:"Fruits",                  items:["Apple","Banana"] },
  { id:"people-power",            name:"People Power",            items:["Canoe","Bicycle"] },
  { id:"alloys",                  name:"Alloys",                  items:["Steel","Aluminum Alloy","Stainless Steel"] },
  { id:"bedrock",                 name:"Bedrock",                 items:["Clay","Sand","Limestone"] },
  { id:"calcium-creations",       name:"Calcium Creations",       items:["Bone","Egg","Limestone"] },
  { id:"closed-circuit",          name:"Closed Circuit",          items:["Battery","Wire","Light Bulb"] },
  { id:"daily-commute",           name:"Daily Commute",           items:["Car","Bicycle","Maglev Train"] },
  { id:"deep-time",               name:"Deep Time",               items:["Diamond","Fossil","Star"] },
  { id:"early-explorers",         name:"Early Explorers",         items:["Canoe","Compass","Star"] },
  { id:"electromagnet",           name:"Electromagnet",           items:["Wire","Magnet","Battery"] },
  { id:"farmstead-feast",         name:"Farmstead Feast",         items:["Chicken","Egg","Apple Pie"] },
  { id:"flora",                   name:"Flora",                   items:["Tree","Grain","Seaweed"] },
  { id:"foundry-basics",          name:"Foundry Basics",          items:["Steel","Furnace","Tools"] },
  { id:"greenhouse",              name:"Greenhouse",              items:["Log Cabin","Glass","Star"] },
  { id:"hydrocarbons",            name:"Hydrocarbons",            items:["Sugar","Seaweed","Tree"] },
  { id:"lab-bench",               name:"Lab Bench",               items:["Microchip","Light Bulb","Engine"] },
  { id:"morning-bake",            name:"Morning Bake",            items:["Egg","Banana","Dough"] },
  { id:"motorcycle",              name:"Motorcycle",              items:["Bicycle","Engine","Fiberglass"] },
  { id:"nautical-trio",           name:"Nautical Trio",           items:["Canoe","Orca","Salmon"] },
  { id:"off-grid-home",           name:"Off-Grid Home",           items:["Log Cabin","Oven","Light Bulb"] },
  { id:"full-circle",             name:"Full Circle",             items:["Clock","Compass","Wheel"] },
  { id:"prosthesis",              name:"Prosthesis",              items:["Bone","Aluminum Alloy","Stainless Steel"] },
  { id:"shelter-from-the-storm",  name:"Shelter from the Storm",  items:["Log Cabin","Lighthouse","Building"] },
  { id:"sky-survey",              name:"Sky Survey",              items:["Telescope","Satellite Dish","Rocket"] },
  { id:"sourdough",               name:"Sourdough",               items:["Flour","Water","Yeast"] },
  { id:"special-exhibit",         name:"Special Exhibit",         items:["Museum","Canoe","Clay"] },
  { id:"sushi-restaurant",        name:"Sushi Restaurant",        items:["Seaweed","Salmon","Building"] },
  { id:"to-the-skies",            name:"To the Skies",            items:["Helicopter","Rocket","Cloud"] },
  { id:"transparency",            name:"Transparency",            items:["Glass","Plastic","Diamond"] },
  { id:"wind-power",              name:"Wind Power",              items:["Tree","Turbine Blade","Battery"] },
  { id:"working-vehicles",        name:"Working Vehicles",        items:["Helicopter","Tractor","Maglev Train"] },
  { id:"ancient-ground",          name:"Ancient Ground",          items:["Fossil","Diamond","Limestone","Magnet"] },
  { id:"beach-town",              name:"Beach Town",              items:["Speedboat","Lighthouse","Fish Cakes"] },
  { id:"cabin-life",              name:"Cabin Life",              items:["Log Cabin","Tree","Deer","Fossil"] },
  { id:"concrete-jungle",         name:"Concrete Jungle",         items:["Concrete","Building","Skyscraper","Museum"] },
  { id:"confectionery",           name:"Confectionery",           items:["Sugar","Banana","Apple","Oven"] },
  { id:"deep-freight",            name:"Deep Freight",            items:["Natural Gas","Steel","Rubber","Maglev Train"] },
  { id:"fauna",                   name:"Fauna",                   items:["Deer","Chicken","Salmon","Orca"] },
  { id:"heavy-metal",             name:"Heavy Metal",             items:["Engine","Turbine Blade","Satellite Dish","Bridge"] },
  { id:"im-looking-through-you",  name:"I'm Looking Through You", items:["Glass","Light Bulb","Compass","Telescope"] },
  { id:"ocean-life",              name:"Ocean Life",              items:["Water","Seaweed","Salmon","Orca"] },
  { id:"old-growth-life",         name:"Old Growth Life",         items:["Soil","Tree","Deer","Salmon"] },
  { id:"power-up",                name:"Power Up",                items:["Furnace","Engine","Solar Panel","Turbine Blade"] },
  { id:"water-cycle",             name:"Water Cycle",             items:["Soil","Tree","Cloud","Water"] },
  { id:"grain-mill",              name:"Grain Mill",              items:["Farm","Grain","Turbine Blade"] },
  { id:"ancient-inventions",      name:"Ancient Inventions",      items:["Wheel","Telescope","Compass","Canoe","Furnace"] },
  { id:"farm-to-table",           name:"Farm to Table",           items:["Farm","Grain","Chicken","Egg","Apple"] },
  { id:"metal-works",             name:"Metal Works",             items:["Steel","Stainless Steel","Aluminum Alloy","Tools","Wire"] },
  { id:"precious-earth",          name:"Precious Earth",          items:["Soil","Limestone","Diamond","Natural Gas","Rubber"] },
  { id:"around-the-world",        name:"Around the World",        items:["Bicycle","Canoe","Speedboat","Car","Tractor","Helicopter","Maglev Train"] },
  { id:"bakery-complete",         name:"Bakery Complete",         items:["Sugar","Water","Yeast","Egg","Flour","Dough","Oven"] },
  { id:"city-complete",           name:"City Complete",           items:["Clay","Limestone","Steel","Concrete","Bridge","Building","Glass"] },
  { id:"deep-mine-complete",      name:"Deep Mine Complete",      items:["Clay","Natural Gas","Steel","Tools","Furnace","Aluminum Alloy","Diamond"] },
  { id:"observatory-complete",    name:"Observatory Complete",    items:["Microchip","Magnet","Compass","Satellite Dish","Telescope","Star","Rocket"] },
  { id:"ocean-complete",          name:"Ocean Complete",          items:["Water","Limestone","Sand","Seaweed","Banana","Cloud","Orca"] },
  { id:"old-growth-complete",     name:"Old Growth Complete",     items:["Sand","Bone","Soil","Salmon","Tree","Canoe","Deer"] },
  { id:"power-plant-complete",    name:"Power Plant Complete",    items:["Battery","Wire","Clock","Engine","Light Bulb","Computer","Turbine Blade"] },
  { id:"greenhouse-complete",     name:"Greenhouse Complete",     items:["Fertilizer","Sugar","DNA","Soil","Farm","Chicken","Apple","Grain"] },
  { id:"world-tour",              name:"World Tour",              items:["Cloud","Tree","Diamond","Grain","Light Bulb","Dough","Building","Telescope"] },
  // Discoverable sub-groups (2026-11-03): tight 3-4 item clusters found
  // inside strong full mats (the player's exported boards plus hill-climb
  // results), each sharing a station, suit or component. Approved by the
  // player in the Collection Workshop (2026-11-04).
  { id:"primordial-soup",         name:"Micro Sugars",            items:["Sugar","DNA","Yeast"] },
  { id:"bake-sale",               name:"Bake Sale",               items:["Fruit Cake","Apple Pie","Banana Bread"] },
  { id:"robotics-lab",            name:"Robotics Lab",            items:["Robot","Computer","Car","Turbine Blade"] },
  { id:"woodshop",                name:"Woodshop",                items:["Tree","Canoe","Log Cabin","Wheel"] },
  { id:"synthetics",              name:"Synthetics",              items:["Plastic","Fiberglass","Computer"] },
  { id:"skyline",                 name:"Skyline",                 items:["Building","Skyscraper","Museum"] },
  { id:"mission-control",         name:"Mission Control",         items:["Computer","Rocket","Satellite Dish"] },
  { id:"barn-raising",            name:"Barn Raising",            items:["Farm","Wheel","Log Cabin"] },
  { id:"fishing-trip",            name:"Fishing Trip",            items:["Canoe","Salmon"] },
];
const matCollectionBonus = col =>
  Math.round(col.items.reduce((n, i) => n + (MAT_CARD_BY_NAME[i] ? MAT_CARD_BY_NAME[i].points : 0), 0) * 0.3);
function buildMatCollections(){
  const out = [];
  MAT_COLLECTIONS_RAW.forEach(c => {
    const missing = c.items.filter(i => !MAT_CARD_BY_NAME[i]);
    if (missing.length){
      console.warn(`Mat collection "${c.name}" drops: ${missing.join(", ")} (not in the Classic deck)`);
      return;
    }
    out.push({
      ...c,
      slots: matOccupancy(c.items.map(i => MAT_CARD_BY_NAME[i])),
      bonus: matCollectionBonus(c),
      hint: c.items.join(", "),
      // Every member must be ON THE MAT, not merely owned -- that is what
      // makes a collection compete for slots against raw points.
      done: mat => c.items.every(i => mat.some(m => m.name === i)),
    });
  });
  return out;
}
const MAT_COLLECTIONS = buildMatCollections();
const matCompletedIn = mat => MAT_COLLECTIONS.filter(col => col.done(mat));

function matScore(mat){
  const has = n => matHas(mat, n);
  const dest = has("Space Station") ? matDestination() : null;
  // A card's points with the capstone point rules: Freight +2 (tier 1),
  // Upgrade +5, complete recipe x2 (Home-Grown x3), Orbit x2.
  const cardPts = c => {
    let p = c.points + (has("Maglev Train") && matIsTier1(c) ? 2 : 0) + (has("Robot") ? 5 : 0);
    if (matIsComplete(c, mat)) p *= has("Homestead") ? 3 : 2;
    if (dest && c.stations.includes(dest)) p *= 2;
    return p;
  };
  const base = mat.reduce((n, c) => n + cardPts(c), 0);
  const completeNames = new Set(mat.filter(c => matIsComplete(c, mat)).map(c => c.name));
  const g = matGroupsOf(mat);
  const combos = {
    station: matAllGroups(g.st),
    suit: matAllGroups(g.su),
    component: matAllGroups(g.cp),
  };
  const comboBonus = [...combos.station, ...combos.suit, ...combos.component]
    .reduce((n, grp) => n + grp.bonus, 0);
  const cols = matCompletedIn(mat);
  const colBonus = cols.reduce((n, c) => n + c.bonus, 0);
  // Signature multipliers: Biodiversity (stations on the mat) and Old
  // Growth (board checks in a row, counting this one).
  const stationsOn = new Set(mat.flatMap(c => c.stations)).size;
  const coralMult = has("Coral Reef") ? stationsOn : 0;
  const ecoMult = has("Ecosystem") ? (state.ecoStreak || 0) + 1 : 0;
  const mult = 1 + comboBonus + coralMult + ecoMult;
  const layered = has("Fruit Cake") && Object.keys(ELEMENT_SUIT_LABEL).every(s => mat.some(c => c.pips.includes(s)));
  // What each capstone on the mat is doing right now (combo-row chips).
  const sigs = [];
  if (has("Coral Reef")) sigs.push({ name: "Coral Reef", label: `+${coralMult}`, on: true });
  if (has("Robot")) sigs.push({ name: "Robot", label: `+${5 * mat.length}`, on: true });
  if (has("Homestead")) sigs.push({ name: "Homestead", label: "×3", on: completeNames.size > 0 });
  if (has("Maglev Train")) sigs.push({ name: "Maglev Train", label: `+${2 * mat.filter(matIsTier1).length}`, on: mat.some(matIsTier1) });
  if (has("Ecosystem")) sigs.push({ name: "Ecosystem", label: `+${ecoMult}`, on: true });
  if (has("Fruit Cake")) sigs.push({ name: "Fruit Cake", label: "×2", on: layered });
  if (has("Metropolis")) sigs.push({ name: "Metropolis", label: "+2", on: true });
  if (has("Space Station")) sigs.push({ name: "Space Station", label: "×2", on: !!dest && mat.some(c => c.stations.includes(dest)) });
  const pre = (base + colBonus) * mult;
  return { base, combos, completeNames, cols, colBonus, mult, sigs, layered, total: layered ? pre * 2 : pre };
}

/* BINGO card (Classic's Marketplace tray, see bingoCardHTML()). Eligible
   pool: core items worth BINGO_MIN_POINTS or more. Drawn once per run into
   state.bingoCard (ensureBingoCard()); freshState() nulls it for a new
   draw. */
const BINGO_SIZE = 5;
const BINGO_MIN_POINTS = 5;
/* Marketplace layout, fixed for the whole run (state.bingoLayout, set from
   prefs.classicBingo by freshState()):
     "rows"  -- 3 rows of 4, mostly tier 3; each finished row pays a "?".
                All 8 capstones sit below the rows (default).
     "bingo" -- the original 5x5 card with a chosen capstone in the centre.
   Fixed per run so switching the setting can't redraw a card mid-run. */
const MARKET_ROWS = 3, MARKET_ROW_LEN = 4;
const marketRowsMode = () => state.bingoLayout === "rows";
/* Rows of three tier 3 items and one tier 2, shuffled within the row; no
   capstones. Given the run's chosen capstone, the first row is that
   capstone plus three items from its station -- ones that feed it first,
   tier 3 before tier 2 -- so the run starts with a clear goal. */
function drawRowCard(capstone){
  const eligible = bingoEligibleItems().filter(n => ITEM_TIER[n] !== "CAPSTONE");
  const used = new Set(), rows = [];
  if (capstone){
    const feeds = new Set(componentClosure(capstone));
    const rank = n => (feeds.has(n) ? 0 : 2) + (ITEM_TIER[n] === "CREATION" ? 0 : 1);
    const mates = shuffle(eligible.filter(n => CORE_ITEM_STATION[n] === CORE_ITEM_STATION[capstone]))
      .sort((a, b) => rank(a) - rank(b)).slice(0, MARKET_ROW_LEN - 1);
    [capstone, ...mates].forEach(n => used.add(n));
    rows.push(shuffle([capstone, ...mates]));
  }
  const t3 = shuffle(eligible.filter(n => ITEM_TIER[n] === "CREATION" && !used.has(n)));
  const t2 = shuffle(eligible.filter(n => ITEM_TIER[n] === "COMPONENT" && !used.has(n)));
  while (rows.length < MARKET_ROWS) rows.push(shuffle([...t3.splice(0, 3), ...t2.splice(0, 1)]));
  return rows.flat();
}
function bingoEligibleItems(){
  return [...CORE_ITEM_NAMES].filter(n => (ITEM_POINTS[n] || 0) >= BINGO_MIN_POINTS);
}
// The 8 possible centre capstones (one per station). The opening capstone
// choice shows these; ensureBingoCard()'s redraw path picks one at random.
function bingoCapstoneChoices(){
  return bingoEligibleItems().filter(n => ITEM_TIER[n] === "CAPSTONE");
}
/* Each capstone's signature rule while it's on the mat (two capstones:
   both apply). Scored in matScore(); the shape rules (Freight, Expansion)
   in matLayout(). The line is shown on its landscape card. */
const CAPSTONE_SIGNATURES = {
  "Coral Reef":    "Biodiversity: +1 multiplier for each different station on your mat.",
  "Robot":         "Upgrade: every card on your mat scores +5.",
  "Homestead":     "Home-Grown: cards with their whole recipe on your mat score ×3 instead of ×2.",
  "Maglev Train":  "Freight: tier 1 cards stack 3 to a slot and score +2 each.",
  "Ecosystem":     "Old Growth: +1 multiplier for each board check in a row it's been on your mat.",
  "Fruit Cake":    "Four-Layer Cake: all 4 suits on your mat doubles your Quarks.",
  "Metropolis":    "Expansion: your mat has 2 extra slots.",
  "Space Station": "Orbit: cards from the station you're travelling to score ×2.",
};
/* Orbit's station: where the Lock-In is travelling to, or the station
   picked on the map (a preview); none otherwise. */
function matDestination(){
  if (typeof travelPromptFor !== "undefined" && travelPromptFor) return travelPromptFor;
  return screen === "map" && selectedMapStation && selectedMapStation !== state.lastStation ? selectedMapStation : null;
}
/* Roman-numeral tier: MATERIAL I, COMPONENT II, CREATION III, CAPSTONE IV. */
const TIER_NUMERAL = {MATERIAL:"I", COMPONENT:"II", CREATION:"III", CAPSTONE:"IV"};
function tierBadgeHTML(name){
  const t = ITEM_TIER[name];
  if (!TIER_NUMERAL[t]) return "";
  return `<span class="bc-tier${t === "CAPSTONE" ? " t4" : ""}" title="Tier ${TIER_NUMERAL[t]}">${TIER_NUMERAL[t]}</span>`;
}
/* Fixed tier spread around the centre capstone: no tier I, 10 tier II, 13
   tier III, 1 extra tier IV (24 + centre). A tier that runs short tops up
   from that tier's full core list, then from other non-tier-I eligible
   items. */
const BINGO_TIER_SPREAD = [["COMPONENT", 10], ["CREATION", 13], ["CAPSTONE", 1]];
function drawBingoCard(chosenCenter){
  const eligible = bingoEligibleItems();
  const capPool = shuffle(eligible.filter(n => ITEM_TIER[n] === "CAPSTONE"));
  const center = chosenCenter || capPool[0];
  const used = new Set([center]);
  const picks = [];
  BINGO_TIER_SPREAD.forEach(([tier, n]) => {
    const fromEligible = shuffle(eligible.filter(x => ITEM_TIER[x] === tier && !used.has(x)));
    const fromCore = shuffle([...CORE_ITEM_NAMES].filter(x => ITEM_TIER[x] === tier && !used.has(x) && !fromEligible.includes(x)));
    [...fromEligible, ...fromCore].slice(0, n).forEach(x => { used.add(x); picks.push(x); });
  });
  const need = BINGO_SIZE * BINGO_SIZE - 1;
  if (picks.length < need){
    shuffle(eligible.filter(x => !used.has(x) && ITEM_TIER[x] !== "CAPSTONE" && ITEM_TIER[x] !== "MATERIAL"))
      .slice(0, need - picks.length).forEach(x => { used.add(x); picks.push(x); });
  }
  const others = shuffle(picks);
  return [...others.slice(0, BINGO_CENTER_IDX), center, ...others.slice(BINGO_CENTER_IDX)];
}
function ensureBingoCard(){
  const need = marketRowsMode() ? MARKET_ROWS * MARKET_ROW_LEN : BINGO_SIZE * BINGO_SIZE;
  // Also redraw if any square is no longer core (an old save after a
  // rebalance): bingoCardHTML() would throw on it and stop the tray from ever
  // opening.
  const stale = state.bingoCard && state.bingoCard.some(n => !CORE_ITEM_NAMES.has(n));
  if (!state.bingoCard || state.bingoCard.length !== need || stale){
    // Replacing an old card: its line progress and centre choice belong to
    // that card, so they go with it.
    if (state.bingoCard){
      state.bingoLinesCompleted = [];
      state.pendingBingoClears = [];
      state.bingoCenterChosen = false;
    }
    state.bingoCard = marketRowsMode() ? drawRowCard() : drawBingoCard();
    save();
  }
  return state.bingoCard;
}
const BINGO_CENTER_IDX = Math.floor(BINGO_SIZE / 2) * BINGO_SIZE + Math.floor(BINGO_SIZE / 2);
/* Sets just the centre square. Only swaps another square if the new
   capstone was already on the card (replaced with a non-capstone of the
   same tier), so no item ever appears twice. */
function setBingoCenter(name){
  if (name === BINGO_RANDOM_CAPSTONE){
    const choices = bingoCapstoneChoices();
    name = choices[Math.floor(Math.random() * choices.length)];
  }
  // Rows layout: no centre -- the chosen capstone gets its own station row
  // (drawRowCard()). Only redrawn before any row has paid out.
  if (marketRowsMode()){
    if (!(state.bingoLinesCompleted || []).length) state.bingoCard = drawRowCard(name);
    else ensureBingoCard();
    state.bingoCenterChosen = true; save(); return;
  }
  const card = ensureBingoCard().slice();
  const dupIdx = card.findIndex((n, i) => i !== BINGO_CENTER_IDX && n === name);
  if (dupIdx !== -1){
    const used = new Set(card);
    used.add(name);
    const filler = shuffle(bingoEligibleItems().filter(n => ITEM_TIER[n] === ITEM_TIER[card[dupIdx]] && !used.has(n)))[0]
      || shuffle(bingoEligibleItems().filter(n => ITEM_TIER[n] !== "CAPSTONE" && ITEM_TIER[n] !== "MATERIAL" && !used.has(n)))[0];
    if (filler) card[dupIdx] = filler;
  }
  card[BINGO_CENTER_IDX] = name;
  state.bingoCard = card;
  state.bingoCenterChosen = true;
  save();
}
// Every row/column/diagonal as a flat array of cell indices -- purely a
// function of BINGO_SIZE, so it's cheap to recompute on every render
// rather than caching it anywhere.
function bingoLines(){
  if (marketRowsMode())
    return Array.from({length: MARKET_ROWS}, (_, r) => Array.from({length: MARKET_ROW_LEN}, (_, c) => r * MARKET_ROW_LEN + c));
  const n = BINGO_SIZE, lines = [], at = (r, c) => r * n + c;
  for (let r = 0; r < n; r++) lines.push(Array.from({length:n}, (_, c) => at(r, c)));
  for (let c = 0; c < n; c++) lines.push(Array.from({length:n}, (_, r) => at(r, c)));
  lines.push(Array.from({length:n}, (_, i) => at(i, i)));
  lines.push(Array.from({length:n}, (_, i) => at(i, n - 1 - i)));
  return lines;
}
/* Tapping a square opens its inspection card ([data-item-card]); pinning
   happens from that card's pin button, and the 📌 here is read-only
   (isPinned()). "Owned" reflects owns() for that one item; completed lines
   only score (checkBingoLines()), with no extra line highlight. */
/* Which page the Marketplace card shows: the BINGO card or a 2x4 grid of
   every Capstone (folder tabs, like the mat's). Reset to BINGO when the tray
   opens. */
let bingoTab = "bingo";
function bingoTabsHTML(){
  return `<div class="bingo-tabs">
    <button type="button" class="mat-tab bingo-tab ${bingoTab === "bingo" ? "active" : ""}" data-bingo-tab="bingo">BINGO</button>
    <button type="button" class="mat-tab bingo-tab ${bingoTab === "capstones" ? "active" : ""}" data-bingo-tab="capstones">🏆 Capstones</button>
  </div>`;
}
function capstoneGridHTML(){
  const cells = bingoCapstoneChoices().map(name => {
    const idx = ENTRIES.findIndex(e => e.name === name);
    const station = STATION_BY_NAME[CORE_ITEM_STATION[name]];
    return `<div class="bingo-cell${owns(name) ? " owned" : ""}" data-cap-inspect="${idx}" title="${esc(name)} -- ${esc(station.name)}">
      <span class="bc-station" title="${esc(station.name)}">${em(station.emoji)}</span>
      <span class="bc-icon">${em(ITEM_EMOJI[name])}</span>
      <span class="bc-name">${esc(name)}</span>
    </div>`;
  }).join("");
  return `${bingoTabsHTML()}<div class="bingo-page">
    <h3 class="bingo-title">Capstones</h3>
    <div class="bingo-wrap"><div class="bingo-grid bingo-pick-grid">${cells}</div></div>
  </div>`;
}
/* One Marketplace square: owned / craftable ring, pin, icon, name, tier.
   cellIdx is its index on the card (null for the rows layout's capstone
   squares, which aren't part of any row). Tapping it crafts or inspects
   (the .bingo-cell[data-item-card] handler). */
function bingoCellHTML(name, cellIdx, inspectOnly){
    const idx = ENTRIES.findIndex(e => e.name === name);
    // Craftable now gets the same green ring as owned (on the parchment face),
    // so actionable squares stand out (craft via openBingoCraftOverlay()).
    const owned = owns(name);
    const craftable = !inspectOnly && !owned && idx >= 0 && canCraft(ENTRIES[idx]);
    const cls = owned ? "bingo-cell owned" : craftable ? "bingo-cell craftable" : "bingo-cell";
    const pinned = isPinned(name);
    // inspectOnly (the Capstones list): data-cap-inspect opens the item card
    // instead of the craft card.
    return `<div class="${cls}"${cellIdx === null ? "" : ` data-cell-idx="${cellIdx}"`} ${inspectOnly ? "data-cap-inspect" : "data-item-card"}="${idx}" title="${esc(name)} -- ${ITEM_POINTS[name]} pts">
      <button type="button" class="bc-pin ${pinned ? "on" : ""}" data-pin="${esc(name)}"
        aria-label="${pinned ? "Unpin " : "Pin "}${esc(name)}" aria-pressed="${pinned}">📌</button>
      ${inspectOnly ? `<span class="bc-station bc-station-badge" title="${esc(CORE_ITEM_STATION[name])}">${em(STATION_BY_NAME[CORE_ITEM_STATION[name]].emoji)}</span>` : ""}
      <span class="bc-icon">${em(ITEM_EMOJI[name])}</span>
      <span class="bc-name">${esc(name)}</span>
      ${tierBadgeHTML(name)}
    </div>`;
}
/* Rows layout: the Market panel (3 rows of 4, the only squares craftable
   from here, each row ending in its "?" reward or a check once paid) and,
   below it, every capstone as a pinnable list -- tapping one inspects it. */
function marketRowsHTML(){
  const card = ensureBingoCard();
  const rows = bingoLines().map((line, r) => {
    const done = (state.bingoLinesCompleted || []).includes(r);
    return `<div class="mrow${done ? " done" : ""}">
      <div class="bingo-grid mrow-grid">${line.map(i => bingoCellHTML(card[i], i)).join("")}</div>
      <span class="mrow-reward" title="${done ? "Row complete -- \"?\" earned" : "Finish this row to earn a \"?\" element"}">${done ? "✓" : emptyElSquareHTML(26)}</span>
    </div>`;
  }).join("");
  const caps = bingoCapstoneChoices().map(n => bingoCellHTML(n, null, true)).join("");
  return `<div class="bingo-page mrow-page">
    <section class="mrow-market" aria-labelledby="mrowMarketTitle">
      <div class="mrow-top">
        <h3 class="mrow-head" id="mrowMarketTitle">🛒 Market</h3>
        <span class="mrow-hint">Tap on an item to craft directly from here!</span>
        <span class="mrow-gift" title="Finish a row to earn a &quot;?&quot; element" aria-label="Row reward">🎁</span>
      </div>
      ${rows}
    </section>
    <h3 class="mrow-head mrow-caps-head">🏆 Capstones</h3>
    <p class="mrow-caps-sub">Capstones must be crafted at their own station</p>
    <div class="bingo-grid bingo-pick-grid mrow-caps">${caps}</div>
  </div>`;
}
function bingoCardHTML(){
  if (marketRowsMode()) return marketRowsHTML();
  if (bingoTab === "capstones") return capstoneGridHTML();
  const card = ensureBingoCard();
  const cells = card.map((name, i) => {
    // Centre square before a capstone is chosen (state.bingoCenterChosen): an
    // "Add Capstone" invitation; data-add-capstone routes the tap to
    // openCapstoneOverlay().
    if (i === BINGO_CENTER_IDX && !state.bingoCenterChosen){
      return `<div class="bingo-cell bingo-cell-addcap" data-cell-idx="${i}" data-add-capstone="1" title="Add a capstone to anchor your BINGO card">
        <span class="bc-addcap-ic">➕</span>
        <span class="bc-addcap-label">Add<br>Capstone</span>
      </div>`;
    }
    return bingoCellHTML(name, i);
  }).join("");
  return `${bingoTabsHTML()}<div class="bingo-page">
    <h3 class="bingo-title">Marketplace</h3>
    <p class="bingo-subhint">Tap on an item to craft it directly from the market!</p>
    <div class="bingo-wrap"><div class="bingo-grid">${cells}</div></div>
    <p class="bingo-hint"><span class="bingo-hint-line">✅ Complete a line of 5 across the card for bonus points.</span></p>
  </div>`;
}
// Sentinel for the picker's "Random" button, resolved to a real capstone by
// chooseBingoCapstone()/setBingoCenter().
const BINGO_RANDOM_CAPSTONE = "__RANDOM__";
/* The 2x4 capstone-choice grid inside #capstoneOverlay, styled like BINGO
   cells without owned/pin states. Taps go to chooseBingoCapstone(). */
function bingoCapstonePickerHTML(){
  const choices = bingoCapstoneChoices();
  const cells = choices.map(name => {
    const station = STATION_BY_NAME[CORE_ITEM_STATION[name]];
    return `<div class="bingo-cell" data-capstone-pick="${esc(name)}" title="${esc(name)} -- ${ITEM_POINTS[name]} pts">
      <span class="bc-station" title="${esc(station.name)}">${em(station.emoji)}</span>
      <span class="bc-icon">${em(ITEM_EMOJI[name])}</span>
      <span class="bc-name">${esc(name)}</span>
    </div>`;
  }).join("");
  return `<h3 class="bingo-title" id="capstoneOverlayTitle">Choose Your Capstone</h3>
    <div class="bingo-wrap"><div class="bingo-grid bingo-pick-grid">${cells}</div></div>
    <button type="button" class="bigbtn sec bingo-random-btn" data-capstone-pick="${BINGO_RANDOM_CAPSTONE}">🎲 Random</button>
    <p class="bingo-hint"><span class="bingo-hint-line">🏆 Pick one to anchor the center of your BINGO card.</span></p>
    <div class="row" style="margin-top:14px">
      <button type="button" class="bigbtn sec" id="capstoneOverlayClose">Cancel</button>
    </div>`;
}



/* Raw materials sold at several stations (Water, Clay, ...) are pinned to
   the top of every shop list, always in this order, so they're learned
   once. Everything else sorts by ITEM_POINTS below them. */
const FUNDAMENTAL_ITEMS = ["Water","Sand","Clay","Soil","Limestone","Natural Gas","Sugar","Glass","Steel","Tools"];
const fundamentalRank = name => {
  const i = FUNDAMENTAL_ITEMS.indexOf(name);
  return i === -1 ? Infinity : i;
};
/* Station shop lists: fundamentals first (fixed order above), then
   everything else ascending by point value. */
function sortShopItems(entries){
  return [...entries].sort((a, b) =>
    fundamentalRank(a.name) - fundamentalRank(b.name) ||
    (ITEM_POINTS[a.name] || 0) - (ITEM_POINTS[b.name] || 0));
}
/* Recipe tokens: elements first (declared order), then items by points. */
function sortIngredientTokens(toks){
  const els = toks.filter(t => t.kind === "element");
  const items = toks.filter(t => t.kind !== "element")
    .sort((a, b) => (ITEM_POINTS[a.name] || 0) - (ITEM_POINTS[b.name] || 0));
  return [...els, ...items];
}

/* Faded backdrop art shown behind each station's own screen (never on the
   map/inventory/etc). Mirrors build_campaign_art.py's BACKDROPS mapping --
   update both if a station's art changes. */
const STATION_BG = {
  "The Ocean":          "backdrops/ocean.webp",
  "The Power Plant":    "backdrops/power-plant.webp",
  "Greenhouse":         "backdrops/greenhouse.webp",
  "Deep Mine":          "backdrops/deep-mine.webp",
  "Old Growth Forest":  "backdrops/old-growth-forest.webp",
  "The Bakery":         "backdrops/bakery.webp",
  "The City":           "backdrops/quarry.webp", // TODO(#127): re-art as city, not quarry
  "The Observatory":    "backdrops/observatory.webp",
};
function shuffle(arr){
  for (let i = arr.length - 1; i > 0; i--){
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

const entriesAt = st => ENTRIES.filter(e => e.station === st);
