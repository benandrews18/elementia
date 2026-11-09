/* =====================================================================
   station.js -- Station screen: renderStation() (header, element pool, roll bar, shop,
   capstone) and the shop list.
   ===================================================================== */
function renderStation(name){
  const s = STATION_BY_NAME[name], su = DATA.suits[s.suit];
  const all = entriesAt(name);
  const allShop     = all.filter(e => e.tier !== "CAPSTONE");
  // Items unlocked by the latest craft stay hidden until the card popup
  // closes (flushPendingReveal()).
  const shopEntries = sortShopItems(allShop.filter(isRevealed)
    .filter(e => !(pendingRevealStation === name && pendingRevealNames && pendingRevealNames.includes(e.name))));
  const capEntry    = all.find(e => e.tier === "CAPSTONE");
  const capRevealed = !!capEntry && isRevealed(capEntry);
  const idx = e => ENTRIES.indexOf(e);
  shopEntries.forEach(e => markSeen(e.name));
  if (capRevealed) markSeen(capEntry.name);
  // Tutorial follow-up to openPinsTray()'s hint: the first time a shop shows
  // the tracked item's badge (itemHTML()'s pinBadge), point it out once.
  if (selectedJobItem){
    const jobTree = new Set([selectedJobItem, ...stillNeededClosure(selectedJobItem)]);
    if (shopEntries.some(e => jobTree.has(e.name))){
      showTutorialHintOnce("pintrackshop", 7,
        "This badge marks what it feeds!",
        "bottom-right", ".item-pin-badge");
    }
  }

  // Sorted by atomic number -- face N (the die-face pip count shown) is
  // this sorted position, matching doRoll()'s own use of sortedDice().
  const gather = sortedDice(s).map((sym, i) =>
    `<div class="gcol"><button type="button" class="gchip" data-elem="${esc(sym)}" title="${esc(sym)} — tap for its card" style="--suit:${ELEMENT_COLOR[sym] || "#8a94a6"}"><span class="gnum">${ATOMIC_NUMBER[sym]}</span><span class="gsym">${esc(sym)}</span>${elSuitBadgeHTML(sym)}</button><span class="gname">${esc(ELEMENT_NAMES[sym] || sym)}</span>${dieFace(i + 1)}</div>`).join("");

  // Empty placeholder for the rolled-dice row (rolling is Home's Roll face,
  // triggerRoll()); playRollAnimation() tweens its height. Omitted once this
  // visit's roll is spent.
  const playBar = state.rolledHere ? "" : `<div class="playbar" id="playBar"></div>`;

  const shopBody = shopBodyHTML(shopEntries, idx);

  // The header is frozen to the top (.stationhead.frozen) until this visit's
  // roll has happened and finished animating (rollAnimationInProgress), so the
  // pool and dice never scroll away mid-roll; after that it scrolls normally.
  const stationheadFrozen = !state.rolledHere || rollAnimationInProgress;
  return `<div class="sheet" style="--suit:${su.color};--suit-soft:${su.soft}">
    <div class="stationhead${stationheadFrozen ? " frozen" : ""}">
      <div class="sheet-head">
        <span class="em">${em(s.emoji)}</span>
        <div class="station-title-wrap">
          <h1><span class="station-title-text">${esc(s.name)}</span></h1>
        </div>
      </div>
      <div class="col-label elements-label">ELEMENTS FOUND HERE:</div>
      <div class="gather">${gather}</div>
      ${playBar}
    </div>
    <div class="makewrap">
      <div class="col-label shop-label">ITEM SHOP</div>
      ${shopBody}
      ${capRevealed ? `<div class="capbox ${!owns(capEntry.name) && canCraft(capEntry) ? "can" : ""}">
        ${itemHTML(capEntry, idx(capEntry))}
      </div>` : ""}
    </div>
  </div>`;
}

/* Shop body: the "Crafted Items" toggle decides whether owned items render
   as full cards or fold into the compact craftedIconsHTML() row (capstones
   always keep their capbox). The toggle always renders first, just above
   wherever crafted items currently show. */
function shopBodyHTML(shopEntries, idx){
  // "Crafted Items": owns() is "crafted", so an item made anywhere shows here
  // at every station that sells it. No toggle until one item sold here is
  // crafted.
  const hasCraftedHere = shopEntries.some(e => owns(e.name));
  if (!hasCraftedHere){
    return `<div class="shop">${shopEntries.map(e => itemHTML(e, idx(e))).join("")}</div>`;
  }
  const stationSuit = STATION_BY_NAME[current] && DATA.suits[STATION_BY_NAME[current].suit];
  const toggle = `<div class="shop-toggle-row">
      <button type="button" class="shop-collapse-toggle ${state.collapseCraftedItems ? "active" : ""}" id="collapseCraftedBtn">
        <span class="collapse-chevron"></span>Crafted Items
      </button>
      ${stationSuit ? `<button type="button" class="arrange-launch-btn" data-arrange-bg="${esc(stationSuit.color)}" title="Arrange your items" aria-label="Arrange your items">🖌️</button>` : ""}
    </div>`;
  if (!state.collapseCraftedItems){
    return toggle + `<div class="shop">${shopEntries.map(e => itemHTML(e, idx(e))).join("")}</div>`;
  }
  const owned = shopEntries.filter(e => owns(e.name));
  const rest = shopEntries.filter(e => !owns(e.name));
  const row = owned.length ? `<div class="crafted-row">${craftedIconsHTML(owned)}</div>` : "";
  return toggle + row + `<div class="shop">${rest.map(e => itemHTML(e, idx(e))).join("")}</div>`;
}

/* Raw element boxes, shared by the legacy drawer and Classic's Elements
   tab (renderMatTop()). */
function elementsGridHTML(){
  const syms = Object.keys(state.elements).filter(k => state.elements[k] > 0)
    .sort((a, b) => (ATOMIC_NUMBER[a] || 999) - (ATOMIC_NUMBER[b] || 999));
  return syms.length
    ? `<div class="elgrid">${syms.map(s =>
        `<button type="button" class="elbox" data-elem="${esc(s)}" style="--suit:${ELEMENT_COLOR[s]}"><span class="elsym">${esc(s)}${elSuitBadgeHTML(s)}</span><span class="elqty">${state.elements[s]}</span></button>`).join("")}</div>`
    : '<p class="empty">No loose elements — visit a station and hit PLAY.</p>';
}
