/* =====================================================================
   craft-animations.js -- Craft animations: the first-craft ingredient fly-in and burst, and the
   "can't craft" bounces.
   ===================================================================== */
/* First craft of an item this run, in two beats:
   1. Every element spent (recipe and any suit-cost "element tax") rises as
      a gather-style square, stacks centre-screen and pops in a firework.
   2. The item components (kept, not spent) rise as mini cards, stack, then
      fly back into the Inventory.
   Then the new item's card shows (autoCardPop()/celebrate()). */
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
  const tx = innerWidth / 2, ty = innerHeight / 2, n = htmls.length;
  const finals = [];
  const cards = htmls.map((html, i) => {
    const wrap = document.createElement("div");
    wrap.innerHTML = html;
    const card = wrap.firstElementChild;
    const startX = tx + (i - (n - 1) / 2) * 70, startY = innerHeight + 90;
    Object.assign(card.style, { position: "fixed", zIndex: String(500 + i), pointerEvents: "none",
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
  // 1. Elements actually spent: the recipe's (catalysts aren't spent) plus
  //    the element tax, one square each.
  const spent = [];
  entry.reqs.forEach(r => { if (r.kind === "element" && !r.catalyst) spent.push(r.name); });
  Object.entries(taxPicks).forEach(([sym, k]) => { for (let i = 0; i < k; i++) spent.push(sym); });
  const items = needsOf(entry.reqs).items;
  const reveal = () => { if (entry.tier === "CAPSTONE") celebrate(entry); else autoCardPop(entry); };

  const itemsBeat = () => {
    if (!items.length){ reveal(); return; }
    // 2. Components rise and stack, then fly home to the Inventory.
    const st = riseIntoStack(items.map(it => miniItemCardHTML(it.name, it.emoji)), 480, 160);
    setTimeout(() => {
      const r = document.getElementById("hubInv").getBoundingClientRect();
      st.cards.forEach((card, i) => {
        card.style.transform = st.finals[i]; // WAAPI fill never writes the end pose back
        const cr = card.getBoundingClientRect();
        const dx = r.left + r.width / 2 - (cr.left + cr.width / 2), dy = r.top + r.height / 2 - (cr.top + cr.height / 2);
        card.animate([
          { transform: st.finals[i], opacity: 1 },
          { transform: `${st.finals[i]} translate(${dx}px, ${dy}px) scale(.15)`, opacity: .4 },
        ], { duration: 420, delay: i * 70, easing: "cubic-bezier(.5,0,.75,.4)", fill: "forwards" }).onfinish = () => card.remove();
      });
      setTimeout(punchInventory, 420 + (st.cards.length - 1) * 70);
      setTimeout(() => st.cards.forEach(c => c.remove()), 1200 + st.cards.length * 70); // insurance
      setTimeout(reveal, 260);
    }, st.landsAt + 180);
  };

  if (!spent.length){ itemsBeat(); return; }
  const st = riseIntoStack(spent.map(miniElementSquareHTML), 420, 80);
  setTimeout(() => {
    fireworkBurst(innerWidth / 2, innerHeight / 2);
    st.cards.forEach((card, i) => {
      card.style.transform = st.finals[i];
      card.animate([
        { transform: `${st.finals[i]} scale(1)`, opacity: 1 },
        { transform: `${st.finals[i]} scale(1.25)`, opacity: 1, offset: .3 },
        { transform: `${st.finals[i]} scale(.2)`, opacity: 0 },
      ], { duration: 280, easing: "ease-in", fill: "forwards" }).onfinish = () => card.remove();
    });
    setTimeout(() => st.cards.forEach(c => { if (c.parentNode) c.remove(); }), 500); // insurance
    // No render() here: performSingleCraft() renders on its own.
    setTimeout(itemsBeat, 200);
  }, st.landsAt + 160);
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
