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
/* autoDismiss: true for the post-craft popup; false when tapped to
   inspect. keepBackStack: true only for drill-in/Back calls; otherwise the
   back stack is cleared. */
function showCardPop(entry, autoDismiss = true, keepBackStack = false){
  if (!keepBackStack) cardPopBackStack = [];
  document.getElementById("cpCeleb").hidden = true;
  document.getElementById("cpCeleb").className = "cp-celeb";
  cardPopEntry = entry;
  // Capstones show as a double-wide (landscape) card with room for their
  // Display Mat rule.
  const isCap = ITEM_TIER[entry.name] === "CAPSTONE";
  document.getElementById("cardPop").classList.toggle("cap-landscape", isCap);
  const sig = document.getElementById("cpSig");
  sig.textContent = (isCap && CAPSTONE_SIGNATURES[entry.name]) || "";
  sig.hidden = !sig.textContent;
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
  // 6+ components (Fruit Cake): slightly smaller so they fit one line.
  document.getElementById("cpIngredients").classList.toggle("many", toks.length >= 6);
  // 10+ (Planet's 16 elements): smaller chips, no "+", so they fit the card.
  document.getElementById("cpIngredients").classList.toggle("lots", toks.length >= 10);
  document.getElementById("cpIngredients").innerHTML = toks.map((r, i) => {
    const body = r.kind === "element"
      ? `<span class="pc-ping elem" data-elem="${esc(r.name)}" title="${esc(r.name)}">${esc(r.name)}</span>`
      : (() => {
          const refIdx = ENTRIES.findIndex(e => e.name === r.name);
          // Owned components get the shop's green check (.tok-check).
          const check = owns(r.name) ? '<span class="tok-check">✓</span>' : "";
          return `<span class="pc-ping"${refIdx >= 0 ? ` data-item-card="${refIdx}"` : ""} title="${esc(r.name)}${owns(r.name) ? " (owned)" : ""}">${em(r.emoji)}${check}</span>`;
        })();
    return (i ? '<span class="pc-plus">+</span>' : "") + body;
  }).join("");
  updateCardPopBackBtn();
  const pinBtn = document.getElementById("cpPinBtn");
  pinBtn.classList.toggle("active", isPinned(entry.name));
  pinBtn.setAttribute("aria-pressed", isPinned(entry.name));
  openOverlay("cardPop");
  clearTimeout(cardPopTimer);
  if (autoDismiss) cardPopTimer = setTimeout(() => closeOverlay("cardPop"), 3800);
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
// holdMs: how long the card waits before flying to the Inventory (the
// craft animation stretches it to cover its element pop).
function autoCardPop(entry, holdMs = 300){
  releaseBingoCraftHold();
  if (prefs.autoCardInspection === false) return;
  if (lowMotion()){ showCardPop(entry); return; } // static card, closes itself
  // A small card, no backdrop. After a short look it flies into the
  // Inventory; tapping it first opens the full inspection, which then stays
  // until dismissed.
  const wrap = document.createElement("div");
  wrap.innerHTML = miniItemCardHTML(entry.name, entry.emoji);
  const card = wrap.firstElementChild;
  card.classList.add("craft-peek");
  card.setAttribute("role", "button");
  card.setAttribute("aria-label", `${entry.name} -- tap to inspect`);
  document.body.appendChild(card);
  const pop = card.animate([
    { transform: "translate(-50%,-50%) scale(.6)", opacity: 0 },
    { transform: "translate(-50%,-50%) scale(1)", opacity: 1 },
  ], { duration: 220, easing: "cubic-bezier(.3,1.4,.4,1)", fill: "forwards" });
  let fly = null;
  const timer = setTimeout(() => {
    const r = document.getElementById("hubInv").getBoundingClientRect(), cr = card.getBoundingClientRect();
    const dx = r.left + r.width / 2 - (cr.left + cr.width / 2), dy = r.top + r.height / 2 - (cr.top + cr.height / 2);
    card.style.pointerEvents = "none";
    fly = card.animate([
      { transform: "translate(-50%,-50%) scale(1)", opacity: 1 },
      { transform: `translate(-50%,-50%) translate(${dx}px, ${dy}px) scale(.15)`, opacity: .4 },
    ], { duration: 450, easing: "cubic-bezier(.5,0,.75,.4)", fill: "forwards" });
    fly.onfinish = () => { card.remove(); punchInventory(); };
  }, 220 + holdMs);
  card.addEventListener("click", ev => {
    ev.stopPropagation();
    clearTimeout(timer);
    if (fly) return;
    pop.cancel();
    card.remove();
    showCardPop(entry, false);
  });
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

/* A capstone just crafted: its full inspection card under a "Capstone
   complete" banner, with confetti. Closing it (capstoneMarketPending, see
   closeOverlay()) nudges the player to track the next capstone, opening the
   Marketplace only for the run's first capstone. Then the items that
   capstone unlocks get their own reveal (queueUnlockReveal()). */
let capstoneMarketPending = false;
function celebrate(entry){
  releaseBingoCraftHold();
  const n = CAPSTONES.filter(owns).length;
  showCardPop(entry, false);
  const banner = document.getElementById("cpCeleb");
  banner.innerHTML = `🏆 Capstone complete!<small>${n === 8
    ? "That's all eight -- every capstone in Elementia!" : `${n} of 8 capstones`}</small>`;
  banner.hidden = false;
  capstoneMarketPending = n < 8;
  queueUnlockReveal(entry.name);
  fireConfetti();
}
// After the capstone card closes: a nudge to track the next capstone. The
// Marketplace itself opens only after the run's first capstone
// (state.sawCapstoneMarket); later ones open it only through a completed
// Market row (the BINGO sequence).
function openNextCapstoneMarket(){
  capstoneMarketPending = false;
  if (state.ended) return;
  if (!state.sawCapstoneMarket && !document.querySelector(".overlay.open")){
    state.sawCapstoneMarket = true; save();
    openJobSelectTray();
  }
  queueEventToast("market", "🏆", "Pick your next capstone", "Pin one in the Marketplace to track it");
}

/* "New Items Unlocked!": a capstone's unlock items (data.js "unlock" rows,
   UNLOCKED_BY) pop onto a dimmed screen in full colour, once the screen is
   clear -- the capstone card closed and any Marketplace tray dismissed.
   Tap to dismiss. */
let unlockRevealQueue = [], unlockRevealTimer = null;
function queueUnlockReveal(capName){
  const names = [...new Set(ENTRIES.filter(e => UNLOCKED_BY[e.name] === capName).map(e => e.name))];
  if (!names.length) return;
  unlockRevealQueue.push({ capName, names });
  maybeShowUnlockReveal();
}
function maybeShowUnlockReveal(){
  if (!unlockRevealQueue.length || unlockRevealTimer) return;
  const busy = anyOverlayOpen() || !!openPanelName() || capstoneMarketPending || bingoClearInProgress
    || document.body.classList.contains("lockin-playing") || comboLabActive;
  if (busy){
    unlockRevealTimer = setTimeout(() => { unlockRevealTimer = null; maybeShowUnlockReveal(); }, 400);
    return;
  }
  const { capName, names } = unlockRevealQueue.shift();
  const cap = ENTRIES.find(e => e.name === capName);
  const step = lowMotion() ? 0 : 140;
  document.getElementById("unlockRevealBody").innerHTML = `
    <h2 class="ur-title">New Items Unlocked!</h2>
    <p class="ur-sub">${cap ? em(cap.emoji) : ""} ${esc(capName)} opened up ${names.length === 1 ? "a new item" : `${names.length} new items`}</p>
    <div class="ur-grid">${names.map((n, i) =>
      `<div class="ur-card" style="animation-delay:${300 + i * step}ms">${matCardHTML(n, { plain: true })}</div>`).join("")}</div>
    <p class="ur-tap">Tap to continue</p>`;
  openOverlay("unlockReveal");
}
// Any tap closes it; the next queued reveal (if any) follows.
document.getElementById("unlockReveal").addEventListener("click", () => {
  closeOverlay("unlockReveal");
  setTimeout(maybeShowUnlockReveal, 300);
});

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
