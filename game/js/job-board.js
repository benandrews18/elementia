/* =====================================================================
   job-board.js -- The tray behind Home's Market face and the To-Do List button
   (#jobSheet): the full BINGO board, the compact To-Do List, its
   ingredient tree and hint, and the stations-visited row. Named
   "job board" after the feature it grew out of.
   ===================================================================== */
const jobSheet = document.getElementById("jobSheet"), jobScrim = document.getElementById("jobScrim");
/* Two doors into this one sheet: Home's Market face opens the FULL board
   (top tray, openJobSelectTray()); the hub's To-Do List button opens the
   smaller left-side tray (openJobBoard()) with pins and jobs only.
   jobSheetVariant remembers which is showing so re-renders keep it. */
let jobSheetVariant = "full"; // "full" | "compact" -- Classic Mode only, see above
function renderJobBoard(){
  const full = jobSheetVariant === "full";
  document.getElementById("jobTitle").innerHTML = full
    ? `${em("__MARKETPLACE__")} Marketplace` // same icon as Home's Market face
    : "📋 To-Do List";
  document.getElementById("jobSheetBody").innerHTML = full
          // Classic's full tray: the stations-visited card and the BINGO card (no
          // job board -- jobs can't be taken here). The BINGO card is always shown;
          // before a capstone is chosen its centre is an "Add Capstone" square that
          // opens the picker overlay (openCapstoneOverlay()).
          ? `<div class="market-classic-progress">${marketStationProgressHTML()}</div>${bingoCardHTML()}`
          : classicPinsAndJobsHTML();
  // Only the BINGO view has cells to animate; a no-op otherwise.
  if (full) scheduleBingoSequence();
}
/* The compact To-Do List: the pinned items only, in the same markup as Item
   Reference's pinned section (refStyleRowHTML() rows), so pin/breakdown
   buttons work via #jobSheetBody's [data-pin]/[data-toggle] handling.
   Nothing renders when nothing is pinned. Switching which pin is tracked
   happens in the Pins tray. Job cards are retired in Classic. */
/* "What should I craft next?": looks through every pinned item's remaining
   ingredient tree (stillNeededClosure()). Prefers items already buildable
   from owned items, then items that feed several pinned goals, then fewer
   remaining steps. Ignores which elements happen to be held (they reset
   every visit). null when everything is owned. */
function computeTodoHint(){
  const roots = prefs.pinnedItems.filter(name => ENTRIES.some(e => e.name === name) && !owns(name));
  if (!roots.length) return null;

  const usage = new Map(); // candidate item name -> Set of pinned roots it feeds
  roots.forEach(root => {
    new Set([root, ...stillNeededClosure(root)]).forEach(name => {
      if (!usage.has(name)) usage.set(name, new Set());
      usage.get(name).add(root);
    });
  });

  let best = null;
  usage.forEach((rootSet, name) => {
    const entry = ENTRIES.find(e => e.name === name);
    if (!entry) return;
    const candidate = {
      name, entry, usageCount: rootSet.size,
      ready: itemReqsMet(entry),
      remaining: stillNeededClosure(name).length,
    };
    const better = !best
      || (candidate.ready && !best.ready)
      || (candidate.ready === best.ready && candidate.usageCount > best.usageCount)
      || (candidate.ready === best.ready && candidate.usageCount === best.usageCount && candidate.remaining < best.remaining)
      || (candidate.ready === best.ready && candidate.usageCount === best.usageCount && candidate.remaining === best.remaining && candidate.name.localeCompare(best.name) < 0);
    if (better) best = candidate;
  });
  if (!best) return null;
  return { ...best, homes: ENTRIES.filter(x => x.name === best.name).map(x => x.station) };
}
function todoHintResultHTML(){
  const hint = computeTodoHint();
  if (!hint) return `<p class="todo-hint-empty">Everything on your list is already crafted!</p>`;
  const homesHTML = hint.homes.map(h => `<span>${em(STATION_BY_NAME[h].emoji)} ${esc(h)}</span>`).join("");
  return `<div class="todo-hint-card">
      <div class="todo-hint-icon">${em(hint.entry.emoji)}</div>
      <div class="todo-hint-body">
        <div class="todo-hint-title">Try crafting ${esc(hint.name)}</div>
        <div class="todo-hint-why">${hint.usageCount > 1 ? `Feeds ${hint.usageCount} items on your list` : "On your list"}${hint.ready ? " — you have everything it needs" : ""}</div>
        <div class="todo-hint-where">${homesHTML}</div>
      </div>
    </div>`;
}
function classicPinsAndJobsHTML(){
  // The tracked item (selectedJobItem) always leads, with a 🔍 corner badge.
  const names = prefs.pinnedItems.filter(name => ENTRIES.some(e => e.name === name))
    .sort((a, b) => (b === selectedJobItem) - (a === selectedJobItem));
  if (!names.length) return "";
  const hintHTML = `<button type="button" class="todo-hint-btn" data-todo-hint aria-expanded="${todoHintOpen}">
      💡 ${todoHintOpen ? "Hide Hint" : "Get a Hint"}
    </button>${todoHintOpen ? todoHintResultHTML() : ""}`;
  return `<div class="ref-pinned-heading">📌 Pinned</div>${hintHTML}<div class="reftable ref-pinned">${
      names.map(name => refStyleRowHTML(ENTRIES.find(e => e.name === name), name === selectedJobItem
        ? { cls: "tracked", badge: '<span class="todo-tracked-badge" title="Currently tracked">🔍</span>' } : {})).join("")
    }</div>`;
}
/* Shared open logic; jobSheetVariant decides the content and whether the
   sheet slides from the top or the left (#jobSheet.top-tray). */
function openJobSheet(){
  renderJobBoard();
  // Jump to this variant's closed position with transitions off, then
  // re-enable and open. Otherwise opening one variant right after closing the
  // other animates from a blend of the two positions.
  jobSheet.style.transition = "none";
  jobSheet.classList.remove("open");
  // "full" is only the Market face's door (Classic BINGO, Hard's tray);
  // "compact" is the hub button.
  jobSheet.classList.toggle("top-tray", jobSheetVariant === "full");
  jobSheet.offsetHeight; // force reflow
  jobSheet.style.transition = "";
  jobSheet.classList.add("open"); jobScrim.classList.add("open");
  jobSheet.setAttribute("aria-hidden", "false");
  document.getElementById("hubJobs").setAttribute("aria-expanded", "true");
  updateHub();
}
/* Home's Market face: the full BINGO board from the top. Counts as visiting the Marketplace
   (state.marketVisited, which clears Home's "!"). */
function openJobSelectTray(){
  jobSheetVariant = "full";
  bingoTab = "bingo";
  state.marketVisited = true;
  state.marketUnseen = false;
  openJobSheet();
  updateHub();
}
/* The hub's To-Do List button: the compact tray (classicPinsAndJobsHTML()). */
function openJobBoard(){
  jobSheetVariant = "compact";
  openJobSheet();
}
function closeJobBoard(){
  // Not dismissible mid-animation: during the flip-in reveal
  // (runBingoRevealSequence()), the BINGO sequence (runBingoSequence()), or
  // the opening capstone sequence -- a scrim tap would leave things
  // half-done.
  if (bingoRevealInProgress || bingoClearInProgress || capstoneIntroInProgress) return;
  jobSheet.classList.remove("open"); jobScrim.classList.remove("open");
  jobSheet.setAttribute("aria-hidden", "true");
  document.getElementById("hubJobs").setAttribute("aria-expanded", "false");
  // Closing the tray is what ends Classic's opening (data-intro-sequence)
  // and hands interactivity back; the extra render() is only needed then.
  if (document.body.hasAttribute("data-intro-sequence")){
    document.body.removeAttribute("data-intro-sequence");
    render();
  }
  updateHub();
}

/* Shared by the topbar's job chips and the (legacy, now-unreachable)
   [data-select-job] case in #screen's own click handler. */
function toggleJobSelect(name){
  selectedJobItem = selectedJobItem === name ? null : name;
  render();
}

/* Expanded tree paths (e.g. "ref/City/Bridge/Concrete"). The tree is
   re-rendered on every toggle, so expand state lives here. Not saved. */
const jobExpanded = new Set();
// Whether the To-Do List's own Hint panel is currently showing -- same
// ephemeral, re-render-from-scratch pattern as jobExpanded above.
let todoHintOpen = false;

/* Where a thing comes from, as station emoji only -- an element is rolled
   at its stations, an item is built at the stations that sell it. */
function whereEmoji(name, kind){
  const where = kind === "element"
    ? DATA.stations.filter(s => s.dice.includes(name))
    : ENTRIES.filter(e => e.name === name).map(e => STATION_BY_NAME[e.station]);
  const seen = new Set();
  return where.filter(s => s && !seen.has(s.name) && seen.add(s.name))
    .map(s => `<span class="mn-at" title="${esc(s.name)}">${em(s.emoji)}</span>`).join("");
}

/* Read-only: this is a map of what's still needed, not a second place to
   craft from -- crafting always happens at the station shop. */
function jobNodeHTML(name, kind, path, seen){
  if (kind === "element"){
    const have = count(name) >= 1;
    return `<div class="mn-leaf ${have ? "have" : "need"}">
      <span class="mn-elsym" style="--suit:${ELEMENT_COLOR[name] || "#8a94a6"}">${esc(name)}</span>
      <span class="mn-elname">${esc(ELEMENT_NAMES[name] || name)}</span>
      <span class="mn-where">${whereEmoji(name, "element")}</span>
    </div>`;
  }
  const entry = ENTRIES.find(e => e.name === name);
  if (!entry) return "";
  const has = owns(name);
  const open = jobExpanded.has(path);
  const pinned = isPinned(name);

  let childrenHTML = "";
  if (!seen.has(name)){
    const seen2 = new Set(seen); seen2.add(name);
    const seenTok = new Set();
    // Same rule as every other level of this tree (see refExpandHTML()'s
    // own top-level sort) -- this was the one nesting level still left in
    // raw declaration order.
    childrenHTML = sortIngredientTokens(entry.reqs.filter(r => {
      const k = r.kind + ":" + r.name;
      if (seenTok.has(k)) return false;
      seenTok.add(k); return true;
    })).map(r => jobNodeHTML(r.name, r.kind, path + "/" + r.name, seen2)).join("");
  }

  // The same pin button as the top-level row, so a component can be pinned
  // from deep in a breakdown.
  return `<div class="mission-node ${has ? "done" : ""}">
    <div class="mn-row">
      ${has ? '<span class="mn-tick">✓</span>' : ""}
      <button type="button" class="mn-head${open ? " open" : ""}" data-toggle="${esc(path)}" aria-expanded="${open}">
        <span class="mn-arrow">▸</span>
        <span class="mn-emoji">${em(entry.emoji)}</span>
        <span class="mn-name">${esc(name)}</span>
        <span class="mn-where">${whereEmoji(name, "item")}</span>
      </button>
      <button type="button" class="refpin ${pinned ? "active" : ""}" data-pin="${esc(name)}"
        title="${pinned ? "Unpin" : "Pin to top"}" aria-label="${pinned ? "Unpin " : "Pin "}${esc(name)}${pinned ? "" : " to top"}" aria-pressed="${pinned}">📌</button>
    </div>
    <div class="mn-children" ${open ? "" : "hidden"}>${childrenHTML}</div>
  </div>`;
}

/* Stations-visited progress row (compact circles) at the top of the BINGO
   tray. */
// Fixed display order (Ocean, Old Growth, Deep Mine, Greenhouse, Power
// Plant, Bakery, City, Observatory), not DATA.stations' order.
const STATION_TRACKER_ORDER = [
  "The Ocean", "Old Growth Forest", "Deep Mine", "Greenhouse",
  "The Power Plant", "The Bakery", "The City", "The Observatory",
];
// Every station shows its icon; visited ones add a green check.
function stationProgressCirclesHTML(){
  return STATION_TRACKER_ORDER.map(name => {
    const s = STATION_BY_NAME[name];
    const visited = !!state.visitedStations[name];
    return `<span class="market-progress-station${visited ? " visited" : ""}" title="${esc(name)}">
      ${em(s.emoji)}
      ${visited ? '<span class="mps-check">✓</span>' : ""}
    </span>`;
  }).join("");
}
function marketStationProgressHTML(){
  const visitedCount = DATA.stations.filter(s => state.visitedStations[s.name]).length;
  return `<div class="market-station-progress-label">${visitedCount}/${DATA.stations.length} Stations Visited</div>
    <div class="market-progress-stations">${stationProgressCirclesHTML()}</div>`;
}

document.getElementById("jobSheetClose").addEventListener("click", closeJobBoard);
jobScrim.addEventListener("click", closeJobBoard);
document.getElementById("jobSheetBody").addEventListener("click", ev => {
  // The BINGO centre square's "Add Capstone" placeholder opens the capstone
  // overlay (openCapstoneOverlay()). Checked before the generic
  // [data-item-card] handling.
  const addCapstoneBtn = ev.target.closest("[data-add-capstone]");
  if (addCapstoneBtn){ openCapstoneOverlay(); return; }

  // Marketplace card's BINGO / Capstones tabs, and the Capstones page's
  // own squares -- each opens that capstone's inspection card.
  const bingoTabBtn = ev.target.closest("[data-bingo-tab]");
  if (bingoTabBtn){
    if (bingoRevealInProgress || bingoClearInProgress) return;
    bingoTab = bingoTabBtn.dataset.bingoTab;
    renderJobBoard();
    return;
  }

  const hintBtn = ev.target.closest("[data-todo-hint]");
  if (hintBtn){ todoHintOpen = !todoHintOpen; renderJobBoard(); return; }

  // A BINGO square's corner pin, checked before the whole-cell handler below
  // (which would also match it).
  const bcPinBtn = ev.target.closest(".bc-pin[data-pin]");
  if (bcPinBtn){
    const name = bcPinBtn.dataset.pin;
    const iconRect = bcPinBtn.closest(".bingo-cell")?.querySelector(".bc-icon")?.getBoundingClientRect();
    togglePin(name);
    const track = isPinned(name);
    if (track) selectedJobItem = name;
    renderJobBoard();
    render();
    if (track) flyItemToTracker(name, iconRect);
    return;
  }

  // Capstone squares (checked after their own 📌 above): the item card.
  const capInspect = ev.target.closest("[data-cap-inspect]");
  if (capInspect){
    const entry = ENTRIES[+capInspect.dataset.capInspect];
    if (entry) showCardPop(entry, false);
    return;
  }
  // BINGO squares: an owned item opens its inspection card; an unowned one
  // opens the craft-from-here card (openBingoCraftOverlay()), so it can be made
  // without travelling.
  const bingoCell = ev.target.closest(".bingo-cell[data-item-card]");
  if (bingoCell){
    const entry = ENTRIES[+bingoCell.dataset.itemCard];
    if (entry){
      if (owns(entry.name)) showCardPop(entry, false);
      else openBingoCraftOverlay(entry);
    }
    return;
  }

  const pinBtn = ev.target.closest("[data-pin]");
  if (pinBtn){
    const name = pinBtn.dataset.pin;
    togglePin(name);
    // Pinning from a card also tracks the item, so its ingredient
    // ring shows everywhere at once.
    if (isPinned(name)) selectedJobItem = name;
    renderJobBoard();
    render();
    return;
  }

  // "Full breakdown" toggles for rows in this sheet (it's outside #screen, so
  // #screen's [data-toggle] handling never sees them).
  const refToggleBtn = ev.target.closest("[data-toggle]");
  if (refToggleBtn){
    const path = refToggleBtn.dataset.toggle;
    if (jobExpanded.has(path)) jobExpanded.delete(path); else jobExpanded.add(path);
    renderJobBoard();
    return;
  }
});
