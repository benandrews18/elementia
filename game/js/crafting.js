/* =====================================================================
   crafting.js -- Crafting rules: owns()/count(), the element conversion rate, canCraft(),
   craft(), performSingleCraft(), and ingredient closures
   (componentClosure()/stillNeededClosure()) used by the To-Do List.
   ===================================================================== */
const owns  = n => state.items.includes(n);
const count = s => state.elements[s] || 0;
/* Elements spent per conversion (3 of one for 1 of another). */
const CONVERT_RATE = 3;
// Total conversions available now, across all elements -- the Convert badge
// count (updateHub()), repeated on missing-element tokens (tokenHTML()).
const totalConvertibleCount = () =>
  [...ELEMENTS].reduce((sum, sym) => sum + Math.floor(count(sym) / CONVERT_RATE), 0);

/* Group a recipe's requirements: elements accumulate, items are unique. */
function needsOf(reqs){
  const els = {}, items = [];
  reqs.forEach(r => {
    if (r.kind === "element") els[r.name] = (els[r.name] || 0) + 1;
    else if (!items.some(i => i.name === r.name)) items.push(r);
  });
  return {els, items};
}
function canCraft(entry){
  const {els, items} = needsOf(entry.reqs);
  for (const sym in els) if (count(sym) < els[sym]) return false;
  for (const it of items) if (!owns(it.name)) return false;
  return true;
}
/* The items-only half of canCraft(): are all its item ingredients owned? */
function itemReqsMet(entry){
  const {items} = needsOf(entry.reqs);
  return items.every(it => owns(it.name));
}
function craft(entry, opts={}){
  if (owns(entry.name) || !canCraft(entry)) return false;
  const {els, items} = needsOf(entry.reqs);
  // Only raw elements are spent. Catalysts are never spent.
  for (const sym in els){
    const isCat = entry.reqs.some(r => r.name === sym && r.kind === "element" && r.catalyst);
    if (!isCat) state.elements[sym] = count(sym) - els[sym];
  }
  Object.keys(state.elements).forEach(k => { if (state.elements[k] <= 0) delete state.elements[k]; });

  state.items.push(entry.name);
  // Auto-place each of a Classic run's first 8 crafts on the Display Mat (an
  // empty mat early on looks broken), using the same matFits() check as
  // toggleMatCard(). After that the player arranges it.
  if (state.items.length <= 8){
    const matCard = MAT_CARD_BY_NAME[entry.name];
    if (matCard && !state.mat.includes(entry.name) && matFits(matOnMat().concat([matCard]))){
      state.mat.push(entry.name);
    }
  }
  // A pin's whole point is tracking progress toward something not owned
  // yet -- once it's actually crafted there's nothing left to track.
  if (isPinned(entry.name)) togglePin(entry.name);
  // Crafting the tracked item clears tracking too; otherwise the Pins
  // button's "!" nudge (updateHub()'s hasUnselectedPin) never shows again.
  if (selectedJobItem === entry.name) selectedJobItem = null;
  checkBingoCompletion(entry.name);
  checkBingoLines();
  checkCraftedEverything();
  // Log the craft on the current turn (goStation() always pushes one first).
  if (state.visitLog && state.visitLog.length) state.visitLog[state.visitLog.length - 1].items.push(entry.name);
  save();
  return true;
}

/* Every item in name's ingredient chain (recursive, items only), excluding
   name. Used for the tracked-item icons on station cards. */
function componentClosure(name){
  const seen = new Set();
  function walk(n){
    if (seen.has(n)) return;
    seen.add(n);
    const entry = ENTRIES.find(e => e.name === n);
    if (!entry) return;
    const {items} = needsOf(entry.reqs);
    items.forEach(i => walk(i.name));
  }
  const rootEntry = ENTRIES.find(e => e.name === name);
  if (!rootEntry) return [];
  const {items} = needsOf(rootEntry.reqs);
  items.forEach(i => walk(i.name));
  return [...seen];
}

/* Like componentClosure(), but stops at anything already owned, so the
   "still needed" badge/ring (itemHTML()/stationItemIconsHTML()) stops
   flagging finished parts. Shared ingredients stay flagged while any branch
   still needs them. Everything else uses the full static
   componentClosure(). */
function stillNeededClosure(name){
  const seen = new Set();
  const needed = new Set();
  function visit(items){
    items.forEach(it => {
      if (owns(it.name)) return; // already satisfied -- nothing further down this branch is needed
      needed.add(it.name);
      if (seen.has(it.name)) return;
      seen.add(it.name);
      const entry = ENTRIES.find(e => e.name === it.name);
      if (entry) visit(needsOf(entry.reqs).items);
    });
  }
  const rootEntry = ENTRIES.find(e => e.name === name);
  if (!rootEntry) return [];
  visit(needsOf(rootEntry.reqs).items);
  return [...needed];
}


function performSingleCraft(entry){
  // First-ever crafts get the fly-and-stack reveal; check before craft()
  // changes owns().
  const wasOwnedBefore = owns(entry.name);
  // Capture the shop card before craft()/render() so bounceCardClosed()
  // animates the real element.
  const preCraftCard = document.querySelector(`[data-item-card="${ENTRIES.indexOf(entry)}"]`);
  if (craft(entry)){
    holdBingoForCraftReveal();

    // The ingredient fly-in runs alongside the shop bounce below (separate DOM,
    // no waiting either way).
    const firstCraftReveal = !wasOwnedBefore &&
      !lowMotion();
    if (firstCraftReveal) flyIngredientsAndReveal(entry);

    // Bounce the old card closed, then (after render()) bounce its new compact
    // icon in, independent of whichever big reveal follows.
    bounceCardClosed(preCraftCard, () => {
      render();
      bounceCardAppear(document.querySelector(`[data-item-card="${ENTRIES.indexOf(entry)}"]`));
      if (!firstCraftReveal){
        if (entry.tier === "CAPSTONE") celebrate(entry);
        else autoCardPop(entry);
      }
    });
  }
}
