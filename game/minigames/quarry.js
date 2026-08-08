/* =========================================================================
   The Quarry station mini-game: stack the stones.
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
  const DURATION_MS = 30000;         // total round length (a clean run can go long)
  const TARGET_STONES = 10;          // stacking this many => score 1.0
  const STONE_H = 40;                // px, height of each stone row
  const BASE_TOP = 360;              // px, screen y where the base stone's top sits
  const START_WIDTH_FRAC = 0.5;      // first stone's width, as a fraction of stage width
  const MIN_WIDTH_PX = 16;           // floor so a placed stone can't shrink to nothing
  const SLIDE_MS_START = 1700;       // full left-right-left cycle, stone #1
  const SLIDE_MS_MIN = 950;          // cycle time floor as difficulty ramps
  const SLIDE_MS_STEP = 90;          // cycle time lost per stone placed
  const MISS_FALL_MS = 550;          // how long the missed stone takes to tumble away
  const RESULT_HOLD_MS = 1300;       // how long the result card sits before onComplete

  const STONE_COLORS = ["#9c9086", "#a89d8f", "#8f8479", "#b3a897"];

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-quarry-style")) { styleInjected = true; return; }
    const css = `
      .mg-quarry-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,#cfd6dc 0%,#aab3ba 45%,#767f86 100%);
        touch-action:manipulation; user-select:none; font-family:inherit;
      }
      .mg-quarry-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#2a2f33;
        text-shadow:0 1px 0 rgba(255,255,255,.35); font-size:15px; pointer-events:none;
      }
      .mg-quarry-hud .mg-pill{
        background:rgba(255,255,255,.5); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
      }
      .mg-quarry-timebar{position:absolute; top:0; left:0; height:4px; background:#e08a3d; z-index:3;
        transition:width .1s linear}
      .mg-quarry-track{ position:absolute; left:0; right:0; top:0; height:100%; will-change:transform; }
      .mg-quarry-stone{
        position:absolute; border-radius:4px; box-shadow:0 2px 4px rgba(0,0,0,.25), inset 0 0 0 1px rgba(0,0,0,.15);
      }
      .mg-quarry-stone.mg-quarry-active{ box-shadow:0 2px 6px rgba(0,0,0,.3), inset 0 0 0 2px rgba(255,255,255,.5); }
      .mg-quarry-track.mg-quarry-pan{ transition:transform .28s ease; }
      .mg-quarry-chip{
        position:absolute; border-radius:3px; opacity:1;
        transition:transform ${MISS_FALL_MS}ms ease-in, opacity ${MISS_FALL_MS}ms ease-in;
      }
      .mg-quarry-chip.mg-quarry-drop{ transform:translateY(90px) rotate(20deg); opacity:0; }
      .mg-quarry-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(30,32,34,.55); color:#fff; text-align:center;
        opacity:0; animation:mg-quarry-fade-in .25s ease forwards;
      }
      .mg-quarry-result .mg-big{font-size:30px; font-weight:800}
      .mg-quarry-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-quarry-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-quarry-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-quarry-stage";

    const hud = document.createElement("div");
    hud.className = "mg-quarry-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-quarry-count">\u{1FAA8} 0</span><span class="mg-pill">Tap to stack!</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-quarry-timebar";
    timebar.style.width = "100%";

    const track = document.createElement("div");
    track.className = "mg-quarry-track";

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(track);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-quarry-count");
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

    function color(i) { return STONE_COLORS[i % STONE_COLORS.length]; }

    function placeStoneEl(left, width, index, active) {
      const el = document.createElement("div");
      el.className = "mg-quarry-stone" + (active ? " mg-quarry-active" : "");
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
      activeEl = placeStoneEl(0, curWidth, rowIndex, true);
    }

    function currentLeft() {
      const range = Math.max(0, stageW - curWidth);
      const elapsed = (Date.now() - stepStart) % slideMs;
      const t = elapsed / slideMs;
      const tri = t < 0.5 ? t * 2 : 2 - t * 2;
      return tri * range;
    }

    function spawnChip(left, width, index) {
      const chip = document.createElement("div");
      chip.className = "mg-quarry-chip";
      chip.style.width = width + "px";
      chip.style.height = (STONE_H - 4) + "px";
      chip.style.left = left + "px";
      chip.style.top = (BASE_TOP - index * STONE_H) + "px";
      chip.style.background = color(index);
      track.appendChild(chip);
      requestAnimationFrame(() => chip.classList.add("mg-quarry-drop"));
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
        activeEl.classList.remove("mg-quarry-active");
        activeEl.style.transition = `transform ${MISS_FALL_MS}ms ease-in, opacity ${MISS_FALL_MS}ms ease-in`;
        activeEl.style.transform = `translateY(120px) rotate(${left < prevLeft ? -25 : 25}deg)`;
        activeEl.style.opacity = "0";
        endRound();
        return;
      }

      // success -- the placed stone shrinks to the overlap, leftover chips fall away
      activeEl.classList.remove("mg-quarry-active");
      activeEl.style.left = overlapLeft + "px";
      activeEl.style.width = overlapW + "px";

      if (overlapLeft > left) spawnChip(left, overlapLeft - left, rowIndex);
      if (right > overlapRight) spawnChip(overlapRight, right - overlapRight, rowIndex);

      stonesPlaced++;
      countEl.textContent = "\u{1FAA8} " + stonesPlaced;
      curWidth = Math.max(MIN_WIDTH_PX, overlapW);
      prevLeft = overlapLeft;
      prevRight = overlapLeft + curWidth;
      panY += STONE_H;
      track.classList.add("mg-quarry-pan");
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
      resultEl.className = "mg-quarry-result";
      resultEl.innerHTML = `
        <div class="mg-big">\u{1FAA8} ${stonesPlaced} stone${stonesPlaced === 1 ? "" : "s"} stacked</div>
        <div class="mg-sub">${Math.round(score * 100)}% -- nice work!</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
