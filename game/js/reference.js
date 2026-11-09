/* =====================================================================
   reference.js -- Item Reference (codex): renderCodex(), its rows and expandable
   ingredient trees, filter/sort, and goToRefItem() jumps.
   ===================================================================== */
/* Jump to an item's Item Reference row (the card popup's "View Item Tree").
   Closes any overlay, clears the previous jump's auto-expansion (otherwise
   everything stays expanded), expands this item's breakdown and briefly
   highlights the row. Nested taps inside Item Reference expand in place
   instead. */
const cssEsc = s => (window.CSS && CSS.escape) ? CSS.escape(s) : s.replace(/["\\]/g, "\\$&");
function goToRefItem(name){
  const openPanel = openPanelName();
  // Capture the current station before it's cleared, so closing Item
  // Reference returns there (codexReturnScreen, see closePanelByName()).
  const fromStation = current;
  // Same "capture before closing touches it" reasoning as fromStation
  // above -- see codexReturnDrawerPeeked's own comment.
  const drawerPeeked = drawer.classList.contains("open") ? !drawer.classList.contains("expanded") : null;
  if (openPanel) closePanelByName(openPanel);
  codexReturnScreen = fromStation;
  codexReturnDrawerPeeked = drawerPeeked;
  screen = "codex"; current = null;
  jobExpanded.clear();
  jobExpanded.add("refroot/" + name);
  render(true);
  requestAnimationFrame(() => {
    const row = document.querySelector(`.refrow[data-refname="${cssEsc(name)}"]`);
    if (!row) return;
    // Jump instantly and anchor the row's TOP under the topbar -- centring a
    // tall expanded row could push its top off-screen.
    const topbarH = document.getElementById("topbar").offsetHeight;
    const refbar = document.querySelector(".refbar");
    const refbarH = refbar ? refbar.offsetHeight : 0;
    const y = row.getBoundingClientRect().top + window.scrollY - topbarH - refbarH - 12;
    window.scrollTo({top: Math.max(0, y), behavior:"instant"});
    row.classList.add("ref-highlight");
    setTimeout(() => row.classList.remove("ref-highlight"), 1600);
  });
}

/* The recursive breakdown, rooted at this item's ingredients (the row
   itself is the root). */
/* The suits an item's recipe uses (itemSuitCosts(), deduped), as a small
   bare icon row. */
function refSuitsHTML(name){
  const suits = [...new Set(itemSuitCosts(name))];
  if (!suits.length) return "";
  // Tinted with CSS mask-image (.refsuit): the SUIT_ICON art is a black
  // glyph CSS colour can't reach.
  return `<div class="refsuits">${suits.map(s =>
    `<span class="refsuit" style="--suit:${SUIT_COLOR[s]};--suit-mask:url(data:image/png;base64,${SUIT_ICON_B64[s]})" title="${esc(ELEMENT_SUIT_LABEL[s])}"></span>`).join("")}</div>`;
}

function refExpandHTML(entry){
  const seenTok = new Set();
  const reqs = sortIngredientTokens(entry.reqs.filter(r => {
    const k = r.kind + ":" + r.name;
    if (seenTok.has(k)) return false;
    seenTok.add(k); return true;
  }));
  return `<div class="mission-tree">${reqs.map(r =>
    jobNodeHTML(r.name, r.kind, "ref/" + entry.name + "/" + r.name, new Set([entry.name]))).join("")}</div>`;
}

/* Item Reference's row (.refrow/.refem/.refbody/...), reused by the To-Do
   List (classicPinsAndJobsHTML()) with the same jobExpanded/refExpandHTML
   machinery and the same expand key ("refroot/"+name), so a row stays
   expanded everywhere it appears. opts.rightControl replaces the pin
   toggle; opts.extraTop adds markup before the points badge; opts.complete
   overrides the owns()-based "owned" styling. */
function refStyleRowHTML(entry, opts){
  opts = opts || {};
  const has = opts.complete !== undefined ? opts.complete : owns(entry.name);
  const pinned = isPinned(entry.name);
  const path = "refroot/" + entry.name;
  const open = jobExpanded.has(path);
  const homes = ENTRIES.filter(x => x.name === entry.name).map(x => x.station);
  const control = opts.rightControl || `<button type="button" class="refpin ${pinned ? "active" : ""}" data-pin="${esc(entry.name)}"
    title="${pinned ? "Unpin" : "Pin to top"}" aria-label="${pinned ? "Unpin " : "Pin "}${esc(entry.name)}${pinned ? "" : " to top"}" aria-pressed="${pinned}">📌</button>`;
  return `<div class="refrow ${has ? "owned" : ""}" data-refname="${esc(entry.name)}" data-toggle="${path}">
    <div class="refem-col"><div class="refem">${em(entry.emoji)}</div>${refSuitsHTML(entry.name)}</div>
    <div class="refbody">
      <div class="reftop">
        <span class="refname">${esc(entry.name)}</span>
        ${has ? '<span class="tick">✓</span>' : ""}
        ${opts.extraTop || ""}
        <span class="refpts">⭐ ${entry.points}</span>
      </div>
      <div class="refwhere">${homes.map(h => `<span>${em(STATION_BY_NAME[h].emoji)} ${esc(h)}</span>`).join("")}</div>
      <button type="button" class="refexpand" data-toggle="${path}" aria-expanded="${open}">
        ${open ? "▾ Hide full breakdown" : "▸ Full breakdown"}
      </button>
      <div class="ref-tree" ${open ? "" : "hidden"}>${open ? refExpandHTML(entry) : ""}</div>
    </div>
    ${control}
  </div>`;
}

/* Item Reference: one row per item with its recipe and stations. Pinned
   items get their own section at the top (togglePin()). */
function renderCodex(){
  const seen = new Set(), allRows = [];
  ENTRIES.forEach(e => {
    if (seen.has(e.name)) return;
    seen.add(e.name);
    const homes = ENTRIES.filter(x => x.name === e.name).map(x => x.station);
    allRows.push({...e, homes});
  });

  // Every item, every mode -- Item Reference is where spoilers are allowed
  // (the walkthrough promises "look up any item's recipe"). Exceptions:
  // sub-zones the player hasn't visited stay off the list, and Classic shows
  // only CORE_SET. That check uses the NAME (CORE_ITEM_NAMES): rows are
  // deduped to one station, which may not be the item's core one (Glass).
  const rows = allRows
    .filter(row => CORE_ITEM_NAMES.has(row.name));

  const REF_SORTERS = {
    az: (a, b) => a.name.localeCompare(b.name),
    points_asc: (a, b) => (a.points - b.points) || a.name.localeCompare(b.name),
    points_desc: (a, b) => (b.points - a.points) || a.name.localeCompare(b.name),
  };
  rows.sort(REF_SORTERS[refSortMode] || REF_SORTERS.az);

  const rowHTML = e => {
    const has = owns(e.name);
    const pinned = isPinned(e.name);
    const open = jobExpanded.has("refroot/" + e.name);
    return `<div class="refrow ${has ? "owned" : ""}" data-refname="${esc(e.name)}" data-toggle="refroot/${esc(e.name)}" data-ref="${esc(e.name.toLowerCase())} ${esc(e.tier.toLowerCase())} ${esc(e.homes.join(" ").toLowerCase())} ${esc(e.recipe.toLowerCase())}">
      <div class="refem-col"><div class="refem">${em(e.emoji)}</div>${refSuitsHTML(e.name)}</div>
      <div class="refbody">
        <div class="reftop">
          <span class="refname">${esc(e.name)}</span>
          ${has ? '<span class="tick">✓</span>' : ""}
          <span class="refpts">⭐ ${e.points}</span>
        </div>
        <div class="refwhere">${e.homes.map(h =>
          `<span>${em(STATION_BY_NAME[h].emoji)} ${esc(h)}</span>`).join("")}</div>
        <button type="button" class="refexpand" data-toggle="refroot/${esc(e.name)}" aria-expanded="${open}">
          ${open ? "▾ Hide full breakdown" : "▸ Full breakdown"}
        </button>
        <div class="ref-tree" ${open ? "" : "hidden"}>${open ? refExpandHTML(e) : ""}</div>
      </div>
      <button type="button" class="refpin ${pinned ? "active" : ""}" data-pin="${esc(e.name)}"
        title="${pinned ? "Unpin" : "Pin to top"}" aria-label="${pinned ? "Unpin " : "Pin "}${esc(e.name)}${pinned ? "" : " to top"}" aria-pressed="${pinned}">📌</button>
    </div>`;
  };

  const pinnedRows = rows.filter(e => isPinned(e.name));
  const restRows = rows.filter(e => !isPinned(e.name));
  const pinnedHTML = pinnedRows.length
    ? `<div class="ref-pinned-heading">📌 Pinned</div><div class="reftable ref-pinned">${pinnedRows.map(rowHTML).join("")}</div>`
    : "";

  return `<div class="map-head"><h1>📖 Item Reference</h1></div>
    <div class="refbar">
      <input id="refFilter" type="search" placeholder="Search items, ingredients or stations…"
             aria-label="Search the item reference" value="${esc(refFilterQuery)}">
      <select id="refSort" aria-label="Sort the item reference">
        <option value="az" ${refSortMode === "az" ? "selected" : ""}>Sort: A–Z</option>
        <option value="points_asc" ${refSortMode === "points_asc" ? "selected" : ""}>Sort: Points (Low to High)</option>
        <option value="points_desc" ${refSortMode === "points_desc" ? "selected" : ""}>Sort: Points (High to Low)</option>
      </select>
    </div>
    ${pinnedHTML}
    <div class="reftable">${restRows.map(rowHTML).join("")}</div>`;
}

/* Re-applies refFilterQuery to the current #refFilter/.refrow markup, on
   input and after every re-render (renderCodex() rebuilds it). */
function applyRefFilter(){
  const refFilterEl = document.getElementById("refFilter");
  if (!refFilterEl) return;
  const q = refFilterQuery.trim().toLowerCase();
  document.querySelectorAll(".refrow").forEach(row => {
    row.style.display = (!q || row.dataset.ref.includes(q)) ? "" : "none";
  });
}

document.getElementById("screen").addEventListener("input", ev => {
  if (ev.target.id !== "refFilter") return;
  refFilterQuery = ev.target.value;
  applyRefFilter();
});
document.getElementById("screen").addEventListener("change", ev => {
  if (ev.target.id !== "refSort") return;
  refSortMode = ev.target.value;
  render();
});
