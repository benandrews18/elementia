/* =====================================================================
   render.js -- render(): redraws the current screen and the shared chrome, plus the
   turn clock and the station backdrop.
   ===================================================================== */
/* Turn clock, top-left: a 24-turn dial (24 at the top). Only the
   checkpoint turns (every MAT_CHECK_EVERY-th, when the Display Mat is
   checked) are numbered; the turns between are tick marks. The hand points
   at this turn, which is circled in gold. On a checkpoint turn the pill
   glows. In Overtime (past RUN_COMPLETE_VISIT) the hand keeps going round
   and the centre reads OT. */
function turnClockSVG(visits){
  const N = RUN_COMPLETE_VISIT;
  const at = (k, r) => { const t = k / N * 2 * Math.PI; return [50 + r * Math.sin(t), 50 - r * Math.cos(t)]; };
  const cur = visits > 0 ? ((visits - 1) % N) + 1 : 0;
  const marks = Array.from({length: N}, (_, i) => {
    const k = i + 1;
    if (k % MAT_CHECK_EVERY === 0){
      const [x, y] = at(k, 36);
      const ring = k === cur ? `<circle cx="${x}" cy="${y}" r="10.5" fill="#e2b25a"/>` : "";
      return `${ring}<text x="${x}" y="${y}" font-size="15" font-weight="900">${k}</text>`;
    }
    const [x1, y1] = at(k, 39), [x2, y2] = at(k, 45);
    const dot = k === cur ? (() => { const [cx, cy] = at(k, 42); return `<circle cx="${cx}" cy="${cy}" r="5.5" fill="#e2b25a"/>`; })() : "";
    return `${dot}<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#6b5a3a" stroke-width="2.5" stroke-linecap="round"/>`;
  }).join("");
  const [hx, hy] = at(cur, cur % MAT_CHECK_EVERY === 0 ? 25 : 34);
  // Time already passed: a shaded slice from 24 o'clock round to the hand
  // (the whole face once the 24th round is reached).
  const [px, py] = at(cur, 46.5);
  const pie = !cur ? "" : cur === N
    ? '<circle cx="50" cy="50" r="46.5" fill="#c9b07a"/>'
    : `<path d="M50 50 L50 3.5 A46.5 46.5 0 ${cur > N / 2 ? 1 : 0} 1 ${px} ${py} Z" fill="#c9b07a"/>`;
  return `<svg class="clock-svg" viewBox="0 0 100 100" aria-hidden="true">
    <circle cx="50" cy="50" r="48" fill="#f4ead2" stroke="#e2b25a" stroke-width="3.5"/>
    ${pie}
    <g text-anchor="middle" dominant-baseline="central" fill="#2a2018" font-family="system-ui, sans-serif">${marks}</g>
    ${cur ? `<line x1="50" y1="50" x2="${hx}" y2="${hy}" stroke="#2a2018" stroke-width="4" stroke-linecap="round"/>` : ""}
    <circle cx="50" cy="50" r="${visits > N ? 9 : 4.5}" fill="#2a2018"/>
    ${visits > N ? '<text x="50" y="50.5" text-anchor="middle" dominant-baseline="central" fill="#e2b25a" font-size="8" font-weight="900" font-family="system-ui, sans-serif">OT</text>' : ""}
  </svg>`;
}
/* Tapping the clock: what a round is, the board check every 3 rounds, and
   the current round. */
function openClockInfo(){
  const v = state.visits, ot = v > RUN_COMPLETE_VISIT;
  document.getElementById("clockInfoBody").innerHTML = `
    <div class="ci-clock">${turnClockSVG(v)}</div>
    <h2 id="clockInfoTitle">Round ${v} / ${RUN_COMPLETE_VISIT}${ot ? " (Overtime)" : ""}</h2>
    <p>There are <b>${RUN_COMPLETE_VISIT} rounds</b> in a game<br>🥾 Moving to a station<br>starts a round!</p>
    <div class="ci-stations">${Object.keys(MAP_NODE_POS).map(n => `<span class="ci-st" style="--st:${DATA.suits[STATION_BY_NAME[n].suit].color}" title="${esc(n)}">${em(STATION_BY_NAME[n].emoji)}</span>`).join("")}</div>
    <p><b>Display Mat challenge</b> every ${MAT_CHECK_EVERY} rounds<br>⚛️ <b>Quark Score</b> rewards you<br>🎲 <b>bonus dice!</b></p>
    <div class="btnrow" style="justify-content:center"><button type="button" class="bigbtn" id="clockInfoOk">Got it</button></div>`;
  openOverlay("clockInfo");
}
document.getElementById("turnClock").addEventListener("click", openClockInfo);
document.getElementById("turnClock").addEventListener("keydown", ev => {
  if (ev.key === "Enter" || ev.key === " "){ ev.preventDefault(); openClockInfo(); }
});
document.getElementById("clockInfo").addEventListener("click", ev => {
  if (ev.target.closest("#clockInfoOk")) closeOverlay("clockInfo");
});
function renderTurnClock(){
  document.getElementById("scorePill").hidden = true;
  const pill = document.getElementById("turnClock");
  document.getElementById("turnClockFace").innerHTML = turnClockSVG(state.visits);
  const checkpoint = isSunsetVisit();
  pill.classList.toggle("checkpoint", checkpoint);
  const note = !checkpoint ? ""
    : state.visits >= BREAKPOINT_GATE_VISIT ? " -- checkpoint: miss the first Quark breakpoint when you next travel and the run ends"
    : " -- checkpoint: your Display Mat is checked when you next travel";
  pill.title = `Turn ${state.visits} of ${RUN_COMPLETE_VISIT}${note}`;
  pill.setAttribute("aria-label", pill.title);
}
measureLive("topbar", "--topbar-h");
measureLive("hub", "--hub-h");
function render(resetScroll){
  applyLowMotion();
  document.body.dataset.screen = screen;
  // No visits/score pills until a starting station is chosen (see #topbar's
  // CSS).
  document.body.toggleAttribute("data-picking", state.lastStation === null);
  const screenEl = document.getElementById("screen");
  screenEl.innerHTML = screen === "map" ? renderMap()
    : screen === "codex" ? renderCodex()
    : renderStation(current);
  document.getElementById("visitCount").textContent = state.visits;
  document.getElementById("visitMax").textContent = visitLimitLabel();
  document.getElementById("scoreCount").textContent = score();
  renderTurnClock();
  renderQuarkTopBar();
  document.getElementById("drawerScoreCount").textContent = score();
  // The inventory's contents only while it's open; openDrawer() builds them
  // on opening.
  if (drawer.classList.contains("open")) setDrawerBody(renderDrawer());
  renderPinsTray();
  renderTrackedPill();
  renderConvertGoalCard();
  if (bingoCraftEntry) renderBingoCraftCard();
  maybeShowEmptyElTip();
  maybeShowCollectionFound();
  renderConvertEmptyEl();
  updateHub();
  updateBackdrop();
  applyRefFilter();
  hideHint();
  if (screen === "map") syncMapPaths();
  if (resetScroll) window.scrollTo({top:0, behavior:"instant"});
  maybeShowWalkthroughTip();
}

/* Station and Marketplace backdrop only (not the map, inventory, reference
   or settings). The wash is baked into the gradient so it follows the
   theme. */
function updateBackdrop(){
  const el = document.getElementById("backdrop");
  const path = screen === "station" && current ? STATION_BG[current] : null;
  if (path){
    const wash = "var(--backdrop-wash)";
    el.style.backgroundImage = `linear-gradient(${wash},${wash}), url("${path}")`;
    el.classList.add("show");
  } else {
    el.classList.remove("show");
  }
}
