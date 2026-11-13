/* =====================================================================
   display-mat.js -- Display Mat screen inside the Inventory drawer: the 8-slot grid
   (#drawerTop), the Quark meter, filters/sort, the owned-card grid
   (renderClassicDrawer()), and placing/removing cards.
   ===================================================================== */
const matInventory = () =>
  MAT_CARDS.filter(c => owns(c.name)).sort((a, b) => b.points - a.points || a.name.localeCompare(b.name));
const matOnMat = () => state.mat.map(n => MAT_CARD_BY_NAME[n]).filter(Boolean);

/* Which stations and suits are paying out right now (a Set per kind, since
   groups can stack, see matAllGroups()). Cards feeding them light those
   icons on the mat and in the tray. */
let matLive = { station: new Set(), suit: new Set() };
function setMatLive(mat){
  const c = matScore(mat).combos;
  matLive = {
    station: new Set(c.station.map(g => g.name)),
    suit:    new Set(c.suit.map(g => g.name)),
  };
}

function matCardHTML(name, opts = {}){
  const c = MAT_CARD_BY_NAME[name];
  if (!c) return "";
  const onMat = state.mat.includes(name);
  const pts = opts.complete ? c.points * 2 : c.points;
  const pipsHTML = c.pips.map(s =>
    `<span class="mm-pip${matLive.suit.has(s) ? " lit" : ""}" style="--suit:${SUIT_COLOR[s]}" title="${ELEMENT_SUIT_LABEL[s]}">${SUIT_ICON[s]}</span>`).join("");
  // One badge per home station (see MAT_CARDS); each lights independently.
  const stationsHTML = c.stations.map(stName => {
    const stMeta = STATION_BY_NAME[stName];
    const stColor = DATA.suits[stMeta.suit].color;
    const stLit = matLive.station.has(stName) ? " lit" : "";
    return `<span class="mm-station${stLit}" style="--st:${stColor}" title="${esc(stName)}">${em(stMeta.emoji)}</span>`;
  }).join("");
  // "wide" (tray only -- the mat grid uses .mm-slot.wide) so a capstone spans
  // two columns in the full list too.
  const cls = ["mm-card", opts.complete ? "complete" : "",
               opts.tray && onMat ? "on" : "",
               opts.tray && matIsCapstone(c) ? "wide" : "", opts.cls || ""].join(" ");
  return `<button type="button" class="${cls}" data-mat-card="${esc(name)}"
      title="${esc(name)} — ${c.points} pts${opts.complete ? ` (doubled to ${pts} -- every ingredient is on the mat)` : ""}, ${c.stations.map(esc).join(" / ")}">
    <span class="mm-pts">${pts}</span>
    ${pipsHTML ? `<span class="mm-pips">${pipsHTML}</span>` : ""}
    <span class="mm-icon">${em(c.emoji)}</span>
    <span class="mm-name">${esc(name)}</span>
    <span class="mm-stations">${stationsHTML}</span>
  </button>`;
}

function matComboChipHTML(g, kind){
  const st = STATION_BY_NAME[g.name];
  // kind doubles as a modifier class (mm-cico.station/.suit/.component).
  const icon =
    kind === "station" ? `<span class="mm-cico ${kind}" style="--st:${DATA.suits[st.suit].color}">${em(st.emoji)}</span>`
    : kind === "suit"  ? `<span class="mm-cico ${kind}" style="--suit:${SUIT_COLOR[g.name]}">${SUIT_ICON[g.name]}</span>`
    : `<span class="mm-cico ${kind}">${ITEM_EMOJI[g.name] ? em(ITEM_EMOJI[g.name]) : esc(g.name)}</span>`;
  const label = kind === "suit" ? ELEMENT_SUIT_LABEL[g.name] : g.name;
  // The shared-icon count sits as a badge on the icon's top-right corner. The
  // whole chip is a button that lists the cards behind it (openComboInfo()).
  return `<button type="button" class="mm-combo" data-combo-kind="${kind}" data-combo-name="${esc(g.name)}" title="${esc(label)} ×${g.k}">${
    icon.replace(/<\/span>$/, `<span class="mm-ccount">${g.k}</span></span>`)}</button>`;
}
/* Combo chips for renderMatTop() (revealAll=false) and playLockInSequence()
   (revealAll=true). Only named collections differ: revealAll=false omits any
   not yet in prefs.everUnlockedMatCollections (nothing hints at them before
   their first Lock-In); revealAll=true includes every completed one but
   marks first-timers ".discovering" (hidden) so the sequence can reveal them
   on their beat. */
// Named collections collapse into one star chip; its number is how many
// discovered collections are on the mat (tap to list them,
// openComboInfo()). During Lock-In the chip exists if ANY is complete
// (hidden if none were known), and playLockInSequence() reveals it and
// bumps the count per collection.
const COLLECTIONS_CHIP = "__collections__";
function matComboChipsHTML(s, revealAll){
  const known = s.cols.filter(c => prefs.everUnlockedMatCollections.includes(c.id));
  const showStar = revealAll ? s.cols.length > 0 : known.length > 0;
  const star = !showStar ? "" :
    `<button type="button" class="mm-combo col${known.length ? "" : " discovering"}" data-combo-kind="collection" data-combo-name="${COLLECTIONS_CHIP}" title="Named collections on your mat"><span class="mm-cico star">★<span class="mm-ccount">${known.length}</span></span></button>`;
  // A complete collection the player hasn't discovered yet: a "!" that
  // says so (not during the Lock-In reveal, which shows it for real).
  const hidden = !revealAll && s.cols.some(c => !prefs.everUnlockedMatCollections.includes(c.id))
    ? `<button type="button" class="mm-combo hidden-col" data-hidden-col title="A hidden collection is on your mat"><span class="mm-cico hidden-ic">!</span></button>` : "";
  // Each capstone's signature, with what it's adding right now (dim when
  // its condition isn't met); tap for the rule.
  const sigs = (s.sigs || []).map(g => `<button type="button" class="mm-combo sig${g.on ? "" : " off"}" data-sig="${esc(g.name)}" title="${esc(CAPSTONE_SIGNATURES[g.name])}"><span class="mm-cico sig-ic">${em(ITEM_EMOJI[g.name])}</span><b>${esc(g.label)}</b></button>`).join("");
  return sigs + s.combos.station.map(g => matComboChipHTML(g, "station")).join("") +
    s.combos.suit.map(g => matComboChipHTML(g, "suit")).join("") +
    s.combos.component.map(g => matComboChipHTML(g, "component")).join("") + star + hidden;
}

/* Fills #matGrid only, using the matScore() the caller already has. */
/* Fills #matGrid only. A filled slot's only interaction is a tap that
   opens its inspection view (#drawerTop's click listener). */
function renderMatGridCells(s){
  const mat = matOnMat();
  const L = matLayout(mat);
  const cells = matPackCells(mat);
  const card = (c, cls) => matCardHTML(c.name, { complete: s.completeNames.has(c.name), cls });
  const html = cells.map(cell => cell.stack
    // Tier 1 squares, stacked; an open half shows as a small dashed square.
    ? `<div class="mm-slot filled stack">${cell.stack.map(t => card(t.card, "mini")).join("")}${
        cell.stack.length < L.perSlot ? `<span class="mm-mini-empty"></span>` : ""}</div>`
    : cell.card
    ? `<div class="mm-slot filled ${cell.w > 1 ? "wide" : ""}" data-idx="${cell.idx}">${card(cell.card)}</div>`
    : `<div class="mm-slot empty"></div>`);
  for (let n = cells.reduce((a, c) => a + c.w, 0); n < L.slots; n++){
    html.push(`<div class="mm-slot empty"></div>`);
  }
  document.getElementById("matGrid").innerHTML = html.join("");
}

// "mat" | "elements": which page fills #drawerTop's lower half
// (renderMatTop()). View state only, not saved.
let matDrawerView = "mat";
// Whether the full scrollable item list shows below the mat/Elements zone,
// or just that zone ("peeked"). openDrawer() sets it on every open.
let matTrayExpanded = false;

// The latest matScore(), cached for the Lock-In sequence and grid refreshes.
let matLastScore = null;

/* The Display Mat rules, two pages: how the check works, then Quark combos.
   Opened by the mat's "?" and automatically at the first check ever. */
function openMatRules(){
  document.getElementById("matRulesPage1").hidden = false;
  document.getElementById("matRulesPage2").hidden = true;
  openOverlay("matRulesOverlay");
}
document.getElementById("matRulesOverlay").addEventListener("click", ev => {
  if (ev.target.closest("#matRulesNext")){
    document.getElementById("matRulesPage1").hidden = true;
    document.getElementById("matRulesPage2").hidden = false;
    return;
  }
  if (ev.target.id === "matRulesOverlay" || ev.target.closest("#matRulesOk")) closeOverlay("matRulesOverlay");
});

/* Rebuilds #drawerTop: the score card, the Elements/Display Mat page, its
   tabs and quick actions. Called on every mat change and tab switch. */
/* The Quark Meter line (Quark icon, four-breakpoint meter, running total),
   shared by the Display Mat header (renderMatTop()) and the bar along the
   top of the screen (renderQuarkTopBar()). Breakpoints are for the next mat
   check (matCheckRound()). */
function quarkMeterLineHTML(s){
  const round = matCheckRound();
  const qmTiers = lockInTiersForRound(round);
  const qmPassed = emptyElementsForScore(s.total, round);
  const qmSegRange = (lo, hi) => hi > lo ? Math.max(0, Math.min(100, ((s.total - lo) / (hi - lo)) * 100)) : (s.total >= lo ? 100 : 0);
  // Four equal segments, one per breakpoint: the three dice tiers at 25/50/75%
  // and the "?" tier at 100%. Each number sits above its own breakpoint icon.
  const qmDiceBounds = [0, qmTiers.one, qmTiers.two, qmTiers.three, qmTiers.four];
  const qmCumPcts = [25, 50, 75, 100];
  const qmSegs = qmDiceBounds.slice(1).map((hi, i) => {
    const pct = qmSegRange(qmDiceBounds[i], hi);
    return `<span class="qm-seg${pct >= 100 ? " lit" : ""}"><span class="qm-seg-fill" style="transform:scaleX(${pct / 100})"></span></span>`;
  }).join("");
  const qmLabels = [1, 2, 3].map(i =>
    `<span class="qm-seg-label" style="left:${qmCumPcts[i - 1]}%">${Math.round(qmDiceBounds[i]).toLocaleString()}</span>`).join("") +
    `<span class="qm-seg-label qm-label-end qm-cap-label" style="right:0">${Math.round(qmDiceBounds[4]).toLocaleString()}</span>`;
  // Breakpoint badges at the fixed marks (qmCumPcts). Lit once the score has
  // reached that tier, i.e. locking in now would earn it (see
  // diceDeltaForReward()/finishLockIn()).
  const QM_BREAK_LABEL = { 1: "+1 bonus die", 2: "+2 bonus dice", 3: "+3 bonus dice", 4: "+3 dice, plus +1 Empty Element" };
  const qmBreaks = [1, 2, 3].map(i =>
    `<span class="qm-break${qmPassed >= i ? " lit" : ""}" style="left:${qmCumPcts[i - 1]}%" title="${QM_BREAK_LABEL[i]}"><span class="qm-break-dice">🎲</span></span>`).join("")
    + `<span class="qm-break qm-break-end${qmPassed >= 4 ? " lit" : ""}" title="${QM_BREAK_LABEL[4]}">${emptyElSquareHTML(20)}</span>`;
  const qmDelta = diceDeltaForReward(qmPassed);
  const qmDeltaLabel = qmPassed === 0 ? "no bonus dice"
    : qmPassed >= 4 ? `+${qmDelta} dice, +1 Empty Element` : `+${qmDelta} dice`;
  const quarkMeterHTML = `<div class="quark-meter-wrap"
      title="${s.total.toLocaleString()} Quarks toward this round's breakpoints: ${Math.round(qmTiers.one).toLocaleString()} / ${Math.round(qmTiers.two).toLocaleString()} / ${Math.round(qmTiers.three).toLocaleString()} / ${Math.round(qmTiers.four).toLocaleString()} -- ${qmDeltaLabel} at your next station if you lock in now">
    <div class="qm-labels">${qmLabels}</div>
    <div class="qm-segs-row">${qmSegs}${qmBreaks}</div>
  </div>`;
  // One compact line: Quark icon, meter, and the running total in a bubble.
  // The two inputs (points x multiplier) show in the title on hover.
  return `<div class="qm-line" title="${(s.base + s.colBonus).toLocaleString()} points on display x ${s.mult.toLocaleString()} combo multiplier = ${s.total.toLocaleString()} Quarks">
      <span class="qm-quark-ic" aria-hidden="true">⚛️</span>
      ${quarkMeterHTML}
      <span class="qm-total" aria-label="${s.total.toLocaleString()} Quarks">${s.total.toLocaleString()}</span>
    </div>`;
}
/* Which visit's breakpoints the meter shows: the next checkpoint's (the
   one the next Lock-In scores against), never earlier than the first check
   on visit 3. */
function matCheckRound(){
  return Math.max(MAT_CHECK_EVERY, Math.ceil(state.visits / MAT_CHECK_EVERY) * MAT_CHECK_EVERY);
}
/* Classic, after the first mat check: the Quark Meter rides along the top
   of every screen (just above #topbar's pills, below every tray/overlay),
   reading the current mat. Tapping it opens the Display Mat. */
function renderQuarkTopBar(){
  const el = document.getElementById("quarkTopBar");
  const show = !!state.matChecked && !state.ended && !comboLabActive;
  document.body.classList.toggle("has-qtop", show);
  if (!show){ el.innerHTML = ""; return; }
  el.innerHTML = `<div class="mat-score-card qtop-card">${quarkMeterLineHTML(matScore(matOnMat()))}</div>`;
  document.documentElement.style.setProperty("--qtop-h", el.offsetHeight + "px");
}
document.getElementById("quarkTopBar").addEventListener("click", () => {
  if (anyOverlayOpen() || startingGiftInProgress) return;
  matDrawerView = "mat";
  openDrawer({ peeked: true });
});
function renderMatTop(){
  const mat = matOnMat();
  setMatLive(mat);
  const s = matScore(mat);
  matLastScore = s;

  // Named collections are discovered: revealAll=false omits any not yet in
  // prefs.everUnlockedMatCollections; other combo kinds always show.
  const chips = matComboChipsHTML(s, false);
  // The score card shows on both the Display Mat and Elements tabs -- it's a
  // live readout of the mat regardless of which page is open.
  const scoreRowHTML = `<div class="mat-score-card">
    ${quarkMeterLineHTML(s)}
    <div class="mat-score-row">
      <div class="mat-combos">${chips || `<span class="mm-combo-none">Three cards alike start a combo</span>`}</div>
    </div>
  </div>`;

  // No title/occupancy/Clear row above the grid any more -- the slot
  // count and a way to clear it weren't earning their place once the
  // tray already shows the mat directly.
  const zoneHTML = matDrawerView === "mat"
    ? `<div class="mat-grid" id="matGrid"></div>`
    : elementsGridHTML();

  // Two folder tabs switch matDrawerView. Both always render so they read as
  // two pages, the inactive one recessed (.mat-tab).
  const tabsHTML = `<div class="mat-zone-tabs">
      <button type="button" class="mat-tab tab-elements ${matDrawerView === "elements" ? "active" : ""}" data-mat-view="elements">Elements</button>
      <button type="button" class="mat-tab tab-mat ${matDrawerView === "mat" ? "active" : ""}" data-mat-view="mat">Display Mat</button>
    </div>`;
  // Clear/Layouts only on the Display Mat page, sharing the tab row (see
  // .mat-zone-topbar).
  const quickActionsHTML = matDrawerView === "mat" ? `<div class="mat-quick-actions">
      <button type="button" class="mat-quick-btn text" id="matClearBtn" title="Clear the Display Mat" aria-label="Clear the Display Mat">Clear Mat</button>
      <button type="button" class="mat-quick-btn" id="matLayoutsBtn" title="Saved Display Mat layouts" aria-label="Saved Display Mat layouts">💾</button>
    </div>` : "";
  const topbarHTML = `<div class="mat-zone-topbar">${quickActionsHTML}${tabsHTML}</div>`;
  // The page has a fixed height (the 2-row mat formula) so switching tabs
  // never resizes the tray; a long elements list scrolls inside. A different
  // parchment shade per tab.
  const pageHTML = `<div class="mat-zone-page zone-${matDrawerView}">${zoneHTML}</div>`;

  // No in-tray Lock In button: Home becomes the "lockin" face (hubHomeFace()).
  const rulesBtnHTML = matDrawerView === "mat"
    ? `<button type="button" class="mat-rules-btn" id="matRulesBtn" title="How the Display Mat scores" aria-label="Display Mat rules"></button>` : "";
  maybeShowCollectionFound();
  document.getElementById("drawerTop").style.setProperty("--mat-cols", matLayout(mat).cols);
  document.getElementById("drawerTop").innerHTML = scoreRowHTML + matMiniRowHTML(mat) +
    `<div class="mat-zone-wrap">${topbarHTML}${pageHTML}${rulesBtnHTML}</div>`;
  syncMatFloatBtns();
  if (matDrawerView === "mat") renderMatGridCells(s);
  renderQuarkTopBar();
}
// View state, not saved. Mirrors cardgame/mat.html's filt: station/suit
// toggles ORed within a group and ANDed across groups, a name search, a
// sort mode.
let matFilt = { stations: new Set(), suits: new Set(), q: "", sort: "points" };
function matVisibleInventory(){
  let list = matInventory();
  // .some(): a multi-home item matches a station filter through any of its
  // homes.
  if (matFilt.stations.size) list = list.filter(c => c.stations.some(s => matFilt.stations.has(s)));
  if (matFilt.suits.size)    list = list.filter(c => c.pips.some(p => matFilt.suits.has(p)));
  if (matFilt.q){
    const q = matFilt.q.toLowerCase();
    list = list.filter(c => c.name.toLowerCase().includes(q) ||
      c.components.some(r => r.name.toLowerCase().includes(q)));
  }
  const sorts = {
    points:  (a, b) => b.points - a.points || a.name.localeCompare(b.name),
    name:    (a, b) => a.name.localeCompare(b.name),
    station: (a, b) => a.station.localeCompare(b.station) || b.points - a.points,
  };
  return list.sort(sorts[matFilt.sort] || sorts.points);
}
/* The tray's sections, by how many element icons (suit costs) an item
   has: none = Tier 1, one = Tier 2, two = Tier 3, three = Capstones.
   Highest first. Card size still follows the item's mat footprint. */
const MAT_TIER_BANDS = [
  { key: "capstone", label: "Capstones", icons: 3 },
  { key: "t3", label: "Tier 3", icons: 2 },
  { key: "t2", label: "Tier 2", icons: 1 },
  { key: "t1", label: "Tier 1", icons: 0 },
];
// Collapsed band keys: an in-memory Set (like matFilt), so collapsed
// sections survive re-renders but not a reload.
let matTierCollapsed = new Set();
/* The scrollable owned-items grid in #drawerBody. A pure string builder
   (matResultsGridHTML()) plus a small DOM wrapper, so
   renderClassicDrawer() and the filter handlers (which update #drawerBody
   directly) share one implementation. Grouped into MAT_TIER_BANDS sections,
   each keeping the current sort order inside it. */
function matResultsGridHTML(){
  const inv = matVisibleInventory();
  if (!inv.length){
    return `<p class="empty">${matInventory().length
      ? "Nothing matches those filters."
      : "Nothing crafted yet — items you craft show up here."}</p>`;
  }
  const sections = MAT_TIER_BANDS.map(band => {
    const items = inv.filter(c => Math.min(itemSuitCosts(c.name).length, 3) === band.icons);
    if (!items.length) return "";
    const collapsed = matTierCollapsed.has(band.key);
    return `<div class="mat-tier-section ${collapsed ? "collapsed" : ""}">
        <button type="button" class="mat-tier-heading" data-mat-tier="${band.key}">
          <span class="mat-tier-line"></span>${esc(band.label)}<span class="collapse-chevron"></span><span class="mat-tier-line"></span>
        </button>
        ${prefs.itemsListView
          ? `<div class="shop mat-shop-list">${items.map(c => matShopRowHTML(c.name)).join("")}</div>`
          // Tier 1 cards at half height, as they stack on the mat; a
          // full-size card in that section spans two half rows.
          : `<div class="mat-results-grid ${band.key === "t1" ? "half" : ""}">${items.map(c =>
              matCardHTML(c.name, { tray: true, cls: (matIsTier1(c) ? "small mini" : "small") + (c.name === matListOpen ? " selected" : "") })).join("")}</div>`}
      </div>`;
  }).join("");
  // The selected item's shop row docks at the top of the list, just under
  // the mat (sticky), while its card or slim row is highlighted.
  const panel = matListOpen && owns(matListOpen)
    ? `<div class="shop mat-sel-panel">${matOpenRowHTML(matListOpen)}</div>` : "";
  return panel + sections;
}
/* The selected item (matListOpen), in both views. List view: one slim line
   per item (icon, name, suit pips, home stations, points). Either view:
   tapping an item highlights it and docks its station shop row under the
   mat, and #matListActions offers Add/Remove above the hub. */
let matListOpen = null;
const matStationBadgesHTML = (c, cls) => c.stations.map(st =>
  `<span class="${cls}" style="--st:${DATA.suits[STATION_BY_NAME[st].suit].color}" title="${esc(st)}">${em(STATION_BY_NAME[st].emoji)}</span>`).join("");
// The open item's full shop row: read-only (plain: nothing faded), with its
// home station(s) and points bubble in the top-right corner.
function matOpenRowHTML(name){
  const c = MAT_CARD_BY_NAME[name];
  const entry = ENTRIES.find(e => e.name === name && e.station === CORE_ITEM_STATION[name]);
  if (!c || !entry) return "";
  return `<div class="item open${state.mat.includes(name) ? " on-mat" : ""}" data-mat-row="${esc(name)}" role="button" tabindex="0" aria-expanded="true">
      <span class="mo-corner">${matStationBadgesHTML(c, "ms-station")}<span class="ms-pts" title="${c.points} points">${c.points}</span></span>
      ${itemRowHTML(entry, false, true)}</div>`;
}
function matShopRowHTML(name){
  const c = MAT_CARD_BY_NAME[name];
  if (!c) return "";
  const pips = c.pips.map(s => `<span class="ms-pip" style="--suit:${SUIT_COLOR[s]}" title="${ELEMENT_SUIT_LABEL[s]}">${SUIT_ICON[s]}</span>`).join("");
  const sel = name === matListOpen;
  return `<div class="mat-slim${state.mat.includes(name) ? " on-mat" : ""}${sel ? " selected" : ""}" data-mat-row="${esc(name)}" role="button" tabindex="0" aria-expanded="${sel}">
    <span class="ms-icon">${em(c.emoji)}</span><span class="ms-name">${esc(name)}</span>
    <span class="ms-pips">${pips}</span><span class="ms-stations">${matStationBadgesHTML(c, "ms-station")}</span>
    <span class="ms-pts" title="${c.points} points">${c.points}</span></div>`;
}
function toggleMatListRow(name){
  matListOpen = matListOpen === name ? null : name;
  renderMatResultsGrid();
}
/* Add/Remove for the selected item, above Home. Shown only while one is
   selected in the full tray (syncMatFloatBtns()). */
function syncMatListActions(){
  const bar = document.getElementById("matListActions");
  const show = matTrayExpanded && !!matListOpen && owns(matListOpen);
  // Slides up from behind the hub (.show), and back down when hidden.
  bar.classList.toggle("show", show);
  bar.setAttribute("aria-hidden", String(!show));
  if (!show) return;
  const onMat = state.mat.includes(matListOpen);
  document.getElementById("matListAdd").disabled = onMat;
  document.getElementById("matListRemove").disabled = !onMat;
}
document.getElementById("matListAdd").addEventListener("click", () => {
  if (matListOpen && !state.mat.includes(matListOpen)) toggleMatCard(matListOpen);
});
document.getElementById("matListRemove").addEventListener("click", () => {
  if (matListOpen && state.mat.includes(matListOpen)) toggleMatCard(matListOpen);
});
function setItemsListView(on){
  prefs.itemsListView = on; savePrefs();
  matListOpen = null;
  syncMatViewBtn();
  renderMatResultsGrid();
}
function syncMatViewBtn(){
  const b = document.getElementById("matViewBtn"), on = !!prefs.itemsListView;
  b.innerHTML = on ? "🃏" : "📋";
  b.title = on ? "Show as cards" : "Show as a list";
  b.setAttribute("aria-label", b.title);
  b.setAttribute("aria-pressed", String(on));
}
function renderMatResultsGrid(){
  document.getElementById("drawerBody").innerHTML = matResultsGridHTML();
  syncMatListActions();
}

/* Filter buttons are built once and only toggled afterwards
   (syncMatFilterBar()), never re-rendered, so #matFSearch keeps focus while
   typing (only #drawerBody re-renders on input). */
let matFilterBarBuilt = false;
/* Stations in STATION_TRACKER_ORDER, the standard station order for every
   list in the game. Labelled rows (the tray has room). */
function buildMatFilterBar(){
  if (matFilterBarBuilt) return;
  const coreStations = new Set(MAT_CARDS.map(c => c.station));
  const stations = STATION_TRACKER_ORDER.filter(s => coreStations.has(s));
  // Icon-only now (see .mat-fbtn's own CSS comment) -- title still carries
  // the name for a tooltip/screen reader, just nothing printed alongside
  // the glyph any more.
  document.getElementById("matFStations").innerHTML = stations.map(s => {
    const m = STATION_BY_NAME[s];
    return `<button type="button" class="mat-fbtn" data-mat-fstation="${esc(s)}" title="${esc(s)}"
        style="--st:${DATA.suits[m.suit].color}">${em(m.emoji)}</button>`;
  }).join("");
  document.getElementById("matFSuits").innerHTML = Object.keys(ELEMENT_SUIT_LABEL).map(s =>
    `<button type="button" class="mat-fbtn" data-mat-fsuit="${s}" title="${ELEMENT_SUIT_LABEL[s]}"
        style="--suit:${SUIT_COLOR[s]}">${SUIT_ICON[s]}</button>`).join("");
  matFilterBarBuilt = true;
}
function syncMatFilterBar(){
  document.querySelectorAll("[data-mat-fstation]").forEach(b =>
    b.classList.toggle("on", matFilt.stations.has(b.dataset.matFstation)));
  document.querySelectorAll("[data-mat-fsuit]").forEach(b =>
    b.classList.toggle("on", matFilt.suits.has(b.dataset.matFsuit)));
}

/* Classic drawer body: the mat/Elements zone + score (#drawerTop), the
   filter bar (#matFilters), and the item grid (returned for #drawerBody). */
/* Minimized board (shown only while the mat is collapsed): the mat's cards
   as a row of icons, then how full it is in half-slots -- a tier 1 card
   takes 1, a normal card 2, a capstone 4, of 16. Tap to show the mat. */
function matMiniRowHTML(mat){
  // In tier 1 units: a slot holds perSlot of them (Freight: 3).
  const L = matLayout(mat);
  const used = mat.reduce((n, c) => n + (matIsTier1(c) ? 1 : matSlotsOf(c) * L.perSlot), 0);
  const icons = mat.map(c => `<span class="mmr-ic" title="${esc(c.name)}">${em(c.emoji)}</span>`).join("");
  return `<button type="button" class="mat-mini-row" id="matMiniRow" title="Show the Display Mat">
    <span class="mmr-icons">${icons || '<span class="mmr-empty">Nothing on the mat yet</span>'}</span>
    <span class="mmr-room">${used}/${L.slots * L.perSlot}</span></button>`;
}
function renderClassicDrawer(){
  document.getElementById("matFilters").hidden = false;
  document.getElementById("drawer").classList.toggle("expanded", matTrayExpanded);
  buildMatFilterBar();
  syncMatFilterBar();
  syncMatViewBtn();
  renderMatTop();
  return matResultsGridHTML();
}

function toggleMatCard(name){
  const i = state.mat.indexOf(name);
  if (i !== -1){
    // Taking off Metropolis/Maglev Train shrinks the mat: only if the rest fit.
    const rest = state.mat.filter(n => n !== name).map(n => MAT_CARD_BY_NAME[n]).filter(Boolean);
    if (!matFits(rest)){ showMatToast(`Make room first -- without ${name} the rest won't fit.`); return; }
    state.mat.splice(i, 1); renderMatTop(); renderMatResultsGrid(); save(); return;
  }
  const card = MAT_CARD_BY_NAME[name];
  if (!card || !owns(name)) return;
  if (!matFits(matOnMat().concat([card]))){
    showMatToast(matIsCapstone(card) ? "A capstone needs two free slots." : "The display mat is full.");
    return;
  }
  state.mat.push(name);
  renderMatTop(); renderMatResultsGrid(); save();
}


let matToastTimer = null;
function showMatToast(msg){
  const el = document.getElementById("matToast");
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(matToastTimer);
  matToastTimer = setTimeout(() => { el.hidden = true; }, 1900);
}

/* #drawerTop's contents are rebuilt by renderMatTop() on every change, so
   clicks are delegated to #drawerTop itself. */
document.getElementById("drawerTop").addEventListener("click", ev => {
  const tabBtn = ev.target.closest("[data-mat-view]");
  if (tabBtn){
    matDrawerView = tabBtn.dataset.matView;
    renderMatTop();
    return;
  }
  if (ev.target.closest("#matMiniRow")){ setMatCollapsed(false); return; }
  const sigChip = ev.target.closest("[data-sig]");
  if (sigChip){ showMatToast(CAPSTONE_SIGNATURES[sigChip.dataset.sig]); return; }
  if (ev.target.closest("[data-hidden-col]")){
    showMatToast("You have a hidden collection on your mat! Lock in your board to discover it.");
    return;
  }
  if (ev.target.closest("#matLayoutsBtn")){ openMatLayoutsOverlay(); return; }
  if (ev.target.closest("#matClearBtn")){ clearMatDisplay(); return; }
  if (ev.target.closest("#matRulesBtn")){ openMatRules(); return; }
  const comboChip = ev.target.closest(".mm-combo[data-combo-kind]");
  if (comboChip && !comboChip.classList.contains("discovering")){
    openComboInfo(comboChip.dataset.comboKind, comboChip.dataset.comboName);
    return;
  }
  const elBtn = ev.target.closest("[data-elem]");
  if (elBtn){ showElCardPop(elBtn.dataset.elem); return; }
  // Tapping a filled mat slot opens its inspection view. A plain "click" --
  // a hand-rolled pointer tap detector kept failing on real touchscreens.
  // Cards can't be rearranged; a tap only inspects.
  const filledSlot = ev.target.closest(".mm-slot.filled");
  if (filledSlot){
    // A tier 1 stack holds two cards: open the one tapped.
    const cardBtn = ev.target.closest("[data-mat-card]") || filledSlot.querySelector("[data-mat-card]");
    if (cardBtn){
      // Same as tapping it in the item list (toggleMatListRow()): selects it,
      // showing its shop row and Add/Remove. Peeked view: expand to the full
      // view first so that row has somewhere to show.
      expandDrawerToFull();
      toggleMatListRow(cardBtn.dataset.matCard);
    }
    return;
  }
});
/* Tapping a combo chip lists the mat cards that earn it
   (matCardsForCombo()) -- or, for the collections star, every discovered
   collection the mat completes, as Collections-menu cards
   (namedCollectionCardHTML()). */
function openComboInfo(kind, name){
  const titleEl = document.getElementById("comboInfoTitle");
  const bodyEl = document.getElementById("comboInfoBody");
  if (kind === "collection"){
    const s = matLastScore || matScore(matOnMat());
    const cols = s.cols.filter(c => prefs.everUnlockedMatCollections.includes(c.id));
    titleEl.textContent = `★ Named Collections (${cols.length})`;
    bodyEl.innerHTML = `<div class="histrows">${cols.map(c => namedCollectionCardHTML(c, false)).join("")}</div>`;
  } else {
    const label = kind === "suit" ? ELEMENT_SUIT_LABEL[name] : name;
    const icon = kind === "station" ? em(STATION_BY_NAME[name].emoji)
      : kind === "suit" ? SUIT_ICON[name]
      : (ITEM_EMOJI[name] ? em(ITEM_EMOJI[name]) : "");
    const cards = matCardsForCombo(kind, name);
    titleEl.innerHTML = `<span class="ci-title-ic">${icon}</span> ${esc(label)} ×${cards.length}`;
    bodyEl.innerHTML = `<div class="combo-info-list">${cards.map(c =>
      `<div class="combo-info-card"><span class="ci-em">${ITEM_EMOJI[c.name] ? em(ITEM_EMOJI[c.name]) : ""}</span><span class="ci-name">${esc(c.name)}</span><span class="ci-pts">${c.points}</span></div>`).join("")}</div>`;
  }
  openOverlay("comboInfoOverlay");
}
document.getElementById("comboInfoClose").addEventListener("click", () => closeOverlay("comboInfoOverlay"));
// One tap, no confirmation: every removed card is still in the owned list
// (or a saved layout).
function clearMatDisplay(){
  state.mat = [];
  save();
  render();
}
document.getElementById("matCollectionsBtn").addEventListener("click", () => openCollectionsOverlay());
document.getElementById("matViewBtn").addEventListener("click", () => setItemsListView(!prefs.itemsListView));
document.getElementById("matFStations").addEventListener("click", ev => {
  const b = ev.target.closest("[data-mat-fstation]");
  if (!b) return;
  const s = b.dataset.matFstation;
  matFilt.stations.has(s) ? matFilt.stations.delete(s) : matFilt.stations.add(s);
  syncMatFilterBar();
  renderMatResultsGrid();
});
document.getElementById("matFSuits").addEventListener("click", ev => {
  const b = ev.target.closest("[data-mat-fsuit]");
  if (!b) return;
  const s = b.dataset.matFsuit;
  matFilt.suits.has(s) ? matFilt.suits.delete(s) : matFilt.suits.add(s);
  syncMatFilterBar();
  renderMatResultsGrid();
});
document.getElementById("matFSearch").addEventListener("input", ev => {
  matFilt.q = ev.target.value.trim();
  renderMatResultsGrid();
});

/* Sort/Filter trays (full inventory only). Only one open at a time:
   opening either closes the other, as does its button again or the shared
   scrim. */
function closeMatSideTrays(){
  document.getElementById("matSortTray").classList.remove("open");
  document.getElementById("matFilterTray").classList.remove("open");
  document.getElementById("matSfScrim").hidden = true;
}
function toggleMatSideTray(id){
  const tray = document.getElementById(id);
  const wasOpen = tray.classList.contains("open");
  closeMatSideTrays();
  if (!wasOpen){
    // Anchor both trays to the gold divider at the top of .dbody (below the
    // mat, above the search bar's padding); .dbody is always in the DOM.
    const top = document.querySelector("#drawer .dbody").getBoundingClientRect().top;
    tray.style.top = top + "px";
    document.getElementById("matSfScrim").style.top = top + "px";
    tray.classList.add("open"); document.getElementById("matSfScrim").hidden = false;
  }
}
document.querySelectorAll("#matSortTray [data-mat-sort]").forEach(x =>
  x.classList.toggle("active", x.dataset.matSort === matFilt.sort));
document.getElementById("matSortBtn").addEventListener("click", () => toggleMatSideTray("matSortTray"));
document.getElementById("matFilterBtn").addEventListener("click", () => toggleMatSideTray("matFilterTray"));
document.getElementById("matSfScrim").addEventListener("click", closeMatSideTrays);
document.getElementById("matSortTray").addEventListener("click", ev => {
  const b = ev.target.closest("[data-mat-sort]");
  if (!b) return;
  matFilt.sort = b.dataset.matSort;
  document.querySelectorAll("#matSortTray [data-mat-sort]").forEach(x =>
    x.classList.toggle("active", x === b));
  renderMatResultsGrid();
});
