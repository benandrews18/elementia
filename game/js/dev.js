/* =====================================================================
   dev.js -- Developer mode: a Dev Panel for jumping around a run and
   changing it, to test a scenario without playing up to it.

   Hidden: tapping Settings' version line 5 times shows (or hides again)
   Settings -> Dev Tools (prefs.devUnlocked), where the Developer mode
   switch (prefs.devMode) shows the 🛠 button that opens the panel.

   Any change made with the panel marks the run (state.dev): its History
   entry goes to the Dev runs list (recordHistory()), and it earns no Stars
   or trophies (grantStars(), awardTrophies()). The save from just before
   the first change is kept (DEV_BACKUP_KEY) for "Restore my real save".

   Tabs: Jump (turn, station, checks and end screens), Inventory
   (elements, "?", items) and Snapshots (named saves of the whole run, to
   load again, or copy/paste as text).
   ===================================================================== */
const DEV_SNAP_KEY = "elementia-dev-snapshots-v1", DEV_BACKUP_KEY = "elementia-save-backup-dev";
let devTab = "jump";

// Marks the run as a dev run, keeping the real save the first time.
function devTouch(){
  if (state.dev) return;
  save();
  const real = lsGet(SAVE_KEY);
  if (real) lsSet(DEV_BACKUP_KEY, real);
  state.dev = true;
  syncDevTools();
}
// After any change: save, redraw the screen and anything open over it.
function devApply(){
  save(); render();
  if (drawer.classList.contains("open")) renderMatTop();
  renderDevPanel();
}

/* ---------------------------------------------------------- Jump --- */
// Arrive at turn n: the clock, mat size, breakpoints and this stretch's
// challenge (drawn for the check that started it) all follow.
function devSetTurn(n){
  n = Math.max(1, Math.min(MAX_VISITS, Math.round(n) || 1));
  devTouch();
  state.visits = n;
  state.matChecked = n > MAT_CHECK_EVERY;
  Object.assign(state, { runComplete: false, ended: false, finalGameOver: false, finalCheckPending: false });
  const c = Math.floor((n - 1) / MAT_CHECK_EVERY) * MAT_CHECK_EVERY; // the last check before this turn
  state.checkRound = c >= MAT_CHECK_EVERY ? c : null;
  state.order = null;
  if (c >= MAT_CHECK_EVERY) setOrder(drawOrder(c));
  devApply();
}
// Be at a station without spending a turn (and roll there again).
function devTeleport(name){
  devTouch();
  current = name; state.lastStation = name; screen = "station";
  state.visitedStations[name] = true;
  state.rolledHere = false; state.pendingRoll = null;
  devApply();
}
// Turn n is a board check when you leave it: jump there, then pick a
// station on the map and tap Travel.
function devNextCheck(){
  devSetTurn(Math.max(MAT_CHECK_EVERY, Math.ceil(state.visits / MAT_CHECK_EVERY) * MAT_CHECK_EVERY));
  if (current) goMap(); else { screen = "map"; render(); }
}
function devFinalCheck(){
  devSetTurn(RUN_COMPLETE_VISIT);
  current = null; screen = "map"; render();
  closeDevPanel();
  startFinalCheck();
}
function devEndScreen(kind){
  devTouch();
  if (kind === "complete") state.runComplete = true;
  else { state.finalGameOver = true; state.ended = true; }
  save(); closeDevPanel();
  showEndGame();
}

/* ----------------------------------------------------- Inventory --- */
function devElement(sym, d){
  devTouch();
  const n = Math.max(0, count(sym) + d);
  if (n) state.elements[sym] = n; else delete state.elements[sym];
  devApply();
}
function devAllElements(n){
  devTouch();
  state.elements = {};
  if (n) CORE_ELEMENT_SYMS.forEach(s => { state.elements[s] = n; });
  devApply();
}
function devEmpty(d){
  devTouch();
  state.emptyElements = Math.max(0, (state.emptyElements || 0) + d);
  devApply();
}
// Given straight to the inventory: no elements spent, no craft reveal.
function devGrant(names){
  devTouch();
  names.forEach(n => { if (CORE_ITEM_NAMES.has(n) && !owns(n)) state.items.push(n); });
  devApply();
}
function devRemove(name){
  devTouch();
  state.items = state.items.filter(n => n !== name);
  state.mat = state.mat.filter(n => n !== name);
  devApply();
}

/* ----------------------------------------------------- Snapshots --- */
const devSnaps = () => { try { return JSON.parse(lsGet(DEV_SNAP_KEY) || "[]"); } catch(e){ return []; } };
const devSaveSnaps = list => lsSet(DEV_SNAP_KEY, JSON.stringify(list));
function devSnapSave(name){
  const list = devSnaps();
  list.unshift({ name: name || `Turn ${state.visits}`, at: new Date().toISOString().slice(0, 16).replace("T", " "),
    state: JSON.parse(JSON.stringify(state)) });
  devSaveSnaps(list);
  renderDevPanel();
}
function devSnapLoad(i){
  const snap = devSnaps()[i];
  if (!snap) return;
  devTouch();
  state = Object.assign(freshState(), JSON.parse(JSON.stringify(snap.state)));
  state.dev = true;
  current = null; screen = "map"; selectedMapStation = null; travelPromptFor = null;
  closeDrawer();
  devApply();
}
// A pasted snapshot: one copied from here ({name, state}) or a bare state.
function devSnapImport(text){
  let snap;
  try { snap = JSON.parse(text); } catch(e){ return false; }
  if (snap && !snap.state && Array.isArray(snap.items)) snap = { name: "Pasted", state: snap };
  if (!snap || !snap.state || !Array.isArray(snap.state.items)) return false;
  const list = devSnaps();
  list.unshift({ name: snap.name || "Pasted", at: snap.at || new Date().toISOString().slice(0, 16).replace("T", " "), state: snap.state });
  devSaveSnaps(list);
  renderDevPanel();
  return true;
}
function devCopy(text, btn){
  navigator.clipboard.writeText(text).then(() => { btn.textContent = "✓"; }).catch(() => window.prompt("Copy this text:", text));
}

/* --------------------------------------------------------- Panel --- */
document.body.insertAdjacentHTML("beforeend", `
  <button type="button" id="devFab" class="dev-fab" hidden aria-label="Dev Panel">🛠</button>
  <div id="devPanel" class="dev-panel" hidden role="dialog" aria-label="Dev Panel">
    <div class="dev-head"><b>🛠 Dev Panel</b><span class="dev-flag" id="devFlag"></span>
      <button type="button" class="dev-x" data-dev="close" aria-label="Close the Dev Panel">✕</button></div>
    <div class="dev-tabs">${[["jump", "Jump"], ["inv", "Inventory"], ["snaps", "Snapshots"]]
      .map(([k, l]) => `<button type="button" data-dev-tab="${k}">${l}</button>`).join("")}</div>
    <div class="dev-body" id="devBody"></div>
  </div>`);
const devPanel = document.getElementById("devPanel");
function openDevPanel(){ devPanel.hidden = false; renderDevPanel(); }
function closeDevPanel(){ devPanel.hidden = true; }

function renderDevPanel(){
  if (devPanel.hidden) return;
  document.getElementById("devFlag").textContent = state.dev ? "dev run" : "real run";
  document.getElementById("devFlag").classList.toggle("on", !!state.dev);
  devPanel.querySelectorAll("[data-dev-tab]").forEach(b => b.classList.toggle("on", b.dataset.devTab === devTab));
  const stations = DATA.stations.map(s => s.name);
  const body = document.getElementById("devBody");
  if (devTab === "jump"){
    body.innerHTML = `
      <div class="dev-row"><label>Turn <input type="number" id="devTurn" min="1" max="${MAX_VISITS}" value="${state.visits}"></label>
        <button type="button" data-dev="turn">Set</button>
        <span class="dev-note">now ${state.visits} / ${RUN_COMPLETE_VISIT}${current ? ` · at ${esc(current)}` : ""}</span></div>
      <div class="dev-row"><select id="devStation">${stations.map(s => `<option${s === (current || state.lastStation) ? " selected" : ""}>${esc(s)}</option>`).join("")}</select>
        <button type="button" data-dev="teleport">Go there (no turn)</button></div>
      <div class="dev-grid">
        <button type="button" data-dev="nextCheck">Next board check</button>
        <button type="button" data-dev="final">Final check (24)</button>
        <button type="button" data-dev="complete">Run Complete screen</button>
        <button type="button" data-dev="gameover">Game Over screen</button>
      </div>`;
  } else if (devTab === "inv"){
    const items = [...CORE_ITEM_NAMES].sort();
    body.innerHTML = `
      <div class="dev-els">${CORE_ELEMENT_SYMS.map(s => `<div class="dev-el" style="--suit:${ELEMENT_COLOR[s]}">
        <button type="button" data-dev-el="${s}" data-d="-1">−</button><b>${s}</b><span>${count(s)}</span><button type="button" data-dev-el="${s}" data-d="1">+</button></div>`).join("")}</div>
      <div class="dev-row"><button type="button" data-dev="all5">All to 5</button><button type="button" data-dev="clearEls">Clear</button>
        <span class="dev-note">"?" ${state.emptyElements || 0}</span><button type="button" data-dev="q-">−</button><button type="button" data-dev="q+">+</button></div>
      <div class="dev-row"><input id="devItem" list="devItemList" placeholder="Item name…"><datalist id="devItemList">${items.map(n => `<option value="${esc(n)}">`).join("")}</datalist></div>
      <div class="dev-row"><button type="button" data-dev="grant">Grant</button><button type="button" data-dev="tree">Grant with its whole tree</button><button type="button" data-dev="remove">Remove</button></div>
      <div class="dev-row"><button type="button" data-dev="grantAll">Grant every item</button><span class="dev-note">${state.items.length} owned</span></div>`;
  } else {
    const snaps = devSnaps();
    body.innerHTML = `
      <div class="dev-row"><input id="devSnapName" placeholder="Name this snapshot…" maxlength="50"><button type="button" data-dev="snapSave">Save</button></div>
      <div class="dev-snaps">${snaps.length ? snaps.map((s, i) => `<div class="dev-snap"><span><b>${esc(s.name)}</b><small>turn ${s.state.visits} · ${esc(s.at)}</small></span>
        <button type="button" data-dev-snap="load" data-i="${i}">Load</button><button type="button" data-dev-snap="copy" data-i="${i}">⧉</button><button type="button" data-dev-snap="del" data-i="${i}">🗑</button></div>`).join("")
        : '<p class="dev-note">No snapshots yet.</p>'}</div>
      <div class="dev-row"><textarea id="devPaste" rows="2" placeholder="Paste a snapshot here…"></textarea><button type="button" data-dev="import">Import</button></div>`;
  }
}

devPanel.addEventListener("click", ev => {
  const tab = ev.target.closest("[data-dev-tab]");
  if (tab){ devTab = tab.dataset.devTab; renderDevPanel(); return; }
  const el = ev.target.closest("[data-dev-el]");
  if (el){ devElement(el.dataset.devEl, +el.dataset.d); return; }
  const sn = ev.target.closest("[data-dev-snap]");
  if (sn){
    const i = +sn.dataset.i, kind = sn.dataset.devSnap;
    if (kind === "load") devSnapLoad(i);
    else if (kind === "copy") devCopy(JSON.stringify(devSnaps()[i]), sn);
    else { const list = devSnaps(); list.splice(i, 1); devSaveSnaps(list); renderDevPanel(); }
    return;
  }
  const b = ev.target.closest("[data-dev]");
  if (!b) return;
  const item = () => (document.getElementById("devItem") || {}).value || "";
  const act = {
    close: closeDevPanel,
    turn: () => devSetTurn(+document.getElementById("devTurn").value),
    teleport: () => devTeleport(document.getElementById("devStation").value),
    nextCheck: devNextCheck, final: devFinalCheck,
    complete: () => devEndScreen("complete"), gameover: () => devEndScreen("over"),
    all5: () => devAllElements(5), clearEls: () => devAllElements(0),
    "q-": () => devEmpty(-1), "q+": () => devEmpty(1),
    grant: () => devGrant([item()]), tree: () => devGrant([...componentClosure(item()), item()]),
    remove: () => devRemove(item()), grantAll: () => devGrant([...CORE_ITEM_NAMES]),
    snapSave: () => devSnapSave(document.getElementById("devSnapName").value.trim()),
    import: () => { if (!devSnapImport(document.getElementById("devPaste").value)) b.textContent = "Not a snapshot"; },
  }[b.dataset.dev];
  if (act) act();
});
document.getElementById("devFab").addEventListener("click", () => devPanel.hidden ? openDevPanel() : closeDevPanel());

/* --------------------------------------------- Settings / unlock --- */
function syncDevTools(){
  document.getElementById("settingsDevBtn").hidden = !prefs.devUnlocked;
  document.getElementById("devModeSwitch").checked = !!prefs.devMode;
  document.getElementById("devFab").hidden = !prefs.devMode;
  document.getElementById("devRestoreBtn").hidden = !lsGet(DEV_BACKUP_KEY);
  if (!prefs.devMode) closeDevPanel();
}
// Five taps on the version line, each within 1.5s of the last.
let devTaps = 0, devTapTimer = null;
document.getElementById("setVersion").addEventListener("click", () => {
  clearTimeout(devTapTimer);
  devTapTimer = setTimeout(() => { devTaps = 0; }, 1500);
  if (++devTaps < 5) return;
  devTaps = 0;
  prefs.devUnlocked = !prefs.devUnlocked;
  if (!prefs.devUnlocked) prefs.devMode = false;
  savePrefs(); syncDevTools();
});
document.getElementById("devModeSwitch").addEventListener("change", ev => {
  prefs.devMode = ev.target.checked; savePrefs(); syncDevTools();
});
document.getElementById("devRestoreBtn").addEventListener("click", () => {
  askConfirm("Replace the current run with your real save from before the Dev Panel changed it?", () => {
    const real = lsGet(DEV_BACKUP_KEY);
    if (!real) return;
    lsSet(SAVE_KEY, real);
    try { localStorage.removeItem(DEV_BACKUP_KEY); } catch(e){}
    location.reload();
  });
});
