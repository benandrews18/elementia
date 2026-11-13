/* =====================================================================
   station.js -- Station screen: renderStation() (header, element pool, roll bar, shop,
   capstone) and the shop list.
   ===================================================================== */
function renderStation(name){
  const s = STATION_BY_NAME[name], su = DATA.suits[s.suit];
  const all = entriesAt(name);
  const allShop     = all.filter(e => e.tier !== "CAPSTONE");
  const shopEntries = sortShopItems(allShop);
  const capEntry    = all.find(e => e.tier === "CAPSTONE");
  const capRevealed = !!capEntry;
  const idx = e => ENTRIES.indexOf(e);

  // Sorted by atomic number -- face N (the die-face pip count shown) is
  // this sorted position, matching doRoll()'s own use of sortedDice().
  const gather = sortedDice(s).map((sym, i) =>
    `<div class="gcol"><button type="button" class="gchip" data-elem="${esc(sym)}" title="${esc(sym)} — tap for its card" style="--suit:${ELEMENT_COLOR[sym] || "#8a94a6"}"><span class="gnum">${ATOMIC_NUMBER[sym]}</span><span class="gsym">${esc(sym)}</span>${elSuitBadgeHTML(sym)}</button><span class="gname">${esc(ELEMENT_NAMES[sym] || sym)}</span></div>`).join("");

  // Empty placeholder for the rolled-dice row (rolling is Home's Roll face,
  // triggerRoll()); playRollAnimation() tweens its height. Omitted once this
  // visit's roll is spent.
  const playBar = state.rolledHere ? "" : `<div class="playbar" id="playBar"></div>`;

  // The capstone sits at the top of the shop, under the compact crafted row.
  const capHTML = capRevealed ? `<div class="capbox ${!owns(capEntry.name) && canCraft(capEntry) ? "can" : ""}">
        ${itemHTML(capEntry, idx(capEntry))}
      </div>` : "";
  // List (shop rows) or card view (prefs.shopCardView: inventory-style cards).
  const viewBtn = `<button type="button" class="shop-view-btn" id="shopViewBtn" aria-pressed="${!!prefs.shopCardView}"
      title="${prefs.shopCardView ? "Show as a list" : "Show as cards"}" aria-label="${prefs.shopCardView ? "Show as a list" : "Show as cards"}">${prefs.shopCardView ? "📋" : "🃏"}</button>`;
  const shopBody = prefs.shopCardView
    ? `<div class="shop-toggle-row">${viewBtn}</div>` + shopCardsHTML(all, idx, capHTML)
    : shopBodyHTML(shopEntries, idx, capHTML, viewBtn);

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
      ${shopBody}
    </div>
  </div>`;
}

/* Shop body: the "Crafted Items" toggle decides whether owned items render
   as full cards or fold into the compact craftedIconsHTML() row (capstones
   always keep their capbox). The toggle always renders first, just above
   wherever crafted items currently show. */
function shopBodyHTML(shopEntries, idx, capHTML = "", viewBtn = ""){
  // "Crafted Items": owns() is "crafted", so an item made anywhere shows here
  // at every station that sells it. No toggle until one item sold here is
  // crafted.
  const hasCraftedHere = shopEntries.some(e => owns(e.name));
  if (!hasCraftedHere){
    return `<div class="shop-toggle-row">${viewBtn}</div>` + capHTML + `<div class="shop">${shopEntries.map(e => itemHTML(e, idx(e))).join("")}</div>`;
  }
  const toggle = `<div class="shop-toggle-row">
      <button type="button" class="shop-collapse-toggle ${state.collapseCraftedItems ? "active" : ""}" id="collapseCraftedBtn">
        <span class="collapse-chevron"></span>Crafted Items
      </button>${viewBtn}
    </div>`;
  if (!state.collapseCraftedItems){
    return toggle + capHTML + `<div class="shop">${shopEntries.map(e => itemHTML(e, idx(e))).join("")}</div>`;
  }
  const owned = shopEntries.filter(e => owns(e.name));
  const rest = shopEntries.filter(e => !owns(e.name));
  const row = owned.length ? `<div class="crafted-row">${craftedIconsHTML(owned)}</div>` : "";
  return toggle + row + capHTML + `<div class="shop">${rest.map(e => itemHTML(e, idx(e))).join("")}</div>`;
}

/* Card view: the station's items as Inventory cards (matCardHTML()), 4 to a
   row, Tier 1 half height and capstones 2 wide, Tier 1 first. Tapping a card
   shows its full shop row (craft, pin) above the cards (stationCardOpen). */
let stationCardOpen = null;
function shopCardsHTML(entries, idx, capHTML){
  const open = entries.find(e => e.name === stationCardOpen);
  const sel = !open ? "" : `<div class="st-card-sel">${open.tier === "CAPSTONE" ? capHTML : itemHTML(open, idx(open))}
      <button type="button" class="cp-close-x st-card-close" data-st-card-close aria-label="Close this item"></button></div>`;
  const card = e => {
    const owned = owns(e.name), t1 = e.tier === "MATERIAL";
    return matCardHTML(e.name, { cls: [t1 ? "small mini" : "small", e.tier === "CAPSTONE" ? "wide" : "",
      owned ? "st-owned" : (canCraft(e) && suitCostPayable(e) ? "st-can" : ""),
      e.name === stationCardOpen ? "selected" : ""].join(" ") });
  };
  return sel + `<div class="st-cards">${[...MAT_TIER_BANDS].reverse().map(b => {
    const items = entries.filter(e => e.tier === b.tier);
    return !items.length ? "" : `<div class="mat-tier-heading"><span class="mat-tier-line"></span>${esc(b.label)}<span class="mat-tier-line"></span></div>
      <div class="mat-results-grid ${b.key === "t1" ? "half" : ""}">${items.map(card).join("")}</div>`;
  }).join("")}</div>`;
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
