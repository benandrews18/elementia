/* =====================================================================
   render.js -- render(): redraws the current screen and the shared chrome, plus the
   turn clock and the station backdrop.
   ===================================================================== */
/* Turn clock, top-left: a dial whose hand and filled wedge show this
   run's turns out of RUN_COMPLETE_VISIT. One tick per Display Mat
   checkpoint (every MAT_CHECK_EVERY turns); on a checkpoint turn the pill
   glows, since from BREAKPOINT_GATE_VISIT on missing the first Quark
   breakpoint there ends the run (confirmLockIn()). */
function turnClockSVG(visits){
  const f = (visits % RUN_COMPLETE_VISIT) / RUN_COMPLETE_VISIT || (visits ? 1 : 0);
  const a = f * 2 * Math.PI, x = 15 + 11 * Math.sin(a), y = 15 - 11 * Math.cos(a);
  const n = RUN_COMPLETE_VISIT / MAT_CHECK_EVERY;
  const ticks = Array.from({length: n}, (_, i) => {
    const t = (i + 1) / n * 2 * Math.PI;
    return `<line x1="${15 + 11 * Math.sin(t)}" y1="${15 - 11 * Math.cos(t)}" x2="${15 + 13.5 * Math.sin(t)}" y2="${15 - 13.5 * Math.cos(t)}"/>`;
  }).join("");
  const wedge = f >= 1 ? `<circle cx="15" cy="15" r="11" fill="rgba(226,178,90,.55)"/>`
    : f > 0 ? `<path d="M15 15 L15 4 A11 11 0 ${f > .5 ? 1 : 0} 1 ${x} ${y} Z" fill="rgba(226,178,90,.55)"/>` : "";
  return `<svg class="clock-svg" viewBox="0 0 30 30" aria-hidden="true">
    <circle cx="15" cy="15" r="14" fill="#f4ead2" stroke="#e2b25a" stroke-width="2"/>
    ${wedge}<g stroke="#5a4a2a" stroke-width="1.6" stroke-linecap="round">${ticks}</g>
    <line x1="15" y1="15" x2="${x}" y2="${y}" stroke="#2a2018" stroke-width="2.2" stroke-linecap="round"/>
    <circle cx="15" cy="15" r="2" fill="#2a2018"/>
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
