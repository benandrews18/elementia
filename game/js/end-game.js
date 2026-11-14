/* =====================================================================
   end-game.js -- End of run: the end screen and its stats, the "crafted everything"
   ending, and confetti.
   ===================================================================== */
/* End screen sections (showEndGame()): an icon + title, the result under
   it -- no card boxes, so the window stays short. */
const endSecHTML = (icon, title, body, extra = "") =>
  `<div class="end-sec"><div class="end-sec-h"><span class="end-sec-ic">${icon}</span>${esc(title)}${extra}</div>${body}</div>`;
// Top row: the scores, small titles over the numbers.
function sessionStatsGridHTML(){
  const caps = CAPSTONES.filter(owns);
  const stat = (icon, title, value) =>
    `<div class="end-stat"><div class="end-stat-h">${icon} ${esc(title)}</div><div class="end-stat-n">${value}</div></div>`;
  return stat("⚛️", "Quarks", Math.round(state.bestMatScore || 0).toLocaleString()) +
    stat("💯", "Item Score", score()) +
    stat("🛠️", "Items", state.items.length) +
    stat("🏆", "Capstones", `${caps.length}<small>/8</small>`) +
    (state.grandExhibition ? stat("🏛️", "Exhibition", "✓") : "");
}
const endIconHTML = n => `<span class="end-ic" title="${esc(n)}">${em(ITEM_EMOJI[n])}</span>`;
function capstonesSectionHTML(){
  const caps = CAPSTONES.filter(owns);
  return endSecHTML("🏆", "Capstones Completed", caps.length
    ? `<div class="end-items">${caps.map(n => `<span class="end-cap">${em(ITEM_EMOJI[n])}<b>${esc(n)}</b></span>`).join("")}</div>`
    : `<p class="end-none">None this time -- plan a route through several stations next run!</p>`);
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
// Biggest Turn, then Station Most Visited.
function endGameFlavorHTML(){
  const turn = biggestTurn(), top = topVisitedStation();
  const stLine = (name, right) => {
    const st = STATION_BY_NAME[name];
    return `<div class="end-line">${st ? `<span class="end-ic">${em(st.emoji)}</span>` : ""}<b>${esc(name)}</b><span class="end-right">${right}</span></div>`;
  };
  return (turn ? endSecHTML("💥", "Biggest Turn", stLine(turn.station, `+${turn.points.toLocaleString()} pts`) +
      `<div class="end-items">${turn.items.map(endIconHTML).join("")}</div>`) : "") +
    (top ? endSecHTML("🧭", "Station Most Visited", stLine(top.name, `${top.count}×`)) : "");
}

/* The end of a run: reached MAX_VISITS (goMap()), missed a breakpoint at
   sunset from BREAKPOINT_GATE_VISIT on (confirmLockIn()), or crafted
   everything (checkCraftedEverything()). */
/* Classic's third ending: every item in CORE_ITEM_NAMES crafted. Flagged on
   the final craft; the End screen waits until that craft's reveal and BINGO
   sequence have finished (the same idle test). */
function checkCraftedEverything(){
  if (state.ended || state.craftedEverything) return;
  if (![...CORE_ITEM_NAMES].every(n => owns(n) || UNLOCKED_BY[n])) return;
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
  // Run Complete: the title says it all (keeps the screen to one phone height).
  document.getElementById("endSub").hidden = completing;
  document.getElementById("endSub").textContent = completing ? ""
    : state.craftedEverything
    ? `You crafted every item in Elementia in ${state.visits} visits -- here's your run:`
    : state.reachedHardLimit
    ? `You kept clearing the Quark breakpoint all the way to visit ${state.visits} -- here's your run:`
    : state.runComplete
    ? `Your board missed the first Quark breakpoint on an Overtime Lock-In at visit ${state.visits}. Your run still counts as complete. Here's what you built:`
    : `Game over -- missed the first Quark breakpoint on a Lock-In from visit ${BREAKPOINT_GATE_VISIT} on. Here's what you built:`;
  document.getElementById("endContinue").hidden = !completing;
  document.getElementById("endReview").hidden = completing;

  document.getElementById("endGrid").innerHTML = sessionStatsGridHTML();
  document.getElementById("endCapsWrap").innerHTML = capstonesSectionHTML();
  document.getElementById("endFlavorWrap").innerHTML = endGameFlavorHTML();
  // Trophies are earned when a run completes (awardTrophies()); the run's
  // Stars ride beside their title as a pill.
  const won = awardTrophies(), stars = completing ? state.starsEarned || 0 : 0;
  const starPill = stars ? `<span class="end-star-pill">+${stars} ⭐</span>` : "";
  document.getElementById("endTrophiesWrap").innerHTML = won.length
    ? endSecHTML("🎖️", won.length === 1 ? "New Trophy" : "New Trophies",
        `<div class="trophy-grid">${won.map(t => trophyTileHTML(t, {})).join("")}</div>`, starPill)
    : stars ? endSecHTML("⭐", "Stars Earned", "", starPill) : "";
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
// Main Menu leaves the run saved (Play continues it), like Settings' button.
document.getElementById("endMenu").addEventListener("click", () => {
  closeOverlay("endGame"); showWelcomeSlide();
});
