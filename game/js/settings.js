/* =====================================================================
   settings.js -- Settings (including Dev Tools and Rules), reset/main-menu buttons, and
   askConfirm().
   ===================================================================== */
const setMinigamesBox = document.getElementById("setMinigames");
const setGuidedTutorialBox = document.getElementById("setGuidedTutorial");
const setAutoCardInspectionBox = document.getElementById("setAutoCardInspection");
const setLowMotionBox = document.getElementById("setLowMotion");
const setClassicBingoBox = document.getElementById("setClassicBingo");
// Just opens the hub (see #settings' own HTML comment) -- the 3 sub-
// screens each have their own open function/handler below.
function openSettings(){
  openOverlay("settings");
}
document.getElementById("setDevBack").addEventListener("click", () => openSettingsScreen("settings"));
document.getElementById("setClose").addEventListener("click", () => closeOverlay("settings"));

document.getElementById("settingsDevBtn").addEventListener("click", () => openSettingsScreen("settingsDev"));

/* Settings > Tutorial Messages: one row per tip window; a tap closes
   Settings and shows that window as it appears in the game. */
const TUTORIAL_MESSAGES = [
  ["▶️", "How to play", () => openClassicTutorial(null, true)],
  ["📌", "Pin items to your To-Do List", () => openOverlay("pinTip")],
  ["🕒", "Display Mat board checks", () => openMatRules()],
  ["📜", "Display Mat Challenges", () => openOrderTip()],
  ["❓", "Unknown Elements", () => showEmptyElTip()],
];
document.getElementById("tutList").innerHTML = TUTORIAL_MESSAGES.map(([ico, title], i) =>
  `<button type="button" class="setting-row" data-tut="${i}"><span class="setting-ico">${ico}</span>
    <span class="setting-body"><span class="setting-label">${title}</span></span><span class="setbtn">View</span></button>`).join("");
document.getElementById("settingsTutsBtn").addEventListener("click", () => openSettingsScreen("settingsTuts"));
document.getElementById("setTutsBack").addEventListener("click", () => openSettingsScreen("settings"));
document.getElementById("tutList").addEventListener("click", ev => {
  const row = ev.target.closest("[data-tut]");
  if (!row) return;
  closeOverlay("settingsTuts");
  TUTORIAL_MESSAGES[+row.dataset.tut][2]();
});

function openSettingsRules(){
  setMinigamesBox.checked = prefs.minigamesEnabled !== false;
  setGuidedTutorialBox.checked = prefs.guidedTutorialEnabled !== false;
  setAutoCardInspectionBox.checked = prefs.autoCardInspection !== false;
  setLowMotionBox.checked = lowMotion();
  setClassicBingoBox.checked = !!prefs.classicBingo;
  openSettingsScreen("settingsRules");
}
document.getElementById("settingsRulesBtn").addEventListener("click", openSettingsRules);
document.getElementById("setRulesCancel").addEventListener("click", () => closeOverlay("settingsRules"));
document.getElementById("setSave").addEventListener("click", () => {
  prefs.minigamesEnabled = setMinigamesBox.checked;
  // showTutorialHintOnce() itself checks this live, so toggling it off
  // stops any further tips immediately, mid-run included -- no separate
  // state to unwind.
  // Turning tips on also brings back every tip window hidden with its ✕.
  if (setGuidedTutorialBox.checked && prefs.guidedTutorialEnabled === false) prefs.hiddenTips = [];
  prefs.guidedTutorialEnabled = setGuidedTutorialBox.checked;
  prefs.autoCardInspection = setAutoCardInspectionBox.checked;
  prefs.lowMotion = setLowMotionBox.checked;
  prefs.classicBingo = setClassicBingoBox.checked; // read by freshState() at the next run
  savePrefs();
  applyLowMotion();
  closeOverlay("settingsRules");
  render();
});

/* -------------------------------------------------------- confirm --- */
/* Replaces window.confirm(), which sandboxed frames suppress outright. */
let confirmAction = null;
function askConfirm(message, onYes){
  document.getElementById("confirmMsg").textContent = message;
  confirmAction = onYes;
  openOverlay("confirmBox");
}
document.getElementById("confirmYes").addEventListener("click", () => {
  const fn = confirmAction;
  confirmAction = null;
  closeOverlay("confirmBox");
  if (fn) fn();
});
document.getElementById("confirmNo").addEventListener("click", () => {
  confirmAction = null;
  closeOverlay("confirmBox");
});

document.getElementById("resetBtn").addEventListener("click", () => {
  // Starts a new run (restartRun() -> startNewRun()).
  askConfirm("Start a new run? Your inventory and visits will be cleared.", () => {
    closeOverlay("settings");
    restartRun();
  });
});
/* Everything the game keeps on this device: localStorage (save, settings,
   history, trophies, Stars, collections, tutorial tips seen) is cleared
   right away; the service worker and its caches after, best-effort.
   clear() is fine: the page owns the whole origin. Used by the Reset
   button and by boot.js's one-time fresh start. */
function clearAllGameData(){
  try { localStorage.clear(); } catch(e){ /* private-browsing storage bans etc. */ }
  return (async () => {
    try {
      if ("serviceWorker" in navigator){
        const regs = await navigator.serviceWorker.getRegistrations();
        await Promise.all(regs.map(r => r.unregister()));
      }
      if (window.caches && caches.keys){
        const keys = await caches.keys();
        await Promise.all(keys.map(k => caches.delete(k)));
      }
    } catch(e){ /* best-effort */ }
  })();
}
/* Full factory reset: on the reload, loadAll() finds no save, so the
   welcome slide shows and every tip plays again. */
document.getElementById("resetCacheBtn").addEventListener("click", () => {
  askConfirm("Reset the game completely? This clears your save, all settings, and every tutorial message, then reloads to a fresh Main Menu. This can't be undone.", async () => {
    closeOverlay("settingsDev");
    await clearAllGameData();
    location.reload();
  });
});

/* Straight to the title screen; the run underneath is untouched
   (showWelcomeSlide() is presentation only), so Play continues it. Reset
   is its own button beside this. */
document.getElementById("mainMenuBtn").addEventListener("click", () => {
  closeOverlay("settings");
  showWelcomeSlide();
});
