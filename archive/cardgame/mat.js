/* =====================================================================
   Elementia -- Display Mat.  A Bazaar-shaped take on the solo game.

   The mana pool is gone from the solitaire half entirely. Elements are
   spent once, in the shop, to craft an item; the item then earns forever
   by sitting on your mat. No card is bought twice.

   A round is: arrange 8 slots from everything you own -> travel -> the
   mat scores -> the score buys you extra dice at the next station -> that
   station's shop adds new cards to your collection.

   Scoring is (base + collection bonuses) x multiplier.
     base  = the points printed on the displayed cards, DOUBLED for any
             card whose full direct recipe is also sitting on the mat
     combo = every QUALIFYING group of cards on the mat that share a
             STATION, a SUIT, or a DIRECT COMPONENT of their recipe --
             multiple groups of the same kind (two different suits, a
             station group AND a component group, etc.) all stack, not
             just the single biggest group of each kind

   Groups still only qualify from three cards up -- two-up was measured
   to reach x32 by round 14 purely from incidental pairs (eight cards
   carrying two to five components each throw off a huge number of them
   on their own), which summing-every-group-from-three still avoids.

   Content comes from data.js (build_cards.py) and run.js
   (reconstruct_run.py --emit-js); art from ../boardgame/icons.js.
   ===================================================================== */

///////////////////////////////////////////////////////////////////////
// Tunables
///////////////////////////////////////////////////////////////////////

const COLS = 4, ROWS = 2;
const SLOTS = COLS * ROWS;       // 2 rows of 4, always drawn in full
const CAPSTONE_SLOTS = 2;        // a capstone eats two of them

/* k alike -> bonus. Applied to the biggest station group, the biggest
   suit group and the biggest shared-component group, and nothing else. */
const COMBO_TIERS = [ {k:3, b:1}, {k:4, b:2}, {k:5, b:4}, {k:6, b:6} ];

/* Dice at the next station. Three is the base roll; the mat buys up to
   three more. Thresholds are a fraction of PAR -- the best mat the solver
   can build from the same collection this round -- because a fixed
   number cannot serve a run whose reachable score climbs from 3 to 1300.
   Measured against par, the question is always "did you arrange this
   well?", which is the only thing the player actually controls. */
const BASE_DICE = 3;
const DICE_TIERS = [ {pct:0.90, dice:3}, {pct:0.70, dice:2}, {pct:0.45, dice:1} ];

const SUIT_ORDER = ["organic", "reactive", "earth", "metal"];

///////////////////////////////////////////////////////////////////////
// Helpers
///////////////////////////////////////////////////////////////////////

const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"']/g, c =>
  ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
const em = key => (typeof ICONS !== "undefined" && ICONS[key]) || esc(key);
const suitArt = s => `<img class="suit-art" src="${SUIT_ART[s]}" alt="${s}">`;

/* Fail loudly, on the page. This file is usually opened straight off
   disk, where a browser will happily serve a cached mat.html against a
   fresh mat.js -- and then the first missing thing throws, nothing
   renders, and the screen just sits there with the reason buried in a
   console nobody has open. */
function fatal(msg){
  console.error(msg);
  document.body.insertAdjacentHTML("afterbegin",
    `<div class="boot-error">
       <h3>The mat could not start</h3>
       <p>${esc(msg)}</p>
       <p>Almost always a stale cache: reload with <b>Ctrl</b>+<b>Shift</b>+<b>R</b>.
         If that does not clear it, re-run <code>python cardgame/build_cards.py</code>
         and <code>python boardgame/build_board.py</code>.</p>
     </div>`);
  throw new Error(msg);
}

/* Checked here rather than in boot(), because BY and STATION_META below
   already read ITEM_CARDS -- by boot() a missing data.js has long since
   thrown. Each name is tested bare, not through window[...]: a top-level
   `const` lives in the script's lexical scope and never becomes a window
   property, so the indexed form reports every one of them missing. */
[["data.js", "ITEM_CARDS", typeof ITEM_CARDS],
 ["data.js", "SUIT_ART", typeof SUIT_ART],
 ["data.js", "CONTENT_VERSION", typeof CONTENT_VERSION],
 ["run.js",  "RECORDED_RUN", typeof RECORDED_RUN]]
  .filter(([, , t]) => t === "undefined")
  .forEach(([file, name]) => fatal(`${file} did not load — ${name} is undefined`));

const BY = {};
ITEM_CARDS.forEach(i => { BY[i.name] = i; });

/* Stations only exist on the cards, so derive the roster from them --
   art and colour included, since a station now renders as its own icon. */
const STATION_META = {};
ITEM_CARDS.forEach(c => { STATION_META[c.station] = { emoji: c.stationEmoji, color: c.stationColor }; });
const STATIONS = Object.keys(STATION_META).sort();

const isCapstone = c => c.tier === "CAPSTONE";
const slotsOf = c => isCapstone(c) ? CAPSTONE_SLOTS : 1;
const comboTier = k => {
  let b = 0;
  COMBO_TIERS.forEach(t => { if (k >= t.k) b = t.b; });
  return b;
};

/* Lay cards out left-to-right across four columns. A capstone is two
   cells wide and will not straddle a row break, so when only one column
   is left the rest of that row is padded out -- the pad still costs a
   slot, which is why occupancy is computed from the packing rather than
   from a plain sum of widths. */
function packCells(cards){
  const cells = [];
  let col = 0;
  cards.forEach((c, i) => {
    const w = slotsOf(c);
    if (col + w > COLS){ while (col < COLS){ cells.push({ w:1 }); col++; } col = 0; }
    cells.push({ card:c, idx:i, w });
    col = (col + w) % COLS;
  });
  return cells;
}
const occupancy = cards => packCells(cards).reduce((n, c) => n + c.w, 0);
const fits = cards => occupancy(cards) <= SLOTS;

///////////////////////////////////////////////////////////////////////
// Collections
///////////////////////////////////////////////////////////////////////

/* Collections are hand-authored sets of specific cards, not rules.

   Rules were the wrong answer: "five cards from the same station" or
   "five sharing a suit" is already what the combo multiplier pays for,
   so naming those too just pays twice for the same arrangement. A
   collection should be a thing you SET OUT to build over most of a run.

   These are tuned against the recorded run for exactly that. Of the
   nineteen below, eight cannot be completed before round 15, four land
   between 10 and 14, and seven cannot be finished in that run at all --
   it never crafted Diamond, Rainbow or Ecosystem. That last group is the
   point: which collections are even reachable changes run to run, which
   is the per-run identity the Bingo card used to supply.

   The digital game's own COLLECTIONS table (elementia.html) is the same
   idea but written against the full catalogue -- only one of its ten,
   Alloys, is buildable from the Classic 79, which is why that game hides
   collections from Classic Mode. These are the Classic-legal rewrite.

   Every item named here must be in the Classic deck; buildCollections()
   drops any that are not and says so. */
const CURATED = [
  { id:"deeptime",  name:"Deep Time",        items:["Fossil","Bone","Diamond","DNA","Clay"] },
  { id:"starchart", name:"Star Charts",      items:["Star","Telescope","Satellite Dish","Rocket","Space Station"] },
  { id:"rolling",   name:"Rolling Stock",    items:["Car","Helicopter","Speedboat","Maglev Train","Tractor"] },
  { id:"bakery",    name:"The Bakery Line",  items:["Flour","Dough","Yeast","Bread","Oven"] },
  { id:"sweet",     name:"Sweet Tooth",      items:["Sugar","Cake","Banana Bread","Fruit Cake","Apple"] },
  { id:"alloys",    name:"Alloy Works",      items:["Steel","Stainless Steel","Aluminum Alloy","Titanium Alloy","Fiberglass"] },
  { id:"livewire",  name:"Live Wire",        items:["Wire","Battery","Microchip","Computer","Light Bulb"] },
  { id:"skyline",   name:"Skyline",          items:["Concrete","Glass","Building","Skyscraper","Metropolis"] },
  { id:"openwater", name:"Open Water",       items:["Water","Seaweed","Salmon","Orca","Coral Reef"] },
  { id:"homestead", name:"The Homestead",    items:["Farm","Grain","Chicken","Log Cabin","Homestead"] },
  { id:"wild",      name:"Wild Things",      items:["Deer","Salmon","Orca","Chicken","Tree"] },
  { id:"weather",   name:"Weather Front",    items:["Cloud","Rainbow","Star","Water"] },
  { id:"instrum",   name:"Fine Instruments", items:["Clock","Compass","Magnet","Telescope"] },
  { id:"growth",    name:"Green Growth",     items:["Soil","Tree","Seaweed","Grain","Farm"] },
  { id:"powergrid", name:"Power Grid",       items:["Battery","Solar Panel","Turbine Blade","Engine","Light Bulb"] },
  { id:"firstlight",name:"First Light",      items:["Furnace","Glass","Light Bulb","Star","Lighthouse"] },
  { id:"machine",   name:"The Machine",      items:["Engine","Wheel","Rubber","Tools","Robot"] },
  { id:"genesis",   name:"Genesis",          items:["DNA","Egg","Life","Ecosystem","Tree"] },
  { id:"flight",    name:"Flight",           items:["Rocket","Helicopter","Satellite Dish","Turbine Blade","Compass"] },
];

/* Bonus is 30% of the set's own printed points, the same rule the digital
   game uses -- a real reward, but under what crafting a same-sized
   capstone pays, since a collection asks for breadth rather than depth.
   Derived rather than hand-set so it stays right if points are rebalanced. */
const collectionBonus = col =>
  Math.round(col.items.reduce((n, i) => n + (BY[i] ? BY[i].points : 0), 0) * 0.3);

function buildCollections(){
  const out = [];
  CURATED.forEach(c => {
    const missing = c.items.filter(i => !BY[i]);
    if (missing.length){
      console.warn(`Collection "${c.name}" drops: ${missing.join(", ")} (not in the Classic deck)`);
      return;
    }
    out.push({
      ...c,
      slots: occupancy(c.items.map(i => BY[i])),
      bonus: collectionBonus(c),
      hint: c.items.join(", "),
      // Every member must be ON THE MAT, not merely owned -- that is what
      // makes a collection compete for slots against raw points.
      done: mat => c.items.every(i => mat.some(m => m.name === i)),
      have: mat => c.items.filter(i => mat.some(m => m.name === i)).length,
    });
  });
  return out;
}
const COLLECTIONS = buildCollections();

const completedIn = mat => COLLECTIONS.filter(col => col.done(mat));

///////////////////////////////////////////////////////////////////////
// Scoring
///////////////////////////////////////////////////////////////////////

/* Components are the card's own DIRECT recipe -- what the shop asks you
   to hand over, nothing further up the tree. Two cards "share a
   component" only if the same name appears on both recipes, which is
   also exactly what the icon strip along the bottom of a card shows. */
const directItems = c => new Set(c.components.filter(x => x.kind === "item").map(x => x.name));

function groupsOf(mat){
  const st = {}, su = {}, cp = {};
  mat.forEach(c => {
    st[c.station] = (st[c.station] || 0) + 1;
    new Set(c.pips).forEach(s => { su[s] = (su[s] || 0) + 1; });
    directItems(c).forEach(n => { cp[n] = (cp[n] || 0) + 1; });
  });
  return { st, su, cp };
}

/* Every group that clears the 3-alike floor, not just the single biggest
   -- two different suit groups, or a station group AND a component
   group, now all stack. Sorted biggest-first purely for a stable,
   readable chip order; every entry here already has bonus > 0. */
function allGroups(map){
  return Object.keys(map)
    .map(name => ({ name, k: map[name], bonus: comboTier(map[name]) }))
    .filter(g => g.bonus > 0)
    .sort((a, b) => b.k - a.k || a.name.localeCompare(b.name));
}

/* A card's full direct recipe being ALSO on the mat is a real slot cost
   (every ingredient has to be displayed at once, same competition a
   collection creates), so it doubles that card's own points. A card with
   no item-kind components (a pure-element MATERIAL) has nothing to
   complete and never qualifies -- without this guard every such card
   would double for free, since "every member of an empty set is present"
   is vacuously true. */
function isComplete(c, mat){
  const need = directItems(c);
  if (!need.size) return false;
  const names = new Set(mat.map(m => m.name));
  return [...need].every(n => names.has(n));
}

function scoreMat(mat){
  const base = mat.reduce((n, c) => n + c.points * (isComplete(c, mat) ? 2 : 1), 0);
  const completeNames = new Set(mat.filter(c => isComplete(c, mat)).map(c => c.name));
  const g = groupsOf(mat);
  const combos = {
    station: allGroups(g.st),
    suit: allGroups(g.su),
    component: allGroups(g.cp),
  };
  const comboBonus = [...combos.station, ...combos.suit, ...combos.component]
    .reduce((n, grp) => n + grp.bonus, 0);
  const cols = completedIn(mat);
  const colBonus = cols.reduce((n, c) => n + c.bonus, 0);
  const mult = 1 + comboBonus;
  return { base, combos, completeNames, cols, colBonus, mult, total: (base + colBonus) * mult };
}

/* Par: the best mat a solver can build from the current collection.
   Greedy by points, then random restarts with hill-climbing -- good
   enough to be a fair benchmark, and deliberately not perfect, so a
   thoughtful arrangement can beat it. */
function parMat(inv, iters = 2500){
  const sorted = inv.slice().sort((a, b) => b.points - a.points);
  const fill = seed => {
    const mat = seed.slice();
    for (const c of sorted){
      if (mat.includes(c)) continue;
      mat.push(c);
      if (!fits(mat)) mat.pop();
    }
    return mat;
  };
  let best = fill([]), bestScore = scoreMat(best).total;
  let seedRng = 20260905;
  const rnd = () => (seedRng = (seedRng * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  for (let i = 0; i < iters; i++){
    const cand = best.slice();
    if (cand.length && rnd() < 0.6) cand.splice(Math.floor(rnd() * cand.length), 1);
    const pool = inv.filter(c => !cand.includes(c));
    for (let j = pool.length - 1; j > 0; j--){
      const k = Math.floor(rnd() * (j + 1));
      [pool[j], pool[k]] = [pool[k], pool[j]];
    }
    for (const c of pool){
      cand.push(c);
      if (!fits(cand)) cand.pop();
    }
    const s = scoreMat(cand).total;
    if (s > bestScore){ bestScore = s; best = cand; }
  }
  return { mat: best, score: bestScore };
}

const diceFor = (score, par) => {
  // No craftable mat at all (the opening station) means par is trivially
  // met, so it pays the full roll rather than the bare minimum -- early
  // rounds are meant to hand out the maximum for free.
  if (par <= 0) return BASE_DICE + DICE_TIERS[0].dice;
  const pct = score / par;
  for (const t of DICE_TIERS) if (pct >= t.pct) return BASE_DICE + t.dice;
  return BASE_DICE;
};

///////////////////////////////////////////////////////////////////////
// State
///////////////////////////////////////////////////////////////////////

const SAVE_KEY = "elementia_mat_v2";
let state = null;

/* Inventory filtering is view state, not run state -- deliberately not
   saved, so a reloaded run never opens onto a hidden collection. */
let filt = { stations: new Set(), suits: new Set(), q: "", sort: "points" };

function newRun(){
  state = {
    v: 2, version: CONTENT_VERSION,
    round: 1,
    mat: [],              // item names, in display order
    unlocked: [],         // collection ids ever completed
    history: [],
    dice: 0,
    over: false,
  };
  autoFill();
  save();
}

// Everything crafted up to and including this round.
function inventoryNames(round){
  const out = [];
  for (let i = 0; i < round && i < RECORDED_RUN.length; i++){
    out.push(...RECORDED_RUN[i].crafted);
  }
  return out.filter(n => BY[n]);
}
const inventory = () => inventoryNames(state.round).map(n => BY[n]);
const matCards = () => state.mat.map(n => BY[n]).filter(Boolean);

/* While the collection is smaller than the mat there is no arrangement
   decision to make -- every card you own goes down. Doing that by hand
   for the first several rounds is busywork, so the mat fills itself
   until the collection outgrows it and choosing starts to mean something. */
function autoFill(){
  const inv = inventory();
  if (!fits(inv)) return false;
  state.mat = inv.map(c => c.name);
  return true;
}

function save(){ try { localStorage.setItem(SAVE_KEY, JSON.stringify(state)); } catch(e){} }
function load(){
  try {
    const s = JSON.parse(localStorage.getItem(SAVE_KEY) || "null");
    if (!s || s.v !== 2 || s.version !== CONTENT_VERSION) return false;
    state = s; return true;
  } catch(e){ return false; }
}

///////////////////////////////////////////////////////////////////////
// Actions
///////////////////////////////////////////////////////////////////////

function toggleCard(name){
  if (state.over) return;
  const i = state.mat.indexOf(name);
  if (i !== -1){ state.mat.splice(i, 1); render(); save(); return; }
  const card = BY[name];
  if (!fits(matCards().concat([card]))){
    toast(isCapstone(card) ? "A capstone needs two free slots." : "The mat is full.", "bad");
    return;
  }
  state.mat.push(name);
  render(); save();
}

function autoArrange(){
  if (state.over) return;
  const { mat } = parMat(inventory());
  state.mat = mat.map(c => c.name);
  toast("Filled with the solver's best mat — try to beat it by hand.");
  render(); save();
}

function clearMat(){ state.mat = []; render(); save(); }

function travel(){
  if (state.over) return;
  const mat = matCards();
  const s = scoreMat(mat);
  const par = parMat(inventory()).score;
  const dice = diceFor(s.total, par);
  const fresh = s.cols.filter(c => !state.unlocked.includes(c.id));
  fresh.forEach(c => state.unlocked.push(c.id));
  state.dice += dice;
  state.history.push({
    round: state.round,
    station: RECORDED_RUN[state.round - 1].station,
    next: state.round < RECORDED_RUN.length ? RECORDED_RUN[state.round].station : null,
    base: s.base, mult: s.mult, total: s.total, par, dice,
    cards: mat.length, cols: s.cols.map(c => c.name), fresh: fresh.map(c => c.name),
  });
  showResult(s, par, dice, fresh);
  save();
}

function nextRound(){
  closeModal();
  if (state.round >= RECORDED_RUN.length){ state.over = true; showSummary(); render(); return; }
  state.round++;
  // Cards stay where they are, unless the whole collection still fits --
  // in which case this round's new crafts drop straight onto the mat.
  autoFill();
  render(); save();
}

///////////////////////////////////////////////////////////////////////
// Card rendering
///////////////////////////////////////////////////////////////////////

/* Which stations, suits and components are actually paying out right
   now -- a Set per kind rather than one name, since multiple groups of
   the same kind can now stack at once (see allGroups()). Every card that
   feeds any of them lights that icon up -- on the mat, so you can see
   what the multiplier is made of, and in the collection, where it reads
   instead as "this card would join it". Recomputed from the mat on every
   draw; a drag only re-orders, so the groups hold. */
let live = { station: new Set(), suit: new Set(), component: new Set() };

function setLive(mat){
  const c = scoreMat(mat).combos;
  live = {
    station:   new Set(c.station.map(g => g.name)),
    suit:      new Set(c.suit.map(g => g.name)),
    component: new Set(c.component.map(g => g.name)),
  };
}

/* The direct recipe, drawn as the component items' own art joined by
   "+". Materials are made of raw elements rather than items, so those
   render as suit-coloured symbol chips instead. */
function componentsHTML(c){
  if (!c.components.length) return `<span class="m-comp"></span>`;
  const parts = c.components.map(x => {
    const lit = live.component.has(x.name) ? " lit" : "";
    return x.kind === "item"
      ? `<span class="cmp${lit}" title="${esc(x.name)}">${BY[x.name] ? em(BY[x.name].emoji) : esc(x.name)}</span>`
      : `<span class="cmp el${lit}" style="--el:${ELEMENT_COLOR[x.name] || "#7b8598"}" title="${
           esc(ELEMENT_NAMES[x.name] || x.name)}">${esc(x.name)}</span>`;
  });
  // The count drives the icon size in CSS -- a five-part recipe has to
  // step down to stay inside a single-width card.
  return `<span class="m-comp" data-n="${parts.length}">${parts.join(`<i class="cplus">+</i>`)}</span>`;
}

function cardHTML(c, opts = {}){
  const on = state.mat.includes(c.name);
  // opts.complete is only ever passed for a card actually on the mat
  // (see renderMat()) -- a collection-view card keeps showing its plain
  // printed value, since it is not currently scoring at all.
  const cls = ["mcard", on ? "on" : "", isCapstone(c) ? "cap" : "",
               c.pips.length ? "" : "nosuit", opts.complete ? "complete" : "", opts.cls || ""].join(" ");
  // A free card shows no pip at all -- at 24px a placeholder is louder
  // than the thing it stands in for, and the dashed border already says it.
  const pips = c.pips.map(s =>
    `<span class="mpip${live.suit.has(s) ? " lit" : ""}" style="--suit:${SUIT_COLOR[s]}">${
      suitArt(s)}</span>`).join("");
  const st = STATION_META[c.station] || {};
  const stLit = live.station.has(c.station) ? " lit" : "";
  // Doubled in the badge itself when complete -- the number there is
  // "what this card is worth right now," which genuinely differs from
  // its printed value while every direct ingredient sits beside it, and
  // showing the plain printed number would just read as a math error
  // against the score band's own total.
  const pts = opts.complete ? c.points * 2 : c.points;
  // Station is a corner badge now (bottom-right), matching the pips/points
  // badges in the other three corners, rather than sharing a bottom row
  // with the recipe -- freeing that row up is what lets name+recipe rise
  // into the middle of the card as their own centered block (see .mcard's
  // own justify-content:center).
  return `<button type="button" class="${cls}" data-card="${esc(c.name)}"
      title="${esc(c.name)} — ${c.points} pts${opts.complete ? " (doubled to " + pts + " -- every ingredient is on the mat)" : ""}, ${esc(c.station)}">
    <span class="m-cost">${pips}</span>
    <span class="m-pts">${pts}</span>
    <span class="m-art">${em(c.emoji)}</span>
    <span class="m-name">${esc(c.name)}</span>
    ${componentsHTML(c)}
    <span class="m-station${stLit}" style="--st:${c.stationColor}" title="${esc(c.station)}">${em(st.emoji)}</span>
  </button>`;
}

///////////////////////////////////////////////////////////////////////
// Score band
///////////////////////////////////////////////////////////////////////

/* Bonuses read as icons rather than words: the station's own art, the
   suit's own art, the shared component's own art. The count and the
   bonus are the only numbers, so three live combos still fit one line. */
function comboChip(g, kind){
  const st = STATION_META[g.name] || {};
  const icon =
    kind === "station" ? `<span class="cico st" style="--st:${st.color}">${em(st.emoji)}</span>`
    : kind === "suit"  ? `<span class="cico su" style="--suit:${SUIT_COLOR[g.name]}">${suitArt(g.name)}</span>`
    : `<span class="cico cp">${BY[g.name] ? em(BY[g.name].emoji) : esc(g.name)}</span>`;
  const label = kind === "suit" ? (ELEMENT_SUIT_LABEL[g.name] || g.name) : g.name;
  // Every group reaching this function already cleared comboTier() (see
  // allGroups()'s own filter), so it is always "lit" -- no longer a
  // conditional case the way a single best-of-category could come back
  // empty.
  return `<span class="combo lit" title="${esc(label)} ×${g.k}">
    ${icon}<b>${g.k}</b><i>+${g.bonus}</i></span>`;
}

///////////////////////////////////////////////////////////////////////
// Inventory filters
///////////////////////////////////////////////////////////////////////

function buildFilterBar(){
  $("fStations").innerHTML = STATIONS.map(s => {
    const m = STATION_META[s];
    return `<button type="button" class="fbtn" data-fstation="${esc(s)}" title="${esc(s)}"
        style="--st:${m.color}">${em(m.emoji)}</button>`;
  }).join("");
  $("fSuits").innerHTML = SUIT_ORDER.map(s =>
    `<button type="button" class="fbtn suit" data-fsuit="${s}" title="${ELEMENT_SUIT_LABEL[s]}"
        style="--st:${SUIT_COLOR[s]}">${suitArt(s)}</button>`).join("");
}

const suitRank = c => c.pips.length
  ? Math.min(...c.pips.map(p => SUIT_ORDER.indexOf(p))) : 99;

const SORTS = {
  points:  (a, b) => b.points - a.points || a.name.localeCompare(b.name),
  name:    (a, b) => a.name.localeCompare(b.name),
  station: (a, b) => a.station.localeCompare(b.station) || b.points - a.points,
  suit:    (a, b) => suitRank(a) - suitRank(b) || b.points - a.points,
};

function visibleInventory(){
  let list = inventory();
  if (filt.stations.size) list = list.filter(c => filt.stations.has(c.station));
  if (filt.suits.size)    list = list.filter(c => c.pips.some(p => filt.suits.has(p)));
  if (filt.q){
    const q = filt.q.toLowerCase();
    list = list.filter(c => c.name.toLowerCase().includes(q));
  }
  return list.sort(SORTS[filt.sort] || SORTS.points);
}

function syncFilterBar(){
  document.querySelectorAll("[data-fstation]").forEach(b =>
    b.classList.toggle("on", filt.stations.has(b.dataset.fstation)));
  document.querySelectorAll("[data-fsuit]").forEach(b =>
    b.classList.toggle("on", filt.suits.has(b.dataset.fsuit)));
}

///////////////////////////////////////////////////////////////////////
// Render
///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////
// Fit to window
///////////////////////////////////////////////////////////////////////

/* The layout is authored once, at 414 x 875, and then scaled as a whole
   to whatever window it is in. That is the entire resize story: one
   number changes, every proportion holds. Anything that sized itself
   from the viewport instead would let width and height move
   independently and the design would stretch between them. */
const CANVAS_W = 414, CANVAS_H = 875;
const CANVAS_MARGIN = 8;      // so the phone never bleeds off the edges
let FIT = 1;

function fitToWindow(){
  const el = document.documentElement;
  // clientWidth/Height, not innerWidth/Height: the inner* pair includes
  // the scrollbar, which would over-report the room available and let
  // the phone hang off the edge.
  const w = el.clientWidth - CANVAS_MARGIN, h = el.clientHeight - CANVAS_MARGIN;
  FIT = Math.max(0.05, Math.min(w / CANVAS_W, h / CANVAS_H));
  el.style.setProperty("--fit", FIT);
}

/* A ResizeObserver rather than just the resize event. The event does not
   fire for every way the viewport can change size -- devtools docking,
   zoom, and an embedded preview pane being re-laid out among them -- and
   a missed one leaves the phone scaled for the previous window, hanging
   off the bottom. Observing the root element catches all of them.
   Scaling is a transform, so it cannot change the root's own box and
   feed back into the observer. */
new ResizeObserver(fitToWindow).observe(document.documentElement);
addEventListener("resize", fitToWindow);
if (window.visualViewport) visualViewport.addEventListener("resize", fitToWindow);
fitToWindow();

const openingLabel = rec => `Begin at ${rec ? rec.station : "the first station"}`;

/* Drawn on its own so a drag can re-flow the mat without rebuilding the
   inventory underneath it. */
function renderMat(){
  const mat = matCards();
  // Set before any card is drawn, so the mat and the collection below it
  // are lit from the same reading of what is currently scoring.
  setLive(mat);
  const completeNames = scoreMat(mat).completeNames;
  const cells = packCells(mat);
  const html = cells.map(cell => cell.card
    ? `<div class="slot filled ${cell.w > 1 ? "wide" : ""}" data-idx="${cell.idx}">${
        cardHTML(cell.card, { complete: completeNames.has(cell.card.name) })}</div>`
    : `<div class="slot empty"></div>`);
  for (let n = cells.reduce((a, c) => a + c.w, 0); n < SLOTS; n++){
    html.push(`<div class="slot empty"></div>`);
  }
  $("mat").innerHTML = html.join("");
  $("slotsUsed").textContent = `${occupancy(mat)}/${SLOTS}`;
}

function render(){
  const inv = inventory();
  const mat = matCards();
  const s = scoreMat(mat);
  const rec = RECORDED_RUN[state.round - 1];

  $("roundNo").textContent = `${state.round} / ${RECORDED_RUN.length}`;
  $("stationTag").textContent = rec ? rec.station : "";
  $("diceChip").innerHTML = `<b>${state.dice}</b><span>dice</span>`;
  $("invCount").textContent = inv.length;

  renderMat();

  $("base").textContent = s.base;
  $("colBonus").hidden = !s.colBonus;
  $("colBonus").textContent = `+${s.colBonus}`;
  $("mult").textContent = "×" + s.mult;
  $("total").textContent = s.total.toLocaleString();

  // One chip per QUALIFYING group now, not one slot per category -- two
  // different suit groups (or a station group alongside a component
  // group) each get their own chip and both add to the line.
  const chips =
    s.combos.station.map(g => comboChip(g, "station")).join("") +
    s.combos.suit.map(g => comboChip(g, "suit")).join("") +
    s.combos.component.map(g => comboChip(g, "component")).join("") +
    s.cols.map(c => `<span class="combo col ${state.unlocked.includes(c.id) ? "" : "new"}"
        title="${esc(c.hint)}"><span class="cico star">★</span><b>${esc(c.name)}</b><i>+${c.bonus}</i></span>`).join("");
  $("combos").innerHTML = chips || `<span class="combo-none">Three cards alike start a combo</span>`;

  const vis = visibleInventory();
  $("invShown").textContent = vis.length === inv.length ? "tap to add or remove" : `${vis.length} shown`;
  /* The recorded run crafts nothing in round 1 -- that round IS the
     opening station, where you shop but do not yet own a card. Say so,
     or eight empty slots and a "Travel" button read as a broken game
     rather than as the start of one. */
  $("inv").innerHTML = vis.length
    ? vis.map(c => cardHTML(c, { cls: "small" })).join("")
    : inv.length
      ? `<p class="inv-empty">Nothing matches those filters.</p>`
      : `<p class="inv-empty">You are at <b>${esc(rec ? rec.station : "the first station")}</b> with
           nothing crafted yet, so there is no mat to arrange. Press
           <b>${esc(openingLabel(rec))}</b> to shop here — your first cards land next round.</p>`;
  syncFilterBar();

  $("travelBtn").disabled = state.over;
  $("travelBtn").textContent = state.round >= RECORDED_RUN.length ? "Score final mat"
    : inv.length === 0 ? `${openingLabel(rec)} ▸`
    : `Travel to ${RECORDED_RUN[state.round] ? RECORDED_RUN[state.round].station : "…"} ▸`;
}

///////////////////////////////////////////////////////////////////////
// Drag to re-arrange
///////////////////////////////////////////////////////////////////////

/* Pointer-driven rather than HTML5 drag-and-drop: the mat re-renders on
   every hover change so the other cards visibly shuffle aside, and a
   native drag does not survive its own source element being replaced.
   A pointerdown that never moves is a tap, and takes the card off. */
let drag = null;

function slotUnder(x, y){
  for (const el of document.elementsFromPoint(x, y)){
    const slot = el.closest && el.closest(".slot");
    if (slot && slot.parentElement === $("mat")) return slot;
  }
  return null;
}

$("mat").addEventListener("pointerdown", e => {
  if (state.over || e.button) return;
  const slot = e.target.closest(".slot.filled");
  if (!slot) return;
  e.preventDefault();
  const r = slot.getBoundingClientRect();
  drag = {
    idx: +slot.dataset.idx,
    name: slot.querySelector("[data-card]").dataset.card,
    x0: e.clientX, y0: e.clientY,
    w: r.width, h: r.height,
    dx: e.clientX - r.left, dy: e.clientY - r.top,
    live: false,
  };
});

document.addEventListener("pointermove", e => {
  if (!drag) return;
  if (!drag.live){
    if (Math.hypot(e.clientX - drag.x0, e.clientY - drag.y0) < 6) return;
    drag.live = true;
    const g = $("ghost");
    // The ghost sits outside .phone, so it is not scaled by --fit. Give
    // it the card's UNSCALED size and scale it itself, or its innards
    // (which are all fixed px) would lay out at the wrong size.
    g.style.width = (drag.w / FIT) + "px";
    g.style.height = (drag.h / FIT) + "px";
    g.style.transform = `scale(${FIT}) rotate(-3deg)`;
    g.innerHTML = cardHTML(BY[drag.name]);
    g.hidden = false;
    $("mat").classList.add("dragging");
  }
  const g = $("ghost");
  g.style.left = (e.clientX - drag.dx) + "px";
  g.style.top  = (e.clientY - drag.dy) + "px";

  const slot = slotUnder(e.clientX, e.clientY);
  if (!slot) return;
  // An empty cell means "put it last"; a filled one means "take that place".
  const to = slot.dataset.idx !== undefined ? +slot.dataset.idx : state.mat.length - 1;
  if (to === drag.idx) return;
  const [n] = state.mat.splice(drag.idx, 1);
  state.mat.splice(to, 0, n);
  // Moving a capstone can force a row pad that a full mat has no room
  // for; refuse that placement rather than growing a third row.
  if (!fits(matCards())){
    state.mat.splice(to, 1);
    state.mat.splice(drag.idx, 0, n);
    return;
  }
  drag.idx = to;
  renderMat();
});

document.addEventListener("pointerup", () => {
  if (!drag) return;
  const was = drag;
  drag = null;
  $("ghost").hidden = true;
  $("ghost").innerHTML = "";
  $("mat").classList.remove("dragging");
  if (was.live){ render(); save(); }
  else toggleCard(was.name);
});

///////////////////////////////////////////////////////////////////////
// Modals
///////////////////////////////////////////////////////////////////////

function openModal(title, body, foot){
  $("modalTitle").textContent = title;
  $("modalBody").innerHTML = body;
  $("modalFoot").innerHTML = foot || `<button type="button" class="btn primary" data-act="close">Close</button>`;
  $("veil").hidden = false;
}
const closeModal = () => { $("veil").hidden = true; };

function showResult(s, par, dice, fresh){
  const rec = RECORDED_RUN[state.round - 1];
  const pct = par > 0 ? Math.round(100 * s.total / par) : 100;
  const next = (RECORDED_RUN[state.round] || {}).station || "the end";
  openModal(`Round ${state.round} — ${rec.station}`,
    `<table>
       <tr><td>Cards displayed</td><td class="num">${s.base}</td></tr>
       ${s.colBonus ? `<tr><td>Collections: ${s.cols.map(c => esc(c.name)).join(", ")}</td>
          <td class="num">${s.colBonus}</td></tr>` : ""}
       <tr><td>Combo multiplier</td><td class="num">×${s.mult}</td></tr>
       <tr><th>Mat score</th><th class="num">${s.total.toLocaleString()}</th></tr>
       <tr><td>Best possible this round</td><td class="num">${par.toLocaleString()}</td></tr>
       <tr><th>You reached</th><th class="num">${pct}% of par</th></tr>
     </table>
     ${fresh.length ? `<h4>New collections unlocked</h4>
       <p>${fresh.map(n => `<b>${esc(n)}</b>`).join(", ")}</p>` : ""}
     <h4>Dice at ${esc(next)}</h4>
     <p><b>${dice}</b> dice — ${BASE_DICE} base${dice > BASE_DICE ? ` + ${dice - BASE_DICE} earned` : ", nothing earned"}.</p>`,
    `<button type="button" class="btn primary" data-act="next">${
      state.round >= RECORDED_RUN.length ? "Run summary ▸" : "Continue ▸"}</button>`);
}

function showSummary(){
  const h = state.history;
  const rows = h.map(x => `<tr><td>${x.round}</td><td>${esc(x.station)}</td>
    <td class="num">${x.cards}</td><td class="num">${x.base}</td><td class="num">×${x.mult}</td>
    <td class="num"><b>${x.total.toLocaleString()}</b></td>
    <td class="num">${Math.round(100 * x.total / Math.max(1, x.par))}%</td>
    <td class="num">${x.dice}</td></tr>`).join("");
  openModal("Run summary",
    `<table>
      <tr><th>#</th><th>Station</th><th class="num">Cards</th><th class="num">Base</th>
          <th class="num">Mult</th><th class="num">Score</th><th class="num">Par</th>
          <th class="num">Dice</th></tr>
      ${rows}
      <tr><th colspan="5">Totals</th>
          <th class="num">${h.reduce((n,x)=>n+x.total,0).toLocaleString()}</th><th></th>
          <th class="num">${state.dice}</th></tr>
     </table>
     <h4>Collections unlocked (${state.unlocked.length} of ${COLLECTIONS.length})</h4>
     <p>${state.unlocked.length
        ? state.unlocked.map(id => esc((COLLECTIONS.find(c => c.id === id) || {}).name || id)).join(", ")
        : "None yet."}</p>`,
    `<button type="button" class="btn primary" data-act="newrun">New run</button>`);
}

function showCollections(){
  /* Ordered by how far along you are, so the near-misses -- the ones
     worth chasing with your next few crafts -- sit at the top. */
  const mat = matCards();
  const owned = new Set(inventory().map(c => c.name));
  const rows = COLLECTIONS.map(c => ({ c, have: c.have(mat), done: c.done(mat) }))
    .sort((a, b) => (b.have / b.c.items.length) - (a.have / a.c.items.length));
  const body = rows.map(({ c, have, done }) => {
    const known = state.unlocked.includes(c.id);
    const items = c.items.map(i => {
      const on = mat.some(m => m.name === i);
      return `<span class="ci ${on ? "on" : owned.has(i) ? "owned" : ""}">${esc(i)}</span>`;
    }).join("");
    return `<div class="crow ${done ? "done" : ""}">
      <div class="crow-head">
        <b>${esc(c.name)}</b>
        <span class="crow-meta">${have}/${c.items.length} on mat · ${c.slots} slots
          · <i>+${c.bonus}</i>${known ? " · unlocked" : ""}</span>
      </div>
      <div class="crow-items">${items}</div>
    </div>`;
  }).join("");
  openModal("Collections",
    `<p>A collection completes when <b>every one of its cards is on your mat</b> at the
      same time. That is what makes it cost something: it competes for slots against
      whatever raw points you would otherwise display.</p>
     <p style="font-size:11px">Bonus is 30% of the set's own points, added before the
      combo multiplier. Eight of these cannot be finished before round 15, and several
      need cards a given run may never craft — which is what makes a run distinct.</p>
     <div class="clist">${body}</div>`);
}

function showRules(){
  openModal("How the mat works",
    `<p>You never buy a card twice. Elements are spent once, in the shop, to craft an
      item — after that the item earns by <b>sitting on your mat</b>.</p>
     <h4>The round</h4>
     <ol>
       <li>Arrange <b>${ROWS} rows of ${COLS}</b> from everything you own. A capstone
         takes <b>${CAPSTONE_SLOTS}</b> cells. Drag cards on the mat to re-order them.</li>
       <li>Travel. The mat scores, and the score buys dice at the next station.</li>
       <li>That station's shop adds new cards, and you re-arrange.</li>
     </ol>
     <h4>Scoring</h4>
     <p><b>(points + collection bonuses) × combo multiplier.</b></p>
     <p>A card's points <b>double</b> when its full direct recipe is also sitting on the
       mat (a gold ring on its points badge marks it) — a real cost, since every
       ingredient has to hold a slot of its own.</p>
     <p>Combos come from cards on the mat sharing a <b>station</b>, a <b>suit</b>, or a
       <b>direct component</b> of their recipe — the icons printed along the bottom of
       each card. Every qualifying group counts, from three up — two different suit
       groups, or a station group alongside a component group, all stack together:</p>
     <table>${COMBO_TIERS.map(t =>
       `<tr><td>${t.k} alike</td><td class="num">+${t.b}</td></tr>`).join("")}</table>
     <h4>Dice</h4>
     <p><b>${BASE_DICE}</b> at every station, plus up to <b>3</b> more for how close your
       mat came to the best one possible from your collection:
       ${DICE_TIERS.map(t => `${Math.round(t.pct*100)}% → +${t.dice}`).join(", ")}.</p>
     <p style="font-size:11px;color:var(--ink-mute)">Content version ${esc(CONTENT_VERSION)}.
       Inventory follows the recorded 20-round run.</p>`);
}

function toast(msg, kind){
  const el = document.createElement("div");
  el.className = "toast " + (kind || "");
  el.textContent = msg;
  $("toasts").appendChild(el);
  while ($("toasts").children.length > 3) $("toasts").firstChild.remove();
  setTimeout(() => el.remove(), 1900);
}

///////////////////////////////////////////////////////////////////////
// Events
///////////////////////////////////////////////////////////////////////

const toggleIn = (set, key) => { set.has(key) ? set.delete(key) : set.add(key); };

document.addEventListener("click", e => {
  const st = e.target.closest("[data-fstation]");
  if (st){ toggleIn(filt.stations, st.dataset.fstation); render(); return; }
  const su = e.target.closest("[data-fsuit]");
  if (su){ toggleIn(filt.suits, su.dataset.fsuit); render(); return; }

  const act = e.target.closest("[data-act]");
  if (act){
    switch (act.dataset.act){
      case "close":   closeModal(); return;
      case "rules":   showRules(); return;
      case "cols":    showCollections(); return;
      case "newrun":  closeModal(); newRun(); render(); return;
      case "next":    nextRound(); return;
      case "travel":  travel(); return;
      case "auto":    autoArrange(); return;
      case "clear":   clearMat(); return;
      case "fclear":
        filt.stations.clear(); filt.suits.clear();
        filt.q = ""; $("fSearch").value = "";
        filt.sort = "points"; $("fSort").value = "points";
        render(); return;
    }
  }
  // Mat cards are handled by the drag layer, so only the collection grid
  // toggles on a plain click.
  const card = e.target.closest(".inv [data-card]");
  if (card){ toggleCard(card.dataset.card); return; }
  if (e.target === $("veil")) closeModal();
});

$("fSearch").addEventListener("input", e => { filt.q = e.target.value.trim(); render(); });
$("fSort").addEventListener("change", e => { filt.sort = e.target.value; render(); });

document.addEventListener("keydown", e => { if (e.key === "Escape") closeModal(); });

///////////////////////////////////////////////////////////////////////
// Boot
///////////////////////////////////////////////////////////////////////

/* The data files are already checked at the top of this file; what is
   left to go wrong here is mat.html being the older copy, missing the
   elements this script now draws into. */
const missingEls = ["mat", "inv", "fStations", "fSuits", "fSearch", "fSort", "combos", "ghost"]
  .filter(id => !$(id));
if (missingEls.length) fatal(`mat.html is out of date — no #${missingEls.join(", #")}`);

buildFilterBar();
if (!load()) newRun();
render();
