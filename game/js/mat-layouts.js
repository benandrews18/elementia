/* =====================================================================
   mat-layouts.js -- Saved mat layouts and the Collections overlay.

   Saved Display Mat layouts: named snapshots of state.mat in
   prefs.savedMatLayouts (account-level), from a real Classic run or Combo
   Lab (#matLayoutsBtn on the Display Mat page).
   ===================================================================== */
function renderMatLayoutsList(){
  const list = document.getElementById("matLayoutsList");
  const layouts = prefs.savedMatLayouts;
  if (!layouts.length){
    list.innerHTML = '<p class="empty">No saved layouts yet -- arrange the mat, then save it above.</p>';
    return;
  }
  list.innerHTML = `<div class="histrows">${layouts.map((L, i) => `
    <div class="histentry">
      <div class="histrow-line">
        <button type="button" class="histrow" data-mat-layout-load="${i}">
          <span class="histvisits">${esc(L.name)}</span>
          <span class="histcaps">${L.items.length} card${L.items.length === 1 ? "" : "s"}</span>
        </button>
        <button type="button" class="histrow-export" data-mat-layout-delete="${i}" title="Delete this layout" aria-label="Delete ${esc(L.name)}">🗑</button>
      </div>
    </div>`).join("")}</div>`;
}
function openMatLayoutsOverlay(){
  renderMatLayoutsList();
  openOverlay("matLayoutsOverlay");
}
function closeMatLayoutsOverlay(){
  closeOverlay("matLayoutsOverlay");
}
function saveMatLayout(){
  const input = document.getElementById("matLayoutName");
  const name = input.value.trim();
  if (!name) return;
  prefs.savedMatLayouts.push({name, items: [...state.mat]});
  savePrefs();
  input.value = "";
  renderMatLayoutsList();
}
/* Loads a saved layout onto the mat: only cards placeable now (all of them
   in Combo Lab, owned ones in a real run), in saved order, trimmed with
   matFits()/matOccupancy() so it fits. */
function loadMatLayout(i){
  const L = prefs.savedMatLayouts[i];
  if (!L) return;
  const placeable = L.items.filter(n => MAT_CARD_BY_NAME[n] && (comboLabActive || owns(n)));
  const kept = [];
  for (const n of placeable){
    if (matFits([...kept, n].map(x => MAT_CARD_BY_NAME[x]))) kept.push(n);
  }
  state.mat = kept;
  save();
  render();
  closeMatLayoutsOverlay();
}
function deleteMatLayout(i){
  prefs.savedMatLayouts.splice(i, 1);
  savePrefs();
  renderMatLayoutsList();
}
document.getElementById("matLayoutsClose").addEventListener("click", closeMatLayoutsOverlay);

/* Only discovered collections get a row; the X/Y count is the only hint of
   how many remain. */
// Every member owned AND the missing ones would fit -- gates "Add to Mat"
// (the add is all-or-nothing, see addCollectionToMat()).
function collectionAddFits(c){
  if (!c.items.every(n => owns(n))) return false;
  const missing = c.items.filter(n => !state.mat.includes(n)).map(n => MAT_CARD_BY_NAME[n]);
  if (!missing.length) return false; // already fully on the mat -- nothing to add
  return matFits(matOnMat().concat(missing));
}
function renderCollectionsList(){
  const total = MAT_COLLECTIONS.length;
  const unlocked = MAT_COLLECTIONS.filter(c => prefs.everUnlockedMatCollections.includes(c.id));
  document.getElementById("collectionsCount").textContent =
    `${unlocked.length} / ${total} Collections Unlocked`;
  const list = document.getElementById("collectionsList");
  const stars = prefs.stars || 0, can = Math.floor(stars / CLUE_COST), left = total - unlocked.length;
  const shop = `<div class="clue-shop">
      <div class="clue-shop-top"><span class="clue-stars">⭐ ${stars}</span><span class="clue-shop-title">Collection Clues</span></div>
      <div class="clue-shop-btns">
        <button type="button" class="bigbtn" id="clueBuyOne" ${can && left ? "" : "disabled"}>🎁 1 clue · ${CLUE_COST} ⭐</button>
        <button type="button" class="bigbtn sec" id="clueBuyAll" ${can > 1 && left ? "" : "disabled"}>🎁 Open all${can > 1 ? ` (${can})` : ""}</button>
      </div>
      <p class="clue-how">Earn ⭐: finish a run +${STARS_RUN}, new trophy +${STARS_TROPHY}, discover a collection +${STARS_DISCOVERY}</p>
    </div>`;
  const clues = prefs.collectionClues || {};
  const leads = MAT_COLLECTIONS.filter(c => clues[c.id] && !prefs.everUnlockedMatCollections.includes(c.id));
  const leadsHTML = leads.length ? `<div class="sec-label" style="margin-top:12px">🔎 CLUES</div><div class="histrows">${leads.map(c => `
    <div class="histentry collection-card clue-lead"><div class="collection-row"><div class="cr-main">
      <div class="cr-line1"><span class="cr-name">${esc(c.name)}</span><span class="cr-bonus">+${c.bonus}</span></div>
      <span class="cr-icons">${c.items.map(n => clues[c.id].includes(n)
        ? `<span class="cr-icon" title="${esc(n)}">${em(ITEM_EMOJI[n])}</span>` : `<span class="cr-icon cr-unknown">?</span>`).join("")}</span>
    </div></div></div>`).join("")}</div>` : "";
  // Classic-only toggle -- only makes sense where a Display Mat exists at
  // all (this overlay is also reachable from the welcome screen outside
  // any run, where state.mat doesn't exist yet).
  list.innerHTML = shop + leadsHTML + (unlocked.length
    ? `<div class="sec-label" style="margin-top:12px">DISCOVERED</div><div class="histrows">${unlocked.map(c => namedCollectionCardHTML(c, true)).join("")}</div>`
    : '<p class="empty">None discovered yet -- Lock In a Display Mat containing a named collection, or open a clue.</p>');
}
/* A named collection's card, shared by the Collections menu and the combo
   star's popup (openComboInfo()). A green check once every member is owned.
   withToggle adds an on/off switch: ON = every member on the mat; switching
   places or removes them all (all-or-nothing, see collectionAddFits()). */
function namedCollectionCardHTML(c, withToggle){
  const ownsAll = c.items.every(n => owns(n));
  const onMat = withToggle && c.items.every(n => state.mat.includes(n));
  const canOn = withToggle && collectionAddFits(c);
  return `
    <div class="histentry collection-card${ownsAll ? " owns-all" : ""}">
      ${ownsAll ? `<span class="cr-check" title="You own every item in this collection">✓</span>` : ""}
      <div class="collection-row">
        <div class="cr-main">
          <div class="cr-line1">
            <span class="cr-name">${esc(c.name)}</span>
            <span class="cr-bonus">+${c.bonus}</span>
          </div>
          <span class="cr-icons">${c.items.map(n =>
            `<span class="cr-icon${owns(n) ? "" : " missing"}" title="${esc(n)}">${ITEM_EMOJI[n] ? em(ITEM_EMOJI[n]) : esc(n)}</span>`).join("")}</span>
        </div>
        ${withToggle ? `<label class="cr-toggle" title="${onMat ? "Take this collection off your Display Mat" : canOn ? "Place this collection on your Display Mat" : "Own every card and free up mat room to place this collection"}">
            <input type="checkbox" class="switch" data-toggle-collection="${esc(c.id)}" ${onMat ? "checked" : ""} ${onMat || canOn ? "" : "disabled"}>
            <span>${onMat ? "On Mat" : "Off"}</span>
          </label>` : ""}
      </div>
    </div>`;
}
/* --------------------------------------------------------- Stars --- */
/* Stars (prefs.stars, kept across runs) buy collection clues. Earned:
   finishing a run, each new trophy, each collection discovered by playing.
   state.starsEarned is this run's total, for the end screen. */
const STARS_RUN = 5, STARS_TROPHY = 2, STARS_DISCOVERY = 1, CLUE_COST = 3;
function grantStars(n){
  if (!n) return;
  prefs.stars = (prefs.stars || 0) + n; savePrefs();
  state.starsEarned = (state.starsEarned || 0) + n;
  syncCollectionsBtn();
}
function syncCollectionsBtn(){
  const b = document.getElementById("tourCollectionsBtn");
  b.innerHTML = `🏆 Collections${prefs.stars ? ` <span class="coll-stars">⭐ ${prefs.stars}</span>` : ""}`;
}
/* One clue: a random undiscovered collection's name plus one more of its
   items, preferring collections without a clue yet. Revealing its last
   item discovers it. Clues live in prefs.collectionClues {id: [items]}. */
function drawCollectionClue(){
  const clues = prefs.collectionClues || (prefs.collectionClues = {});
  const hidden = MAT_COLLECTIONS.filter(c => !prefs.everUnlockedMatCollections.includes(c.id));
  if (!hidden.length) return null;
  const fresh = hidden.filter(c => !clues[c.id]);
  const pool = fresh.length ? fresh : hidden;
  const c = pool[Math.floor(Math.random() * pool.length)];
  const known = clues[c.id] || [];
  const item = shuffle(c.items.filter(n => !known.includes(n)))[0];
  clues[c.id] = [...known, item];
  const discovered = clues[c.id].length >= c.items.length;
  if (discovered){ prefs.everUnlockedMatCollections.push(c.id); delete clues[c.id]; }
  return { c, item, known: discovered ? c.items : clues[c.id], discovered };
}
/* Spends Stars for n clues up front (saved before any animation), then
   opens them one gift box at a time (openClueBoxes()). */
function buyClues(n){
  const hiddenLeft = MAT_COLLECTIONS.filter(c => !prefs.everUnlockedMatCollections.includes(c.id)).length;
  n = Math.min(n, Math.floor((prefs.stars || 0) / CLUE_COST));
  if (n < 1 || !hiddenLeft) return;
  const got = [];
  for (let i = 0; i < n; i++){ const clue = drawCollectionClue(); if (!clue) break; got.push(clue); }
  prefs.stars -= got.length * CLUE_COST;
  savePrefs(); syncCollectionsBtn();
  renderCollectionsList();
  openClueBoxes(got);
}
/* The gift box: wobbles until tapped, bursts open, and the clue card flips
   in. "Next" brings the next box. */
let clueQueue = [], clueIdx = 0;
function openClueBoxes(list){
  clueQueue = list; clueIdx = 0;
  showClueBox();
  openOverlay("clueOpen");
}
function showClueBox(){
  const left = clueQueue.length - clueIdx;
  document.getElementById("clueOpenBody").innerHTML = `
    <p class="clue-count">Gift ${clueIdx + 1} of ${clueQueue.length}</p>
    <button type="button" class="clue-box" id="clueBox" aria-label="Open the gift">🎁</button>
    <p class="clue-tap">Tap to open!</p>`;
  if (left <= 0) closeOverlay("clueOpen");
}
function revealClue(){
  const clue = clueQueue[clueIdx];
  const box = document.getElementById("clueBox");
  if (!clue || !box || box.classList.contains("opening")) return;
  box.classList.add("opening");
  const show = () => {
    const c = clue.c;
    const icons = c.items.map(n => clue.known.includes(n)
      ? `<span class="clue-ic${n === clue.item ? " new" : ""}" title="${esc(n)}">${em(ITEM_EMOJI[n])}</span>`
      : `<span class="clue-ic unknown">?</span>`).join("");
    const last = clueIdx >= clueQueue.length - 1;
    document.getElementById("clueOpenBody").innerHTML = `
      <div class="clue-burst" aria-hidden="true"></div>
      <div class="clue-card${clue.discovered ? " found" : ""}">
        <div class="clue-kicker">${clue.discovered ? "Collection discovered!" : "New clue"}</div>
        <div class="clue-name">${esc(c.name)}</div>
        <div class="clue-icons">${icons}</div>
        <div class="clue-new">${clue.discovered ? `+${c.bonus} on your mat when it's all there` : `${esc(clue.item)} is in this collection`}</div>
      </div>
      <div class="btnrow" style="justify-content:center">
        <button type="button" class="bigbtn" id="clueNext">${last ? "Done" : `Next gift (${clueQueue.length - clueIdx - 1} left)`}</button>
      </div>`;
  };
  if (lowMotion()) show(); else setTimeout(show, 650);
}
document.getElementById("clueOpen").addEventListener("click", ev => {
  if (ev.target.closest("#clueBox")){ revealClue(); return; }
  if (ev.target.closest("#clueNext")){ clueIdx++; showClueBox(); return; }
});
document.getElementById("collectionsList").addEventListener("click", ev => {
  if (ev.target.closest("#clueBuyOne")) buyClues(1);
  else if (ev.target.closest("#clueBuyAll")) buyClues(Infinity);
});
// Opened from the welcome screen (#tourCollectionsBtn) and from the
// inventory filter bar (#matCollectionsBtn) -- the same overlay either way.
// The #tour layering class is harmless when #tour isn't open.
function openCollectionsOverlay(){
  renderCollectionsList();
  document.getElementById("tour").classList.add("behind-settings");
  openOverlay("collectionsOverlay");
}
function closeCollectionsOverlay(){
  closeOverlay("collectionsOverlay");
  document.getElementById("tour").classList.remove("behind-settings");
}
document.getElementById("collectionsClose").addEventListener("click", closeCollectionsOverlay);
// All-or-nothing: every unplaced member goes on at once, re-checked with
// collectionAddFits() in case the mat changed while this was open.
function addCollectionToMat(id){
  const c = MAT_COLLECTIONS.find(x => x.id === id);
  if (!c || !collectionAddFits(c)) return;
  c.items.forEach(n => { if (!state.mat.includes(n)) state.mat.push(n); });
  save();
  renderCollectionsList();
  renderMatTop(); renderMatResultsGrid();
}
// Switch off: every member comes off the mat (a card shared with another
// collection goes too -- the mat holds each card once).
function removeCollectionFromMat(id){
  const c = MAT_COLLECTIONS.find(x => x.id === id);
  if (!c) return;
  state.mat = state.mat.filter(n => !c.items.includes(n));
  save();
  renderCollectionsList();
  renderMatTop(); renderMatResultsGrid();
}
document.getElementById("collectionsList").addEventListener("change", ev => {
  const sw = ev.target.closest("[data-toggle-collection]");
  if (!sw) return;
  if (sw.checked) addCollectionToMat(sw.dataset.toggleCollection);
  else removeCollectionFromMat(sw.dataset.toggleCollection);
});
document.getElementById("tourCollectionsBtn").addEventListener("click", openCollectionsOverlay);
document.getElementById("matLayoutSaveBtn").addEventListener("click", saveMatLayout);
document.getElementById("matLayoutName").addEventListener("keydown", ev => {
  if (ev.key === "Enter") saveMatLayout();
});
document.getElementById("matLayoutsList").addEventListener("click", ev => {
  const loadBtn = ev.target.closest("[data-mat-layout-load]");
  if (loadBtn){ loadMatLayout(+loadBtn.dataset.matLayoutLoad); return; }
  const delBtn = ev.target.closest("[data-mat-layout-delete]");
  if (delBtn){ deleteMatLayout(+delBtn.dataset.matLayoutDelete); return; }
});
// Copies every saved layout as JSON, like #historyExport, for analysis
// elsewhere.
document.getElementById("matLayoutsExport").addEventListener("click", async () => {
  const btn = document.getElementById("matLayoutsExport");
  const json = JSON.stringify(prefs.savedMatLayouts, null, 2);
  try {
    await navigator.clipboard.writeText(json);
    btn.textContent = "✓ Copied!";
    btn.classList.add("done");
  } catch (e){
    window.prompt("Copy this text:", json);
  }
  setTimeout(() => { btn.textContent = "⧉ Export"; btn.classList.remove("done"); }, 1800);
});

/* Mat card taps are handled in #drawerTop's main click listener (the
   .mm-slot.filled branch). */
