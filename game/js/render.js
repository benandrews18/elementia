/* =====================================================================
   render.js -- render(): redraws the current screen and the shared chrome, plus the
   turn clock and the station backdrop.
   ===================================================================== */
/* Turn clock, top-left: a 24-hour dial numbered 1-24 (24 at the top) with
   one hand pointing at this turn's number, which is also circled. Every
   MAT_CHECK_EVERY-th number (the Display Mat checkpoints) is set larger;
   on a checkpoint turn the pill glows, since from BREAKPOINT_GATE_VISIT on
   missing the first Quark breakpoint there ends the run (confirmLockIn()).
   In Overtime (past RUN_COMPLETE_VISIT) the hand keeps going round and
   the centre reads OT. */
function turnClockSVG(visits){
  const N = RUN_COMPLETE_VISIT;
  const at = (k, r) => { const t = k / N * 2 * Math.PI; return [50 + r * Math.sin(t), 50 - r * Math.cos(t)]; };
  const cur = visits > 0 ? ((visits - 1) % N) + 1 : 0;
  const nums = Array.from({length: N}, (_, i) => {
    // Checkpoints on an inner ring, the rest small on the rim, so the two
    // sizes never crowd each other.
    const k = i + 1, big = k % MAT_CHECK_EVERY === 0, [x, y] = at(k, big ? 30 : 41);
    const ring = k === cur ? `<circle cx="${x}" cy="${y}" r="${big ? 9.5 : 6.5}" fill="#e2b25a"/>` : "";
    return `${ring}<text x="${x}" y="${y}" font-size="${big ? 13 : 7.5}" font-weight="${big ? 900 : 700}"${big ? "" : ' fill="#6b5a3a"'}>${k}</text>`;
  }).join("");
  const [hx, hy] = at(cur, cur % MAT_CHECK_EVERY === 0 ? 20 : 33);
  return `<svg class="clock-svg" viewBox="0 0 100 100" aria-hidden="true">
    <circle cx="50" cy="50" r="48" fill="#f4ead2" stroke="#e2b25a" stroke-width="3.5"/>
    <g text-anchor="middle" dominant-baseline="central" fill="#2a2018" font-family="system-ui, sans-serif">${nums}</g>
    ${cur ? `<line x1="50" y1="50" x2="${hx}" y2="${hy}" stroke="#2a2018" stroke-width="4" stroke-linecap="round"/>` : ""}
    <circle cx="50" cy="50" r="${visits > N ? 9 : 4.5}" fill="#2a2018"/>
    ${visits > N ? '<text x="50" y="50.5" text-anchor="middle" dominant-baseline="central" fill="#e2b25a" font-size="8" font-weight="900" font-family="system-ui, sans-serif">OT</text>' : ""}
  </svg>`;
}
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
  document.getElementById("drawerBody").innerHTML = renderDrawer();
  renderPinsTray();
  renderTrackedPill();
  renderConvertGoalCard();
  if (bingoCraftEntry) renderBingoCraftCard();
  renderConvertEmptyEl();
  updateHub();
  updateBackdrop();
  applyRefFilter();
  hideHint();
  if (screen === "map") syncMapPaths();
  if (resetScroll) window.scrollTo({top:0, behavior:"instant"});
  // Measured live (not a constant) so the fixed map card sits right under the
  // topbar at any font size or zoom.
  document.documentElement.style.setProperty("--topbar-h", document.getElementById("topbar").offsetHeight + "px");
  // The hub's height is measured live too, and everything that must clear it
  // (job sheet, pins tray, drawer, overlay padding) reads --hub-h.
  document.documentElement.style.setProperty("--hub-h", document.getElementById("hub").offsetHeight + "px");
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
