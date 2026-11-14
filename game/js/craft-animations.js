/* =====================================================================
   craft-animations.js -- Craft animations: the first-craft ingredient fly-in and burst, and the
   "can't craft" bounces.
   ===================================================================== */
/* First craft of an item this run, all at once: the new item's card shows
   right away (autoCardPop()/celebrate()); every element spent (recipe and
   any suit-cost "element tax") rises onto it as a gather-style square,
   stacks and pops in a firework; the item components (kept, not spent) peek
   up from behind the hub and slide back down. Then the card flies to the
   Inventory. */
function miniItemCardHTML(name, emoji){
  const ing = ENTRIES.find(e => e.name === name);
  return `<div class="fc-card fc-item">
    <div class="fc-icon">${em(emoji || (ing && ing.emoji) || "")}</div>
    <div class="fc-name">${esc(name)}</div>
  </div>`;
}
/* An element square like the gather window's (.gchip). */
function miniElementSquareHTML(sym){
  return `<div class="fc-elsq" style="--suit:${ELEMENT_COLOR[sym] || "#8a94a6"}"><span class="gnum">${ATOMIC_NUMBER[sym] || ""}</span><span class="fc-elsq-sym">${esc(sym)}</span>${elSuitBadgeHTML(sym)}</div>`;
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
/* Launches html cards from below the screen into a fanned stack at the
   centre. Returns the cards, their resting transforms and when the last
   one lands (ms). */
function riseIntoStack(htmls, riseMs, staggerMs){
  const tx = innerWidth / 2, ty = innerHeight * .45, n = htmls.length; // the new card's centre (.craft-peek)
  const finals = [];
  const cards = htmls.map((html, i) => {
    const wrap = document.createElement("div");
    wrap.innerHTML = html;
    const card = wrap.firstElementChild;
    const startX = tx + (i - (n - 1) / 2) * 70, startY = innerHeight + 90;
    Object.assign(card.style, { position: "fixed", zIndex: String(610 + i), pointerEvents: "none", // over .craft-peek (600)
      left: startX + "px", top: startY + "px", transform: "translate(-50%,-50%)" });
    document.body.appendChild(card);
    // Fanned, not a dead-on overlap, so it reads as a pile of cards.
    const off = i - (n - 1) / 2;
    const final = `translate(-50%,-50%) translate(${tx + off * 7 - startX}px, ${ty + off * 7 - startY}px) rotate(${off * 5}deg)`;
    finals.push(final);
    card.animate([
      { transform: "translate(-50%,-50%) scale(.9)", opacity: 0, offset: 0 },
      { transform: "translate(-50%,-50%) scale(1)", opacity: 1, offset: .12 },
      { transform: final, opacity: 1, offset: 1 },
    ], { duration: riseMs, delay: i * staggerMs, easing: "cubic-bezier(.25,.7,.3,1.1)", fill: "forwards" });
    return card;
  });
  return { cards, finals, landsAt: (n - 1) * staggerMs + riseMs };
}
function flyIngredientsAndReveal(entry, taxPicks = {}){
  // Elements actually spent: the recipe's (catalysts aren't spent) plus the
  // element tax, one square each.
  const spent = [];
  entry.reqs.forEach(r => { if (r.kind === "element" && !r.catalyst) spent.push(r.name); });
  Object.entries(taxPicks).forEach(([sym, k]) => { for (let i = 0; i < k; i++) spent.push(sym); });
  const items = needsOf(entry.reqs).items;
  const RISE = 420, STAGGER = 80, POP = 280;
  const popAt = spent.length ? (spent.length - 1) * STAGGER + RISE + 160 : 0;

  // All at once: the new card shows right away and waits for the elements
  // to pop on top of it before flying to the Inventory (a capstone gets its
  // full card instead); the kept components peek up from the hub meanwhile.
  if (entry.tier === "CAPSTONE") celebrate(entry);
  else autoCardPop(entry, Math.max(300, popAt + POP));

  if (items.length){
    // Components (kept, not spent): 75% of each card peeks up from behind
    // the hub, then slides back down into it.
    const hubTop = document.getElementById("hub").getBoundingClientRect().top;
    const n = items.length, step = Math.min(96, (innerWidth - 150) / Math.max(1, n - 1));
    const cards = items.map((it, i) => {
      const wrap = document.createElement("div");
      wrap.innerHTML = miniItemCardHTML(it.name, it.emoji);
      const card = wrap.firstElementChild;
      Object.assign(card.style, { position: "fixed", zIndex: "71", pointerEvents: "none", // just under #hub (72)
        left: (innerWidth / 2 + (i - (n - 1) / 2) * step) + "px", top: hubTop + "px", transform: "translate(-50%, 0)" });
      document.body.appendChild(card);
      return card;
    });
    const h = cards[0].offsetHeight, up = -0.75 * h;
    const UP = 380, HOLD = Math.max(650, popAt), PEEK_STAGGER = 70;
    cards.forEach((card, i) => {
      const rot = (i - (n - 1) / 2) * 4;
      card.animate([
        { transform: "translate(-50%, 0) rotate(0deg)", offset: 0 },
        { transform: `translate(-50%, ${up}px) rotate(${rot}deg)`, offset: UP / (UP * 2 + HOLD), easing: "cubic-bezier(.3,1.3,.5,1)" },
        { transform: `translate(-50%, ${up}px) rotate(${rot}deg)`, offset: (UP + HOLD) / (UP * 2 + HOLD), easing: "cubic-bezier(.5,0,.75,.4)" },
        { transform: "translate(-50%, 0) rotate(0deg)", offset: 1 },
      ], { duration: UP * 2 + HOLD, delay: i * PEEK_STAGGER, fill: "forwards" }).onfinish = () => card.remove();
    });
    const total = UP * 2 + HOLD + (n - 1) * PEEK_STAGGER;
    setTimeout(punchInventory, total);
    setTimeout(() => cards.forEach(c => c.remove()), total + 600); // insurance
  }

  if (!spent.length) return;
  // Elements rise onto the new card, stack, then pop with the firework.
  const st = riseIntoStack(spent.map(miniElementSquareHTML), RISE, STAGGER);
  setTimeout(() => {
    fireworkBurst(innerWidth / 2, innerHeight * .45);
    st.cards.forEach((card, i) => {
      card.style.transform = st.finals[i];
      card.animate([
        { transform: `${st.finals[i]} scale(1)`, opacity: 1 },
        { transform: `${st.finals[i]} scale(1.25)`, opacity: 1, offset: .3 },
        { transform: `${st.finals[i]} scale(.2)`, opacity: 0 },
      ], { duration: POP, easing: "ease-in", fill: "forwards" }).onfinish = () => card.remove();
    });
    setTimeout(() => st.cards.forEach(c => { if (c.parentNode) c.remove(); }), POP + 220); // insurance
  }, popAt);
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
  // Card view has no cost badges: the balloon points at the button.
  const badge = anchor.closest("[data-item-card]")?.querySelector(".isuit-costs") || anchor.closest(".isuit-costs") || anchor;
  if (badge){ if (ev) ev.stopPropagation(); openSuitSpendBalloon(entry, badge); }
}
function bounceMissingItems(cBtn, text = "Missing Items!"){ floatNote(cBtn, esc(text)); }
// A short note that pops up out of anchor, holds, and drops back. html is
// trusted markup (icons); cls adds a colour variant.
function floatNote(anchor, html, cls = ""){
  const rect = anchor.getBoundingClientRect();
  const note = document.createElement("div");
  note.className = "missing-items-note " + cls;
  note.innerHTML = html;
  note.style.left = (rect.left + rect.width / 2) + "px";
  note.style.top = rect.top + "px";
  document.body.appendChild(note);
  // Keep it on screen (centred on the anchor, but not past either edge).
  const half = note.offsetWidth / 2;
  note.style.left = Math.min(Math.max(rect.left + rect.width / 2, half + 8), innerWidth - half - 8) + "px";
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
