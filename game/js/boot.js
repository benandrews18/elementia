/* =====================================================================
   boot.js -- Boot: loads the save, shows the welcome slide when needed, first
   render(). Runs last -- every other file has loaded.
   ===================================================================== */
/* One-time fresh start: a device that played a version from before
   RESET_EPOCH is wiped (clearAllGameData()) and opens as a first-time
   player, with today's default settings (mini-games off, auto card
   inspection on, low motion off). Bump RESET_EPOCH to do it again. */
const RESET_EPOCH_KEY = "elementia-reset-epoch", RESET_EPOCH = "2026-11-12";
if (lsGet(RESET_EPOCH_KEY) !== RESET_EPOCH){
  clearAllGameData();
  try { sessionStorage.clear(); } catch(e){}
  lsSet(RESET_EPOCH_KEY, RESET_EPOCH);
}
loadAll();
// Every load, a refresh included, opens on the main menu.
showWelcomeSlide();
render();
document.getElementById("setVersion").textContent = "Elementia v" + (DATA.version || "dev");

/* The rest of "How to Play" (the guided tour) is opt-in -- reachable from
   Settings, or auto-started here via ?tutorial=1 for testing/linking
   directly to it. */
if (/[?&]tutorial=1/.test(location.search)) startTour();

// Reveal the real UI and retire #bootScreen: state is loaded and the first
// screen is rendered.
document.body.classList.add("game-ready");
