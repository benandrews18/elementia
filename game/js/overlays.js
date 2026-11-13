/* =====================================================================
   overlays.js -- Overlay plumbing: openOverlay()/closeOverlay() with focus return, and
   the event toast queue (queueEventToast()).
   ===================================================================== */
let lastFocused = null;
function openOverlay(id){
  lastFocused = document.activeElement;
  const el = document.getElementById(id);
  el.classList.add("open");
  const focusable = el.querySelector("button, input, [tabindex]");
  if (focusable) focusable.focus();
  // Dim everything behind Convert and its goal card, like #jobScrim.
  if (id === "convert") document.getElementById("convertScrim").classList.add("open");
  updateHub(); // e.g. Settings' hub button going green while it's open
}
// The settings hub and its three sub-screens: exactly one is open at a
// time, and anySettingsOpen()/openSettingsScreen() treat all four as one
// "Settings is open" state while moving between them.
const SETTINGS_OVERLAY_IDS = ["settings", "settingsRules", "settingsDev", "settingsTuts"];
function anySettingsOpen(){
  return SETTINGS_OVERLAY_IDS.some(id => document.getElementById(id).classList.contains("open"));
}
// Switch settings screens WITHOUT closeOverlay(), whose "left Settings"
// side effects (#tour layering, flushing a queued tip) would fire too
// early.
function openSettingsScreen(id){
  SETTINGS_OVERLAY_IDS.forEach(otherId => { if (otherId !== id) document.getElementById(otherId).classList.remove("open"); });
  openOverlay(id);
}
function closeOverlay(id){
  document.getElementById(id).classList.remove("open");
  if (lastFocused && document.contains(lastFocused)) lastFocused.focus();
  // Only when NONE of the four settings screens is still open -- moving
  // between them can close one without openSettingsScreen().
  if (SETTINGS_OVERLAY_IDS.includes(id) && !anySettingsOpen()){
    document.getElementById("tour").classList.remove("behind-settings");
  }
  // The BINGO reward closes by its button, a backdrop tap or Escape; every
  // one must finish the sequence, or #jobSheet stays locked (frozen game).
  if (id === "bingoClearOverlay") finishBingoSequence();
  // A tick later, so a card closed to open another (an element card) wins.
  if (id === "cardPop" && capstoneMarketPending) setTimeout(openNextCapstoneMarket, 0);
  // #convertGoalCard sits above #convert's box, so the closing slide doesn't
  // carry it off-screen -- clear it here (every close path comes through).
  // Reset convertGoalEntry too: render() calls renderConvertGoalCard() every
  // time and would repopulate it.
  if (id === "convert"){
    convertGoalEntry = null;
    document.getElementById("convertGoalCard").innerHTML = "";
    document.getElementById("convertScrim").classList.remove("open");
  }
  // Hand #backdrop back to updateBackdrop() after an end screen forced it
  // on (showSessionEndBackdrop()).
  if (id === "endGame") updateBackdrop();
  updateHub();
  // No-op unless this closed the last blocking overlay and a tip queued
  // meanwhile, so it's safe to call unconditionally.
  flushPendingMouseTip();
}
const anyOverlayOpen = () => !!document.querySelector(".overlay.open");

/* One FIFO queue for event toasts (see #eventToast). kind picks the
   .et-<kind> class; icon is raw HTML; bonus is optional. */
let eventToastQueue = [];
let eventToastTimer = null;
function queueEventToast(kind, icon, title, name, bonus){
  eventToastQueue.push({kind, icon, title, name, bonus});
  if (!eventToastTimer) showNextEventToast();
}
function showNextEventToast(){
  const toast = document.getElementById("eventToast");
  const t = eventToastQueue.shift();
  if (!t){ eventToastTimer = null; return; }
  toast.className = "et-" + t.kind;
  toast.innerHTML = `
    <span class="ct-icon">${t.icon}</span>
    <span class="ct-body"><div class="ct-title">${esc(t.title)}</div><div class="ct-name">${esc(t.name)}</div></span>
    ${t.bonus ? `<span class="ct-bonus">${esc(t.bonus)}</span>` : ""}`;
  toast.setAttribute("aria-hidden", "false");
  requestAnimationFrame(() => toast.classList.add("show"));
  const dismiss = () => {
    toast.classList.remove("show");
    toast.setAttribute("aria-hidden", "true");
    eventToastTimer = setTimeout(showNextEventToast, 350);
  };
  toast.onclick = dismiss;
  eventToastTimer = setTimeout(dismiss, 3500);
}
