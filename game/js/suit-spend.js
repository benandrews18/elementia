/* =====================================================================
   suit-spend.js -- Suit-spend balloon: a speech bubble on the suit-cost badge that opened it
   (tapping the badge, or Craft on an item with a suit cost). One row of
   .convert-pick elements per required suit (its four core elements,
   SUIT_CORE_ELEMENTS); no text, by design. Tapping spends toward that suit;
   once every row is picked it confirms itself (deducts, then
   performSingleCraft()).
   ===================================================================== */
let suitSpendEntry = null, suitSpendPicks = {}, suitSpendAnchor = null;
// Optional hook for a caller that needs to know when this balloon's craft
// goes through (e.g. openBingoCraftOverlay()). null for the shop.
let suitSpendOnCraft = null;
function suitSpendPickedForSuit(suit){
  // shortcut: "any" counts every pick -- right while Planet (the only "any" item) has no other tag; revisit if one ever mixes them.
  return Object.keys(suitSpendPicks).filter(sym => suit === "any" || ELEMENT_SUIT[sym] === suit)
    .reduce((sum, sym) => sum + suitSpendPicks[sym], 0);
}
function closeSuitSpendBalloon(){
  document.getElementById("suitSpendBalloon").classList.remove("open", "above", "below");
  suitSpendEntry = null; suitSpendPicks = {}; suitSpendAnchor = null; suitSpendOnCraft = null;
  clearSuitBadgeProgress();
}
/* While the balloon is open, the card's suit-cost badges ring green on each
   slot not yet picked. Updated directly on those nodes (no render()) so the
   balloon anchored to them isn't rebuilt mid-pick. */
function updateSuitBadgeProgress(){
  if (!suitSpendEntry) return;
  const group = document.querySelector(`[data-item-card="${ENTRIES.indexOf(suitSpendEntry)}"] .isuit-costs`);
  if (!group) return;
  const seenCount = {};
  group.querySelectorAll(".isuit-badge").forEach(badge => {
    const suit = badge.dataset.suit;
    const idx = seenCount[suit] || 0;
    seenCount[suit] = idx + 1;
    badge.classList.toggle("picking", suitSpendPickedForSuit(suit) <= idx);
  });
}
function clearSuitBadgeProgress(){
  document.querySelectorAll(".isuit-badge.picking").forEach(b => b.classList.remove("picking"));
}
/* Above the badge, or flipped below if it would run off the top (like
   placeHint()), centred horizontally. Re-run after every render. */
function placeSuitSpendBalloon(anchor){
  const b = document.getElementById("suitSpendBalloon");
  const r = anchor.getBoundingClientRect();
  const br = b.getBoundingClientRect();
  let left = r.left + window.scrollX + r.width / 2 - br.width / 2;
  left = Math.max(8, Math.min(left, window.scrollX + window.innerWidth - br.width - 8));
  let top = r.top + window.scrollY - br.height - 12;
  const above = top >= window.scrollY + 4;
  if (!above) top = r.bottom + window.scrollY + 12;
  b.classList.toggle("above", above);
  b.classList.toggle("below", !above);
  b.style.left = left + "px";
  b.style.top = top + "px";
  // The tail stays centred on the real badge even when the bubble shifts to
  // fit on screen.
  const anchorCenter = r.left + window.scrollX + r.width / 2;
  b.querySelector(".ssb-tail").style.left = Math.max(14, Math.min(anchorCenter - left, br.width - 14)) + "px";
}
function openSuitSpendBalloon(entry, anchor, onCraft = null){
  suitSpendEntry = entry;
  suitSpendPicks = {};
  suitSpendAnchor = anchor;
  suitSpendOnCraft = onCraft;
  document.getElementById("suitSpendBalloon").classList.add("open");
  renderSuitSpendBalloon();
}
function renderSuitSpendBalloon(){
  const entry = suitSpendEntry;
  const need = suitCostNeed(entry);
  const {els: reserved} = needsOf(entry.reqs);
  const SUIT_ORDER = [...Object.keys(ELEMENT_SUIT_LABEL), "any"];
  document.getElementById("suitSpendRows").innerHTML = SUIT_ORDER.filter(s => need[s]).map(suit => {
    const row = SUIT_CORE_ELEMENTS[suit].map(sym => {
      const avail = Math.max(0, count(sym) - (reserved[sym] || 0));
      const have = suitSpendPicks[sym] || 0;
      const suitStyle = `style="--suit:${ELEMENT_COLOR[sym] || "#8a94a6"}"`;
      const inert = avail <= 0 && have === 0;
      return `<button type="button" class="convert-pick ${inert ? "invalid" : ""}" data-sym="${esc(sym)}" data-suit="${suit}" ${inert ? "disabled" : ""} title="${esc(ELEMENT_NAMES[sym] || sym)}">
          <span class="elsym" ${suitStyle}>${esc(sym)}${elSuitBadgeHTML(sym)}</span>
          <span class="pickqty">×${avail}</span>
          ${have > 0 ? `<span class="ssb-picked">${have}</span>` : ""}
        </button>`;
    }).join("");
    return `<div class="ssb-row">${row}</div>`;
  }).join("");
  if (suitSpendAnchor) placeSuitSpendBalloon(suitSpendAnchor);
  updateSuitBadgeProgress();
}
document.getElementById("suitSpendRows").addEventListener("click", ev => {
  const btn = ev.target.closest("[data-sym]");
  if (!btn || !suitSpendEntry) return;
  ev.stopPropagation();
  const entry = suitSpendEntry;
  const sym = btn.dataset.sym, suit = btn.dataset.suit;
  const {els: reserved} = needsOf(entry.reqs);
  const need = suitCostNeed(entry);
  const avail = Math.max(0, count(sym) - (reserved[sym] || 0));
  const have = suitSpendPicks[sym] || 0;
  const othersPickedForSuit = suitSpendPickedForSuit(suit) - have;
  const maxForSym = Math.min(avail, need[suit] - othersPickedForSuit);
  if (maxForSym <= 0) return;
  // Tap-to-cycle: +1 each tap, wrapping back to 0 once this symbol alone
  // is already covering everything its suit still needs from it.
  const next = have >= maxForSym ? 0 : have + 1;
  if (next === 0) delete suitSpendPicks[sym]; else suitSpendPicks[sym] = next;
  const ready = Object.keys(need).every(s => suitSpendPickedForSuit(s) === need[s]);
  if (!ready){ renderSuitSpendBalloon(); return; }
  // Every row satisfied -- spend the picks for real and hand off to the
  // exact same post-craft pipeline the item's Craft tap normally does.
  Object.keys(suitSpendPicks).forEach(pickedSym => {
    state.elements[pickedSym] = count(pickedSym) - suitSpendPicks[pickedSym];
    if (state.elements[pickedSym] <= 0) delete state.elements[pickedSym];
  });
  save();
  // Captured before closeSuitSpendBalloon() clears it -- see
  // suitSpendOnCraft's own comment above.
  const onCraft = suitSpendOnCraft, taxPicks = {...suitSpendPicks};
  closeSuitSpendBalloon();
  performSingleCraft(entry, taxPicks);
  if (onCraft) onCraft();
});
// Any click outside the balloon cancels it with no state change. Its own
// open/close taps stop propagation so they don't trigger this.
document.addEventListener("click", ev => {
  if (suitSpendEntry && !ev.target.closest("#suitSpendBalloon")) closeSuitSpendBalloon();
});
