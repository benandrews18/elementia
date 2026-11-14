/* =====================================================================
   trophies.js -- Trophies: earned when a run completes (turn
   RUN_COMPLETE_VISIT, or crafting everything), kept across runs in their
   own localStorage key (TROPHY_KEY, not the run save), and shown from the
   home screen (#tourTrophiesBtn). Locked trophies show as silhouettes with
   a hint, to point players at new capstones, items and collections.
   ===================================================================== */
const TROPHY_KEY = "elementia-trophies-v1";

/* Each: id, icon (emoji or __MARKER__, drawn with em()), name, hint (shown
   while locked), test(state) -> earned on this completed run. The
   collection trophies count discoveries across runs
   (prefs.everUnlockedMatCollections). */
const TROPHIES = [
  { id:"first-run", icon:"🏁", name:"First Run", hint:"Complete a run (reach turn 24)", test:() => true },
  ...CAPSTONES.map(cap => ({
    id: "cap-" + cap.toLowerCase().replace(/[^a-z]+/g, "-"),
    icon: ITEM_EMOJI[cap], name: `${cap} Run`,
    hint: `Complete a run that crafts the ${cap}`,
    test: st => st.items.includes(cap),
  })),
  { id:"items-40", icon:"🧰", name:"Busy Builder", hint:"Craft 40 items in one run", test:st => st.items.length >= 40 },
  { id:"items-all", icon:"🌍", name:"Every Item", hint:"Craft every item in one run", test:st => !!st.craftedEverything },
  ...[1000, 2500, 4000].map((q, i) => ({
    id: "quarks-" + q, icon: ["⚛️", "💫", "🌟"][i], name: `${q.toLocaleString()} Quarks`,
    hint: `Lock In a Display Mat worth ${q.toLocaleString()} Quarks`,
    test: st => (st.bestMatScore || 0) >= q,
  })),
  ...[[5, "🔍", "Collector"], [20, "🗂️", "Curator"], [0, "🏛️", "Every Collection"]].map(([n, icon, name]) => ({
    id: n ? "collections-" + n : "collections-all", icon, name,
    hint: n ? `Discover ${n} collections on your Display Mat (across runs)` : "Discover every collection (across runs)",
    test: () => prefs.everUnlockedMatCollections.length >= (n || MAT_COLLECTIONS.length),
  })),
  { id:"bingo-1", icon:"🎯", name:"BINGO!", hint:"Complete a BINGO line in a run", test:st => (st.bingoLinesCompleted || []).length >= 1 },
  { id:"bingo-3", icon:"🎰", name:"Triple BINGO", hint:"Complete 3 BINGO lines in one run", test:st => (st.bingoLinesCompleted || []).length >= 3 },
  { id:"ot-30", icon:"⏱️", name:"Overtime", hint:"Reach visit 30 in Overtime", test:st => st.visits >= 30 },
  { id:"ot-36", icon:"🔥", name:"Iron Will", hint:"Reach visit 36 in Overtime", test:st => st.visits >= 36 },
];

function loadTrophies(){
  try { return JSON.parse(lsGet(TROPHY_KEY) || "{}") || {}; } catch(e){ return {}; }
}
/* Awards every trophy this run now qualifies for; returns the newly earned
   ones. Only for a completed run (turn 24 or crafted everything). */
function awardTrophies(){
  if (!state.runComplete && !state.craftedEverything) return [];
  const got = loadTrophies();
  const fresh = TROPHIES.filter(t => !got[t.id] && t.test(state));
  if (!fresh.length) return [];
  const at = new Date().toLocaleDateString("en-CA"); // local YYYY-MM-DD
  fresh.forEach(t => { got[t.id] = {at}; });
  lsSet(TROPHY_KEY, JSON.stringify(got));
  grantStars(fresh.length * STARS_TROPHY);
  return fresh;
}
function trophyTileHTML(t, earned){
  return `<div class="trophy${earned ? " earned" : ""}" title="${esc(earned ? t.name : t.hint)}">
    <span class="trophy-ic">${em(t.icon)}</span>
    <span class="trophy-name">${earned ? esc(t.name) : "???"}</span>
    <span class="trophy-sub">${earned ? `Earned ${esc(earned.at)}` : esc(t.hint)}</span>
  </div>`;
}
/* The Trophies window: icons only, tap one for its detail. */
function trophyMiniHTML(t, earned){
  return `<button type="button" class="trophy-mini${earned ? " earned" : ""}" data-trophy="${esc(t.id)}" aria-label="${esc(earned ? t.name : "Locked trophy")}"><span class="tm-ic">${em(t.icon)}</span></button>`;
}
function openTrophyDetail(id){
  const t = TROPHIES.find(x => x.id === id);
  if (!t) return;
  const earned = loadTrophies()[id];
  document.getElementById("trophyDetailBody").innerHTML = `
    <div class="trophy-detail-ic${earned ? "" : " locked"}"><span class="tm-ic">${em(t.icon)}</span></div>
    <h2 id="trophyDetailName">${earned ? esc(t.name) : "Locked"}</h2>
    <p>${esc(t.hint)}</p>
    <p class="trophy-detail-at">${earned ? `Earned ${esc(earned.at)}` : "Not earned yet"}</p>
    <div class="btnrow" style="justify-content:center"><button type="button" class="bigbtn" data-trophy-ok>OK</button></div>`;
  openOverlay("trophyDetail");
}
/* The end screen's "New trophies" strip (showEndGame()). */
function openTrophies(){
  const got = loadTrophies();
  document.getElementById("trophiesCount").textContent =
    `${TROPHIES.filter(t => got[t.id]).length} of ${TROPHIES.length} earned -- tap one to see how to earn it.`;
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
