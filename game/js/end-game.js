/* =====================================================================
   end-game.js -- End of run: the end screen and its stats, the "crafted everything"
   ending, and confetti.
   ===================================================================== */
/* Stats grid for showEndGame(). extraCells (raw .sumstat HTML) lets the
   caller append its own tiles. */
function sessionStatsGridHTML(extraCells){
  const caps = CAPSTONES.filter(owns);
  const elementsHeld = Object.values(state.elements).reduce((a,b) => a+b, 0);
  const byTier = t => state.items.filter(n => ITEM_TIER[n] === t).length;
  return `
    <div class="sumstat"><div class="n" style="color:var(--gold)">${score()}</div><div class="l">SCORE</div></div>
    <div class="sumstat"><div class="n">${state.items.length}</div><div class="l">ITEMS BUILT</div></div>
    <div class="sumstat"><div class="n" style="color:var(--gold)">${caps.length}<span style="font-size:16px;color:var(--mute)">/8</span></div><div class="l">CAPSTONES</div></div>
    <div class="sumstat"><div class="n">${byTier("CREATION")}</div><div class="l">CREATIONS</div></div>
    <div class="sumstat"><div class="n">${elementsHeld}</div><div class="l">ELEMENTS LEFT</div></div>
    ${extraCells || ""}`;
}
function capstonesSectionHTML(){
  const caps = CAPSTONES.filter(owns);
  return caps.length
    ? `<div class="sec-label" style="margin-top:16px">CAPSTONES COMPLETED</div>
       <div class="sumcaps">${caps.map(n =>
         `<span class="sumcap">${em(ITEM_EMOJI[n])} ${esc(n)}</span>`).join("")}</div>`
    : `<p class="empty" style="margin-top:14px">No capstones this time — they need
       materials from several stations, so plan your route next run!</p>`;
}
// Show the last station's backdrop behind the end screen (it can open from
// the map or Settings, where updateBackdrop() wouldn't). closeOverlay()
// hands control back.
function showSessionEndBackdrop(){
  const bg = STATION_BG[state.lastStation];
  if (bg){
    const bgEl = document.getElementById("backdrop");
    bgEl.style.backgroundImage = `linear-gradient(var(--backdrop-wash),var(--backdrop-wash)), url("${bg}")`;
    bgEl.classList.add("show");
  }
}

/* Most-visited station and the highest-scoring visit, both derived from
   state.visitLog. */
function topVisitedStation(){
  const counts = {};
  (state.visitLog || []).forEach(t => { counts[t.station] = (counts[t.station] || 0) + 1; });
  let top = null;
  Object.keys(counts).forEach(s => { if (!top || counts[s] > counts[top]) top = s; });
  return top ? { name: top, count: counts[top] } : null;
}
function biggestTurn(){
  let best = null;
  (state.visitLog || []).forEach(t => {
    const points = (t.items || []).reduce((n, i) => n + (ITEM_POINTS[i] || 0), 0);
    if (points > 0 && (!best || points > best.points)) best = { station: t.station, items: t.items, points };
  });
  return best;
}
function endGameFlavorHTML(){
  const turn = biggestTurn();
  if (!turn) return "";
  return `<div class="sec-label" style="margin-top:16px">BIGGEST TURN -- ${esc(turn.station)} (+${turn.points.toLocaleString()} pts)</div>
    <div class="sumcaps">${turn.items.map(n =>
      `<span class="sumcap" title="${esc(n)}">${em(ITEM_EMOJI[n])}</span>`).join("")}</div>`;
}

/* The end of a run: reached MAX_VISITS (goMap()), missed a breakpoint at
   sunset from BREAKPOINT_GATE_VISIT on (confirmLockIn()), or crafted
   everything (checkCraftedEverything()). */
/* Classic's third ending: every item in CORE_ITEM_NAMES crafted. Flagged on
   the final craft; the End screen waits until that craft's reveal and BINGO
   sequence have finished (the same idle test). */
function checkCraftedEverything(){
  if (state.ended || state.craftedEverything) return;
  if (![...CORE_ITEM_NAMES].every(owns)) return;
  state.craftedEverything = true;
  save();
  scheduleCraftedEverythingEnd();
}
function scheduleCraftedEverythingEnd(){
  setTimeout(() => {
    if (state.ended) return;
    const busy = bingoSequenceBlocked() || bingoClearInProgress || bingoPendingSquares.length
      || (state.pendingBingoClears || []).length;
    if (busy){ scheduleCraftedEverythingEnd(); return; }
    // The End screen sits below the Marketplace tray -- put the tray away first.
    if (jobSheet.classList.contains("open")){ closeJobBoard(); scheduleCraftedEverythingEnd(); return; }
    state.ended = true;
    save();
    fireConfetti();
    showEndGame();
  }, 500);
}
/* Also the run-complete moment at RUN_COMPLETE_VISIT (state.runComplete,
   not yet ended): same stats, with Keep playing (Overtime) / New game.
   Closing it any other way also keeps playing. */
function showEndGame(){
  const completing = state.runComplete && !state.ended;
  document.getElementById("endTitle").textContent = completing ? "🎉 Run Complete!"
    : state.craftedEverything ? "🏆 Every Item Crafted!"
    : state.reachedHardLimit ? "🎉 You Reached the End!"
    : state.runComplete ? "⏱️ Overtime Over" : "🏁 Game Over";
  document.getElementById("endSub").textContent = completing
    ? `You made it to turn ${RUN_COMPLETE_VISIT}! Keep playing in Overtime to craft every item, but every Lock-In must now clear the first Quark breakpoint. Or start a new game.`
    : state.craftedEverything
    ? `You crafted every item in Elementia in ${state.visits} visits -- here's your run:`
    : state.reachedHardLimit
    ? `You kept clearing the Quark breakpoint all the way to visit ${state.visits} -- here's your run:`
    : state.runComplete
    ? `Your board missed the first Quark breakpoint on an Overtime Lock-In at visit ${state.visits}. Your run still counts as complete. Here's what you built:`
    : `Game over -- missed the first Quark breakpoint on a Lock-In from visit ${BREAKPOINT_GATE_VISIT} on. Here's what you built:`;
  document.getElementById("endContinue").hidden = !completing;
  document.getElementById("endReview").hidden = completing;
  document.getElementById("endNew").textContent = completing ? "New game" : "Start a new session";

  const bingoTotal = bingoLines().length;
  const bingoDone = (state.bingoLinesCompleted || []).length;
  const top = topVisitedStation();
  const extraCells = `
    <div class="sumstat"><div class="n" style="color:var(--gold)">${bingoDone}<span style="font-size:16px;color:var(--mute)">/${bingoTotal}</span></div><div class="l">${marketRowsMode() ? "MARKET ROWS" : "BINGO LINES"}</div></div>
    <div class="sumstat"><div class="n" style="color:var(--gold)">⚛️ ${Math.round(state.bestMatScore || 0).toLocaleString()}</div><div class="l">TOP QUARK SCORE</div></div>${
      top ? `<div class="sumstat"><div class="n" style="font-size:18px">${esc(top.name)}</div><div class="l">STATION MOST VISITED (${top.count}×)</div></div>` : ""}`;

  document.getElementById("endGrid").innerHTML = sessionStatsGridHTML(extraCells);
  document.getElementById("endCapsWrap").innerHTML = capstonesSectionHTML();
  // Trophies are earned when a run completes (awardTrophies()).
  document.getElementById("endTrophiesWrap").innerHTML = newTrophiesHTML(awardTrophies());
  document.getElementById("endFlavorWrap").innerHTML = endGameFlavorHTML();
  showSessionEndBackdrop();
  openOverlay("endGame");
}

/* --------------------------------------------------- celebration --- */
function fireConfetti(){
  if (lowMotion()) return;
  const wrap = document.createElement("div");
  wrap.className = "confetti";
  const colors = ["#2e9e5b","#d9432b","#b7791f","#3b7fc4","#a16a34","#e2b25a"];
  for (let i = 0; i < 70; i++){
    const p = document.createElement("i");
    p.className = "cpiece";
    p.style.left = Math.random() * 100 + "vw";
    p.style.top = (-12 - Math.random() * 20) + "vh";
    p.style.background = colors[(Math.random() * colors.length) | 0];
    p.style.setProperty("--spin", (Math.random() * 1080 - 540) + "deg");
    p.style.animation = `fall ${1.9 + Math.random() * 1.6}s cubic-bezier(.25,.6,.5,1) ${Math.random() * .5}s forwards`;
    if (Math.random() < .35) p.style.borderRadius = "50%";
    wrap.appendChild(p);
  }
  document.body.appendChild(wrap);
  setTimeout(() => wrap.remove(), 4200);
}

document.getElementById("endNew").addEventListener("click", () => {
  closeOverlay("endGame"); restartRun();
});
document.getElementById("endContinue").addEventListener("click", () => closeOverlay("endGame"));
document.getElementById("endReview").addEventListener("click", () => {
  closeOverlay("endGame"); openDrawer();
});
