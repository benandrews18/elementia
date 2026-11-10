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
  drawer.classList.add("open"); scrim.classList.add("open");
  drawer.setAttribute("aria-hidden", "false");
  updateHub();
  maybeShowBreakpointGateNotice();
};
const closeDrawer = () => {
  setMatCollapsed(false);
  // Combo Lab hides #hub, so this close is the lab's only exit.
  if (comboLabActive){ closeComboLab(); return; }
  // Remove .expanded here: translateY(100%) only moves the box by its own
  // height, so closing while expanded would leave its top edge visible above
  // the hub.
  drawer.classList.remove("open", "expanded"); scrim.classList.remove("open");
  matTrayExpanded = false;
  drawer.setAttribute("aria-hidden", "true");
  // #matSortBtn/#matFilterBtn are separate fixed elements, so closing the
  // drawer must hide them (and their trays) too, or they'd sit over
  // #pinsBtn/#quickConvertBtn.
  document.getElementById("matSortBtn").hidden = true;
  document.getElementById("matFilterBtn").hidden = true;
  document.getElementById("matHideBtn").hidden = true;
  closeMatSideTrays();
  updateHub();
};

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
// "^" on the gold divider: hide/show the Display Mat zone so the card list
// gets the whole tray (#matCollapseBar). Resets to shown on every open.
function setMatCollapsed(on){
  drawer.classList.toggle("mat-collapsed", on);
  for (const id of ["matCollapseBtn", "matHideBtn"]){
    const btn = document.getElementById(id);
    btn.setAttribute("aria-expanded", String(!on));
    btn.setAttribute("aria-label", on ? "Show the Display Mat" : "Hide the Display Mat");
    btn.title = btn.getAttribute("aria-label");
  }
}
for (const id of ["matCollapseBtn", "matHideBtn"])
  document.getElementById(id).addEventListener("click", () =>
    setMatCollapsed(!drawer.classList.contains("mat-collapsed")));
function collapseDrawerToPeeked(){
  setMatCollapsed(false);
  matTrayExpanded = false;
  drawer.classList.remove("expanded");
  renderMatTop();
  updateHub();
}
