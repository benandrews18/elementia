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
  // A normal shop row, plus .cap-item (dark face, gold border).
  const capHTML = capRevealed ? itemHTML(capEntry, idx(capEntry)).replace('class="item ', 'class="item cap-item ') : "";
  // List (shop rows) or card view (prefs.shopCardView: inventory-style cards).
  const viewBtn = `<button type="button" class="shop-view-btn" id="shopViewBtn" aria-pressed="${!!prefs.shopCardView}"
      title="${prefs.shopCardView ? "Show as a list" : "Show as cards"}" aria-label="${prefs.shopCardView ? "Show as a list" : "Show as cards"}">${prefs.shopCardView ? "📋" : "🃏"}</button>`;
  const shopBody = prefs.shopCardView ? shopCardsHTML(all, idx) : shopBodyHTML(shopEntries, idx, capHTML);
  // Card view: the tapped card's full shop row, pinned under the header.
  const open = prefs.shopCardView && all.find(e => e.name === stationCardOpen);
  const selPanel = !open ? "" : `<div class="st-card-sel shop">${open.tier === "CAPSTONE" ? capHTML : itemHTML(open, idx(open))}
      <button type="button" class="cp-close-x st-card-close" data-st-card-close aria-label="Close this item"></button></div>`;

  // The header is frozen to the top (.stationhead.frozen) until this visit's
  // roll has happened and finished animating (rollAnimationInProgress), so the
  // pool and dice never scroll away mid-roll; after that it scrolls normally.
  const stationheadFrozen = !state.rolledHere || rollAnimationInProgress || !!open;
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
      ${shopHeadHTML(shopEntries, viewBtn)}
      ${selPanel}
    </div>
    <div class="makewrap">
      ${shopBody}
    </div>
  </div>`;
}

/* Under the element pool, in the dark header: "Crafted Items", then a bar
   with the fold button (>), the crafted icons and the list/card switch. The
   bar always shows; folded (state.collapseCraftedItems), crafted items sit
   in it and leave the list or cards. owns() is "crafted", so an item made
   anywhere counts at every station that sells it. */
const craftedFolded = () => !!state.collapseCraftedItems;
function shopHeadHTML(shopEntries, viewBtn){
  const owned = shopEntries.filter(e => owns(e.name));
  const fold = state.collapseCraftedItems;
  const toggle = `<button type="button" class="shop-collapse-toggle ${fold ? "active" : ""}" id="collapseCraftedBtn"
      title="${fold ? "Show crafted items in the list" : "Fold crafted items into this bar"}" aria-label="${fold ? "Show crafted items in the list" : "Fold crafted items into this bar"}"><span class="collapse-chevron"></span></button>`;
  const icons = fold && owned.length ? craftedIconsHTML(owned) : "";
  return `<div class="col-label elements-label crafted-label">CRAFTED ITEMS:</div>
    <div class="shop-toggle-row">${toggle}<div class="crafted-row">${icons}</div>${viewBtn}</div>`;
}
// The list: capstone first, then the rest (minus folded crafted items).
function shopBodyHTML(shopEntries, idx, capHTML = ""){
  const list = craftedFolded() ? shopEntries.filter(e => !owns(e.name)) : shopEntries;
  return `<div class="shop">${capHTML}${list.map(e => itemHTML(e, idx(e))).join("")}</div>`;
}

/* Card view: the station's items as Inventory cards (matCardHTML()), 4 to a
   row, Tier 1 half height and capstones 2 wide, Tier 1 first; folded crafted
   items leave it as in the list. Tapping a card pins its full shop row
   (craft, pin) under the header (stationCardOpen, renderStation()). */
let stationCardOpen = null;
function shopCardsHTML(entries, idx){
  const shown = entries.filter(e => !(craftedFolded() && owns(e.name) && e.tier !== "CAPSTONE"));
  const card = e => {
    const owned = owns(e.name), t1 = e.tier === "MATERIAL";
    return matCardHTML(e.name, { cls: [t1 ? "small mini" : "small", e.tier === "CAPSTONE" ? "wide" : "",
      owned ? "st-owned" : (canCraft(e) && suitCostPayable(e) ? "st-can" : ""),
      e.name === stationCardOpen ? "selected" : ""].join(" ") });
  };
  return `<div class="st-cards">${[...MAT_TIER_BANDS].reverse().map(b => {
    const items = shown.filter(e => e.tier === b.tier);
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
