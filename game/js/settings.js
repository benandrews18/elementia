/* =====================================================================
   settings.js -- Settings (including Dev Tools and Rules), reset/main-menu buttons, and
   askConfirm().
   ===================================================================== */
const setMinigamesBox = document.getElementById("setMinigames");
const setGuidedTutorialBox = document.getElementById("setGuidedTutorial");
const setAutoCardInspectionBox = document.getElementById("setAutoCardInspection");
const setLowMotionBox = document.getElementById("setLowMotion");
// Just opens the hub (see #settings' own HTML comment) -- the 3 sub-
// screens each have their own open function/handler below.
function openSettings(){
  openOverlay("settings");
}
document.getElementById("setDevBack").addEventListener("click", () => openSettingsScreen("settings"));
document.getElementById("setClose").addEventListener("click", () => closeOverlay("settings"));

const setExpCompassTrackingBox = document.getElementById("setExpCompassTracking");
const setExpTieredConversionBox = document.getElementById("setExpTieredConversion");
const setExpTractorHarvestBox = document.getElementById("setExpTractorHarvest");
function openSettingsDev(){
  setExpCompassTrackingBox.checked = !!prefs.expCompassTracking;
  setExpTieredConversionBox.checked = !!prefs.expTieredConversion;
  setExpTractorHarvestBox.checked = !!prefs.expTractorHarvest;
  openSettingsScreen("settingsDev");
}
document.getElementById("settingsDevBtn").addEventListener("click", openSettingsDev);
// Applies immediately (no Save): a dev toggle, not a game rule.
setExpCompassTrackingBox.addEventListener("change", () => {
  prefs.expCompassTracking = setExpCompassTrackingBox.checked;
  savePrefs();
});
setExpTieredConversionBox.addEventListener("change", () => {
  prefs.expTieredConversion = setExpTieredConversionBox.checked;
  savePrefs();
  updateHub(); // Convert button's own icon reflects the new rate immediately
});
setExpTractorHarvestBox.addEventListener("change", () => {
  prefs.expTractorHarvest = setExpTractorHarvestBox.checked;
  savePrefs();
  applyDiceCount(); // may add/remove the +1 bonus immediately if a Tractor's already owned
});

function openSettingsRules(){
  setMinigamesBox.checked = prefs.minigamesEnabled !== false;
  setGuidedTutorialBox.checked = prefs.guidedTutorialEnabled !== false;
  setAutoCardInspectionBox.checked = prefs.autoCardInspection !== false;
  setLowMotionBox.checked = lowMotion();
  openSettingsScreen("settingsRules");
}
document.getElementById("settingsRulesBtn").addEventListener("click", openSettingsRules);
document.getElementById("setRulesCancel").addEventListener("click", () => closeOverlay("settingsRules"));
document.getElementById("setSave").addEventListener("click", () => {
  prefs.minigamesEnabled = setMinigamesBox.checked;
  // showTutorialHintOnce() itself checks this live, so toggling it off
  // stops any further tips immediately, mid-run included -- no separate
  // state to unwind.
  prefs.guidedTutorialEnabled = setGuidedTutorialBox.checked;
  prefs.autoCardInspection = setAutoCardInspectionBox.checked;
  prefs.lowMotion = setLowMotionBox.checked;
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
  // Resets only the current mode and stays in it (resetCurrentModeRun() ->
  // startFreshMode()).
  askConfirm("Start a new run? Your inventory and visits will be cleared.", () => {
    closeOverlay("settings");
    resetCurrentModeRun();
  });
});
/* Full factory reset: unregisters the service worker, clears its caches,
   and clears localStorage (every mode's save, prefs, history, legacy keys)
   -- including tutorialHintsSeen, so every tip plays again. On the reload,
   loadAll() finds no save, so the welcome slide shows. clear() is fine: the
   page owns the whole origin. */
document.getElementById("resetCacheBtn").addEventListener("click", () => {
  askConfirm("Reset the game completely? This clears your save, all settings, and every tutorial message, then reloads to a fresh Main Menu. This can't be undone.", async () => {
    closeOverlay("settingsDev");
    try {
      if ("serviceWorker" in navigator){
        const regs = await navigator.serviceWorker.getRegistrations();
        await Promise.all(regs.map(r => r.unregister()));
      }
      if (window.caches && caches.keys){
        const keys = await caches.keys();
        await Promise.all(keys.map(k => caches.delete(k)));
      }
    } catch(e){ /* best-effort -- still reload below even if this failed */ }
    try { localStorage.clear(); } catch(e){ /* best-effort -- private-browsing storage bans etc. */ }
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
