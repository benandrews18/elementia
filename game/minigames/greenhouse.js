/* =========================================================================
   Greenhouse station mini-game: catch the eggs.
   -------------------------------------------------------------------------
   Eggs fall from the top; drag the basket along the bottom to catch them.
   Good eggs (cream, plain) add to the score; bad eggs (mottled green)
   subtract more than a good egg is worth, so catching one is a real
   setback without ending the round outright -- avoidance is the skill,
   not sudden death (unlike the Quarry/Observatory games, on purpose --
   not every station needs the same tension). Missing a good egg (letting
   it fall past the basket) is free; only what you actually catch counts.

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
  const TARGET_GOOD = 9;             // net good-egg-equivalents => score 1.0
  const BAD_PENALTY = 2;             // score lost per bad egg caught
  // Basket sizes relative to the stage, not fixed px -- a thumb needs to be
  // able to comfortably cover it regardless of device width. 50% wider and
  // much shorter than the old CSS-drawn basket -- matches the 🧺 emoji's
  // own low, wide proportions instead of the tall narrow box it replaced.
  const BASKET_W_FRAC = 0.375;       // basket width, as a fraction of stage width
  const BASKET_ASPECT = 0.65;        // basket height = width * this
  const BASKET_BOTTOM_GAP = 104;     // px from stage floor to basket bottom
  // ~0.71 w:h is what actually reads as an egg rather than a small oval --
  // the shape comes from the border-radius in .mg-green-egg, but it needs
  // both the ratio AND enough pixels to be legible while falling.
  const EGG_W = 30;
  const EGG_H = 42;
  const CATCH_BAND = 14;             // px of vertical tolerance around the basket rim
  const FALL_MS_RAMP = 20000;        // time to reach max fall speed / spawn rate
  const FALL_SPEED_START = 100;      // px/s
  const FALL_SPEED_MAX = 600;        // px/s
  const SPAWN_MS_START = 900;
  const SPAWN_MS_MIN = 250;
  const BAD_CHANCE_START = 0.24;
  const BAD_CHANCE_MAX = 0.4;
  const RESULT_HOLD_MS = 1300;
  const DICE_MIN = 3;                // dice awarded at score 0
  const DICE_MAX = 6;                // dice awarded at score 1
  const TIMER_SHOW_MS = 10000;       // timer pill stays hidden until this much time remains
  const BACKDROP = "greenhouse";     // backdrops/<BACKDROP>.webp

  /* Good eggs run through the rainbow; bad ones are deliberately OUTSIDE
     that palette (dark, cracked) so "is this one worth catching" is never
     a hue judgement between two similar greens. */
  const EGG_COLORS = [
    ["#ff8a80", "#e5384a"], ["#ffc17a", "#ef8b21"], ["#ffe680", "#e8c22a"],
    ["#a8e6a3", "#43a047"], ["#8fd3f4", "#2196c4"], ["#a9a8f0", "#4a47c9"],
    ["#d6a8f0", "#8e3fc0"],
  ];

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
  function diceFor(s) {
    return Math.round(DICE_MIN + (DICE_MAX - DICE_MIN) * Math.max(0, Math.min(1, s)));
  }
  /* 2-row-of-3 dice grid (see .mg-dice-pill), half the old single-line size. */
  function diceGridHTML(n) {
    return "<span class=\"mg-die\">\u{1F3B2}</span>".repeat(n);
  }

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-green-style")) { styleInjected = true; return; }
    const css = `
      .mg-green-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,rgba(223,243,216,.58) 0%,rgba(191,227,180,.5) 55%,rgba(143,196,127,.58) 100%),
          var(--mg-backdrop, none);
        background-size:cover, cover; background-position:center, center;
        touch-action:none; user-select:none; font-family:inherit;
      }
      .mg-green-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#20401c;
        text-shadow:0 1px 0 rgba(255,255,255,.4); font-size:15px; pointer-events:none;
      }
      .mg-green-hud .mg-pill{
        background:rgba(255,255,255,.55); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
        white-space:nowrap;
      }
      /* Dice earned shown as that many die-face emojis in a 2-row-by-3
         grid, half the old single-line size. */
      .mg-dice-pill{
        display:grid; grid-template-columns:repeat(3,1fr); gap:0 4px; padding:3px 8px;
        font-size:1.5em; line-height:1.1;
      }
      .mg-green-hud .mg-timer-pill{ font-variant-numeric:tabular-nums; }
      .mg-green-timebar{position:absolute; top:0; left:0; height:4px; background:#4c9a3f; z-index:3;
        transition:width .1s linear}
      /* The classic CSS egg: equal horizontal radii, but a much taller
         vertical radius at the top than the bottom, which pulls the top to
         a point and leaves the base round. Needs the ~0.71 w:h from EGG_W/
         EGG_H to actually look like one. */
      .mg-green-egg{
        position:absolute; z-index:2;
        border-radius:50% 50% 50% 50% / 62% 62% 38% 38%;
        box-shadow:inset -3px -5px 8px rgba(0,0,0,.18), 0 2px 4px rgba(0,0,0,.22);
      }
      .mg-green-egg.mg-green-good{
        background:radial-gradient(circle at 34% 26%, #fff 0%, var(--egg-a) 38%, var(--egg-b) 100%);
      }
      /* Cracked and colourless -- reads as "don't catch" on shape and value,
         not just hue (see EGG_COLORS). */
      .mg-green-egg.mg-green-bad{
        background:radial-gradient(circle at 34% 26%, #7c7468, #4a443b 55%, #2b2822 100%);
      }
      .mg-green-egg.mg-green-bad::after{
        content:""; position:absolute; inset:0;
        background:
          linear-gradient(115deg, transparent 44%, rgba(0,0,0,.75) 45%, transparent 47%),
          linear-gradient(60deg, transparent 56%, rgba(0,0,0,.6) 57%, transparent 59%);
      }
      .mg-green-egg.mg-green-pop{ animation:mg-green-pop-anim .22s ease-out forwards; }
      @keyframes mg-green-pop-anim{ 0%{transform:scale(1); opacity:1} 100%{transform:scale(1.5); opacity:0} }
      /* Real 🧺 emoji instead of a CSS-drawn box -- font-size (set per stage
         size in JS) drives its rendered size, so the div's own width/height
         here just define the (shorter) catch hit-box; overflow:visible lets
         the glyph render at its own natural proportions above/around it. */
      .mg-green-basket{
        position:absolute; z-index:3; display:flex; align-items:center; justify-content:center;
        overflow:visible; line-height:1; pointer-events:none;
      }
      .mg-green-stage.mg-green-bad-flash{ animation:mg-green-flash .3s ease; }
      @keyframes mg-green-flash{
        0%{ box-shadow: inset 0 0 0 0 rgba(200,40,30,0) } 30%{ box-shadow: inset 0 0 46px 8px rgba(200,40,30,.55) }
        100%{ box-shadow: inset 0 0 0 0 rgba(200,40,30,0) }
      }
      .mg-green-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(20,45,15,.55); color:#fff; text-align:center;
        opacity:0; animation:mg-green-fade-in .25s ease forwards;
      }
      .mg-green-result .mg-big{font-size:30px; font-weight:800}
      .mg-green-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-green-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-green-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function rand(min, max) { return min + Math.random() * (max - min); }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-green-stage";
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);

    const hud = document.createElement("div");
    hud.className = "mg-green-hud";
    hud.innerHTML = `<span class="mg-pill mg-dice-pill" id="mg-green-dice">${diceGridHTML(DICE_MIN)}</span>` +
      `<span class="mg-pill mg-timer-pill" id="mg-green-timer" style="display:none"></span>` +
      `<span class="mg-pill mg-score-pill" id="mg-green-score">\u{1F331} 0</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-green-timebar";
    timebar.style.width = "100%";

    const basket = document.createElement("div");
    basket.className = "mg-green-basket";
    basket.textContent = "\u{1F9FA}";

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(basket);
    container.appendChild(stage);

    const scoreEl = hud.querySelector("#mg-green-score");
    const diceEl = hud.querySelector("#mg-green-dice");
    const timerEl = hud.querySelector("#mg-green-timer");
    // Live, not captured once -- the stage can still be resizing when the
    // round starts (e.g. entering the CSS-only fullscreen overlay resizes
    // the stage element itself without firing a window "resize" event), so
    // a value read right here can be stale for the rest of the round. Kept
    // in sync every frame (see tick()) instead. BASKET_W/H ride along with
    // it since they're stage-relative now too.
    let stageW = stage.clientWidth || 320;
    let stageH = stage.clientHeight || 420;
    let BASKET_W = stageW * BASKET_W_FRAC;
    let BASKET_H = BASKET_W * BASKET_ASPECT;
    basket.style.width = BASKET_W + "px";
    basket.style.height = BASKET_H + "px";
    basket.style.fontSize = (BASKET_W * 0.9) + "px";
    let basketTop = stageH - BASKET_H - BASKET_BOTTOM_GAP;
    basket.style.top = basketTop + "px";

    let basketX = stageW / 2 - BASKET_W / 2;
    basket.style.left = basketX + "px";

    let running = true;
    let score = 0;
    let nextSpawnAt = 0;
    let eggHue = 0;   // walks EGG_COLORS so consecutive eggs differ
    const eggs = [];

    function setBasketX(clientX) {
      const rect = stage.getBoundingClientRect();
      basketX = Math.max(0, Math.min(stageW - BASKET_W, clientX - rect.left - BASKET_W / 2));
      basket.style.left = basketX + "px";
    }
    function onPointer(e) { setBasketX(e.clientX); }
    stage.addEventListener("pointerdown", onPointer);
    stage.addEventListener("pointermove", onPointer);

    function spawnEgg(elapsed) {
      const ramp = Math.min(1, elapsed / FALL_MS_RAMP);
      const bad = Math.random() < BAD_CHANCE_START + (BAD_CHANCE_MAX - BAD_CHANCE_START) * ramp;
      const el = document.createElement("div");
      el.className = "mg-green-egg " + (bad ? "mg-green-bad" : "mg-green-good");
      if (!bad) {
        const c = EGG_COLORS[eggHue++ % EGG_COLORS.length];
        el.style.setProperty("--egg-a", c[0]);
        el.style.setProperty("--egg-b", c[1]);
      }
      el.style.width = EGG_W + "px";
      el.style.height = EGG_H + "px";
      const x = rand(4, stageW - EGG_W - 4);
      el.style.left = x + "px";
      el.style.top = "-" + EGG_H + "px";
      stage.appendChild(el);
      eggs.push({ el, x, y: -EGG_H, bad, speed: FALL_SPEED_START + (FALL_SPEED_MAX - FALL_SPEED_START) * ramp });
      const spawnMs = SPAWN_MS_START + (SPAWN_MS_MIN - SPAWN_MS_START) * ramp;
      nextSpawnAt = elapsed + spawnMs;
    }

    function updateScore() {
      scoreEl.textContent = "\u{1F331} " + Math.max(0, score);
      diceEl.innerHTML = diceGridHTML(diceFor(Math.max(0, score) / TARGET_GOOD));
    }

    function flashBad() {
      stage.classList.remove("mg-green-bad-flash");
      void stage.offsetWidth;
      stage.classList.add("mg-green-bad-flash");
    }

    function catchEgg(egg) {
      eggs.splice(eggs.indexOf(egg), 1);
      egg.el.classList.add("mg-green-pop");
      setTimeout(() => egg.el.remove(), 250);
      if (egg.bad) {
        score -= BAD_PENALTY;
        flashBad();
      } else {
        score += 1;
      }
      updateScore();
    }

    const start = Date.now();
    let rafId = null;
    let lastFrame = start;

    function tick() {
      const now = Date.now();
      const dt = Math.min(0.05, (now - lastFrame) / 1000);
      lastFrame = now;
      const elapsed = now - start;

      const liveW = stage.clientWidth || stageW;
      const liveH = stage.clientHeight || stageH;
      if (liveW !== stageW || liveH !== stageH) {
        stageW = liveW; stageH = liveH;
        BASKET_W = stageW * BASKET_W_FRAC;
        BASKET_H = BASKET_W * BASKET_ASPECT;
        basket.style.width = BASKET_W + "px";
        basket.style.height = BASKET_H + "px";
        basket.style.fontSize = (BASKET_W * 0.9) + "px";
        basketTop = stageH - BASKET_H - BASKET_BOTTOM_GAP;
        basket.style.top = basketTop + "px";
        basketX = Math.max(0, Math.min(stageW - BASKET_W, basketX));
        basket.style.left = basketX + "px";
      }

      if (elapsed >= nextSpawnAt) spawnEgg(elapsed);

      const catchY = basketTop - CATCH_BAND / 2;
      for (let i = eggs.length - 1; i >= 0; i--) {
        const egg = eggs[i];
        egg.y += egg.speed * dt;
        egg.el.style.top = egg.y + "px";

        if (egg.y + EGG_H >= catchY && egg.y <= basketTop + BASKET_H) {
          const eggCx = egg.x + EGG_W / 2;
          if (eggCx >= basketX && eggCx <= basketX + BASKET_W) {
            catchEgg(egg);
            continue;
          }
        }
        if (egg.y > stageH) {
          egg.el.remove();
          eggs.splice(i, 1);
        }
      }

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
      stage.removeEventListener("pointerdown", onPointer);
      stage.removeEventListener("pointermove", onPointer);
      if (rafId) cancelAnimationFrame(rafId);

      const net = Math.max(0, score);
      const finalScore = Math.max(0, Math.min(1, net / TARGET_GOOD));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-green-result";
      resultEl.innerHTML = `
        <div class="mg-big">\u{1F95A} ${net} caught</div>
        <div class="mg-sub">\u{1F3B2} ${diceFor(finalScore)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(finalScore, {raw: net, label: "eggs caught"}), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
