/* =====================================================================
   card-popup.js -- Item card popup (#cardPop) and its buttons,
   the element card popup, and the craft celebration.
   ===================================================================== */
const TAG_COLORS = {MATERIAL:"#8a94a6", COMPONENT:"#3b7fc4", CREATION:"#3fa66b", CAPSTONE:"#c79a2e"};
let cardPopTimer;
// Tracks whatever's currently shown so #cpTreeBtn (added after the card,
// see its own click handler below) knows what to jump to in Item Reference
// without needing to re-derive it from the DOM.
let cardPopEntry = null;
// Cards drilled into (#cpIngredients handler); Back pops one level at a
// time (updateCardPopBackBtn()). Cleared on every fresh open (see
// keepBackStack).
let cardPopBackStack = [];
// Whether the current card is in "mat panel" mode; kept through drill-in and
// Back (reset with cardPopBackStack) so browsing from the mat stays in the
// small panel.
let cardPopMatPanel = false;
/* autoDismiss: true for the post-craft popup; false when tapped to
   inspect. keepBackStack: true only for drill-in/Back calls; otherwise the
   back stack is cleared. matPanel: null leaves cardPopMatPanel unchanged (so
   drill-in/Back can't drop out of panel mode); only openMatCardPop() passes
   true. */
function showCardPop(entry, autoDismiss = true, keepBackStack = false, matPanel = null){
  if (!keepBackStack){ cardPopBackStack = []; cardPopMatPanel = false; }
  if (matPanel !== null) cardPopMatPanel = matPanel;
  cardPopEntry = entry;
  const su = DATA.suits[STATION_BY_NAME[entry.station].suit];
  const cpCard = document.getElementById("cpCard");
  cpCard.style.setProperty("--suit", su.color);
  // Bottom-right corner circle: the station this item is made at (matches
  // every other corner circle's own size/shape -- see .pc-station-badge).
  document.getElementById("cpStationBadge").innerHTML = em(STATION_BY_NAME[entry.station].emoji);
  // Top-right corner stack: up to 3 suit-cost circles (see itemSuitCosts()),
  // empty for a 4-points-or-under item.
  const suitCosts = itemSuitCosts(entry.name);
  document.getElementById("cpSuitCosts").innerHTML = suitCosts.map(s =>
    `<span class="pc-suitcost-badge" style="--suit:${SUIT_COLOR[s]}" title="${ELEMENT_SUIT_LABEL[s]} suit cost">${SUIT_ICON[s]}</span>`).join("");
  document.getElementById("cpName").textContent = entry.name;
  const cpIconEl = document.getElementById("cpIcon");
  cpIconEl.innerHTML = em(entry.emoji);
  cpIconEl.classList.toggle("pc-icon-xl", entry.name === "Gemstone Collection");
  cpIconEl.classList.toggle("pc-icon-lg", PDF_ENLARGED_ICONS.has(entry.name));
  document.getElementById("cpPts").textContent = entry.points;
  const seen = new Set();
  // Elements first, then items by points, like the shop and Item Reference.
  const toks = sortIngredientTokens(entry.reqs.filter(r => {
    const k = r.kind + ":" + r.name;
    if (seen.has(k)) return false;
    seen.add(k); return true;
  }));
  // Icon-only components; tapping opens that ingredient's card (item: this
  // popup again; element: the element card). See the #cpIngredients handler,
  // which stops propagation so the tap doesn't dismiss.
  document.getElementById("cpIngredients").innerHTML = toks.map((r, i) => {
    const body = r.kind === "element"
      ? `<span class="pc-ping elem" data-elem="${esc(r.name)}" title="${esc(r.name)}">${esc(r.name)}</span>`
      : (() => {
          const refIdx = ENTRIES.findIndex(e => e.name === r.name);
          return `<span class="pc-ping"${refIdx >= 0 ? ` data-item-card="${refIdx}"` : ""} title="${esc(r.name)}">${em(r.emoji)}</span>`;
        })();
    return (i ? '<span class="pc-plus">+</span>' : "") + body;
  }).join("");
  updateCardPopBackBtn();
  const pinBtn = document.getElementById("cpPinBtn");
  pinBtn.classList.toggle("active", isPinned(entry.name));
  pinBtn.setAttribute("aria-pressed", isPinned(entry.name));
  // Display Mat controls (Classic, owned, mat-eligible only): the panel gets
  // Place/Remove/Close (#cpMatToggles), other contexts the single #cpMatBtn.
  // This popup is the only add/remove entry point (see toggleMatCard()).
  const matEligible = !!MAT_CARD_BY_NAME[entry.name] && owns(entry.name);
  document.getElementById("cardPop").classList.toggle("mat-panel", cardPopMatPanel);
  document.getElementById("cpMatToggles").hidden = !(cardPopMatPanel && matEligible);
  // Not on the "just crafted" popup (autoDismiss) -- Item Info and the pin
  // are all that card offers (2026-11-03).
  document.getElementById("cpMatBtn").hidden = !(!cardPopMatPanel && matEligible) || autoDismiss;
  if (cardPopMatPanel){
    if (matEligible) setMatToggleState(state.mat.includes(entry.name), null);
  } else if (matEligible){
    setMatBtnState(document.getElementById("cpMatBtn"), state.mat.includes(entry.name));
  }
  openOverlay("cardPop");
  if (cardPopMatPanel) positionCardPopMatPanel();
  // Reset every inline style positionCardPopMatPanel() sets, or a normal card
  // shown after a mat-panel one inherits stale values (a leftover paddingTop
  // once pushed post-craft cards far down the screen).
  else {
    document.getElementById("cardPop").style.paddingTop = "";
    document.getElementById("cpMatBackdrop").style.top = "";
    document.getElementById("cpMatBackdrop").style.bottom = "";
    document.querySelector(".pc-card-scale").style.width = "";
    document.querySelector(".pc-card-scale").style.height = "";
    document.getElementById("cpCard").style.transform = "";
    document.getElementById("cpMatToggles").style.left = "";
    document.getElementById("cpMatToggles").style.bottom = "";
  }
  clearTimeout(cardPopTimer);
  if (autoDismiss) cardPopTimer = setTimeout(() => closeOverlay("cardPop"), 3800);
}
/* Docks the card just under #drawerTop and scales .pc-card to fill the
   space down to the hub (CSS can't size this box -- see the
   #cardPop.mat-panel CSS). Recomputed on every open since #drawerTop's
   height changes. #drawer and .overlay share the same left/right rules, so
   the right edge needs no math; the card WIDTH and the toggle stack's
   position do (see maxCardW). */
function positionCardPopMatPanel(){
  const cardPop = document.getElementById("cardPop");
  const drawerTopBottom = document.getElementById("drawerTop").getBoundingClientRect().bottom;
  const paddingTop = Math.max(0, drawerTopBottom + 10);
  cardPop.style.paddingTop = paddingTop + "px";
  // Available height = the real viewport height, minus the padding-top
  // just set and the hub-reservation padding-bottom every overlay already
  // carries (see .overlay's own comment).
  const hubPad = parseFloat(getComputedStyle(cardPop).paddingBottom) || 0;
  const availH = Math.max(0, window.innerHeight - paddingTop - hubPad);
  // The full-width dim layer (.pc-mat-backdrop) covers the same band as this
  // panel's padding, ignoring the side padding.
  const backdrop = document.getElementById("cpMatBackdrop");
  backdrop.style.top = paddingTop + "px";
  backdrop.style.bottom = hubPad + "px";
  // Card width is capped three ways: by the available height (5:7), at its
  // native 300px, and so the toggle stack (66px) plus breathing room still
  // fits beside it.
  const contentW = cardPop.clientWidth - 20 - 14; // .overlay's own left padding (20) + this panel's own right padding (14)
  const toggleStackW = 66;
  // 56px of slack: with less, the card's shadow blur (0 10px 28px) visually
  // covered the toggles.
  const maxCardW = Math.max(0, Math.min(300, availH * 5 / 7, contentW - toggleStackW - 56));
  const scaleBox = document.querySelector(".pc-card-scale");
  scaleBox.style.width = maxCardW + "px";
  scaleBox.style.height = (maxCardW * 7 / 5) + "px";
  // .pc-card's own natural width (300, its own 5:7 ratio) is the only
  // fixed reference point this needs.
  const scale = maxCardW > 0 ? (maxCardW / 300) : 0.5;
  document.getElementById("cpCard").style.transform = `scale(${scale})`;
  // Toggle stack: flush left, centred against the card's height (both share
  // the same bottom anchor).
  const cardW = maxCardW, cardH = maxCardW * 7 / 5;
  const toggles = document.getElementById("cpMatToggles");
  const togglesH = toggles.offsetHeight;
  // Toggles pinned flush to the content box's left edge (the same 20px page
  // margin as other edge controls), so all the slack sits between them and
  // the card.
  toggles.style.left = "0px";
  toggles.style.bottom = Math.max(0, (cardH - togglesH) / 2) + "px";
}
/* Place/Remove state. onMat: whether the card is on the mat now.
   bounceTarget: "place" | "remove" | null -- the button that just became
   active and should bounce. */
function setMatToggleState(onMat, bounceTarget){
  const placeBtn = document.getElementById("cpPlaceBtn");
  const removeBtn = document.getElementById("cpRemoveBtn");
  placeBtn.classList.toggle("lit", !onMat);
  removeBtn.classList.toggle("lit", onMat);
  placeBtn.disabled = onMat;
  removeBtn.disabled = !onMat;
  if (bounceTarget === "place"){ placeBtn.classList.remove("bounce"); void placeBtn.offsetWidth; placeBtn.classList.add("bounce"); }
  if (bounceTarget === "remove"){ removeBtn.classList.remove("bounce"); void removeBtn.offsetWidth; removeBtn.classList.add("bounce"); }
}
/* Shows/hides #cpBackBtn based on cardPopBackStack -- the icon inside it
   is always the entry on top of the stack (the card this one was drilled
   in FROM), never the card currently showing. */
function updateCardPopBackBtn(){
  const btn = document.getElementById("cpBackBtn");
  const prev = cardPopBackStack[cardPopBackStack.length - 1];
  btn.hidden = !prev;
  if (prev) document.getElementById("cpBackIcon").innerHTML = em(prev.emoji);
}
/* Every automatic post-craft popup goes through here, so the "Auto card
   inspection" setting is read in one place. Capstones use celebrate()
   instead. With inspection off, performSingleCraft()'s bounce sequence is
   the feedback. */
function autoCardPop(entry){
  releaseBingoCraftHold();
  if (prefs.autoCardInspection !== false) showCardPop(entry);
}
document.getElementById("cardPop").addEventListener("click", () => {
  clearTimeout(cardPopTimer);
  closeOverlay("cardPop");
});
/* Tapping a component icon opens that ingredient instead of dismissing:
   an item swaps this popup's content (no auto-dismiss); an element closes
   it and opens the element card. Both stop propagation so the tap doesn't
   also dismiss. */
document.getElementById("cpIngredients").addEventListener("click", ev => {
  const itemBtn = ev.target.closest("[data-item-card]");
  if (itemBtn){
    ev.stopPropagation();
    clearTimeout(cardPopTimer);
    // Push the current card onto the back stack first; keepBackStack:true so
    // showCardPop() doesn't clear it.
    if (cardPopEntry) cardPopBackStack.push(cardPopEntry);
    showCardPop(ENTRIES[+itemBtn.dataset.itemCard], false, true);
    return;
  }
  const elBtn = ev.target.closest("[data-elem]");
  if (elBtn){
    ev.stopPropagation();
    clearTimeout(cardPopTimer);
    closeOverlay("cardPop");
    showElCardPop(elBtn.dataset.elem);
  }
});
/* Back: pop the stack and show the new top (keepBackStack:true keeps deeper
   history). */
document.getElementById("cpBackBtn").addEventListener("click", ev => {
  ev.stopPropagation();
  if (!cardPopBackStack.length) return;
  const prev = cardPopBackStack.pop();
  clearTimeout(cardPopTimer);
  showCardPop(prev, false, true);
});
/* "View Item Tree": jump to this item's Item Reference row with one level
   expanded (goToRefItem()). */
document.getElementById("cpTreeBtn").addEventListener("click", ev => {
  ev.stopPropagation();
  if (!cardPopEntry) return;
  const name = cardPopEntry.name;
  clearTimeout(cardPopTimer);
  closeOverlay("cardPop");
  goToRefItem(name);
});
/* Pin toggle: stays on the card, so pinning while browsing doesn't close
   it. */
document.getElementById("cpPinBtn").addEventListener("click", ev => {
  ev.stopPropagation();
  if (!cardPopEntry) return;
  togglePin(cardPopEntry.name);
  const pinned = isPinned(cardPopEntry.name);
  ev.currentTarget.classList.toggle("active", pinned);
  ev.currentTarget.setAttribute("aria-pressed", pinned);
  render();
});
/* Mat toggle: stays on the card, like the pin. toggleMatCard() refreshes
   the drawer itself. */
document.getElementById("cpMatBtn").addEventListener("click", ev => {
  ev.stopPropagation();
  if (!cardPopEntry) return;
  toggleMatCard(cardPopEntry.name);
  setMatBtnState(ev.currentTarget, state.mat.includes(cardPopEntry.name));
});
/* Mat-panel Place/Remove (setMatToggleState()). Each checks `disabled`
   itself, since some browsers still deliver clicks to disabled buttons.
   toggleMatCard() can no-op (mat full), so re-read state.mat afterwards
   rather than assuming success. */
document.getElementById("cpPlaceBtn").addEventListener("click", ev => {
  ev.stopPropagation();
  if (!cardPopEntry || ev.currentTarget.disabled) return;
  const before = state.mat.includes(cardPopEntry.name);
  toggleMatCard(cardPopEntry.name);
  const after = state.mat.includes(cardPopEntry.name);
  setMatToggleState(after, after !== before ? "remove" : null);
});
document.getElementById("cpRemoveBtn").addEventListener("click", ev => {
  ev.stopPropagation();
  if (!cardPopEntry || ev.currentTarget.disabled) return;
  const before = state.mat.includes(cardPopEntry.name);
  toggleMatCard(cardPopEntry.name);
  const after = state.mat.includes(cardPopEntry.name);
  setMatToggleState(after, after !== before ? "place" : null);
});
document.getElementById("cpMatCloseBtn").addEventListener("click", ev => {
  ev.stopPropagation();
  clearTimeout(cardPopTimer);
  closeOverlay("cardPop");
});

/* -------------------------------------------------- element card popup --- */
/* Element card, tapped from an element box -- the only place the atomic
   number is shown. */
function showElCardPop(sym){
  const suit = ELEMENT_SUIT[sym];
  document.getElementById("ecCard").style.setProperty("--suit", ELEMENT_COLOR[sym]);
  const num = ATOMIC_NUMBER[sym] || "";
  document.getElementById("ecNum").textContent = num;
  document.getElementById("ecNum2").textContent = num;
  const icon = SUIT_ICON[suit] || "";
  document.getElementById("ecIconTR").innerHTML = icon;
  document.getElementById("ecIconBL").innerHTML = icon;
  // Metal's glyph is boosted 1.5x and may overlap the bubble edge.
  document.getElementById("ecIconTR").classList.toggle("suit-icon-big", suit === "metal");
  document.getElementById("ecIconBL").classList.toggle("suit-icon-big", suit === "metal");
  document.getElementById("ecSym").textContent = sym;
  document.getElementById("ecName").textContent = ELEMENT_NAMES[sym] || sym;
  document.getElementById("ecPill").textContent = ELEMENT_SUIT_LABEL[suit] || "";
  openOverlay("elCardPop");
}
document.getElementById("elCardPop").addEventListener("click", () => closeOverlay("elCardPop"));

function celebrate(entry){
  releaseBingoCraftHold();
  const n = CAPSTONES.filter(owns).length;
  document.getElementById("celebEmoji").innerHTML = em(entry.emoji);
  document.getElementById("celebName").textContent = entry.name;
  document.getElementById("celebSub").textContent =
    n === 8 ? "That's all eight — you've completed every capstone in Elementia!"
            : `${n} of 8 capstones complete.`;
  openOverlay("celebrate");
  fireConfetti();
}

/* The craft + reveal, called straight away (no suit cost) or once the
   suit-spend balloon confirms. The suit cost must already be paid; craft()
   still checks the recipe itself. */
/* "Bounce closed": the shop card about to move to Crafted Items pops and
   collapses in place (the real element, captured before render()).
   Per-keyframe easing for the two halves. onDone always fires, even with
   nothing to animate, so callers can render. setTimeout, not onfinish:
   onfinish never fires in a background tab, which would leave the old card
   stuck. */
function bounceCardClosed(cardEl, onDone){
  const DURATION = 300;
  if (!cardEl || lowMotion()){ onDone(); return; }
  cardEl.style.pointerEvents = "none";
  cardEl.animate([
    { transform: "scale(1)", opacity: 1, offset: 0, easing: "cubic-bezier(.3,1.4,.4,1)" },
    { transform: "scale(1.05)", opacity: 1, offset: .3, easing: "cubic-bezier(.55,0,.75,.1)" },
    { transform: "scale(0)", opacity: 0, offset: 1 },
  ], { duration: DURATION, fill: "forwards" });
  setTimeout(onDone, DURATION);
}
/* "Bounce appearance": the item's new spot (crafted strip icon or "✓
   Owned" card, both [data-item-card]) pops in after bounceCardClosed().
   No-op if it's not on screen or under reduced motion. */
function bounceCardAppear(targetEl){
  if (!targetEl || lowMotion()) return;
  targetEl.animate([
    { transform: "scale(0)", opacity: 0 },
    { transform: "scale(1.18)", opacity: 1, offset: .6 },
    { transform: "scale(1)", opacity: 1 },
  ], { duration: 320, easing: "cubic-bezier(.3,1.4,.4,1)" });
}

/* ------------------------------------------------------ overlays --- */
document.getElementById("celebClose").addEventListener("click", () => closeOverlay("celebrate"));
