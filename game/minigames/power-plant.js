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
  const DURATION_MS = 40000;      // total round length
  const TARGET_SOLVES = 5;        // solving this many puzzles => score 1.0
  const START_WIRES = 4;
  const MAX_WIRES = 7;            // +1 wire per solve, capped here
  const MARGIN = 30;              // px, inset from stage edges for handle travel
  const HANDLE_R = 11;            // px, visible handle radius
  const HIT_R = 22;               // px, generous pointerdown target radius
  const RESULT_HOLD_MS = 1300;

  const WIRE_COLORS = ["#e6564f", "#eb9a3c", "#e8d24c", "#5fcf6a", "#4ea8de", "#8b6fe0", "#e06fc0"];

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-power-style")) { styleInjected = true; return; }
    const css = `
      .mg-power-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:
          linear-gradient(rgba(255,255,255,.04) 1px, transparent 1px) 0 0/100% 24px,
          linear-gradient(180deg,#232a33 0%,#1a2027 55%,#12171d 100%);
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
      .mg-power-hud .mg-pill.mg-power-clear{ background:rgba(95,207,106,.35); }
      .mg-power-timebar{position:absolute; top:0; left:0; height:4px; background:#ffb648; z-index:3;
        transition:width .1s linear}
      .mg-power-handle{ cursor:grab; }
      .mg-power-handle.mg-power-dragging{ cursor:grabbing; }
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

    const hud = document.createElement("div");
    hud.className = "mg-power-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-power-solved">\u{1F50C} 0</span><span class="mg-pill" id="mg-power-status">Drag to untangle</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-power-timebar";
    timebar.style.width = "100%";

    const svg = svgEl("svg", { width: "100%", height: "100%", style: "position:absolute; inset:0;" });

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(svg);
    container.appendChild(stage);

    const solvedEl = hud.querySelector("#mg-power-solved");
    const statusEl = hud.querySelector("#mg-power-status");
    const stageW = stage.clientWidth || 320;
    const stageH = stage.clientHeight || 420;
    const TOP_Y = 46, BOTTOM_Y = stageH - 46;

    let running = true;
    let solved = 0;
    let wireCount = START_WIRES;
    // bottomX[k]/slot k are the same fixed x-coordinates throughout a puzzle.
    // slotOfWire[wireIndex] = which slot that wire's top currently sits in --
    // a permutation of 0..wireCount-1. topX is purely derived for rendering.
    let bottomX = [], slotOfWire = [], topX = [];
    let lines = [], topHandles = [], hitHandles = [], botHandles = [];
    let draggingIndex = null;

    function slotPositions(n) {
      if (n === 1) return [stageW / 2];
      const arr = [];
      for (let i = 0; i < n; i++) arr.push(MARGIN + (stageW - 2 * MARGIN) * (i / (n - 1)));
      return arr;
    }

    // Counts inversions in a wireIndex -> slotIndex permutation: since bottom
    // slots are always in wire-index order, wire i crosses wire j (i<j) iff
    // their top order is reversed, i.e. slots[i] > slots[j].
    function crossingsOf(slots) {
      let c = 0;
      for (let i = 0; i < wireCount; i++) {
        for (let j = i + 1; j < wireCount; j++) {
          if (slots[i] > slots[j]) c++;
        }
      }
      return c;
    }

    function updateStatus(slots) {
      const c = crossingsOf(slots);
      if (c === 0) {
        statusEl.textContent = "Untangled!";
        statusEl.classList.add("mg-power-clear");
      } else {
        statusEl.textContent = c + (c === 1 ? " crossing" : " crossings");
        statusEl.classList.remove("mg-power-clear");
      }
      return c;
    }

    function positionsToDom() {
      for (let i = 0; i < wireCount; i++) {
        lines[i].setAttribute("x1", topX[i]);
        lines[i].setAttribute("x2", bottomX[i]);
        topHandles[i].setAttribute("cx", topX[i]);
        hitHandles[i].setAttribute("cx", topX[i]);
      }
    }

    function buildPuzzle() {
      svg.innerHTML = "";
      lines = []; topHandles = []; hitHandles = []; botHandles = [];
      bottomX = slotPositions(wireCount);
      slotOfWire = shuffledSlots(wireCount);
      topX = slotOfWire.map(s => bottomX[s]);

      for (let i = 0; i < wireCount; i++) {
        const color = WIRE_COLORS[i % WIRE_COLORS.length];
        const line = svgEl("line", {
          x1: topX[i], y1: TOP_Y, x2: bottomX[i], y2: BOTTOM_Y,
          stroke: color, "stroke-width": 5, "stroke-linecap": "round", opacity: 0.85,
        });
        svg.appendChild(line);
        lines.push(line);
      }
      for (let i = 0; i < wireCount; i++) {
        const color = WIRE_COLORS[i % WIRE_COLORS.length];
        const bot = svgEl("circle", { cx: bottomX[i], cy: BOTTOM_Y, r: HANDLE_R - 2, fill: color, stroke: "#fff", "stroke-width": 2 });
        svg.appendChild(bot);
        botHandles.push(bot);
      }
      for (let i = 0; i < wireCount; i++) {
        const color = WIRE_COLORS[i % WIRE_COLORS.length];
        const top = svgEl("circle", {
          cx: topX[i], cy: TOP_Y, r: HANDLE_R, fill: color, stroke: "#fff", "stroke-width": 2.5,
          class: "mg-power-handle",
        });
        // invisible, larger circle on top purely for a touch-friendly hit target --
        // the visible handle stays small so several can sit close together.
        // pointer-events must be forced to "all": SVG's default
        // (visiblePainted) skips hit-testing on transparent fills entirely.
        const hit = svgEl("circle", {
          cx: topX[i], cy: TOP_Y, r: HIT_R, fill: "transparent", "pointer-events": "all", class: "mg-power-handle",
        });
        hit.dataset.index = i;
        hit.addEventListener("pointerdown", (e) => {
          e.preventDefault();
          draggingIndex = i;
          top.classList.add("mg-power-dragging");
          hit.setPointerCapture && hit.setPointerCapture(e.pointerId);
        });
        svg.appendChild(top);
        svg.appendChild(hit);
        topHandles.push(top);
        hitHandles.push(hit);
      }
      updateStatus(slotOfWire);
    }
    buildPuzzle();

    // Nearest slot index to a raw pixel x -- used both for live feedback
    // while dragging and to decide where a wire snaps to on release.
    function nearestSlot(x) {
      let best = 0, bestDist = Infinity;
      for (let s = 0; s < wireCount; s++) {
        const d = Math.abs(bottomX[s] - x);
        if (d < bestDist) { bestDist = d; best = s; }
      }
      return best;
    }

    function onMove(e) {
      if (draggingIndex === null) return;
      const rect = stage.getBoundingClientRect();
      const x = Math.max(MARGIN, Math.min(stageW - MARGIN, e.clientX - rect.left));
      topX[draggingIndex] = x;
      positionsToDom();
      // live feedback only -- swap the dragged wire's slot into a scratch
      // copy so the crossing count previews where it would land, without
      // touching the authoritative permutation until it's actually dropped.
      const provisional = slotOfWire.slice();
      provisional[draggingIndex] = nearestSlot(x);
      updateStatus(provisional);
    }
    function onUp() {
      if (draggingIndex === null) return;
      topHandles[draggingIndex].classList.remove("mg-power-dragging");

      const targetSlot = nearestSlot(topX[draggingIndex]);
      const oldSlot = slotOfWire[draggingIndex];
      if (targetSlot !== oldSlot) {
        const otherWire = slotOfWire.indexOf(targetSlot);
        slotOfWire[draggingIndex] = targetSlot;
        if (otherWire !== -1) slotOfWire[otherWire] = oldSlot;
      }
      topX = slotOfWire.map(s => bottomX[s]);
      positionsToDom();
      draggingIndex = null;

      const c = updateStatus(slotOfWire);
      if (c === 0) {
        solved++;
        solvedEl.textContent = "\u{1F50C} " + solved;
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
        <div class="mg-sub">${Math.round(score * 100)}% -- nice work!</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
