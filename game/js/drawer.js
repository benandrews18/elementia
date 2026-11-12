/* =====================================================================
   drawer.js -- Inventory drawer: open/close, peeked vs expanded, and renderDrawer().
   ===================================================================== */
const drawer = document.getElementById("drawer"), scrim = document.getElementById("scrim");
// Combo Lab (openComboLab()): comboLabActive blocks save() and turns
// closeDrawer() into the lab's exit (the hub is hidden).
let comboLabActive = false;
let realGameState = null, realScreen = null, realCurrent = null, realSelectedMapStation = null;
// "Peeked" (half view) is opt-in via opts.peeked; every other opener lands
// on the full list. Set here directly, since render() runs in the
// background and may have left .expanded either way.
const openDrawer = (opts = {}) => {
  setMatCollapsed(false);
  matTrayExpanded = !opts.peeked;
  drawer.classList.toggle("expanded", !opts.peeked);
  // render() skips the inventory while it's closed, so build it now.
  document.getElementById("drawerBody").innerHTML = renderDrawer();
  drawer.classList.add("open"); scrim.classList.add("open");
  drawer.setAttribute("aria-hidden", "false");
  syncMatFloatBtns();
  updateHub();
};
const closeDrawer = () => {
  setMatCollapsed(false);
  matListOpen = null;
  // Combo Lab hides #hub, so this close is the lab's only exit.
  if (comboLabActive){ closeComboLab(); return; }
  // Remove .expanded here: translateY(100%) only moves the box by its own
  // height, so closing while expanded would leave its top edge visible above
  // the hub.
  drawer.classList.remove("open", "expanded"); scrim.classList.remove("open");
  matTrayExpanded = false;
  drawer.setAttribute("aria-hidden", "true");
  syncMatFloatBtns();
  updateHub();
};

// Sort/Filter/Hide-mat float outside #drawer and only apply to the full
// item list, so show them exactly when matTrayExpanded. Call after every
// change to it: opening the tray doesn't redraw the mat.
function syncMatFloatBtns(){
  for (const id of ["matSortBtn", "matFilterBtn"])
    document.getElementById(id).hidden = !matTrayExpanded;
  if (!matTrayExpanded) closeMatSideTrays();
  syncMatListActions();
}

function renderDrawer(){
  return renderClassicDrawer();
}

// Expand a peeked drawer to the full view (used by #hubInv and by tapping a
// mat card while peeked). Returns false if the drawer isn't open-and-peeked.
function expandDrawerToFull(){
  if (!(drawer.classList.contains("open") && !drawer.classList.contains("expanded"))) return false;
  matTrayExpanded = true;
  drawer.classList.add("expanded");
  renderMatTop();
  updateHub();
  return true;
}
// Mirror of expandDrawerToFull(): collapse to the peeked view without
// closing. Only used mid Lock-In (#hubInv's handler).
// #matCollapseBtn: collapse the Display Mat to its minimized board (meter,
// combos, a row of the mat's icons) so the list gets the tray. Resets to
// shown on every open.
function setMatCollapsed(on){
  drawer.classList.toggle("mat-collapsed", on);
  const btn = document.getElementById("matCollapseBtn");
  btn.setAttribute("aria-expanded", String(!on));
  btn.setAttribute("aria-label", on ? "Show the Display Mat" : "Hide the Display Mat");
  btn.title = btn.getAttribute("aria-label");
}
document.getElementById("matCollapseBtn").addEventListener("click", () =>
  setMatCollapsed(!drawer.classList.contains("mat-collapsed")));
function collapseDrawerToPeeked(){
  setMatCollapsed(false);
  matTrayExpanded = false;
  drawer.classList.remove("expanded");
  renderMatTop();
  updateHub();
}
