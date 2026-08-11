/* =========================================================================
   The City station mini-game: stack the stones.
   -------------------------------------------------------------------------
   A stone slab slides back and forth across the screen. Tapping stops it
   in place; however much of it overlaps the stone below becomes the new
   placed stone (the overhang breaks off and falls away), and the camera
   pans up so the freshly placed stone always sits at the same spot on
   screen -- classic "Stack" feel. Missing entirely (zero overlap) ends
   the round early. Each successful placement narrows the working stone
   and speeds up the next slide, so it gets harder as the tower grows.

   Same public interface as every station mini-game (see ocean-bubbles.js
   for the fuller contract note):

       runMinigame(container, onComplete)
         container   - DOM element to render into, cleared/owned for the run.
         onComplete  - called once with a score in 0..1 when the round ends.

   No external assets/dependencies -- has to survive being pasted into the
   single portable elementia.html file later.
   ========================================================================= */
(function (global) {
  "use strict";

  /* ---- tunables -------------------------------------------------------- */
  const DURATION_MS = 15000;         // total round length (standardized across all 8 games)
  const TARGET_STONES = 4;           // stacking this many => score 1.0
  const STONE_H = 70;                // px, height of each stone row
  const BASE_TOP = 360;              // px, screen y where the base stone's top sits
  const START_WIDTH_FRAC = 0.7;      // first stone's width, as a fraction of stage width
  const MIN_WIDTH_PX = 40;           // floor so a placed stone can't shrink to nothing
  const SLIDE_MS_START = 3000;       // full left-right-left cycle, stone #1
  const SLIDE_MS_MIN = 950;          // cycle time floor as difficulty ramps
  const SLIDE_MS_STEP = 260;         // cycle time lost per stone placed
  const MISS_FALL_MS = 550;          // how long the missed stone takes to tumble away
  const RESULT_HOLD_MS = 1300;       // how long the result card sits before onComplete
  const DICE_MIN = 3;                // dice awarded at score 0
  const DICE_MAX = 6;                // dice awarded at score 1
  const TIMER_SHOW_MS = 10000;       // timer pill stays hidden until this much time remains
  const BACKDROP = "quarry";         // backdrops/<BACKDROP>.webp -- art is still the quarry piece

  // Darker and clearly distinct from each other (not four shades of the
  // same beige) so a placed stone reads as its own block against the ones
  // below it, not a blur of near-identical grey.
  const STONE_COLORS = ["#4a4640", "#5c6b5f", "#6b4c3a", "#3d4a52"];

  /* Station art behind the stage. The base is overridable so one file works
     both from game/minigames/ (sandbox + tuning lab) and from the built
     single-file game, where backdrops/ sits alongside the HTML instead. */
  function backdropURL() {
    const f = BACKDROP + ".webp";
    return (global.MINIGAME_ASSETS && global.MINIGAME_ASSETS[f]) ||
           ((global.MINIGAME_BACKDROP_BASE || "../backdrops/") + f);
  }
  /* Dice this run has earned so far -- shown live in the HUD so effort in
     the mini-game visibly feeds the roll it pays out into. */
  function diceFor(score) {
    return Math.round(DICE_MIN + (DICE_MAX - DICE_MIN) * Math.max(0, Math.min(1, score)));
  }
  /* 2-row-of-3 dice grid (see .mg-dice-pill), half the old single-line size. */
  function diceGridHTML(n) {
    return "<span class=\"mg-die\">\u{1F3B2}</span>".repeat(n);
  }

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-city-style")) { styleInjected = true; return; }
    const css = `
      .mg-city-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,rgba(207,214,220,.6) 0%,rgba(170,179,186,.5) 45%,rgba(118,127,134,.6) 100%),
          var(--mg-backdrop, none);
        background-size:cover, cover; background-position:center, center;
        touch-action:manipulation; user-select:none; font-family:inherit;
      }
      .mg-city-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#2a2f33;
        text-shadow:0 1px 0 rgba(255,255,255,.35); font-size:15px; pointer-events:none;
      }
      .mg-city-hud .mg-pill{
        background:rgba(255,255,255,.5); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
        white-space:nowrap;
      }
      .mg-city-hud .mg-dice-pill{
        display:grid; grid-template-columns:repeat(3,1fr); gap:0 4px; padding:3px 10px;
        font-size:1.5em; line-height:1.1;
      }
      .mg-city-hud .mg-timer-pill{ font-variant-numeric:tabular-nums; }
      .mg-city-timebar{position:absolute; top:0; left:0; height:4px; background:#e08a3d; z-index:3;
        transition:width .1s linear}
      .mg-city-track{ position:absolute; left:0; right:0; top:0; height:100%; will-change:transform; }
      .mg-city-stone{
        position:absolute; border-radius:4px; box-sizing:border-box;
        border:3px solid rgba(0,0,0,.65); box-shadow:0 2px 4px rgba(0,0,0,.25);
      }
      .mg-city-stone.mg-city-active{ box-shadow:0 2px 6px rgba(0,0,0,.3), inset 0 0 0 2px rgba(255,255,255,.5); }
      .mg-city-track.mg-city-pan{ transition:transform .28s ease; }
      .mg-city-chip{
        position:absolute; border-radius:3px; opacity:1; box-sizing:border-box;
        border:3px solid rgba(0,0,0,.65);
        transition:transform ${MISS_FALL_MS}ms ease-in, opacity ${MISS_FALL_MS}ms ease-in;
      }
      .mg-city-chip.mg-city-drop{ transform:translateY(90px) rotate(20deg); opacity:0; }
      .mg-city-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(30,32,34,.55); color:#fff; text-align:center;
        opacity:0; animation:mg-city-fade-in .25s ease forwards;
      }
      .mg-city-result .mg-big{font-size:30px; font-weight:800}
      .mg-city-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-city-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-city-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-city-stage";
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);

    const hud = document.createElement("div");
    hud.className = "mg-city-hud";
    hud.innerHTML = `<span class="mg-pill mg-dice-pill" id="mg-city-dice">${diceGridHTML(DICE_MIN)}</span>` +
      `<span class="mg-pill mg-timer-pill" id="mg-city-timer" style="display:none"></span>` +
      `<span class="mg-pill mg-score-pill" id="mg-city-count">\u{1F3D7}\u{FE0F} 0</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-city-timebar";
    timebar.style.width = "100%";

    const track = document.createElement("div");
    track.className = "mg-city-track";

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(track);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-city-count");
    const diceEl = hud.querySelector("#mg-city-dice");
    const timerEl = hud.querySelector("#mg-city-timer");
    const stageW = stage.clientWidth || 320;

    let running = true;
    let stonesPlaced = 0;
    let rowIndex = 0;
    let panY = 0;
    let slideMs = SLIDE_MS_START;
    let curWidth = Math.max(MIN_WIDTH_PX, stageW * START_WIDTH_FRAC);
    let prevLeft = (stageW - curWidth) / 2;
    let prevRight = prevLeft + curWidth;
    let stepStart = Date.now();
    let activeEl = null;
    let rafId = null;
    let enterFromRight = false;

    function color(i) { return STONE_COLORS[i % STONE_COLORS.length]; }

    function placeStoneEl(left, width, index, active) {
      const el = document.createElement("div");
      el.className = "mg-city-stone" + (active ? " mg-city-active" : "");
      el.style.width = width + "px";
      el.style.height = (STONE_H - 4) + "px";
      el.style.left = left + "px";
      el.style.top = (BASE_TOP - index * STONE_H) + "px";
      el.style.background = color(index);
      track.appendChild(el);
      return el;
    }

    // base stone (row 0), doesn't count toward the score
    placeStoneEl(prevLeft, curWidth, 0, false);
    spawnActive();

    function spawnActive() {
      rowIndex++;
      stepStart = Date.now();
      // Alternate which edge the stone slides in from, so the stack doesn't
      // settle into one repeated left-to-right rhythm the player can time
      // blind. Derived from the row index rather than randomised -- a strict
      // alternation is what reads as deliberate.
      enterFromRight = rowIndex % 2 === 0;
      activeEl = placeStoneEl(enterFromRight ? Math.max(0, stageW - curWidth) : 0, curWidth, rowIndex, true);
    }

    function currentLeft() {
      const range = Math.max(0, stageW - curWidth);
      const elapsed = (Date.now() - stepStart) % slideMs;
      const t = elapsed / slideMs;
      const tri = t < 0.5 ? t * 2 : 2 - t * 2;
      return (enterFromRight ? 1 - tri : tri) * range;
    }

    function spawnChip(left, width, index) {
      const chip = document.createElement("div");
      chip.className = "mg-city-chip";
      chip.style.width = width + "px";
      chip.style.height = (STONE_H - 4) + "px";
      chip.style.left = left + "px";
      chip.style.top = (BASE_TOP - index * STONE_H) + "px";
      chip.style.background = color(index);
      track.appendChild(chip);
      requestAnimationFrame(() => chip.classList.add("mg-city-drop"));
      setTimeout(() => chip.remove(), MISS_FALL_MS + 60);
    }

    function onTap() {
      if (!running || !activeEl) return;
      const left = currentLeft();
      const right = left + curWidth;
      const overlapLeft = Math.max(left, prevLeft);
      const overlapRight = Math.min(right, prevRight);
      const overlapW = overlapRight - overlapLeft;

      if (overlapW <= 0) {
        // total miss -- tumble the stone away and end the round
        activeEl.classList.remove("mg-city-active");
        activeEl.style.transition = `transform ${MISS_FALL_MS}ms ease-in, opacity ${MISS_FALL_MS}ms ease-in`;
        activeEl.style.transform = `translateY(120px) rotate(${left < prevLeft ? -25 : 25}deg)`;
        activeEl.style.opacity = "0";
        endRound();
        return;
      }

      // success -- the placed stone shrinks to the overlap, leftover chips fall away
      activeEl.classList.remove("mg-city-active");
      activeEl.style.left = overlapLeft + "px";
      activeEl.style.width = overlapW + "px";

      if (overlapLeft > left) spawnChip(left, overlapLeft - left, rowIndex);
      if (right > overlapRight) spawnChip(overlapRight, right - overlapRight, rowIndex);

      stonesPlaced++;
      countEl.textContent = "\u{1F3D7}\u{FE0F} " + stonesPlaced;
      diceEl.innerHTML = diceGridHTML(diceFor(stonesPlaced / TARGET_STONES));
      curWidth = Math.max(MIN_WIDTH_PX, overlapW);
      prevLeft = overlapLeft;
      prevRight = overlapLeft + curWidth;
      panY += STONE_H;
      track.classList.add("mg-city-pan");
      track.style.transform = `translateY(${panY}px)`;

      slideMs = Math.max(SLIDE_MS_MIN, SLIDE_MS_START - stonesPlaced * SLIDE_MS_STEP);
      spawnActive();
    }
    stage.addEventListener("pointerdown", onTap);

    const start = Date.now();
    function tick() {
      if (running && activeEl) {
        activeEl.style.left = currentLeft() + "px";
      }
      const elapsed = Date.now() - start;
      const left = Math.max(0, 1 - elapsed / DURATION_MS);
      timebar.style.width = (left * 100) + "%";
      const remainMs = DURATION_MS - elapsed;
      if (remainMs <= TIMER_SHOW_MS) {
        timerEl.style.display = "";
        timerEl.textContent = Math.max(0, Math.ceil(remainMs / 1000)) + "s";
      }
      if (elapsed >= DURATION_MS) { endRound(); return; }
      if (running) rafId = requestAnimationFrame(tick);
    }

    function endRound() {
      if (!running) return;
      running = false;
      stage.removeEventListener("pointerdown", onTap);
      if (rafId) cancelAnimationFrame(rafId);

      const score = Math.max(0, Math.min(1, stonesPlaced / TARGET_STONES));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-city-result";
      resultEl.innerHTML = `
        <div class="mg-big">\u{1FAA8} ${stonesPlaced} stone${stonesPlaced === 1 ? "" : "s"} stacked</div>
        <div class="mg-sub">\u{1F3B2} ${diceFor(score)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
