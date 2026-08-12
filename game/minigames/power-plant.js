/* =========================================================================
   Power Plant station mini-game: untangle the wires.
   -------------------------------------------------------------------------
   N colored wires run from the top of the screen to the bottom. Each
   wire's bottom end is fixed; its top end can be dragged left/right
   along the top edge. A wire pair crosses whenever their top-to-top
   left/right order doesn't match their bottom-to-bottom order -- drag
   the top ends until every wire's left-right order at the top matches
   its order at the bottom and all the crossings resolve at once.
   Solving one puzzle immediately serves up a harder one (one more
   wire); solve as many as you can before time runs out.

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
  const DURATION_MS = 30000;      // total round length (Bakery/Power Plant/Observatory get 30s, the rest 15s)
  const TARGET_SOLVES = 2;        // solving this many puzzles => score 1.0
  const START_WIRES = 4;
  const MAX_WIRES = 8;            // +1 wire per solve, capped here
  const MARGIN = 30;              // px, inset from stage edges for handle travel
  const HANDLE_R = 21;            // px, visible handle radius
  const HIT_R = 42;               // px, generous pointerdown target radius
  const RESULT_HOLD_MS = 1300;
  const DICE_MIN = 3;             // dice awarded at score 0
  const DICE_MAX = 6;             // dice awarded at score 1
  const TIMER_SHOW_MS = 10000;    // timer pill stays hidden until this much time remains
  const BACKDROP = "power-plant"; // backdrops/<BACKDROP>.webp

  const WIRE_COLORS = ["#e6564f", "#eb9a3c", "#e8d24c", "#5fcf6a", "#4ea8de", "#8b6fe0", "#e06fc0"];

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
    if (styleInjected || document.getElementById("mg-power-style")) { styleInjected = true; return; }
    const css = `
      .mg-power-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:
          linear-gradient(rgba(255,255,255,.04) 1px, transparent 1px) 0 0/100% 24px,
          linear-gradient(180deg,rgba(35,42,51,.78) 0%,rgba(26,32,39,.72) 55%,rgba(18,23,29,.8) 100%),
          var(--mg-backdrop, none);
        background-size:100% 24px, cover, cover;
        background-position:0 0, center, center;
        touch-action:none; user-select:none; font-family:inherit;
      }
      .mg-power-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#eef2f6;
        text-shadow:0 1px 2px rgba(0,0,0,.5); font-size:14px; pointer-events:none; gap:8px;
      }
      .mg-power-hud .mg-pill{
        background:rgba(255,255,255,.13); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
        white-space:nowrap;
      }
      .mg-power-hud .mg-dice-pill{
        display:grid; grid-template-columns:repeat(3,1fr); gap:0 4px; padding:3px 10px;
        font-size:1.5em; line-height:1.1;
      }
      .mg-power-hud .mg-timer-pill{ font-variant-numeric:tabular-nums; }
      .mg-power-timebar{position:absolute; top:0; left:0; height:4px; background:#ffb648; z-index:3;
        transition:width .1s linear}
      .mg-power-handle{ cursor:grab; transition:filter .12s ease; }
      /* Much stronger feedback than just the cursor swap (invisible on
         touch anyway): the dragged handle itself grows (see the JS r
         bump around drag start/end) plus a bright glow ring, so it's
         obvious which wire end is actually being held. */
      .mg-power-handle.mg-power-dragging{
        cursor:grabbing;
        filter:drop-shadow(0 0 4px #fff) drop-shadow(0 0 12px rgba(255,255,255,.85));
      }
      .mg-power-stage.mg-power-solved{ animation:mg-power-pulse .35s ease; }
      @keyframes mg-power-pulse{
        0%{ box-shadow: inset 0 0 0 0 rgba(95,207,106,0) } 30%{ box-shadow: inset 0 0 50px 8px rgba(95,207,106,.55) }
        100%{ box-shadow: inset 0 0 0 0 rgba(95,207,106,0) }
      }
      .mg-power-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(15,20,26,.6); color:#fff; text-align:center;
        opacity:0; animation:mg-power-fade-in .25s ease forwards;
      }
      .mg-power-result .mg-big{font-size:30px; font-weight:800}
      .mg-power-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-power-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-power-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  const SVG_NS = "http://www.w3.org/2000/svg";
  function svgEl(tag, attrs) {
    const el = document.createElementNS(SVG_NS, tag);
    for (const k in attrs) el.setAttribute(k, attrs[k]);
    return el;
  }

  // Returns a shuffled permutation of [0..n-1], guaranteed not to be the
  // identity (so every fresh puzzle starts with at least one crossing).
  function shuffledSlots(n) {
    const arr = [];
    for (let i = 0; i < n; i++) arr.push(i);
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    if (arr.every((v, i) => v === i) && arr.length > 1) {
      [arr[0], arr[1]] = [arr[1], arr[0]];
    }
    return arr;
  }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-power-stage";
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);

    const hud = document.createElement("div");
    hud.className = "mg-power-hud";
    hud.innerHTML = `<span class="mg-pill mg-dice-pill" id="mg-power-dice">${diceGridHTML(DICE_MIN)}</span>` +
      `<span class="mg-pill mg-timer-pill" id="mg-power-timer" style="display:none"></span>` +
      `<span class="mg-pill mg-score-pill" id="mg-power-solved">\u{26A1} 0</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-power-timebar";
    timebar.style.width = "100%";

    const svg = svgEl("svg", { width: "100%", height: "100%", style: "position:absolute; inset:0;" });

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(svg);
    container.appendChild(stage);

    const solvedEl = hud.querySelector("#mg-power-solved");
    const diceEl = hud.querySelector("#mg-power-dice");
    const timerEl = hud.querySelector("#mg-power-timer");
    const stageW = stage.clientWidth || 320;
    const stageH = stage.clientHeight || 420;
    // Clears the full HUD row (dice/timer/score pills) -- was 46, which let
    // the handles' top edge creep up under the HUD text. Bottom row lifted
    // another 100px off the stage floor per user request.
    const TOP_Y = 84, BOTTOM_Y = stageH - 146;

    let running = true;
    let solved = 0;
    let wireCount = START_WIRES;
    // BOTH ends are draggable. slotX[k] are the fixed x-coordinates shared
    // by the top and bottom rows; topSlot[w]/botSlot[w] say which slot each
    // end of wire w currently occupies, each its own permutation of
    // 0..wireCount-1. topX/botX are pixel positions derived from those --
    // except for whichever end is mid-drag, which follows the pointer.
    let slotX = [], topSlot = [], botSlot = [], topX = [], botX = [];
    let lines = [], topHandles = [], botHandles = [], hitHandles = [];
    // {wire, end:"top"|"bot"} while dragging, else null.
    let drag = null;

    function slotPositions(n) {
      if (n === 1) return [stageW / 2];
      const arr = [];
      for (let i = 0; i < n; i++) arr.push(MARGIN + (stageW - 2 * MARGIN) * (i / (n - 1)));
      return arr;
    }

    // Two wires cross exactly when their ends are ordered oppositely at the
    // top and the bottom. With both ends free the goal isn't "wires in index
    // order" any more -- it's just that the two permutations agree on SOME
    // common ordering, which is what a zero here means.
    function crossingsOf(top, bot) {
      let c = 0;
      for (let i = 0; i < wireCount; i++) {
        for (let j = i + 1; j < wireCount; j++) {
          if ((top[i] - top[j]) * (bot[i] - bot[j]) < 0) c++;
        }
      }
      return c;
    }

    function positionsToDom() {
      for (let i = 0; i < wireCount; i++) {
        lines[i].setAttribute("x1", topX[i]);
        lines[i].setAttribute("x2", botX[i]);
        topHandles[i].setAttribute("cx", topX[i]);
        botHandles[i].setAttribute("cx", botX[i]);
        hitHandles[i].top.setAttribute("cx", topX[i]);
        hitHandles[i].bot.setAttribute("cx", botX[i]);
      }
    }

    function buildPuzzle() {
      svg.innerHTML = "";
      lines = []; topHandles = []; botHandles = []; hitHandles = [];
      slotX = slotPositions(wireCount);
      // Shuffle both ends, then insist the result actually starts tangled --
      // with two free permutations it's now perfectly possible to roll a
      // pair that already agree, which would hand out a free solve.
      do {
        topSlot = shuffledSlots(wireCount);
        botSlot = shuffledSlots(wireCount);
      } while (wireCount > 1 && crossingsOf(topSlot, botSlot) === 0);
      topX = topSlot.map(s => slotX[s]);
      botX = botSlot.map(s => slotX[s]);

      for (let i = 0; i < wireCount; i++) {
        const color = WIRE_COLORS[i % WIRE_COLORS.length];
        const line = svgEl("line", {
          x1: topX[i], y1: TOP_Y, x2: botX[i], y2: BOTTOM_Y,
          stroke: color, "stroke-width": 5, "stroke-linecap": "round", opacity: 0.85,
        });
        svg.appendChild(line);
        lines.push(line);
      }
      // Handles are appended after every line so they always paint on top,
      // and the invisible hit targets after those so a tap near two close
      // handles still resolves to a handle rather than the wire behind it.
      for (let i = 0; i < wireCount; i++) {
        const color = WIRE_COLORS[i % WIRE_COLORS.length];
        const mk = (cx, cy) => svgEl("circle", {
          cx: cx, cy: cy, r: HANDLE_R, fill: color, stroke: "rgba(0,0,0,.7)", "stroke-width": 3.5,
          class: "mg-power-handle",
        });
        const top = mk(topX[i], TOP_Y), bot = mk(botX[i], BOTTOM_Y);
        svg.appendChild(top); svg.appendChild(bot);
        topHandles.push(top); botHandles.push(bot);
      }
      for (let i = 0; i < wireCount; i++) {
        // Invisible, larger circles purely for a touch-friendly hit target --
        // the visible handles stay small so several can sit close together.
        // pointer-events must be forced to "all": SVG's default
        // (visiblePainted) skips hit-testing on transparent fills entirely.
        const mkHit = (cx, cy, end) => {
          const hit = svgEl("circle", {
            cx: cx, cy: cy, r: HIT_R, fill: "transparent", "pointer-events": "all", class: "mg-power-handle",
          });
          hit.addEventListener("pointerdown", (e) => {
            e.preventDefault();
            drag = { wire: i, end: end };
            const handleEl = (end === "top" ? topHandles : botHandles)[i];
            handleEl.classList.add("mg-power-dragging");
            handleEl.setAttribute("r", HANDLE_R * 1.5); // grabbed handle grows -- see onUp() for the reset
            hit.setPointerCapture && hit.setPointerCapture(e.pointerId);
          });
          svg.appendChild(hit);
          return hit;
        };
        hitHandles.push({ top: mkHit(topX[i], TOP_Y, "top"), bot: mkHit(botX[i], BOTTOM_Y, "bot") });
      }
    }
    buildPuzzle();

    // Nearest slot index to a raw pixel x -- used both for live feedback
    // while dragging and to decide where a wire snaps to on release.
    function nearestSlot(x) {
      let best = 0, bestDist = Infinity;
      for (let s = 0; s < wireCount; s++) {
        const d = Math.abs(slotX[s] - x);
        if (d < bestDist) { bestDist = d; best = s; }
      }
      return best;
    }

    function onMove(e) {
      if (!drag) return;
      const rect = stage.getBoundingClientRect();
      const x = Math.max(MARGIN, Math.min(stageW - MARGIN, e.clientX - rect.left));
      (drag.end === "top" ? topX : botX)[drag.wire] = x;
      positionsToDom();
    }
    function onUp() {
      if (!drag) return;
      const { wire, end } = drag;
      const handles = end === "top" ? topHandles : botHandles;
      const slots = end === "top" ? topSlot : botSlot;
      handles[wire].classList.remove("mg-power-dragging");
      handles[wire].setAttribute("r", HANDLE_R);

      // Snap to the nearest slot, swapping with whoever already held it so
      // this end's arrangement stays a permutation (no two ends stacked).
      const targetSlot = nearestSlot(end === "top" ? topX[wire] : botX[wire]);
      const oldSlot = slots[wire];
      if (targetSlot !== oldSlot) {
        const otherWire = slots.indexOf(targetSlot);
        slots[wire] = targetSlot;
        if (otherWire !== -1) slots[otherWire] = oldSlot;
      }
      topX = topSlot.map(s => slotX[s]);
      botX = botSlot.map(s => slotX[s]);
      positionsToDom();
      drag = null;

      const c = crossingsOf(topSlot, botSlot);
      if (c === 0) {
        solved++;
        solvedEl.textContent = "\u{26A1} " + solved;
        diceEl.innerHTML = diceGridHTML(diceFor(solved / TARGET_SOLVES));
        stage.classList.remove("mg-power-solved");
        void stage.offsetWidth;
        stage.classList.add("mg-power-solved");
        wireCount = Math.min(MAX_WIRES, wireCount + 1);
        setTimeout(() => { if (running) buildPuzzle(); }, 260);
      }
    }
    // pointerup is scoped to the stage, not window, so it's cleaned up for
    // free when the container is cleared (no dispose hook in this contract).
    // setPointerCapture (set on pointerdown, above) keeps release events
    // routed here even if the pointer drifts outside the stage first.
    stage.addEventListener("pointermove", onMove);
    stage.addEventListener("pointerup", onUp);

    const start = Date.now();
    let rafId = null;
    function tick() {
      const elapsed = Date.now() - start;
      const left = Math.max(0, 1 - elapsed / DURATION_MS);
      timebar.style.width = (left * 100) + "%";
      const remainMs = DURATION_MS - elapsed;
      if (remainMs <= TIMER_SHOW_MS) {
        timerEl.style.display = "";
        timerEl.textContent = Math.max(0, Math.ceil(remainMs / 1000)) + "s";
      }
      if (elapsed >= DURATION_MS) { endRound(); return; }
      rafId = requestAnimationFrame(tick);
    }

    function endRound() {
      if (!running) return;
      running = false;
      stage.removeEventListener("pointermove", onMove);
      stage.removeEventListener("pointerup", onUp);
      if (rafId) cancelAnimationFrame(rafId);

      const score = Math.max(0, Math.min(1, solved / TARGET_SOLVES));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-power-result";
      resultEl.innerHTML = `
        <div class="mg-big">\u{1F50C} ${solved} puzzle${solved === 1 ? "" : "s"} untangled</div>
        <div class="mg-sub">\u{1F3B2} ${diceFor(score)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
