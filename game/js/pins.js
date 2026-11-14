/* =====================================================================
   pins.js -- Pinned/tracked items: the pins tray, the tracked-item pill, and
   togglePin().
   ===================================================================== */
/* The tracking chip row lives in the pins tray (#pinsTray), rebuilt on
   every render(). */
function renderPinsTray(){
  const el = document.getElementById("pinsTrayBody");
  if (!el) return;
  const names = prefs.pinnedItems.filter(name => ENTRIES.some(e => e.name === name));
  const chips = names.length
    ? names.map(name => {
        const entry = ENTRIES.find(e => e.name === name);
        const sel = selectedJobItem === name;
        return `<button type="button" class="map-job-chip ${sel ? "selected" : ""}" data-select-job="${esc(name)}" aria-pressed="${sel}">
          ${sel ? '<span class="mj-search-badge" title="Currently tracked">🔍</span>' : ""}
          <span class="mj-em">${em(entry.emoji)}</span><span class="mj-name">${esc(name)}</span>
        </button>`;
      }).join("")
    : `<span class="pinned-empty-note">Pin items in Item Reference to track them here.</span>`;
  el.innerHTML = `<div class="map-job-chips">${chips}</div>`;
}

/* Read-only pill showing the tracked item (selectedJobItem). Content stays
   while hiding so it slides away with its label. */
function renderTrackedPill(){
  const el = document.getElementById("trackedPill");
  if (!el) return;
  const entry = selectedJobItem && ENTRIES.find(e => e.name === selectedJobItem);
  if (entry){
    el.innerHTML = `<span class="tp-em">${em(entry.emoji)}</span><span class="tp-name">${esc(entry.name)}</span>`;
  }
  el.classList.toggle("show", !!entry);
}
// Sits outside #screen (see its own comment above its HTML), so it needs
// its own click listener rather than going through #screen's delegation.
document.getElementById("trackedPill").addEventListener("click", () => {
  const entry = selectedJobItem && ENTRIES.find(e => e.name === selectedJobItem);
  if (!entry) return;
  showCardPop(entry, false);
  // Above the card: the magnifier button's circle and a green pill.
  const banner = document.getElementById("cpCeleb");
  banner.className = "cp-celeb cp-tracking";
  banner.innerHTML = `<span class="cpt-glass" aria-hidden="true"></span><span class="cpt-pill">You are tracking this item!</span>`;
  banner.hidden = false;
});

/* --------------------------------------------------- pinned items --- */
/* Pins live in prefs (a personal habit, not progress), so they survive
   resets. No cap. */
const isPinned = name => prefs.pinnedItems.includes(name);
function togglePin(name){
  const i = prefs.pinnedItems.indexOf(name);
  if (i !== -1) prefs.pinnedItems.splice(i, 1);
  else prefs.pinnedItems.push(name);
  savePrefs();
  return true;
}

/* Classic initial station pick (state.lastStation === null): the previewed
   station's capstone is auto-pinned; switching previews swaps it, clearing
   the preview removes it. Only ever removes its own pin
   (initialPickPinnedCapstone), never a manual one. Tracking
   (selectedJobItem) is only changed while unset or still this function's
   own pick (trackingIsOurs). Call right after setting selectedMapStation,
   before render(). */
function syncInitialPickCapstoneTracking(){
  if (state.lastStation !== null) return;
  const wantedName = selectedMapStation ? STATION_BY_NAME[selectedMapStation].capstone[1] : null;
  const trackingIsOurs = selectedJobItem === null || selectedJobItem === initialPickPinnedCapstone;
  if (initialPickPinnedCapstone && initialPickPinnedCapstone !== wantedName){
    if (isPinned(initialPickPinnedCapstone)) togglePin(initialPickPinnedCapstone);
    if (trackingIsOurs && selectedJobItem === initialPickPinnedCapstone) selectedJobItem = null;
  }
  if (wantedName){
    if (!isPinned(wantedName)) togglePin(wantedName);
    if (trackingIsOurs) selectedJobItem = wantedName;
  }
  initialPickPinnedCapstone = wantedName;
}

document.getElementById("pinsTrayBody").addEventListener("click", ev => {
  const jobSelectBtn = ev.target.closest("[data-select-job]");
  if (jobSelectBtn) toggleJobSelect(jobSelectBtn.dataset.selectJob);
});

/* ------------------------------------------ pins tray + convert --- */
const pinsTray = document.getElementById("pinsTray");
function openPinsTray(){
  pinsTray.classList.add("open");
  pinsTray.setAttribute("aria-hidden", "false");
  document.getElementById("pinsBtn").setAttribute("aria-expanded", "true");
  updateHub();
  // Only guide once there's a pin to tap; an empty tray explains itself.
  if (prefs.pinnedItems.length){
    // No spotlight -- the chips fill the tray, and cutting out one would draw
    // attention away from the others.
    showTutorialHintOnce("pinselect", 10,
      `<span style="font-size:17.5px">Tap to start tracking!</span>`,
      "bottom-left");
  }
}
function closePinsTray(){
  pinsTray.classList.remove("open");
  pinsTray.setAttribute("aria-hidden", "true");
  document.getElementById("pinsBtn").setAttribute("aria-expanded", "false");
  updateHub();
}
document.getElementById("pinsBtn").addEventListener("click", () => hubPanelClick("pins", openPinsTray));
document.getElementById("pinsTrayClose").addEventListener("click", closePinsTray);
