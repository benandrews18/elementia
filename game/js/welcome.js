/* =====================================================================
   welcome.js -- Welcome screen and run start: the Classic card, resume/new run
   (startNewRun()), the intro, the how-to-play slides, and restartRun().
   ===================================================================== */
// The save's visits/points, or "New" (scoreOf() reads any saved blob).
function refreshModePicker(){
  const saved = readSave();
  document.querySelector('[data-mode-stats="classic"]').textContent =
    saved ? `${saved.visits || 0} visits · ${scoreOf(saved)} points` : "New";
}
function openModePicker(){
  refreshModePicker();
  openOverlay("modeOverlay");
}
// Continue: resume the save if there is one, otherwise start fresh (only a
// fresh start plays the intro).
function continueRun(){
  if (hasSave()) resumeRun(); else startNewRun();
}
/* Load a save straight back into play -- no reset, no intro. */
function resumeRun(){
  state = Object.assign(freshState(), readSave(), {mode: "classic"});
  closeOverlay("modeOverlay");
  screen = "map"; current = null; selectedMapStation = null;
  render(true);
}
/* Start a run from scratch (freshState() + the intro), for the first
   Continue and for New Game/Reset. Pins, tracked item and dismissed tips live
   in prefs/module state rather than `state`, so they're cleared here
   explicitly. */
function startNewRun(){
  state = freshState();
  state.mode = "classic";
  selectedJobItem = null;
  mouseTipsShown = new Set();
  prefs.pinnedItems = [];
  savePrefs();
  save();
  closeOverlay("modeOverlay");
  render();
  playClassicIntro();
}
/* "New Game": confirms only if there's a real save with progress. */
function newRun(){
  if (!hasSave()){ startNewRun(); return; }
  askConfirm("Start a new run? Your current save will be erased.", startNewRun);
}

// True while the intro logo shows (playClassicIntro()): hides the map's
// capstone-preview badges. data-intro-sequence covers the whole opening.
let classicIntroHideCapstones = false;
// How long the Classic intro logo shows before the rules slides.
const CLASSIC_INTRO_LOGO_MS = 1000;
/* Classic's opening: the bare map renders (capstone badges hidden), the
   Elementia logo bounces in (#introLogo) for CLASSIC_INTRO_LOGO_MS, then the
   rules slides open, followed by the capstone choice (openCapstoneChoice()).
   body[data-intro-sequence] keeps the hub and map nodes untappable
   throughout; it's cleared when the opening's To-Do List tray closes
   (closeJobBoard()). */
function playClassicIntro(){
  screen = "map"; current = null; selectedMapStation = null;
  document.body.setAttribute("data-intro-sequence", "");
  classicIntroHideCapstones = true;
  render(true);
  document.getElementById("introLogo").classList.add("show");
  setTimeout(() => {
    document.getElementById("introLogo").classList.remove("show");
    classicIntroHideCapstones = false;
    openClassicTutorial(openCapstoneChoice);
  }, CLASSIC_INTRO_LOGO_MS);
}
/* Classic's quick how-to-play (see #classicTut): one idea per line, icons
   first -- (1) the goal, the 8 Capstones; (2) station elements are spent
   like currency on items you keep; (3) Display Mat items earn Quarks, Quarks
   earn dice, and combos multiply them. Examples come from the real game
   data. */
let ctIdx = 0, ctOnDone = null;
function ctElChip(sym){
  return `<span class="mn-elsym" style="--suit:${ELEMENT_COLOR[sym] || "#8a94a6"}">${esc(sym)}</span>`;
}
function classicTutSlides(){
  const tile = (inner, badge) => `<span class="ct-tile">${inner}${badge ? `<span class="ct-badge">${badge}</span>` : ""}</span>`;
  // 1 -- the goal
  const caps = DATA.stations.map(st => `<div class="ct-cap" title="${esc(st.capstone[1])} -- ${esc(st.name)}">
      <span class="ct-cap-st">${em(st.emoji)}</span><span class="ct-cap-em">${em(st.capstone[0])}</span></div>`).join("");
  const s1 = `<div class="ct-kicker">The goal</div>
    <div class="ct-cap-grid">${caps}</div>
    <p class="ct-line">Discover and craft the 8 <b>Capstones</b> -- one at each station</p>`;

  // 2 -- gather, spend, keep
  const st = STATION_BY_NAME["The Ocean"] || DATA.stations[0];
  const ex = ENTRIES.find(e => e.station === st.name && e.reqs.length >= 2 && e.reqs.every(r => r.kind === "element"))
    || ENTRIES.find(e => e.reqs.length >= 2 && e.reqs.every(r => r.kind === "element"));
  const s2 = `<div class="ct-kicker">Gather &amp; craft</div>
    <div class="ct-row"><span class="ct-big">${em(st.emoji)}</span><span class="ct-arrow">🎲</span>
      <span class="ct-els">${sortedDice(st).map(ctElChip).join("")}</span></div>
    <p class="ct-sub">Every station has its own pool of elements</p>
    <div class="ct-row">
      <div class="ct-col"><span class="ct-els">${ex.reqs.map(r => ctElChip(r.name)).join("")}</span><span class="ct-tag">🪙 spent</span></div>
      <span class="ct-arrow">➜</span>
      <div class="ct-col"><span class="ct-item">${em(ex.emoji)}</span><span class="ct-tag">♾️ kept</span></div>
    </div>
    <p class="ct-line">Spend elements like currency -- <b>items are yours forever</b></p>`;

  // 3 -- Display Mat, Quarks, dice, and the combos
  const matIcons = [st.capstone[1], ...CORE_ITEM_NAMES].filter((n, i, a) => ITEM_EMOJI[n] && a.indexOf(n) === i);
  const sameSt = [...CORE_ITEM_NAMES].filter(n => CORE_ITEM_STATION[n] === st.name && ITEM_TIER[n] !== "CAPSTONE").slice(0, 3);
  const suit = Object.keys(SUIT_ICON)[0];
  // A component shared by several cards, and a card whose own recipe items
  // could all sit beside it (its "complete" 2x).
  const shared = {};
  MAT_CARDS.forEach(c => matDirectItems(c).forEach(n => { (shared[n] = shared[n] || []).push(c.name); }));
  const compName = Object.keys(shared).filter(n => ITEM_EMOJI[n] && shared[n].length >= 3).sort((a, b) => shared[b].length - shared[a].length)[0];
  const completeCard = MAT_CARDS.find(c => matDirectItems(c).size === 2 && c.tier !== "CAPSTONE");
  const col = MAT_COLLECTIONS_RAW.find(c => c.items.length === 3 && c.items.every(n => ITEM_EMOJI[n]));
  const combos = [
    [tile(em(st.emoji)) + tile(em(st.emoji)) + tile(em(st.emoji)), "3+ from the <b>same station</b>"],
    [[0, 1, 2].map(() => `<span class="ct-tile suit" style="--suit:${SUIT_COLOR[suit]}">${SUIT_ICON[suit]}</span>`).join(""), "3+ of the <b>same suit</b>"],
    compName ? [shared[compName].slice(0, 3).map(n => tile(em(ITEM_EMOJI[n]), em(ITEM_EMOJI[compName]))).join(""), "3+ that <b>share an item</b>"] : null,
    completeCard ? [tile(em(completeCard.emoji)) + '<span class="ct-plus">+</span>' + [...matDirectItems(completeCard)].map(n => tile(em(ITEM_EMOJI[n]))).join(""), "An item with its recipe = <b>2× points</b>"] : null,
    col ? ['<span class="ct-plus">★</span>' + col.items.map(n => tile(em(ITEM_EMOJI[n]))).join(""), "Secret <b>collections</b> for bonus Quarks"] : null,
  ].filter(Boolean).map(([icons, label]) => `<span class="ct-combo-icons">${icons}</span><span class="ct-combo-label">${label}</span>`).join("");
  const s3 = `<div class="ct-kicker">Display Mat</div>
    <div class="ct-row">
      <span class="ct-mat">${matIcons.slice(0, 4).map(n => `<span>${em(ITEM_EMOJI[n])}</span>`).join("")}</span>
      <span class="ct-arrow">➜</span><span class="ct-quark">⚛️</span>
      <span class="ct-arrow">➜</span><span class="ct-dice">🎲🎲🎲</span>
    </div>
    <p class="ct-line">Arrange items to earn <b>Quark Points</b> -- Quarks gather more elements</p>
    <div class="ct-combos">${combos}</div>
    <div class="ct-row"><span style="width:52px; height:52px; flex:none">${turnClockSVG(BREAKPOINT_GATE_VISIT)}</span><span class="ct-sub" style="margin:0">Checked every 3rd turn -- its dice last 3 turns. From turn ${BREAKPOINT_GATE_VISIT}, a miss ends the run</span></div>`;
  return [s1, s2, s3];
}
function renderClassicTut(){
  const slides = classicTutSlides();
  document.getElementById("ctSlide").innerHTML = slides[ctIdx];
  document.getElementById("ctDots").innerHTML = slides.map((_, i) => `<span class="${i === ctIdx ? "on" : ""}"></span>`).join("");
  document.getElementById("ctNext").textContent = ctIdx === slides.length - 1 ? "Let's play" : "Next";
}
function openClassicTutorial(onDone){
  ctIdx = 0;
  ctOnDone = onDone;
  const el = document.getElementById("classicTut");
  el.classList.add("open");
  el.setAttribute("aria-hidden", "false");
  renderClassicTut();
  document.getElementById("ctNext").focus({preventScroll: true});
}
function classicTutNext(){
  if (ctIdx < classicTutSlides().length - 1){ ctIdx++; renderClassicTut(); return; }
  const el = document.getElementById("classicTut");
  el.classList.remove("open");
  el.setAttribute("aria-hidden", "true");
  const done = ctOnDone;
  ctOnDone = null;
  if (done) done();
}
document.getElementById("ctNext").addEventListener("click", classicTutNext);
document.getElementById("ctSlide").addEventListener("click", classicTutNext);
document.getElementById("modeOverlay").addEventListener("click", ev => {
  const newBtn = ev.target.closest("[data-mode-newgame]");
  if (newBtn){ newRun(); return; }
  const selectBtn = ev.target.closest("[data-mode-select]");
  if (selectBtn) continueRun();
});

/* "Reset Session" and "Play Again": record the finished run, then start
   over (startNewRun()). */
function restartRun(){
  recordHistory();
  startNewRun();
}
