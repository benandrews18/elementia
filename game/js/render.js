/* =====================================================================
   render.js -- render(): redraws the current screen and the shared chrome, plus the
   day-cycle pill and the station backdrop.
   ===================================================================== */
/* Classic's day cycle, top-right in place of the score: each 3-visit day
   goes sunrise -> midday -> sunset; sunset checks can end the run (see
   MAT_CHECK_EVERY). One small SVG: horizon, the sun's arc, and the sun's
   position for this visit. */
const DAY_PHASES = [
  { key: "sunrise", label: "Sunrise", sky: ["#f6a35c", "#5b6fb0"], at: [9, 25] },
  { key: "midday",  label: "Midday",  sky: ["#8fd3ff", "#3d8fd8"], at: [30, 8] },
  { key: "sunset",  label: "Sunset",  sky: ["#e0603c", "#5a3a7a"], at: [51, 25] },
];
function dayCycleSVG(phase){
  const [x, y] = phase.at;
  return `<svg class="day-svg" viewBox="0 0 60 30" aria-hidden="true">
    <defs><linearGradient id="daySky-${phase.key}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${phase.sky[1]}"/><stop offset="1" stop-color="${phase.sky[0]}"/></linearGradient>
      <clipPath id="dayClip-${phase.key}"><rect x="0" y="0" width="60" height="28" rx="6"/></clipPath></defs>
    <rect x="0" y="0" width="60" height="28" rx="6" fill="url(#daySky-${phase.key})"/>
    <path d="M7 28 A23 23 0 0 1 53 28" fill="none" stroke="rgba(255,255,255,.55)" stroke-width="1.4" stroke-dasharray="2.5 2.5"/>
    <g clip-path="url(#dayClip-${phase.key})"><circle cx="${x}" cy="${y}" r="6" fill="#ffd94a" stroke="#fff3b0" stroke-width="1.5"/></g>
    <rect x="2" y="26.5" width="56" height="3" rx="1.2" fill="#2a3b2a"/>
  </svg>`;
}
function renderDayCycle(){
  const pill = document.getElementById("dayPill");
  document.getElementById("scorePill").hidden = true;
  pill.hidden = false;
  const v = Math.max(1, state.visits);
  const phase = DAY_PHASES[(v - 1) % MAT_CHECK_EVERY];
  const day = Math.ceil(v / MAT_CHECK_EVERY);
  const note = phase.key !== "sunset" ? ""
    : state.visits >= BREAKPOINT_GATE_VISIT ? " -- miss the first Quark breakpoint when you next travel and the run ends"
    : " -- your Display Mat is checked when you next travel";
  pill.title = `Day ${day}, ${phase.label}${note}`;
  pill.setAttribute("aria-label", pill.title);
  pill.innerHTML = dayCycleSVG(phase);
  pill.classList.toggle("sunset", phase.key === "sunset");
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
  renderDayCycle();
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
