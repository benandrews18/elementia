/* =====================================================================
   minigames.js -- Mini-game hosting: launchMinigame() for a station visit, dice from a
   score (minigameDiceFor()), and the Mini-Games arcade.
   ===================================================================== */
/* Mini-Games map: same art and positions as the real map, every node
   tappable, no session state. */
function renderArcadeMap(){
  const nodesHTML = Object.keys(MAP_NODE_POS).map(name => {
    const [x, y] = MAP_NODE_POS[name];
    const s = STATION_BY_NAME[name];
    const best = prefs.arcadeHighScores[name];
    const badge = best ? `<span class="arcade-best-badge">🏆 ${esc(String(best.raw))}</span>` : "";
    return `<button type="button" class="map-node reachable" style="left:${x}%;top:${y}%" data-arcade-node="${esc(name)}" aria-label="${esc(name)}${best ? `, best ${esc(String(best.raw))} ${esc(best.label)}` : ""}">
      <span class="mn-em">${em(s.emoji)}</span>${badge}
    </button>`;
  }).join("");
  return `<div class="map-canvas" data-map-bg><div class="map-nodes">${nodesHTML}</div></div>`;
}

/* The mini-game's score (0-1) sets this roll's dice (3-6, see DICE_MIN/
   DICE_MAX in game/minigames/*.js). A station with no mini-game falls back
   to doRoll() with TAKE. */
const MG_DICE_MIN = 3, MG_DICE_MAX = 6;
function minigameDiceFor(score){
  return Math.round(MG_DICE_MIN + (MG_DICE_MAX - MG_DICE_MIN) * Math.max(0, Math.min(1, score)));
}
// One line of "what is this" + "how do I play it" per station, shown on
// the pre-round intro card. Deliberately terse -- this is a "tap to
// continue" beat, not a rules page.
const MINIGAME_INTRO = {
  "The Ocean":         {title:"Pop the Bubbles", blurb:"Tap rising bubbles before they float off the top."},
  "The Power Plant":   {title:"Untangle the Wires", blurb:"Drag each handle so no wire crosses another."},
  "Greenhouse":        {title:"Catch the Eggs", blurb:"Drag the basket under falling eggs. Dodge the bad ones."},
  "Deep Mine":         {title:"Break the Rocks", blurb:"Tap a rock again and again to crack it open."},
  "Old Growth Forest": {title:"Plant the Trees", blurb:"Tap when the arm sweeps through the green zone."},
  "The Bakery":        {title:"Fill the Order", blurb:"Match the base, icing, and topping shown, then send it."},
  "The City":          {title:"Stack the Stones", blurb:"Tap to drop each stone lined up with the one below."},
  "The Observatory":   {title:"Fly the Rocket", blurb:"Hold left or right to steer and dodge the asteroids."},
};
function launchMinigame(){
  if (state.rolledHere) return;
  const run = window.MINIGAMES && window.MINIGAMES[current];
  // Mini-games off, or no mini-game: skip the overlay but still require a
  // Roll tap (triggerRoll()), using TAKE.
  if (!run || !prefs.minigamesEnabled){
    state.pendingRoll = TAKE;
    save();
    render();
    return;
  }
  const overlay = document.getElementById("mgOverlay");
  const stage = document.getElementById("mgStage");
  const introEl = document.getElementById("mgIntro");
  const resultsEl = document.getElementById("mgResults");
  stage.innerHTML = "";
  resultsEl.classList.remove("show");

  // The overlay starts below the station title banner (see #mgOverlay).
  // Scroll is pinned to the top and locked while it's open (restored on
  // close), since the crop is measured once.
  window.scrollTo({top:0, behavior:"instant"});
  const bannerEl = document.querySelector(".sheet-head");
  overlay.style.top = (bannerEl ? Math.max(0, bannerEl.getBoundingClientRect().bottom) : 0) + "px";
  // Both html and body -- either can be the real scroller.
  document.documentElement.style.overflow = "hidden";
  document.body.style.overflow = "hidden";
  // Also snap the scroll back if something moves it programmatically despite
  // overflow:hidden.
  function mgScrollGuard(){ if (window.scrollY !== 0) window.scrollTo(0, 0); }
  window.addEventListener("scroll", mgScrollGuard, {passive:true});

  // Read by each mini-game's craftedBgHTML() for a faded backdrop of this
  // station's crafted items. Pre-rendered with em() because the mini-game
  // files can't reach CUSTOM_ICONS.
  window.MINIGAME_CRAFTED_ITEMS = entriesAt(current).filter(e => owns(e.name)).map(e => em(e.emoji));

  const info = MINIGAME_INTRO[current] || {title: current, blurb: "Do your best before time runs out."};
  introEl.innerHTML = `<div class="mg-intro-title">${esc(info.title)}</div>` +
    `<div class="mg-intro-blurb">${esc(info.blurb)}</div>` +
    `<div class="mg-intro-tap">Tap to Continue</div>`;
  overlay.classList.add("show");
  introEl.classList.add("show");
  if (state.visits === 1){
    showMouseTipOnce("minigame1", 1, "Quick challenge! Do your best.", "top-left");
  }

  function startRound(){
    introEl.classList.remove("show");
    introEl.removeEventListener("click", startRound);

    // Each game's own HUD timer pill handles the countdown (TIMER_SHOW_MS),
    // matching its own DURATION_MS (15s for most, 30s for Bakery/Power Plant/
    // Observatory).
    run(stage, (score) => {
      const diceCount = minigameDiceFor(score);
      const s = STATION_BY_NAME[current];
      stage.innerHTML = "";
      resultsEl.innerHTML = `<div class="mg-results-icon">${em(s.emoji)}</div>` +
        `<div class="mg-results-pts">+${diceCount} dice earned</div>` +
        `<div class="mg-results-dice">${"\u{1F3B2}".repeat(diceCount)}</div>`;
      resultsEl.classList.add("show");
      setTimeout(() => {
        resultsEl.classList.remove("show");
        overlay.classList.remove("show");
        document.documentElement.style.overflow = "";
        document.body.style.overflow = "";
        window.removeEventListener("scroll", mgScrollGuard);
        // No more auto-roll: the dice earned sit on Home's Roll badge (see
        // updateHub()) until the player taps it themselves -- see
        // triggerRoll().
        state.pendingRoll = diceCount;
        save();
        render();
      }, 1400);
    });
  }
  introEl.addEventListener("click", startRound);
}

/* ------------------------------------------------------ Mini-Games --- */
/* Mini-Games mode: never reads or writes `state` and never calls
   goStation()/doRoll()/save(). Shares #mgOverlay and friends with
   launchMinigame() but returns to the arcade map at the end. */
function openArcade(){
  document.getElementById("arcadeMap").innerHTML = renderArcadeMap();
  document.getElementById("arcade").classList.add("open");
}
function closeArcade(){
  document.getElementById("arcade").classList.remove("open");
}
function launchArcadeGame(name){
  const run = window.MINIGAMES && window.MINIGAMES[name];
  if (!run) return;
  const overlay = document.getElementById("mgOverlay");
  const stage = document.getElementById("mgStage");
  const introEl = document.getElementById("mgIntro");
  const resultsEl = document.getElementById("mgResults");
  stage.innerHTML = "";
  resultsEl.classList.remove("show");
  // No station shop banner to crop below here -- #arcade already covers
  // the full viewport on its own, so the overlay just covers all of it.
  overlay.style.top = "0";

  const info = MINIGAME_INTRO[name] || {title: name, blurb: "Do your best before time runs out."};
  introEl.innerHTML = `<div class="mg-intro-title">${esc(info.title)}</div>` +
    `<div class="mg-intro-blurb">${esc(info.blurb)}</div>` +
    `<div class="mg-intro-tap">Tap to Continue</div>`;
  overlay.classList.add("show");
  introEl.classList.add("show");

  function startRound(){
    introEl.classList.remove("show");
    introEl.removeEventListener("click", startRound);
    run(stage, (score, meta) => {
      const diceCount = minigameDiceFor(score);
      const s = STATION_BY_NAME[name];
      // High score, keyed on the game's raw number (see prefs.arcadeHighScores).
      const prevBest = prefs.arcadeHighScores[name];
      const isNewBest = !!meta && (!prevBest || meta.raw > prevBest.raw);
      if (isNewBest){
        prefs.arcadeHighScores[name] = {raw: meta.raw, label: meta.label, score, dice: diceCount};
        savePrefs();
      }
      stage.innerHTML = "";
      resultsEl.innerHTML = `<div class="mg-results-icon">${em(s.emoji)}</div>` +
        `<div class="mg-results-pts">+${diceCount} dice earned</div>` +
        `<div class="mg-results-dice">${"\u{1F3B2}".repeat(diceCount)}</div>` +
        (meta ? `<div class="mg-results-raw">${esc(String(meta.raw))} ${esc(meta.label)}${isNewBest ? " — 🏆 New best!" : ""}</div>` : "") +
        (meta && !isNewBest && prevBest ? `<div class="mg-results-best">Best: ${esc(String(prevBest.raw))} ${esc(prevBest.label)}</div>` : "");
      resultsEl.classList.add("show");
      setTimeout(() => {
        resultsEl.classList.remove("show");
        overlay.classList.remove("show");
        // Back to the arcade grid; refresh its best-score badges by hand.
        document.getElementById("arcadeMap").innerHTML = renderArcadeMap();
      }, 1800);
    });
  }
  introEl.addEventListener("click", startRound);
}
document.getElementById("arcade").addEventListener("click", ev => {
  const node = ev.target.closest("[data-arcade-node]");
  if (node) launchArcadeGame(node.dataset.arcadeNode);
});
document.getElementById("arcadeExit").addEventListener("click", closeArcade);
document.getElementById("tourArcadeBtn").addEventListener("click", () => {
  endTour();
  openArcade();
});
