/* =====================================================================
   craft-animations.js -- Craft animations: the first-craft ingredient fly-in and burst, and the
   "can't craft" bounces.
   ===================================================================== */
/* First-ever craft of an item: inspection-style mini cards for each
   ingredient rise one at a time, fan into a stack centre-screen, burst like
   a firework, and the new item's card is left standing. Re-crafts stay
   instant. */
/* An item's home-station suit colour (miniIngredientCardHTML()). */
function itemSuitColor(name){
  const ing = ENTRIES.find(e => e.name === name);
  return ing ? DATA.suits[STATION_BY_NAME[ing.station].suit].color : "#4a4f5c";
}
function miniIngredientCardHTML(req){
  if (req.kind === "element"){
    // Same layout as the element card popup (showElCardPop()) at mini-card
    // scale.
    const suit = ELEMENT_SUIT[req.name];
    const color = ELEMENT_COLOR[req.name] || "#4a4f5c";
    const num = ATOMIC_NUMBER[req.name] || "";
    const icon = SUIT_ICON[suit] || "";
    const big = suit === "metal" ? " big" : "";
    return `<div class="fc-card fc-el" style="--suit:${color}">
      <span class="fc-el-bubble tl">${esc(num)}</span>
      <span class="fc-el-bubble br">${esc(num)}</span>
      <span class="fc-el-bubble tr${big}">${icon}</span>
      <span class="fc-el-bubble bl${big}">${icon}</span>
      <div class="fc-sym">${esc(req.name)}</div>
      <div class="fc-name">${esc(ELEMENT_NAMES[req.name] || req.name)}</div>
      <div class="fc-el-pill">${esc(ELEMENT_SUIT_LABEL[suit] || "")}</div>
    </div>`;
  }
  const ing = ENTRIES.find(e => e.name === req.name);
  const suit = itemSuitColor(req.name);
  return `<div class="fc-card fc-item" style="--suit:${suit}">
    <div class="fc-icon">${em(req.emoji || (ing && ing.emoji) || "")}</div>
    <div class="fc-name">${esc(req.name)}</div>
  </div>`;
}
/* Radial spark burst from one point (the firework). Throwaway WAAPI nodes,
   like fireConfetti(). */
function fireworkBurst(x, y){
  const colors = ["#2e9e5b", "#d9432b", "#b7791f", "#3b7fc4", "#a16a34", "#e2b25a", "#fff"];
  const N = 26;
  for (let i = 0; i < N; i++){
    const p = document.createElement("div");
    p.style.cssText = `position:fixed; left:${x}px; top:${y}px; width:7px; height:7px; ` +
      `border-radius:50%; z-index:600; pointer-events:none; background:${colors[(Math.random() * colors.length) | 0]};`;
    document.body.appendChild(p);
    const angle = (i / N) * Math.PI * 2 + Math.random() * 0.35;
    const dist = 80 + Math.random() * 110;
    const dx = Math.cos(angle) * dist, dy = Math.sin(angle) * dist;
    const anim = p.animate([
      { transform: "translate(-50%,-50%) scale(1)", opacity: 1 },
      { transform: `translate(${dx - 3.5}px, ${dy - 3.5}px) scale(.25)`, opacity: 0 },
    ], { duration: 550 + Math.random() * 220, easing: "cubic-bezier(.2,.6,.4,1)", fill: "forwards" });
    anim.onfinish = () => p.remove();
  }
}
function flyIngredientsAndReveal(entry){
  const seen = new Set();
  // Elements first, then items by points -- sets both the launch stagger and
  // the stack order.
  const reqs = sortIngredientTokens(entry.reqs.filter(r => {
    const k = r.kind + ":" + r.name;
    if (seen.has(k)) return false;
    seen.add(k); return true;
  }));

  const tx = innerWidth / 2, ty = innerHeight / 2;
  const RISE_MS = 560, RISE_STAGGER_MS = 220, FAN_STEP_PX = 7, FAN_STEP_DEG = 5;
  // fill:"forwards" never writes the end transform back to the element, so
  // each card's resting transform is tracked here for the fade-out to start
  // from.
  const finalTransforms = [];
  const cards = reqs.map((r, i) => {
    const el = document.createElement("div");
    el.innerHTML = miniIngredientCardHTML(r);
    const card = el.firstElementChild;
    card.style.position = "fixed";
    // Stack by recipe position, so each card lands on the one before it (two
    // fixed layers made cards appear out of order).
    card.style.zIndex = String(500 + i);
    card.style.pointerEvents = "none";
    // Start just below the bottom edge, spread across the width so a
    // multi-ingredient recipe doesn't launch every card from one spot.
    const startX = innerWidth / 2 + (i - (reqs.length - 1) / 2) * 70;
    const startY = innerHeight + 90;
    card.style.left = startX + "px";
    card.style.top = startY + "px";
    card.style.transform = "translate(-50%,-50%)";
    document.body.appendChild(card);
    return card;
  });

  const lastIdx = cards.length - 1;
  const lastArrivesAt = lastIdx * RISE_STAGGER_MS + RISE_MS;

  cards.forEach((card, i) => {
    // Fanned resting spot in the stack, not a dead-on overlap -- reads as
    // a pile of distinct cards, matching how a hand of real cards fans.
    const fanX = tx + (i - (reqs.length - 1) / 2) * FAN_STEP_PX;
    const fanY = ty + (i - (reqs.length - 1) / 2) * FAN_STEP_PX;
    const fanRot = (i - (reqs.length - 1) / 2) * FAN_STEP_DEG;
    const startX = innerWidth / 2 + (i - (reqs.length - 1) / 2) * 70;
    const startY = innerHeight + 90;
    const dx = fanX - startX, dy = fanY - startY;
    const finalTransform = `translate(-50%,-50%) translate(${dx}px, ${dy}px) rotate(${fanRot}deg) scale(1)`;
    finalTransforms.push(finalTransform);
    card.animate([
      { transform: "translate(-50%,-50%) translate(0,0) rotate(0deg) scale(.9)", opacity: 0, offset: 0 },
      { transform: "translate(-50%,-50%) translate(0,0) rotate(0deg) scale(1)", opacity: 1, offset: .12 },
      { transform: finalTransform, opacity: 1, offset: 1 },
    ], { duration: RISE_MS, delay: i * RISE_STAGGER_MS, easing: "cubic-bezier(.25,.7,.3,1.1)", fill: "forwards" });
  });

  // A short beat once assembled, then the burst. setTimeout, not onfinish:
  // only the last staggered animation matters, and a timer on the total
  // duration is simpler.
  setTimeout(() => {
    fireworkBurst(tx, ty);
    cards.forEach((card, i) => {
      card.style.transform = finalTransforms[i]; // lock in the resting pose WAAPI never wrote back
      card.animate([
        { transform: finalTransforms[i].replace(/scale\([^)]*\)/, "scale(1)"), opacity: 1 },
        { transform: finalTransforms[i].replace(/scale\([^)]*\)/, "scale(.2)"), opacity: 0 },
      ], { duration: 260, easing: "ease-in", fill: "forwards" }).onfinish = () => card.remove();
    });
    // Same belt-and-suspenders as the reveal itself below -- onfinish is
    // the real cleanup, this is just insurance against a dropped frame
    // leaving stray cards stuck in the DOM forever.
    setTimeout(() => cards.forEach(c => { if (c.parentNode) c.remove(); }), 400);
    // No render() here: performSingleCraft() renders on its own via
    // bounceCardClosed(), independently of this animation.
    setTimeout(() => {
      if (entry.tier === "CAPSTONE") celebrate(entry); else autoCardPop(entry);
    }, 260);
  }, lastArrivesAt + 220);
}
function punchInventory(){
  document.getElementById("hubInv").animate([
    { transform: "scale(1)" }, { transform: "scale(1.32)" }, { transform: "scale(1)" },
  ], { duration: 380, easing: "cubic-bezier(.3,1.4,.4,1)" });
}

/* Blocked Craft tap: a small notice pops up out of the button, holds about
   a second, then drops back. A fixed-position element so no ancestor's
   overflow clips it. */
/* Which notice a blocked Craft tap shows: any recipe item unowned ->
   "Missing Items!"; items owned but elements short -> "Missing Elements!",
   and if it's the suit cost that can't be paid, its balloon opens over the
   card's cost badges. */
function bounceCantCraft(anchor, entry, ev){
  const missingItems = !entry || !itemReqsMet(entry);
  bounceMissingItems(anchor, missingItems ? "Missing Items!" : "Missing Elements!");
  if (missingItems || suitCostPayable(entry)) return;
  const badge = anchor.closest("[data-item-card]")?.querySelector(".isuit-costs") || anchor.closest(".isuit-costs");
  if (badge){ if (ev) ev.stopPropagation(); openSuitSpendBalloon(entry, badge); }
}
function bounceMissingItems(cBtn, text = "Missing Items!"){
  const rect = cBtn.getBoundingClientRect();
  const note = document.createElement("div");
  note.className = "missing-items-note";
  note.textContent = text;
  note.style.left = (rect.left + rect.width / 2) + "px";
  note.style.top = rect.top + "px";
  document.body.appendChild(note);
  // Per-keyframe easing: a top-level easing's overshoot pushed progress past 1
  // during the hold and jumped to the end early. Per-segment easing keeps the
  // hold static.
  note.animate([
    { transform: "translate(-50%, 6px) scale(.7)", opacity: 0, offset: 0, easing: "cubic-bezier(.3,1.4,.4,1)" },
    { transform: "translate(-50%, -34px) scale(1)", opacity: 1, offset: .16 },
    { transform: "translate(-50%, -34px) scale(1)", opacity: 1, offset: .84, easing: "cubic-bezier(.3,1.4,.4,1)" },
    { transform: "translate(-50%, 6px) scale(.7)", opacity: 0, offset: 1 },
  ], { duration: 1400 }).onfinish = () => note.remove();
}
