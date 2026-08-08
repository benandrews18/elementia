/* =========================================================================
   Ocean station mini-game: pop the bubbles.
   -------------------------------------------------------------------------
   Public interface (the shape every station mini-game should share, so
   dropping a new one into elementia.html later is a copy-paste, not a
   redesign):

       runMinigame(container, onComplete)
         container   - a DOM element to render into. Cleared and owned for
                        the duration of the run; left empty when it ends.
         onComplete  - called once with a single number, 0..1, once the
                        round is over. The caller decides what that becomes
                        (e.g. bonus dice = round(score * MAX_BONUS)).

   Everything else here is private. No external assets, no dependencies --
   this has to survive being pasted into a single portable HTML file later,
   same as the rest of the game.
   ========================================================================= */
(function (global) {
  "use strict";

  /* ---- tunables --------------------------------------------------------
     These are the knobs to turn while play-testing. Nothing else in this
     file should need to change to retune difficulty/feel. */
  const DURATION_MS = 14000;      // total round length
  const SPAWN_MIN_MS = 380;       // gap between bubble spawns
  const SPAWN_MAX_MS = 700;
  const SIZE_MIN_PX = 34;         // bubble diameter range
  const SIZE_MAX_PX = 68;
  const RISE_MIN_MS = 2200;       // time for a bubble to float top to bottom
  const RISE_MAX_MS = 3600;
  const TARGET_POPS = 16;         // popping this many => score 1.0
  const RESULT_HOLD_MS = 1200;    // how long the "time's up" card sits before onComplete

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-ocean-style")) { styleInjected = true; return; }
    const css = `
      .mg-ocean-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,#bfe4fb 0%,#8fd0f2 55%,#57b3e0 100%);
        touch-action:manipulation; user-select:none; font-family:inherit;
      }
      .mg-ocean-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#0b3a55;
        text-shadow:0 1px 0 rgba(255,255,255,.5); font-size:15px; pointer-events:none;
      }
      .mg-ocean-hud .mg-pill{
        background:rgba(255,255,255,.55); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
      }
      .mg-ocean-timebar{position:absolute; top:0; left:0; height:4px; background:#ff8a3d; z-index:3;
        transition:width .1s linear}
      .mg-bubble{
        position:absolute; bottom:-10%; border-radius:50%; cursor:pointer;
        background:radial-gradient(circle at 30% 26%, rgba(255,255,255,.95), rgba(255,255,255,.18) 42%,
          rgba(140,215,255,.35) 70%, rgba(70,170,225,.55) 100%);
        border:1px solid rgba(255,255,255,.65);
        box-shadow:0 0 10px rgba(255,255,255,.25) inset, 0 2px 6px rgba(10,60,90,.25);
        will-change:transform, opacity;
      }
      .mg-bubble.mg-pop{animation:mg-pop-anim .22s ease-out forwards}
      @keyframes mg-pop-anim{
        0%{transform:scale(1); opacity:1}
        100%{transform:scale(1.5); opacity:0}
      }
      .mg-ocean-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(8,40,60,.55); color:#fff; text-align:center;
        opacity:0; animation:mg-fade-in .25s ease forwards;
      }
      .mg-ocean-result .mg-big{font-size:30px; font-weight:800}
      .mg-ocean-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-ocean-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function rand(min, max) { return min + Math.random() * (max - min); }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-ocean-stage";
    const hud = document.createElement("div");
    hud.className = "mg-ocean-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-pop-count">🫧 0</span><span class="mg-pill">Pop the bubbles!</span>`;
    const timebar = document.createElement("div");
    timebar.className = "mg-ocean-timebar";
    timebar.style.width = "100%";
    stage.appendChild(hud);
    stage.appendChild(timebar);
    container.appendChild(stage);

    const popCountEl = hud.querySelector("#mg-pop-count");
    let popped = 0;
    let spawnTimer = null;
    let running = true;
    const liveBubbles = new Set();

    function spawnBubble() {
      if (!running) return;
      const size = rand(SIZE_MIN_PX, SIZE_MAX_PX);
      const stageW = stage.clientWidth || 320;
      const left = rand(4, Math.max(4, stageW - size - 4));
      const riseMs = rand(RISE_MIN_MS, RISE_MAX_MS);
      const drift = rand(-18, 18); // px of horizontal wobble over the rise

      const b = document.createElement("div");
      b.className = "mg-bubble";
      b.style.width = size + "px";
      b.style.height = size + "px";
      b.style.left = left + "px";
      stage.appendChild(b);
      liveBubbles.add(b);

      const anim = b.animate(
        [
          { transform: "translate(0px, 0px)", offset: 0 },
          { transform: `translate(${drift}px, -${stage.clientHeight + size}px)`, offset: 1 },
        ],
        { duration: riseMs, easing: "linear" }
      );
      anim.onfinish = () => {
        if (!liveBubbles.has(b)) return; // already popped
        liveBubbles.delete(b);
        b.remove();
      };

      const pop = () => {
        if (!running || !liveBubbles.has(b)) return;
        liveBubbles.delete(b);
        anim.cancel();
        popped++;
        popCountEl.textContent = "🫧 " + popped;
        b.classList.add("mg-pop");
        setTimeout(() => b.remove(), 250);
      };
      b.addEventListener("pointerdown", pop);

      scheduleSpawn();
    }
    function scheduleSpawn() {
      if (!running) return;
      spawnTimer = setTimeout(spawnBubble, rand(SPAWN_MIN_MS, SPAWN_MAX_MS));
    }

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
      clearTimeout(spawnTimer);
      if (rafId) cancelAnimationFrame(rafId);
      liveBubbles.forEach(b => b.remove());
      liveBubbles.clear();

      const score = Math.max(0, Math.min(1, popped / TARGET_POPS));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-ocean-result";
      resultEl.innerHTML = `
        <div class="mg-big">🫧 ${popped} popped</div>
        <div class="mg-sub">${Math.round(score * 100)}% -- nice work!</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    scheduleSpawn();
    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
