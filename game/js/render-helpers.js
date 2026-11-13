/* =====================================================================
   render-helpers.js -- Rendering helpers shared by every screen: esc(), em() (icon markup),
   dice faces, element tokens, recipe rows and the shop item card
   (itemHTML()).
   ===================================================================== */
const esc = s => String(s).replace(/[&<>"']/g, c =>
  ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
/* Convert's own icon since 2026-10-31: an atomic nucleus (protons/neutrons
   ringed by electron orbits) -- replaced the two circular arrows. */
const ATOM_SVG = '<svg class="converticon" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><g fill="none" stroke="#7fd6ff" stroke-width="2.6"><ellipse cx="32" cy="32" rx="28" ry="10.5"/><ellipse cx="32" cy="32" rx="28" ry="10.5" transform="rotate(60 32 32)"/><ellipse cx="32" cy="32" rx="28" ry="10.5" transform="rotate(120 32 32)"/></g><g stroke="#1b1b24" stroke-width="1"><circle cx="27.5" cy="29" r="5.2" fill="#4d7cf2"/><circle cx="36.5" cy="29" r="5.2" fill="#f0674c"/><circle cx="32" cy="25" r="5.2" fill="#f0674c"/><circle cx="25.5" cy="35" r="5.2" fill="#f0674c"/><circle cx="38.5" cy="35" r="5.2" fill="#4d7cf2"/><circle cx="32" cy="38.5" r="5.2" fill="#4d7cf2"/><circle cx="32" cy="32" r="5.2" fill="#f0674c"/></g><g fill="#fff" opacity=".55"><circle cx="30.4" cy="30.4" r="1.6"/><circle cx="30.4" cy="23.4" r="1.6"/><circle cx="34.9" cy="27.4" r="1.6"/><circle cx="23.9" cy="33.4" r="1.6"/></g></svg>';
const CUSTOM_ICONS = {...NOTO_ICONS, "__WHEEL__": WHEEL_IMG, "__FURNACE__": FURNACE_IMG, "__OVEN__": OVEN_IMG, "__BANANABREAD__": BANANABREAD_IMG, "__TURBINEBLADE__": TURBINEBLADE_IMG, "__STEEL__": STEEL_IMG, "__FOSSIL__": FOSSIL_IMG, "__CONCRETE__": CONCRETE_IMG, "__FIBERGLASS__": FIBERGLASS_IMG, "__LOGCABIN__": LOGCABIN_IMG, "__ORCA__": ORCA_SVG, "__CORAL__": CORAL_SVG, "__FLOUR__": FLOUR_SVG, "__LIGHTHOUSE__": LIGHTHOUSE_SVG, "__RUBBER__": RUBBER_SVG, "__MICROCHIP__": MICROCHIP_IMG, "__LIFE__": LIFE_IMG, "__ECOSYSTEM__": ECOSYSTEM_IMG, "__DIAMOND__": DIAMOND_IMG, "__BRASSBAR__": BRASS_BAR_SVG, "__MARKETPLACE__": MARKETPLACE_IMG, "__CONVERT__": ATOM_SVG};
const em = e => CUSTOM_ICONS[e] || esc(e);
// Items whose art reads small on the card popup; same set as
// build_cards_classic.py's ENLARGED_ICONS (see showCardPop()).
const PDF_ENLARGED_ICONS = new Set(["Ecosystem", "Fruit Cake", "Coral Reef", "Banana Bread", "Concrete", "Fiberglass"]);

/* Dots are CSS gradients on the .die element (see .die-1..6), keyed off
   PIPS -- no child nodes. */
function dieFace(v){
  return `<div class="die die-${v}"></div>`;
}

// plain: inventory list (already crafted), so no have/need colouring and no
// convert count -- also skips totalConvertibleCount() per token.
function tokenHTML(r, groupedEls, plain){
  // Element tokens open the element card (same as tapping one anywhere
  // else).
  if (r.kind === "element"){
    const need = groupedEls[r.name], have = count(r.name);
    const ok = plain || have >= need;
    const suit = ELEMENT_COLOR_DARK[r.name] || "#4a4f5c";
    // Missing tokens only: the global conversion count (as on the Convert
    // badge), hinting that Convert could cover this.
    const totalConvertible = ok ? 0 : totalConvertibleCount();
    const convertBadge = totalConvertible > 0
      ? `<span class="tok-convert-badge" title="${totalConvertible} conversion${totalConvertible === 1 ? "" : "s"} available right now"></span>` : "";
    const checkBadge = ok ? '<span class="tok-check">✓</span>' : "";
    return `<button type="button" class="tok el ${ok ? "have" : "need"}" style="--suit:${suit}" data-elem="${esc(r.name)}" title="You have ${have}, need ${need} — tap for its card">` +
      `${esc(r.name)}${checkBadge}${convertBadge}` +
      (r.catalyst ? '<span class="cat">not spent</span>' : "") + "</button>";
  }
  const ok = owns(r.name);
  // Item tokens open that ingredient's inspection card (via #screen's
  // [data-item-card] delegation), owned or not.
  const refIdx = ENTRIES.findIndex(e => e.name === r.name);
  const checkBadge = ok ? '<span class="tok-check">✓</span>' : "";
  return `<span class="tok ${ok ? "have" : "need"}"${refIdx >= 0 ? ` data-item-card="${refIdx}"` : ""} title="${esc(r.name)}">` +
    `<span class="tok-icon">${em(r.emoji)}</span>${checkBadge}` +
    (r.catalyst ? '<span class="cat">not spent</span>' : "") + "</span>";
}

function recipeHTML(entry, plain){
  const {els} = needsOf(entry.reqs);
  const seen = new Set();
  const toks = entry.reqs.filter(r => {
    const k = r.kind + ":" + r.name;
    if (seen.has(k)) return false;
    seen.add(k); return true;
  });
  return sortIngredientTokens(toks).map(r => tokenHTML(r, els, plain)).join('<span class="plus">+</span>');
}

// Craft button (shop rows and the station's card view). aria-disabled, not
// disabled: a blocked craft still gets the tap for its "Missing ..." notice
// (the [data-craft] handler).
function craftBtnHTML(entry, idx){
  if (owns(entry.name)) return '<span class="craftbtn done">✓ Owned</span>';
  const can = canCraft(entry) && suitCostPayable(entry);
  return `<button type="button" class="craftbtn ${can ? "go" : ""}" data-craft="${idx}" aria-disabled="${can ? "false" : "true"}">Craft</button>`;
}
function itemHTML(entry, idx){
  const done = owns(entry.name);
  const can = canCraft(entry) && suitCostPayable(entry);
  const cls = [done ? "owned" : (can ? "can" : "")];
  // Green ring = craftable right now, nothing else. The corner badge below
  // separately marks items still needed for the tracked item (it shows the
  // TRACKED item's icon). stillNeededClosure() so finished intermediates stop
  // flagging their ingredients unless a sibling branch still needs them.
  if (can && !done) cls.push("job-highlight");
  let pinBadge = "";
  if (selectedJobItem){
    const jobTree = new Set([selectedJobItem, ...stillNeededClosure(selectedJobItem)]);
    // The tracked item itself keeps its pin button (so it can be unpinned);
    // the badge is only for what feeds it.
    if (jobTree.has(entry.name) && entry.name !== selectedJobItem){
      const selEntry = ENTRIES.find(e => e.name === selectedJobItem);
      if (selEntry) pinBadge = `<span class="item-pin-badge" role="button" tabindex="0" data-open-todo="${esc(entry.name)}" title="Needed for ${esc(selectedJobItem)} -- tap to see it on your To-Do List">${em(selEntry.emoji)}</span>`;
    }
  }
  // The badge takes the pin button's corner -- a card shows one or the
  // other.
  const pinSlot = pinBadge || `<button type="button" class="refpin shop-pin ${isPinned(entry.name) ? "active" : ""}" data-shop-pin="${esc(entry.name)}"
      title="${isPinned(entry.name) ? "Unpin" : "Pin to top"}" aria-label="${isPinned(entry.name) ? "Unpin " : "Pin "}${esc(entry.name)}${isPinned(entry.name) ? "" : " to top"}" aria-pressed="${isPinned(entry.name)}">📌</button>`;
  const btn = craftBtnHTML(entry, idx);
  return `<div class="item ${cls.join(" ")}" data-item-card="${idx}">
    ${pinSlot}
    ${itemRowHTML(entry, can)}${btn}</div>`;
}
// The icon/name/suit costs/recipe row, shared by the shop and the
// Inventory's list view (matShopRowHTML()).
function itemRowHTML(entry, can, plain){
  return `<div class="irow">
      <div class="iem" style="--item-suit:${SUIT_COLOR[itemSuitOf(entry.name)]}">${em(entry.emoji)}</div>
      <div class="ibody">
        <div class="itop"><span class="iname">${esc(entry.name)}</span>${suitCostBadgesHTML(entry, can, plain)}</div>
        <div class="recipe">${recipeHTML(entry, plain)}</div>
      </div>
    </div>`;
}

/* Compact crafted-items row (when "Collapse crafted" is on, see
   renderStation()), using the map preview's icon style. */
function craftedIconsHTML(entries){
  return entries.map(e => `<span class="station-item-icon owned" title="${esc(e.name)}" data-item-card="${idx(e)}">${em(e.emoji)}</span>`).join("");
  function idx(e){ return ENTRIES.indexOf(e); }
}
