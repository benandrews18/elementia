/* =====================================================================
   opening.js -- Run opening: the capstone choice and confirmation, the starting gift,
   the pin tip, and the 5x5 card's "Add Capstone" square (older saves).
   ===================================================================== */
/* =====================================================================
   Classic's opening choice: rules slides -> pick a Capstone -> confirm.
   The capstone becomes the BINGO centre and its station the starting
   station (its elements handed over, no map pick); the To-Do List opens
   with the capstone and its breakdown plus a pinning tip, then the run
   starts in that station's shop.
   ===================================================================== */
let capstoneIntroInProgress = false;
function capstoneStationOf(name){
  return (DATA.stations.find(st => st.capstone[1] === name) || {}).name || CORE_ITEM_STATION[name];
}
function capstoneComponents(entry){
  const seen = new Set();
  return sortIngredientTokens(entry.reqs.filter(r => {
    const k = r.kind + ":" + r.name;
    if (seen.has(k)) return false;
    seen.add(k); return true;
  }));
}
function openCapstoneChoice(){
  const cells = bingoCapstoneChoices().map(name => {
    const station = STATION_BY_NAME[capstoneStationOf(name)];
    return `<div class="bingo-cell" data-cap-choose="${esc(name)}" title="${esc(name)} -- ${esc(station.name)}">
      <span class="bc-station" title="${esc(station.name)}">${em(station.emoji)}</span>
      <span class="bc-icon">${em(ITEM_EMOJI[name])}</span>
      <span class="bc-name">${esc(name)}</span>
    </div>`;
  }).join("");
  document.getElementById("capChoiceBody").innerHTML = `
    <h2 id="capChoiceTitle">Choose a Capstone Project</h2>
    <p class="cap-choice-sub">Completing Capstone Projects will guide your journey through Elementia!</p>
    <div class="bingo-wrap"><div class="bingo-grid bingo-pick-grid">${cells}</div></div>`;
  openOverlay("capChoice");
}
function openCapstoneConfirm(name){
  const entry = ENTRIES.find(e => e.name === name);
  const stationName = capstoneStationOf(name);
  const comps = capstoneComponents(entry).map((r, i) => r.kind === "element"
    ? `<div class="cc-comp"><span class="cc-comp-ic el" data-cc-comp="${i}" style="--suit:${ELEMENT_COLOR[r.name] || "#8a94a6"}">${esc(r.name)}</span><span class="cc-comp-name">${esc(ELEMENT_NAMES[r.name] || r.name)}</span></div>`
    : `<div class="cc-comp"><span class="cc-comp-ic" data-cc-comp="${i}">${em(ITEM_EMOJI[r.name])}</span><span class="cc-comp-name">${esc(r.name)}</span></div>`).join("");
  document.getElementById("capConfirmBody").innerHTML = `
    ${mapCardHTML(stationName)}
    <div class="cc-cap">
      <span class="cc-cap-em" id="ccCapEm">${em(entry.emoji)}</span>
      <h2 class="cc-cap-name" id="capConfirmTitle">${esc(name)}</h2>
      <span class="cc-cap-pts">⭐ ${entry.points} pts</span>
    </div>
    <div class="cc-comp-label">COMPONENTS</div>
    <div class="cc-comps">${comps}</div>
    <div class="btnrow" style="justify-content:center; margin-top:16px">
      <button type="button" class="bigbtn sec" id="capConfirmBack">Back</button>
      <button type="button" class="bigbtn cc-go" id="capConfirmGo" data-cap-name="${esc(name)}">
        <span>Start at ${esc(stationName)}</span><small>and track ${esc(name)}</small></button>
    </div>`;
  openOverlay("capConfirm");
}
document.getElementById("capChoice").addEventListener("click", ev => {
  const cell = ev.target.closest("[data-cap-choose]");
  if (cell) openCapstoneConfirm(cell.dataset.capChoose);
});
document.getElementById("capConfirm").addEventListener("click", ev => {
  if (capstoneIntroInProgress) return;
  if (ev.target.closest("#capConfirmBack")){ closeOverlay("capConfirm"); return; }
  const go = ev.target.closest("#capConfirmGo");
  if (go) confirmCapstoneChoice(go.dataset.capName);
});
function confirmCapstoneChoice(name){
  if (capstoneIntroInProgress) return;
  capstoneIntroInProgress = true;
  const entry = ENTRIES.find(e => e.name === name);
  const stationName = capstoneStationOf(name);
  const reduced = lowMotion();
  setBingoCenter(name);
  if (!isPinned(name)) togglePin(name);
  selectedJobItem = name;
  jobExpanded.add("refroot/" + name);
  const dice = sortedDice(STATION_BY_NAME[stationName]);
  const box = document.getElementById("capConfirmBody");

  // Beat 1 -- the station's elements into the inventory, which lights up
  // (and nothing else does) until the To-Do List opens.
  introInvLit = true; updateHub();
  const chips = reduced ? [] : [...box.querySelectorAll(".map-card .pchip")];
  const hub = document.getElementById("hubInv").getBoundingClientRect();
  const FLY_MS = 560, STAGGER_MS = 80;
  chips.forEach((chip, i) => {
    const {c, r} = flightClone(chip);
    chip.style.opacity = ".25";
    const dx = hub.left + hub.width / 2 - (r.left + r.width / 2), dy = hub.top + hub.height / 2 - (r.top + r.height / 2);
    c.animate([
      { transform: "translate(0,0) scale(1)", opacity: 1, offset: 0 },
      { transform: `translate(${dx * .15}px, ${dy * .15 - 40}px) scale(1.08)`, opacity: 1, offset: .25 },
      { transform: `translate(${dx}px, ${dy}px) scale(.45)`, opacity: 1, offset: .72 },
      { transform: `translate(${dx}px, ${dy}px) scale(.12)`, opacity: 0, offset: 1 },
    ], { duration: FLY_MS, delay: i * STAGGER_MS, easing: "cubic-bezier(.4,.1,.3,1)", fill: "forwards" }).onfinish = () => c.remove();
    setTimeout(punchInventory, i * STAGGER_MS + FLY_MS * .72);
  });
  const beat2At = chips.length ? (chips.length - 1) * STAGGER_MS + FLY_MS + 150 : 0;

  // Beat 2 -- the To-Do List opens with the capstone on it (breakdown
  // expanded), and a tip about pinning pops up over it. With that tip
  // hidden (its ✕), straight to the station instead (finishPinTip()).
  setTimeout(() => {
    dice.forEach(d => { state.elements[d] = count(d) + 1; });
    save();
    introInvLit = false;
    closeOverlay("capConfirm");
    closeOverlay("capChoice");
    capStartPending = {stationName, dice};
    if (tipHidden("pinTip")){ finishPinTip(); return; }
    openJobBoard();
    setTimeout(() => openOverlay("pinTip"), reduced ? 0 : 450);
  }, beat2At);
}
// Beat 3 -- the tip is dismissed: the list closes and the run starts in
// the chosen station's shop.
let capStartPending = null;
document.getElementById("pinTip").addEventListener("click", ev => {
  if (ev.target.closest("#pinTipHide")) hideTipForever("pinTip");
  else if (!ev.target.closest("#pinTipOk")) return;
  finishPinTip();
});
function finishPinTip(){
  closeOverlay("pinTip");
  const pending = capStartPending;
  capStartPending = null;
  capstoneIntroInProgress = false;
  closeJobBoard();
  if (!pending) return;
  setTimeout(() => fadeThroughBlack(() => {
    goStation(pending.stationName);
    const turn = state.visitLog && state.visitLog[state.visitLog.length - 1];
    if (turn){
      if (!turn.elements) turn.elements = {};
      pending.dice.forEach(d => { turn.elements[d] = (turn.elements[d] || 0) + 1; });
    }
    save(); updateHub();
  }), lowMotion() ? 0 : 350);
}
/* The tracked-item badge on a shop card opens the To-Do List with the
   tracked item's breakdown unfolded down to THIS item, outlined in gold.
   Tree paths follow jobNodeHTML(): "ref/<root>/<child>/...". */
function openTodoAt(name){
  const root = selectedJobItem;
  if (!root) return;
  const itemReqs = n => {
    const e = ENTRIES.find(x => x.name === n);
    return e ? [...new Set(e.reqs.filter(r => r.kind === "item").map(r => r.name))] : [];
  };
  const find = (cur, trail) => {
    if (cur === name) return trail;
    if (trail.length > 8) return null;
    for (const c of itemReqs(cur)){
      if (trail.includes(c)) continue;
      const hit = find(c, [...trail, c]);
      if (hit) return hit;
    }
    return null;
  };
  const trail = name === root ? [] : find(root, []);
  jobExpanded.add("refroot/" + root);
  let path = "ref/" + root;
  (trail || []).slice(0, -1).forEach(n => { path += "/" + n; jobExpanded.add(path); });
  const targetPath = trail && trail.length ? "ref/" + root + "/" + trail.join("/") : null;
  openJobBoard();
  const rowSel = `#jobSheetBody .refrow[data-refname="${CSS.escape(root)}"]`;
  const target = targetPath
    ? document.querySelector(`${rowSel} .mn-head[data-toggle="${CSS.escape(targetPath)}"]`)?.closest(".mn-row")
    : document.querySelector(rowSel);
  document.querySelectorAll("#jobSheetBody .todo-hl").forEach(el => el.classList.remove("todo-hl"));
  if (!target) return;
  target.classList.add("todo-hl");
  setTimeout(() => target.scrollIntoView({block: "center", behavior: lowMotion() ? "auto" : "smooth"}), 350);
}
/* Choosing from the capstone overlay (or "Random"): sets the centre
   (setBingoCenter()), closes the overlay and flips the centre square in. */
function chooseBingoCapstone(name){
  setBingoCenter(name);
  closeCapstoneOverlay();
  renderJobBoard();
  const centerCell = document.querySelectorAll("#jobSheetBody .bingo-cell")[BINGO_CENTER_IDX];
  bingoCellFlipAppear(centerCell);
}
/* The capstone-choice grid as an overlay over the BINGO tray, opened from
   the "Add Capstone" square. */
function openCapstoneOverlay(){
  document.getElementById("capstoneOverlayBody").innerHTML = bingoCapstonePickerHTML();
  openOverlay("capstoneOverlay");
}
function closeCapstoneOverlay(){
  closeOverlay("capstoneOverlay");
}
/* Craft-from-BINGO (#bingoCraftOverlay): the real itemHTML() card, so it
   behaves exactly like the shop. craft() never checks the current station,
   so crafting away from an item's home is safe. */
let bingoCraftEntry = null;
function openBingoCraftOverlay(entry){
  bingoCraftEntry = entry;
  openOverlay("bingoCraftOverlay");
  renderBingoCraftCard();
}
// Called from render() too, so a conversion made over this card (Convert
// sits above it while it's open) updates its tokens and Craft button.
function renderBingoCraftCard(){
  if (!bingoCraftEntry || !document.getElementById("bingoCraftOverlay").classList.contains("open")) return;
  document.getElementById("bingoCraftOverlayBody").innerHTML =
    `<div class="shop">${itemHTML(bingoCraftEntry, ENTRIES.indexOf(bingoCraftEntry))}</div>`;
}
function closeBingoCraftOverlay(){
  bingoCraftEntry = null;
  if (document.getElementById("convert").classList.contains("open")) closeOverlay("convert");
  closeOverlay("bingoCraftOverlay");
}
// Shared tail for both craft paths (Craft tap, or the suit balloon's async
// craft). Clear the card markup BEFORE performSingleCraft()'s
// bounceCardAppear() looks up [data-item-card], or it would find this card
// and pop it back in.
function finishBingoCraft(){
  bingoCraftEntry = null;
  document.getElementById("bingoCraftOverlayBody").innerHTML = "";
  closeBingoCraftOverlay();
  renderJobBoard();
}
// Delegated, since the card's buttons only exist once itemHTML() is
// injected; mirrors the pieces of handleScreenClick this card needs (the
// overlay is outside #screen).
document.getElementById("bingoCraftOverlay").addEventListener("click", ev => {
  if (ev.target === ev.currentTarget){ closeBingoCraftOverlay(); return; } // scrim tap

  // A recipe token opens that ingredient's card on top (checked first, same
  // order as handleScreenClick).
  const tok = ev.target.closest(".tok[data-item-card]");
  if (tok){
    const tokEntry = ENTRIES[+tok.dataset.itemCard];
    if (tokEntry) showCardPop(tokEntry, false, true);
    return;
  }

  // Tapping the item's own icon opens its card on top (checked before the
  // pin/craft buttons in the same wrapper).
  const iconTap = ev.target.closest(".iem");
  if (iconTap){
    const itemCard = iconTap.closest("[data-item-card]");
    const entry = itemCard && ENTRIES[+itemCard.dataset.itemCard];
    if (entry) showCardPop(entry, false, true);
    return;
  }

  const shopPinBtn = ev.target.closest("[data-shop-pin]");
  if (shopPinBtn){
    const name = shopPinBtn.dataset.shopPin;
    const iconRect = shopPinBtn.closest("[data-item-card]")?.querySelector(".iem")?.getBoundingClientRect();
    togglePin(name);
    const track = isPinned(name);
    if (track) selectedJobItem = name;
    renderJobBoard();
    render();
    if (track) flyItemToTracker(name, iconRect);
    const idx = +ev.target.closest("[data-item-card]").dataset.itemCard;
    openBingoCraftOverlay(ENTRIES[idx]); // re-render this same card so its pin icon reflects the new state
    return;
  }

  const cBtn = ev.target.closest("[data-craft]");
  if (!cBtn) return;
  if (cBtn.getAttribute("aria-disabled") === "true"){ bounceCantCraft(cBtn, ENTRIES[+cBtn.dataset.craft], ev); return; }
  const entry = ENTRIES[+cBtn.dataset.craft];
  // Suit-cost items stop at the spend balloon, which crafts later;
  // finishBingoCraft() is passed as its onCraft.
  if (itemSuitCosts(entry.name).length){
    const badge = cBtn.closest("[data-item-card]")?.querySelector(".isuit-costs");
    if (badge){ ev.stopPropagation(); openSuitSpendBalloon(entry, badge, finishBingoCraft); }
    return;
  }
  performSingleCraft(entry);
  finishBingoCraft();
});

/* Legacy Classic starting gift, used when a run starts from the map: the
   first station hands over one of each element in its dice pool and its
   capstone becomes the tracked item. Two beats on the map, before
   goStation(): (1) the element chips fly into the inventory icon; (2) the
   capstone icon flies into the tracked pill. The gift and trip happen once
   both land. New runs use the capstone choice instead
   (confirmCapstoneChoice()). */
let startingGiftInProgress = false;
function isClassicFirstPick(){
  return state.lastStation === null && state.visits === 0;
}
// A fixed-position stand-in for el, sitting exactly on top of it, so the
// real card can re-render underneath without yanking anything mid-flight.
function flightClone(el){
  const r = el.getBoundingClientRect();
  const c = el.cloneNode(true);
  c.removeAttribute("data-elem");
  c.style.cssText += `;position:fixed; left:${r.left}px; top:${r.top}px; width:${r.width}px; height:${r.height}px;` +
    `margin:0; z-index:600; pointer-events:none; box-sizing:border-box;`;
  document.body.appendChild(c);
  return {c, r};
}
/* Pinning from a shop card or BINGO square: a round badge of the item flies
   into the tracked pill, which pops. The target is read from offsetLeft/Top
   since the pill may still be sliding out. */
// fromRect: the tapped card's icon, measured BEFORE the re-render that
// toggling the pin triggers (that render replaces the element itself).
function flyItemToTracker(name, fromRect){
  const entry = ENTRIES.find(e => e.name === name);
  const pill = document.getElementById("trackedPill");
  if (!entry || !fromRect || !fromRect.width || !pill || lowMotion()) return;
  const pillEm = pill.querySelector(".tp-em");
  const r = fromRect;
  const size = Math.max(36, Math.min(60, r.height));
  const c = document.createElement("div");
  c.className = "fly-item-circle";
  c.innerHTML = em(entry.emoji);
  c.style.cssText = `left:${r.left + r.width / 2 - size / 2}px; top:${r.top + r.height / 2 - size / 2}px;` +
    `width:${size}px; height:${size}px; font-size:${size * .58}px`;
  document.body.appendChild(c);
  if (pillEm) pillEm.style.visibility = "hidden";
  const tx = pill.offsetLeft + (pillEm ? pillEm.offsetLeft + pillEm.offsetWidth / 2 : 24);
  const ty = pill.offsetTop + pill.offsetHeight / 2;
  const dx = tx - (r.left + r.width / 2), dy = ty - (r.top + r.height / 2);
  const endScale = 22 / size;
  const anim = c.animate([
    { transform: "translate(0,0) scale(.6)", opacity: 0, offset: 0 },
    { transform: `translate(${dx * .1}px, ${dy * .1 - 30}px) scale(1.1)`, opacity: 1, offset: .25 },
    { transform: `translate(${dx}px, ${dy}px) scale(${endScale})`, opacity: 1, offset: .9 },
    { transform: `translate(${dx}px, ${dy}px) scale(${endScale * .6})`, opacity: 0, offset: 1 },
  ], { duration: 720, easing: "cubic-bezier(.4,.1,.3,1)", fill: "forwards" });
  anim.onfinish = () => {
    c.remove();
    const em2 = pill.querySelector(".tp-em");
    if (em2) em2.style.visibility = "";
    pill.animate([{ transform: "scale(1)" }, { transform: "scale(1.15)" }, { transform: "scale(1)" }],
      { duration: 340, easing: "cubic-bezier(.3,1.4,.4,1)" });
  };
}
function playStartingGift(name){
  if (startingGiftInProgress) return;
  startingGiftInProgress = true;
  const s = STATION_BY_NAME[name];
  const capName = s.capstone[1];
  // Track the capstone now so the pill can slide out before the icon lands;
  // its own icon stays hidden until then.
  selectedJobItem = capName;
  renderTrackedPill();
  const pill = document.getElementById("trackedPill");
  const pillEm = pill.querySelector(".tp-em");
  if (pillEm) pillEm.style.visibility = "hidden";

  const finish = () => {
    dice.forEach(d => { state.elements[d] = count(d) + 1; });
    if (pillEm) pillEm.style.visibility = "";
    startingGiftInProgress = false;
    goStation(name);
    // goStation() pushes this visit's turn-log entry -- the gift is part
    // of what the player collected on visit 1.
    const turn = state.visitLog && state.visitLog[state.visitLog.length - 1];
    if (turn){
      if (!turn.elements) turn.elements = {};
      dice.forEach(d => { turn.elements[d] = (turn.elements[d] || 0) + 1; });
    }
    save(); updateHub();
  };

  const dice = sortedDice(s);
  const chips = [...document.querySelectorAll(".map-card .pchip")];
  const hub = document.getElementById("hubInv").getBoundingClientRect();
  const hx = hub.left + hub.width / 2, hy = hub.top + hub.height / 2;
  const FLY_MS = 560, STAGGER_MS = 80, CONTACT = .72;
  // Beat 1 -- elements into the inventory.
  chips.forEach((chip, i) => {
    const sym = chip.querySelector(".psym");
    const {c, r} = flightClone(chip);
    const cSym = c.querySelector(".psym");
    if (sym && cSym) cSym.style.fontSize = getComputedStyle(sym).fontSize;
    c.style.boxShadow = "0 6px 16px rgba(0,0,0,.35)";
    chip.style.opacity = ".25";
    const dx = hx - (r.left + r.width / 2), dy = hy - (r.top + r.height / 2);
    const anim = c.animate([
      { transform: "translate(0,0) scale(1)", opacity: 1, offset: 0 },
      { transform: `translate(${dx * .15}px, ${dy * .15 - 40}px) scale(1.08)`, opacity: 1, offset: .25 },
      { transform: `translate(${dx}px, ${dy}px) scale(.45)`, opacity: 1, offset: CONTACT },
      { transform: `translate(${dx}px, ${dy}px) scale(.12)`, opacity: 0, offset: 1 },
    ], { duration: FLY_MS, delay: i * STAGGER_MS, easing: "cubic-bezier(.4,.1,.3,1)", fill: "forwards" });
    anim.onfinish = () => c.remove();
    setTimeout(punchInventory, i * STAGGER_MS + FLY_MS * CONTACT);
  });
  const beat2At = chips.length ? (chips.length - 1) * STAGGER_MS + FLY_MS + 180 : 0;

  // Beat 2 -- the capstone into the tracked-item pill.
  setTimeout(() => {
    const src = document.querySelector(".map-card .capline .cap-em");
    const target = pillEm || pill;
    if (!src || !pill.classList.contains("show")){ finish(); return; }
    const {c, r} = flightClone(src);
    c.style.fontSize = getComputedStyle(src).fontSize;
    c.style.display = "flex"; c.style.alignItems = "center"; c.style.justifyContent = "center";
    src.style.visibility = "hidden";
    const t = target.getBoundingClientRect();
    const dx = (t.left + t.width / 2) - (r.left + r.width / 2), dy = (t.top + t.height / 2) - (r.top + r.height / 2);
    const endScale = Math.max(.4, Math.min(1.2, t.height / Math.max(1, r.height)));
    const anim = c.animate([
      { transform: "translate(0,0) scale(1)", offset: 0 },
      { transform: `translate(${dx * .2}px, ${dy * .2 - 30}px) scale(1.9)`, offset: .3 },
      { transform: `translate(${dx}px, ${dy}px) scale(${endScale})`, offset: 1 },
    ], { duration: 720, easing: "cubic-bezier(.45,.05,.3,1)", fill: "forwards" });
    anim.onfinish = () => {
      c.remove();
      if (pillEm) pillEm.style.visibility = "";
      pill.animate([
        { transform: "translateX(0) scale(1)" }, { transform: "translateX(0) scale(1.15)" }, { transform: "translateX(0) scale(1)" },
      ], { duration: 380, easing: "cubic-bezier(.3,1.4,.4,1)" });
      setTimeout(finish, 420);
    };
  }, beat2At);
}

// Delegated: the picker's buttons only exist once openCapstoneOverlay() has
// injected bingoCapstonePickerHTML().
document.getElementById("capstoneOverlay").addEventListener("click", ev => {
  if (ev.target === ev.currentTarget){ closeCapstoneOverlay(); return; } // scrim tap
  if (ev.target.closest("#capstoneOverlayClose")){ closeCapstoneOverlay(); return; }
  const pickBtn = ev.target.closest("[data-capstone-pick]");
  if (pickBtn) chooseBingoCapstone(pickBtn.dataset.capstonePick);
});
