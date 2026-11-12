/* =====================================================================
   input.js -- Input wiring: handleScreenClick() (delegated clicks on #screen),
   global keys (Escape), and overlay scrim taps.
   ===================================================================== */
document.addEventListener("click", hideHint);
document.addEventListener("keydown", e => {
  if (document.body.classList.contains("lockin-playing")){ e.preventDefault(); return; }
  if (e.key === "Escape"){
    // The topmost (last in page order) open overlay.
    const open = [...document.querySelectorAll(".overlay.open")].pop();
    if (open && open.id === "lockInRewardOverlay"){ dismissLockInRewardModal(); return; }
    if (open){ if (!open.hasAttribute("data-no-dismiss")) closeOverlay(open.id); return; }
    if (jobSheet.classList.contains("open")){ closeJobBoard(); return; }
    hideHint(); closeDrawer();
  }
  if (e.key === "i" && !e.metaKey && !e.ctrlKey && !anyOverlayOpen()
      && document.activeElement.tagName !== "INPUT"){
    drawer.classList.contains("open") ? closeDrawer() : openDrawer();
  }
});
// A tap on an overlay's backdrop closes it, except data-no-dismiss ones:
// steps of the opening (capstone choice, pin tip) that the run can't start
// without, so closing them early would leave the game stuck.
document.querySelectorAll(".overlay").forEach(ov => {
  ov.addEventListener("click", ev => {
    if (ev.target === ov && !ov.hasAttribute("data-no-dismiss")) closeOverlay(ov.id);
  });
});

// Named so it can be attached twice: #screen, and #convertGoalCard (an
// itemHTML() card outside #screen, inside the Convert tray), whose buttons
// would otherwise be inert.
function handleScreenClick(ev){
  const todoBadge = ev.target.closest("[data-open-todo]");
  if (todoBadge){ ev.stopPropagation(); openTodoAt(todoBadge.dataset.openTodo); return; }
  const hintEl = ev.target.closest("[data-hint]");
  if (hintEl){
    ev.stopPropagation();
    showHint(hintEl, hintEl.dataset.hint, hintEl.dataset.hintkind);
    return;
  }
  hideHint();

  if (ev.target.closest("#showEndBtn")){ showEndGame(); return; }

  if (ev.target.closest("#emptyElBadgeBtn")){
    openEmptyElPicker();
    return;
  }

  const arrangeLaunchBtn = ev.target.closest("[data-arrange-bg]");
  if (arrangeLaunchBtn){
    state.arrangement.bg = arrangeLaunchBtn.dataset.arrangeBg;
    save();
    openArrangeScreen();
    return;
  }

  const nodeBtn = ev.target.closest("[data-map-node]");
  if (nodeBtn){
    if (startingGiftInProgress) return; // the preview card is mid-gift
    selectedMapStation = selectedMapStation === nodeBtn.dataset.mapNode ? null : nodeBtn.dataset.mapNode;
    syncInitialPickCapstoneTracking();
    render();
    return;
  }

  if (selectedMapStation && ev.target.closest("[data-map-bg]")){
    selectedMapStation = null;
    syncInitialPickCapstoneTracking();
    render();
    return;
  }

  if (ev.target.closest("#collapseCraftedBtn")){
    state.collapseCraftedItems = !state.collapseCraftedItems;
    save();
    render();
    return;
  }

  const cBtn = ev.target.closest("[data-craft]");
  if (cBtn){
    // Not craftable: the button still receives taps (aria-disabled, see
    // itemHTML()) so it can show the "Missing ..." notice.
    if (cBtn.getAttribute("aria-disabled") === "true"){
      bounceCantCraft(cBtn, ENTRIES[+cBtn.dataset.craft], ev);
      return;
    }
    const entry = ENTRIES[+cBtn.dataset.craft];
    // Items with a suit cost stop here for the player to pick which elements to
    // spend (the same balloon as the .isuit-costs branch); the craft waits.
    // suitCostPayable() already gated the button.
    if (itemSuitCosts(entry.name).length){
      const badge = cBtn.closest("[data-item-card]")?.querySelector(".isuit-costs");
      // stopPropagation, or this click would reach the balloon's outside-click
      // listener and close it immediately.
      if (badge){ ev.stopPropagation(); openSuitSpendBalloon(entry, badge); }
      return;
    }
    performSingleCraft(entry);
    return;
  }

  // A suit-cost badge still short ("need"): open Convert with the target set
  // to that suit's least-held element (the player can change it). Checked
  // before the whole-badge-group handler below.
  const needSuitBadge = ev.target.closest(".isuit-badge.need");
  if (needSuitBadge){
    ev.stopPropagation();
    const suit = needSuitBadge.dataset.suit;
    const members = SUIT_CORE_ELEMENTS[suit] || [];
    openConvertScreen();
    convertTo = members.slice().sort((a, b) => count(a) - count(b))[0] || null;
    updateConvertUI();
    const itemCard = needSuitBadge.closest("[data-item-card]");
    const idx = itemCard && +itemCard.dataset.itemCard;
    convertGoalEntry = itemCard ? ENTRIES[idx] : null;
    renderConvertGoalCard();
    return;
  }

  // The suit-cost badge group: opens the same balloon as Craft, so the choice
  // can be made first. If not payable yet, bounce the "Missing ..." notice
  // like Craft.
  const suitBadge = ev.target.closest(".isuit-costs");
  if (suitBadge){
    ev.stopPropagation();
    const card = suitBadge.closest("[data-item-card]");
    const entry = card && ENTRIES[+card.dataset.itemCard];
    if (entry && canCraft(entry) && suitCostPayable(entry)) openSuitSpendBalloon(entry, suitBadge);
    else if (entry) bounceCantCraft(suitBadge, entry, ev);
    return;
  }

  // A missing-element recipe token (.tok.el.need): open Convert targeting
  // that element. Checked before the generic element-card handler below.
  const needElemBtn = ev.target.closest(".tok.el.need[data-elem]");
  if (needElemBtn){
    openConvertScreen();
    convertTo = needElemBtn.dataset.elem;
    updateConvertUI();
    // The token's nearest [data-item-card] is always its own item's card
    // (recipeHTML() is only called from itemHTML()); a copy of that card shows
    // at the top of the tray (#convertGoalCard).
    const itemCard = needElemBtn.closest("[data-item-card]");
    const idx = itemCard && +itemCard.dataset.itemCard;
    convertGoalEntry = itemCard ? ENTRIES[idx] : null;
    // The card's border uses var(--suit), which stations set on .sheet;
    // #convert doesn't, so renderConvertGoalCard() sets it.
    renderConvertGoalCard();
    return;
  }

  // Raw element (pool chip or recipe token): open the same element card as
  // the inventory drawer.
  const elemBtn = ev.target.closest("[data-elem]");
  if (elemBtn){
    showElCardPop(elemBtn.dataset.elem);
    return;
  }

  // Shop card pin toggle, checked before the [data-item-card] fallback.
  // Pinning also tracks the item, with its icon flying into the tracked pill
  // (flyItemToTracker()).
  const shopPinBtn = ev.target.closest("[data-shop-pin]");
  if (shopPinBtn){
    const name = shopPinBtn.dataset.shopPin;
    const iconRect = shopPinBtn.closest(".item")?.querySelector(".iem")?.getBoundingClientRect();
    togglePin(name);
    const track = isPinned(name);
    if (track) selectedJobItem = name;
    render();
    if (track) flyItemToTracker(name, iconRect);
    return;
  }

  // Tapping the CARD (not its Craft button, which returned above) opens the
  // item's playing card, owned or not -- same non-auto-dismissing popup the
  // inventory drawer uses for an owned item.
  const itemCard = ev.target.closest("[data-item-card]");
  if (itemCard){
    const entry = ENTRIES[+itemCard.dataset.itemCard];
    if (entry) showCardPop(entry, false);
    return;
  }

  const pinBtn = ev.target.closest("[data-pin]");
  if (pinBtn){
    const name = pinBtn.dataset.pin;
    const wasPinned = isPinned(name);
    const rowBefore = pinBtn.closest(".refrow");
    const beforeTop = rowBefore ? rowBefore.getBoundingClientRect().top : null;
    togglePin(name);
    render();
    const rowAfter = document.querySelector(`.refrow[data-refname="${cssEsc(name)}"]`);
    if (!wasPinned){
      // Just pinned: snap to its new spot in the pinned section (like
      // goToRefItem()).
      if (rowAfter){
        const topbarH = document.getElementById("topbar").offsetHeight;
        const y = rowAfter.getBoundingClientRect().top + window.scrollY - topbarH - 12;
        window.scrollTo({top: Math.max(0, y), behavior:"instant"});
        rowAfter.classList.add("ref-highlight");
        setTimeout(() => rowAfter.classList.remove("ref-highlight"), 1600);
      }
    } else if (beforeTop !== null && rowAfter){
      // Just UNPINNED -- the row moved back into the main list, but the
      // view itself shouldn't jump at all; re-anchor scroll so it stays
      // exactly where it already was.
      const afterTop = rowAfter.getBoundingClientRect().top;
      (document.scrollingElement || document.documentElement).scrollTop += (afterTop - beforeTop);
    }
    return;
  }

  const jobSelectBtn = ev.target.closest("[data-select-job]");
  if (jobSelectBtn){ toggleJobSelect(jobSelectBtn.dataset.selectJob); return; }

  const refToggleBtn = ev.target.closest("[data-toggle]");
  if (refToggleBtn){
    const path = refToggleBtn.dataset.toggle;
    const beforeTop = refToggleBtn.getBoundingClientRect().top;
    if (jobExpanded.has(path)) jobExpanded.delete(path); else jobExpanded.add(path);
    render();
    // Re-anchor scroll so toggling a tree node doesn't jump the list
    // (collapsing shortens the page and the browser clamps scroll elsewhere).
    const btnAfter = document.querySelector(`[data-toggle="${cssEsc(path)}"]`);
    if (btnAfter){
      const afterTop = btnAfter.getBoundingClientRect().top;
      (document.scrollingElement || document.documentElement).scrollTop += (afterTop - beforeTop);
    }
    return;
  }

}
document.getElementById("screen").addEventListener("click", handleScreenClick);
document.getElementById("convertGoalCard").addEventListener("click", handleScreenClick);

document.getElementById("screen").addEventListener("keydown", ev => {
  const hintEl = ev.target.closest("[data-hint]");
  if (hintEl && (ev.key === "Enter" || ev.key === " ")){
    ev.preventDefault();
    showHint(hintEl, hintEl.dataset.hint, hintEl.dataset.hintkind);
  }
});

document.getElementById("screen").addEventListener("change", ev => {
  if (ev.target.id === "noRepeat"){ state.noRepeat = ev.target.checked; save(); render(); }
});
