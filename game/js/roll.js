/* =====================================================================
   roll.js -- Dice: doRoll(), the roll popup animation, Collect, and the dice
   flying into the inventory.
   ===================================================================== */
function doRoll(rollCount){
  if (state.rolledHere) return;
  const s = STATION_BY_NAME[current], out = [];
  const dice = sortedDice(s);
  const base = rollCount == null ? TAKE : rollCount;
  // Classic: MAT_PRE_CHECK_DICE (4) until the first mat check, then base +
  // this trip's bonus (state.tripDice, set by finishLockIn()/quietCheck();
  // older saves fall back to the latest check's).
  const bonus = state.tripDice != null ? state.tripDice : (state.matBonusDice || 0);
  const n = state.matChecked ? base + bonus : Math.max(MAT_PRE_CHECK_DICE, base);
  for (let i = 0; i < n; i++){
    const sym = dice[Math.floor(Math.random() * 6)];
    const face = dice.indexOf(sym) + 1;
    state.elements[sym] = count(sym) + 1;
    out.push({face, sym});
  }
  state.rolledHere = true; state.lastRoll = out;
  // Tallied into this visit's own turn-log entry (see goStation()'s own
  // push) -- History's per-turn breakdown reads this to show what was
  // collected here alongside what got crafted.
  if (state.visitLog && state.visitLog.length){
    const turn = state.visitLog[state.visitLog.length - 1];
    if (!turn.elements) turn.elements = {};
    out.forEach(({sym}) => { turn.elements[sym] = (turn.elements[sym] || 0) + 1; });
  }
  save();
  // Unlock the Map button now rather than with the deferred render() -- both
  // landing at once read as a stutter.
  updateHub();
  playRollAnimation(out);
}

// True from the start of a roll's animation until its last card lands
// (flyToInventory()); renderStation() keeps .stationhead frozen meanwhile,
// since rolledHere flips true too early.
let rollAnimationInProgress = false;
/* The roll plays in #rollPopup, centred on screen: each die tumbles, holds
   and reveals; then a Collect button appears and only tapping it sends the
   elements to the inventory (collectRoll()). */
let rollPopupCards = null;
function playRollAnimation(out){
  rollAnimationInProgress = true;
  const popup = document.getElementById("rollPopup");
  const row = document.getElementById("rollPopupRow");
  const collect = document.getElementById("rollCollect");
  row.innerHTML = "";
  collect.classList.remove("show");
  popup.classList.add("open");
  popup.setAttribute("aria-hidden", "false");
  const STAGGER_MS = 90, TUMBLE_MS = 500, PAUSE_MS = 350;
  const cards = out.map((r, i) => {
    const card = document.createElement("div");
    card.className = "rollchip";
    card.style.setProperty("--suit", ELEMENT_COLOR[r.sym] || "#8a94a6");
    // Same square as the station's element pool (see .rc-face), with the
    // die laid over it until the reveal.
    card.innerHTML = `<div class="rc-face"><span class="rc-num">${ATOMIC_NUMBER[r.sym] || ""}</span>` +
      `<span class="rc-sym">${esc(r.sym)}</span>${elSuitBadgeHTML(r.sym)}` +
      `<span class="rc-name">${esc(ELEMENT_NAMES[r.sym] || r.sym)}</span>` +
      `<div class="rc-die die die-${r.face} tumbling" style="animation-delay:${i * STAGGER_MS}ms"></div></div>`;
    row.appendChild(card);
    // Hold briefly on the settled face, then the die fades off the element.
    setTimeout(() => card.classList.add("revealed"), i * STAGGER_MS + TUMBLE_MS + PAUSE_MS);
    return card;
  });
  rollPopupCards = cards;
  const lastRevealMs = (cards.length - 1) * STAGGER_MS + TUMBLE_MS + PAUSE_MS;
  setTimeout(() => { collect.classList.add("show"); collect.focus({preventScroll: true}); }, lastRevealMs + 300);
}
function collectRoll(){
  const cards = rollPopupCards;
  if (!cards) return;
  rollPopupCards = null;
  const popup = document.getElementById("rollPopup");
  document.getElementById("rollCollect").classList.remove("show");
  // Lift each card out of the popup to the body at its exact spot first --
  // the popup fades out underneath while they fly.
  const rects = cards.map(c => c.getBoundingClientRect());
  cards.forEach((c, i) => {
    const r = rects[i];
    c.style.cssText += `;position:fixed; left:${r.left}px; top:${r.top}px; width:${r.width}px; height:${r.height}px; margin:0; z-index:150; animation:none; transform-origin:50% 50%`;
    document.body.appendChild(c);
  });
  popup.classList.remove("open");
  popup.setAttribute("aria-hidden", "true");
  flyToInventory(cards, null);
}
document.getElementById("rollCollect").addEventListener("click", collectRoll);

function flyToInventory(cards, playBar){
  const hub = document.getElementById("hubInv");
  const target = hub.getBoundingClientRect();
  const tx = target.left + target.width / 2, ty = target.top + target.height / 2;
  // Measure every card's rect BEFORE changing any: making one fixed reflows
  // the rest.
  const rects = cards.map(c => c.getBoundingClientRect());
  const FLY_MS = 480, FLY_STAGGER_MS = 45, CONTACT_FRACTION = .72;

  cards.forEach((card, i) => {
    const r = rects[i];
    card.style.position = "fixed";
    card.style.left = r.left + "px";
    card.style.top = r.top + "px";
    card.style.width = r.width + "px";
    card.style.margin = "0";
    card.style.animation = "none"; // stop the CSS pop/tumble before WAAPI takes over transform
    card.classList.add("flying");
    const dx = tx - (r.left + r.width / 2), dy = ty - (r.top + r.height / 2);
    // Arrives at CONTACT_FRACTION, then shrinks and fades in place ("absorbed
    // into the bag").
    const anim = card.animate([
      { transform: "translate(0,0) scale(1)", opacity: 1, offset: 0 },
      { transform: `translate(${dx}px, ${dy}px) scale(.55)`, opacity: 1, offset: CONTACT_FRACTION },
      { transform: `translate(${dx}px, ${dy}px) scale(.15)`, opacity: 0, offset: 1 },
    ], { duration: FLY_MS, delay: i * FLY_STAGGER_MS, easing: "cubic-bezier(.4,.1,.3,1)", fill: "forwards" });
    // Render after this WAAPI animation, not the CSS height transition:
    // reduced motion collapses CSS transitions but not WAAPI, so a
    // transitionend render would pull cards out mid-flight. Wrapped, because
    // onfinish passes an event that would land in render()'s resetScroll
    // parameter.
    if (i === cards.length - 1) anim.onfinish = () => { cards.forEach(c => c.remove()); rollAnimationInProgress = false; render(); };
  });
  // Punch as soon as the FIRST card makes contact, not once everything
  // (including every card's post-contact shrink/fade) has finished.
  setTimeout(punchInventory, FLY_MS * CONTACT_FRACTION);

  // Collapse the playbar during the flight, not after. Margin-top goes to 0
  // too: renderStation() drops the playbar once rolled, so a leftover 16px
  // margin would snap.
  if (!playBar) return; // the roll popup (see collectRoll()) has no bar to contract
  if (playBar.classList.contains("lm-overlay")){
    // Nothing to contract -- the row only ever floated on top. Fade its
    // backing plate out as the dice leave it.
    const row = playBar.querySelector(".rolled");
    if (row) row.style.background = "transparent";
    return;
  }
  const startH = playBar.getBoundingClientRect().height;
  playBar.style.height = startH + "px";
  playBar.offsetHeight; // force reflow
  playBar.style.transition = "height .5s ease, margin-top .5s ease";
  playBar.style.height = "0px";
  playBar.style.marginTop = "0px";
}
