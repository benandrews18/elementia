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
  if (!unlocked.length){
    list.innerHTML = '<p class="empty">None discovered yet -- Lock In a Display Mat containing a named collection to reveal it here.</p>';
    return;
  }
  // Classic-only toggle -- only makes sense where a Display Mat exists at
  // all (this overlay is also reachable from the welcome screen outside
  // any run, where state.mat doesn't exist yet).
  list.innerHTML = `<div class="histrows">${unlocked.map(c => namedCollectionCardHTML(c, true)).join("")}</div>`;
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
