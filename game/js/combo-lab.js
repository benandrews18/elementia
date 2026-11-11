/* =====================================================================
   combo-lab.js -- Combo Lab sandbox.

   Combo Lab: a sandbox for Display Mat combos, opened from the welcome
   screen (#tourComboLabBtn). Reuses the real #drawer and mat code, forced
   .open.expanded, with everything else hidden ([data-combo-lab] CSS).
   Safe because `state` is swapped for a throwaway object (the real one is
   stashed in realGameState and restored on exit) and comboLabActive blocks
   save().
   ===================================================================== */
function openComboLab(){
  realGameState = state; realScreen = screen; realCurrent = current; realSelectedMapStation = selectedMapStation;
  const lab = freshState();
  lab.mode = "classic"; // required for renderDrawer()/showCardPop() etc. to treat this as Classic at all
  lab.items = [...CORE_ITEM_NAMES]; // every Classic item "owned" -- the whole point of the lab
  lab.bingoCenterChosen = true; // sidesteps the BINGO opening sequence's own checks, never shown here anyway
  // Visit 20 so the Quark Meter thresholds (lockInTiersForRound()) have
  // real headroom to experiment against.
  lab.visits = 20;
  state = lab;
  screen = "map"; current = null; selectedMapStation = null;
  comboLabActive = true;
  matDrawerView = "mat";
  matTrayExpanded = true;
  document.body.setAttribute("data-combo-lab", "");
  document.getElementById("drawerHead").textContent = "🧪 Combo Lab";
  document.getElementById("drawerScore").hidden = true;
  document.getElementById("closeDrawer").setAttribute("aria-label", "Exit Combo Lab");
  const drawerEl = document.getElementById("drawer");
  drawerEl.classList.add("open", "expanded");
  drawerEl.setAttribute("aria-hidden", "false");
  render();
}
function closeComboLab(){
  comboLabActive = false;
  state = realGameState; screen = realScreen; current = realCurrent; selectedMapStation = realSelectedMapStation;
  realGameState = null;
  document.body.removeAttribute("data-combo-lab");
  document.getElementById("drawerHead").textContent = "🎒 Inventory";
  document.getElementById("drawerScore").hidden = false;
  document.getElementById("closeDrawer").setAttribute("aria-label", "Close inventory");
  matTrayExpanded = false;
  const drawerEl = document.getElementById("drawer");
  drawerEl.classList.remove("open", "expanded");
  drawerEl.setAttribute("aria-hidden", "true");
  syncMatFloatBtns();
  render();
}
document.getElementById("tourComboLabBtn").addEventListener("click", () => {
  endTour();
  openComboLab();
});
document.getElementById("comboLabExitBtn").addEventListener("click", closeComboLab);
document.getElementById("closeDrawer").addEventListener("click", closeDrawer);
scrim.addEventListener("click", closeDrawer);
document.getElementById("drawerBody").addEventListener("click", ev => {
  if (ev.target.closest("#openConvertBtn")){ closeDrawer(); openConvertScreen(); return; }
  if (ev.target.closest("#openArrangeBtn")){ closeDrawer(); openArrangeScreen(); return; }
  // Tier breakline (see MAT_TIER_BANDS/matTierCollapsed) -- collapses/
  // expands just that one section's own grid.
  const tierHeading = ev.target.closest("[data-mat-tier]");
  if (tierHeading){
    const key = tierHeading.dataset.matTier;
    matTierCollapsed.has(key) ? matTierCollapsed.delete(key) : matTierCollapsed.add(key);
    renderMatResultsGrid();
    return;
  }
  // The results grid (renderClassicDrawer()): tap opens the card popup
  // (openMatCardPop()), where adding/removing happens.
  const elBtn = ev.target.closest("[data-elem]");
  if (elBtn){ showElCardPop(elBtn.dataset.elem); return; }
  const listRow = ev.target.closest("[data-mat-row]");
  if (listRow){ toggleMatListRow(listRow.dataset.matRow); return; }
  const matCard = ev.target.closest("[data-mat-card]");
  if (matCard){ openMatCardPop(matCard.dataset.matCard); return; }
  const iBtn = ev.target.closest("[data-item]");
  if (!iBtn) return;
  const entry = ENTRIES.find(e => e.name === iBtn.dataset.item);
  if (entry) showCardPop(entry, false);
});
