/* =====================================================================
   trophies.js -- Trophies: earned when a run completes (turn
   RUN_COMPLETE_VISIT, or crafting everything), kept across runs in their
   own localStorage key (TROPHY_KEY, not the run save), and shown from the
   home screen (#tourTrophiesBtn). Locked trophies show as silhouettes with
   a hint, to point players at new capstones, items and collections.

   Daily and cumulative: each trophy can be earned once per day, and every
   day it's earned again adds to its count ({at: first day, last, n}). The
   first time pays STARS_TROPHY Stars, each repeat STARS_TROPHY_AGAIN.
   Milestones count across completed runs (prefs.lifetime); streaks count
   days played in a row (prefs.playDays, recordPlayDay()).
   ===================================================================== */
const TROPHY_KEY = "elementia-trophies-v1";
const STARS_TROPHY_AGAIN = 1;
const todayKey = () => new Date().toLocaleDateString("en-CA"); // local YYYY-MM-DD

/* ---- what a run's own records say */
const runCaps = st => CAPSTONES.filter(c => st.items.includes(c));
// The turn an item was crafted (1-based), or 0.
const craftTurn = (st, name) => (st.visitLog || []).findIndex(t => t.items.includes(name)) + 1;
const boardChecks = st => (st.checkLog || []).filter(c => !c.final && c.q != null);
const checkTier = c => emptyElementsForScore(c.q, c.v);
const orderKind = c => c.o && CHECK_ORDERS[c.o] ? CHECK_ORDERS[c.o].kind : null;
const finalQ = st => ((st.checkLog || []).find(c => c.final) || {}).q || 0;
// Days in a row ending today (prefs.playDays, sorted ascending).
function playStreak(){
  const days = new Set(prefs.playDays || []);
  let n = 0;
  for (let d = new Date(); days.has(d.toLocaleDateString("en-CA")); d.setDate(d.getDate() - 1)) n++;
  return n;
}
const STATION_SHOP = Object.fromEntries(DATA.stations.map(s => [s.name, s.shop.map(r => r[1])]));
const WAY_OUT_THERE = ["Planet", "Solar System", "University", "Library", "Trumpet"];

/* Each: id, icon (emoji or __MARKER__, drawn with em()), name, hint (shown
   while locked), test(state) -> earned on this completed run. The
   collection trophies count discoveries across runs
   (prefs.everUnlockedMatCollections); milestones use prefs.lifetime. */
const TROPHIES = [
  { id:"first-run", icon:"🏁", name:"First Run", hint:"Complete a run (reach turn 24)", test:() => true },
  // ---- capstones
  ...CAPSTONES.map(cap => ({
    id: "cap-" + cap.toLowerCase().replace(/[^a-z]+/g, "-"),
    icon: ITEM_EMOJI[cap], name: `${cap} Run`,
    hint: `Complete a run that crafts the ${cap}`,
    test: st => st.items.includes(cap),
  })),
  { id:"caps-2", icon:"🥈", name:"Double Feature", hint:"Craft 2 capstones in one run", test:st => runCaps(st).length >= 2 },
  { id:"caps-3", icon:"🥇", name:"Triple Crown", hint:"Craft 3 capstones in one run", test:st => runCaps(st).length >= 3 },
  { id:"cap-early", icon:"⚡", name:"Early Riser", hint:"Craft a capstone by turn 15", test:st => runCaps(st).some(c => craftTurn(st, c) <= 15) },
  { id:"caps-all", icon:"👑", name:"Grand Collection", hint:"Craft all 8 capstones (across runs)", test:() => (prefs.lifetime?.caps || []).length >= CAPSTONES.length },
  // ---- items
  { id:"items-40", icon:"🧰", name:"Busy Builder", hint:"Craft 40 items in one run", test:st => st.items.length >= 40 },
  { id:"items-50", icon:"🏗️", name:"Master Builder", hint:"Craft 50 items in one run", test:st => st.items.length >= 50 },
  { id:"items-all", icon:"🌍", name:"Every Item", hint:"Craft every item in one run", test:st => !!st.craftedEverything },
  ...DATA.stations.map(s => ({
    id: "station-" + s.name.toLowerCase().replace(/^the /, "").replace(/[^a-z]+/g, "-"),
    icon: s.emoji, name: `${s.name.replace(/^The /, "")} Complete`,
    hint: `Craft every item in the ${s.name} shop in one run`,
    test: st => STATION_SHOP[s.name].every(n => st.items.includes(n)),
  })),
  { id:"unlocked", icon:"🔓", name:"Unlocked!", hint:"Craft an item a capstone unlocks", test:st => st.items.some(n => UNLOCKED_BY[n]) },
  { id:"way-out", icon:"🪐", name:"Way Out There", hint:"Craft Planet, Solar System, University, Library or Trumpet", test:st => WAY_OUT_THERE.some(n => st.items.includes(n)) },
  // ---- Quarks and breakpoints
  ...[1000, 2500, 4000].map((q, i) => ({
    id: "quarks-" + q, icon: ["⚛️", "💫", "🌟"][i], name: `${q.toLocaleString()} Quarks`,
    hint: `Lock In a Display Mat worth ${q.toLocaleString()} Quarks`,
    test: st => (st.bestMatScore || 0) >= q,
  })),
  { id:"grand", icon:"🏛️", name:"Grand Exhibition", hint:`Reach ${GRAND_EXHIBITION_TARGET.toLocaleString()} Quarks at the final check`, test:st => finalQ(st) >= GRAND_EXHIBITION_TARGET },
  { id:"grand-gala", icon:"🎆", name:"Grand Gala", hint:"Reach 6,000 Quarks at the final check", test:st => finalQ(st) >= 6000 },
  { id:"top-shelf", icon:"❓", name:"Top Shelf", hint:'Reach the top breakpoint at a board check (its "?")', test:st => boardChecks(st).some(c => checkTier(c) >= 4) },
  { id:"never-zero", icon:"🎲", name:"Never Zero", hint:"Earn at least 1 bonus die at every board check", test:st => boardChecks(st).length >= 7 && boardChecks(st).every(c => checkTier(c) >= 1) },
  { id:"steady", icon:"🎯", name:"Steady Hand", hint:"Earn 2+ bonus dice at every board check", test:st => boardChecks(st).length >= 7 && boardChecks(st).every(c => checkTier(c) >= 2) },
  // ---- challenges
  { id:"request", icon:"📜", name:"By Request", hint:"Meet a Display Mat request", test:st => boardChecks(st).some(c => orderKind(c) === "request" && c.ok) },
  { id:"requests-all", icon:"🧾", name:"Every Request", hint:"Meet the requests at turns 3, 6 and 9", test:st => [3, 6, 9].every(v => boardChecks(st).some(c => c.v === v && orderKind(c) === "request" && c.ok)) },
  { id:"rule-keeper", icon:"⚖️", name:"Rule Keeper", hint:"Keep every restriction in a run (turns 12-21)", test:st => { const r = boardChecks(st).filter(c => orderKind(c) === "restriction"); return r.length >= 4 && r.every(c => c.ok); } },
  { id:"short-table", icon:"🪑", name:"Short Table", hint:"Keep the Short Table restriction", test:st => boardChecks(st).some(c => c.o === "shortTable" && c.ok) },
  // ---- the Display Mat (state.matFeats, noted at every Lock-In)
  ...[["full", "🖼️", "Full House", "Fill the whole 4×2 Display Mat"], ["combo5", "✖️", "Big Combo", "Reach a ×5 combo multiplier"],
      ["recipe", "🧩", "Full Recipe", "Lock In a card with its whole recipe on the mat"], ["suits4", "🌈", "Four Suits", "Lock In all four suits on the mat"],
      ["metro10", "🌆", "Metropolis Mat", "Fill all 10 slots of a Metropolis mat"], ["freight9", "🚄", "Freight Line", "Lock In Maglev Train with 9+ tier 1 cards"],
      ["layered", "🎂", "Layered", "Lock In Fruit Cake with its ×2 active"]].map(([f, icon, name, hint]) => ({
    id: "mat-" + f, icon, name, hint, test: st => (st.matFeats || []).includes(f),
  })),
  ...[[5, "🔍", "Collector"], [20, "🗂️", "Curator"], [0, "🏛️", "Every Collection"]].map(([n, icon, name]) => ({
    id: n ? "collections-" + n : "collections-all", icon, name,
    hint: n ? `Discover ${n} collections on your Display Mat (across runs)` : "Discover every collection (across runs)",
    test: () => prefs.everUnlockedMatCollections.length >= (n || MAT_COLLECTIONS.length),
  })),
  // ---- the map, the Market, elements
  { id:"explorer", icon:"🧭", name:"Explorer", hint:"Visit all 8 stations by turn 8", test:st => new Set((st.visitLog || []).slice(0, 8).map(t => t.station)).size >= 8 },
  { id:"heli", icon:"🚁", name:"Fast Travel", hint:"Fly the Helicopter to a station off your path", test:st => (st.heliTrips || 0) >= 1 },
  { id:"regular", icon:"🏠", name:"Regular", hint:"Visit one station 6 times in a run", test:st => { const n = {}; (st.visitLog || []).forEach(t => n[t.station] = (n[t.station] || 0) + 1); return Object.values(n).some(x => x >= 6); } },
  { id:"bingo-1", icon:"🎯", name:"Market Row", hint:"Complete a Market row", test:st => (st.bingoLinesCompleted || []).length >= 1 },
  { id:"bingo-3", icon:"🎰", name:"Market Sweep", hint:"Complete all 3 Market rows in one run", test:st => (st.bingoLinesCompleted || []).length >= 3 },
  { id:"waste-not", icon:"♻️", name:"Waste Not", hint:"Finish a run with no elements left over", test:st => !Object.values(st.elements || {}).some(n => n > 0) },
  { id:"alchemist", icon:"⚗️", name:"Alchemist", hint:"Convert elements 10 times in one run", test:st => (st.converts || 0) >= 10 },
  { id:"unknowns", icon:"🔮", name:"Into the Unknown", hint:'Spend 5 "?" elements in one run', test:st => (st.qSpent || 0) >= 5 },
  // ---- milestones (across completed runs) and streaks (days in a row)
  ...[[5, "🎮", "Regular Player"], [25, "🕹️", "Devoted"], [100, "💯", "Centurion"]].map(([n, icon, name]) => ({
    id: "runs-" + n, icon, name, hint: `Complete ${n} runs`, test: () => (prefs.lifetime?.runs || 0) >= n })),
  ...[[500, "📦", "Stockpile"], [2000, "🏭", "Factory"]].map(([n, icon, name]) => ({
    id: "crafted-" + n, icon, name, hint: `Craft ${n.toLocaleString()} items in total`, test: () => (prefs.lifetime?.items || 0) >= n })),
  { id:"capstones-10", icon:"🏆", name:"Capstone Veteran", hint:"Craft 10 capstones in total", test:() => (prefs.lifetime?.capCount || 0) >= 10 },
  ...[[3, "📅", "Three in a Row"], [7, "🗓️", "Week Streak"], [30, "🔥", "Month Streak"]].map(([n, icon, name]) => ({
    id: "streak-" + n, icon, name, hint: `Play ${n} days in a row`, test: () => playStreak() >= n })),
  { id:"ot-30", icon:"⏱️", name:"Overtime", hint:"Reach visit 30 in Overtime", test:st => st.visits >= 30 },
  { id:"ot-36", icon:"🔥", name:"Iron Will", hint:"Reach visit 36 in Overtime", test:st => st.visits >= 36 },
];

/* Mat feats for the Display Mat trophies, noted at every Lock-In
   (finishLockIn(), finishFinalCheck()) into state.matFeats. */
function noteMatFeats(){
  const mat = matOnMat(), s = matScore(mat), feats = new Set(state.matFeats || []);
  const full = matStage() === MAT_GROW_ROUNDS.length && !matHasEmptySlot(mat);
  if (full) feats.add("full");
  if (s.mult >= 5) feats.add("combo5");
  if (mat.some(c => matIsComplete(c, mat))) feats.add("recipe");
  if (Object.keys(ELEMENT_SUIT_LABEL).every(su => mat.some(c => c.pips.includes(su)))) feats.add("suits4");
  if (full && matHas(mat, "Metropolis")) feats.add("metro10");
  if (matHas(mat, "Maglev Train") && mat.filter(matIsTier1).length >= 9) feats.add("freight9");
  if (s.layered) feats.add("layered");
  state.matFeats = [...feats];
}
// A day played (any turn, not in a dev run): for the streak trophies.
function recordPlayDay(){
  if (state.dev) return;
  const d = todayKey(), days = prefs.playDays || (prefs.playDays = []);
  if (days[days.length - 1] === d) return;
  days.push(d);
  if (days.length > 60) days.splice(0, days.length - 60);
  savePrefs();
}

function loadTrophies(){
  try { return JSON.parse(lsGet(TROPHY_KEY) || "{}") || {}; } catch(e){ return {}; }
}
/* Awards every trophy this run qualifies for that wasn't already earned
   today; returns them (each with .again when it's a repeat). Only for a
   completed run (turn 24 or crafted everything), never a dev run. The run
   counts toward the milestones once (state.lifetimeCounted). */
function awardTrophies(){
  if (state.dev || (!state.runComplete && !state.craftedEverything)) return [];
  if (!state.lifetimeCounted){
    const L = prefs.lifetime || (prefs.lifetime = { runs: 0, items: 0, capCount: 0, caps: [] });
    L.runs++; L.items += state.items.length;
    runCaps(state).forEach(c => { L.capCount++; if (!L.caps.includes(c)) L.caps.push(c); });
    state.lifetimeCounted = true;
    savePrefs(); save();
  }
  const got = loadTrophies(), day = todayKey();
  const fresh = TROPHIES.filter(t => (!got[t.id] || (got[t.id].last || got[t.id].at) !== day) && t.test(state));
  if (!fresh.length) return [];
  let stars = 0;
  const won = fresh.map(t => {
    const g = got[t.id];
    if (g){ g.n = (g.n || 1) + 1; g.last = day; stars += STARS_TROPHY_AGAIN; return { ...t, again: g.n }; }
    got[t.id] = { at: day, last: day, n: 1 }; stars += STARS_TROPHY;
    return t;
  });
  lsSet(TROPHY_KEY, JSON.stringify(got));
  grantStars(stars);
  return won;
}
function trophyTileHTML(t, earned){
  return `<div class="trophy${earned ? " earned" : ""}" title="${esc(earned ? t.name : t.hint)}">
    <span class="trophy-ic">${em(t.icon)}</span>
    <span class="trophy-name">${earned ? esc(t.name) : "???"}${t.again ? ` ×${t.again}` : ""}</span>
    <span class="trophy-sub">${earned ? `Earned ${esc(earned.at)}` : esc(t.hint)}</span>
  </div>`;
}
/* The Trophies window: icons only, tap one for its detail. */
function trophyMiniHTML(t, earned){
  const n = earned ? earned.n || 1 : 0;
  return `<button type="button" class="trophy-mini${earned ? " earned" : ""}" data-trophy="${esc(t.id)}" aria-label="${esc(earned ? t.name : "Locked trophy")}"><span class="tm-ic">${em(t.icon)}</span>${n > 1 ? `<span class="tm-n">×${n}</span>` : ""}</button>`;
}
function openTrophyDetail(id){
  const t = TROPHIES.find(x => x.id === id);
  if (!t) return;
  const earned = loadTrophies()[id];
  document.getElementById("trophyDetailBody").innerHTML = `
    <div class="trophy-detail-ic${earned ? "" : " locked"}"><span class="tm-ic">${em(t.icon)}</span></div>
    <h2 id="trophyDetailName">${earned ? esc(t.name) : "Locked"}</h2>
    <p>${esc(t.hint)}</p>
    <p class="trophy-detail-at">${!earned ? "Not earned yet"
      : (earned.n || 1) > 1 ? `Earned ${earned.n} times · first ${esc(earned.at)} · latest ${esc(earned.last)}` : `Earned ${esc(earned.at)}`}</p>
    <div class="btnrow" style="justify-content:center"><button type="button" class="bigbtn" data-trophy-ok>OK</button></div>`;
  openOverlay("trophyDetail");
}
/* The end screen's "New trophies" strip (showEndGame()). */
function openTrophies(){
  const got = loadTrophies();
  document.getElementById("trophiesCount").textContent =
    `${TROPHIES.filter(t => got[t.id]).length} of ${TROPHIES.length} earned -- each can be earned again once a day. Tap one to see how.`;
  document.getElementById("trophiesList").innerHTML =
    `<div class="trophy-mini-grid">${TROPHIES.map(t => trophyMiniHTML(t, got[t.id])).join("")}</div>`;
  document.getElementById("tour").classList.add("behind-settings");
  openOverlay("trophies");
}
document.getElementById("tourTrophiesBtn").addEventListener("click", openTrophies);
document.getElementById("trophiesClose").addEventListener("click", () => {
  closeOverlay("trophies");
  document.getElementById("tour").classList.remove("behind-settings");
});
document.getElementById("trophiesList").addEventListener("click", ev => {
  const b = ev.target.closest("[data-trophy]");
  if (b) openTrophyDetail(b.dataset.trophy);
});
document.getElementById("trophyDetail").addEventListener("click", ev => {
  if (ev.target.closest("[data-trophy-ok]")) closeOverlay("trophyDetail");
});
