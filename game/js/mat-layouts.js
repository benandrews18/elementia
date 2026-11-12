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
  const L = prefs.savedMatLayouts[i];
  if (!L) return;
  askConfirm(`Delete the layout "${L.name}"? This can't be undone.`, () => deleteMatLayoutNow(i));
}
function deleteMatLayoutNow(i){
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
  // Main Menu only: Stars in a bubble by the title, the two clue buttons
  // under the count.
  const stars = prefs.stars || 0, can = Math.floor(stars / CLUE_COST), left = total - unlocked.length;
  const starsEl = document.getElementById("collectionsStars"), btns = document.getElementById("clueShopBtns");
  starsEl.hidden = btns.hidden = !collectionsFromMenu;
  starsEl.textContent = `⭐ ${stars}`;
  btns.innerHTML = `
    <button type="button" class="bigbtn" id="clueBuyOne" ${can && left ? "" : "disabled"}>🎁 1 clue · ${CLUE_COST} ⭐</button>
    <button type="button" class="bigbtn sec" id="clueBuyAll" ${can > 1 && left ? "" : "disabled"}>🎁 Open all${can > 1 ? ` (${can})` : ""}</button>`;
  // One list, in collection order: discovered ones, and ones you have clues
  // for (their unknown items as "?").
  const clues = prefs.collectionClues || {};
  const shown = MAT_COLLECTIONS.filter(c => prefs.everUnlockedMatCollections.includes(c.id) || clues[c.id]);
  const leadHTML = c => `
    <div class="histentry collection-card clue-lead"><div class="collection-row"><div class="cr-main">
      <div class="cr-line1"><span class="cr-name">${esc(c.name)}</span><span class="cr-bonus">+${c.bonus}</span><span class="cr-clue">🔎 clue</span></div>
      <span class="cr-icons">${c.items.map(n => clues[c.id].includes(n)
        ? `<span class="cr-icon" title="${esc(n)}">${em(ITEM_EMOJI[n])}</span>` : `<span class="cr-icon cr-unknown">?</span>`).join("")}</span>
    </div></div></div>`;
  // Classic-only toggle -- only makes sense where a Display Mat exists at
  // all (this overlay is also reachable from the welcome screen outside
  // any run, where state.mat doesn't exist yet).
  list.innerHTML = shown.length
    ? `<div class="histrows">${shown.map(c => prefs.everUnlockedMatCollections.includes(c.id) ? namedCollectionCardHTML(c, true) : leadHTML(c)).join("")}</div>`
    : '<p class="empty">None discovered yet -- Lock In a Display Mat containing a named collection, or open a clue.</p>';
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
/* -------------------------------------------- collection discovery --- */
/* A collection is discovered the moment it's complete on the Display Mat
   (any run, not Combo Lab): a window shows it and "Add to Collections"
   saves it. Called from render() and renderMatTop(); waits while anything
   else is on screen. One at a time, in collection order. */
let collectionFoundTimer = null, collectionFoundShowing = null;
function maybeShowCollectionFound(){
  if (comboLabActive || collectionFoundShowing || collectionFoundTimer || !state || !state.mode) return;
  const c = matCompletedIn(matOnMat()).find(x => !prefs.everUnlockedMatCollections.includes(x.id));
  if (!c) return;
  const busy = anyOverlayOpen() || bingoClearInProgress || document.body.classList.contains("lockin-playing")
    || (typeof lockInCommitted !== "undefined" && lockInCommitted);
  if (busy){
    collectionFoundTimer = setTimeout(() => { collectionFoundTimer = null; maybeShowCollectionFound(); }, 500);
    return;
  }
  collectionFoundShowing = c.id;
  document.getElementById("collectionFoundBody").innerHTML = `
    <div class="clue-burst" aria-hidden="true"></div>
    <div class="clue-card found">
      <div class="clue-kicker">New collection!</div>
      <div class="clue-name" id="collectionFoundName">${esc(c.name)}</div>
      <div class="clue-icons">${c.items.map(n => `<span class="clue-ic" title="${esc(n)}">${em(ITEM_EMOJI[n])}</span>`).join("")}</div>
      <div class="clue-new">+${c.bonus} on your mat whenever it's all there</div>
    </div>
    <div class="btnrow" style="justify-content:center">
      <button type="button" class="bigbtn" id="collectionFoundAdd">🏆 Add to Collections</button>
    </div>`;
  openOverlay("collectionFound");
}
document.getElementById("collectionFound").addEventListener("click", ev => {
  if (!ev.target.closest("#collectionFoundAdd") || !collectionFoundShowing) return;
  const id = collectionFoundShowing;
  if (!prefs.everUnlockedMatCollections.includes(id)) prefs.everUnlockedMatCollections.push(id);
  if (prefs.collectionClues) delete prefs.collectionClues[id];
  savePrefs();
  grantStars(STARS_DISCOVERY);
  collectionFoundShowing = null;
  closeOverlay("collectionFound");
  if (drawer.classList.contains("open")) renderMatTop();
  maybeShowCollectionFound(); // another one completed by the same move
});
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
document.getElementById("clueShopBtns").addEventListener("click", ev => {
  if (ev.target.closest("#clueBuyOne")) buyClues(1);
  else if (ev.target.closest("#clueBuyAll")) buyClues(Infinity);
});
// Opened from the welcome screen (#tourCollectionsBtn) and from the
// inventory filter bar (#matCollectionsBtn) -- the same overlay either way.
// The #tour layering class is harmless when #tour isn't open.
// The clue shop only shows when opened from the main menu (not in a run).
let collectionsFromMenu = false;
function openCollectionsOverlay(fromMenu = false){
  collectionsFromMenu = fromMenu;
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
  trimMatToFit(); // Maglev Train is in collections; without it tier 1 stacks shrink
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
document.getElementById("tourCollectionsBtn").addEventListener("click", () => openCollectionsOverlay(true));
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
