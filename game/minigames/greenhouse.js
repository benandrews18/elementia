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
  const DURATION_MS = 24000;         // total round length
  const TARGET_GOOD = 14;            // net good-egg-equivalents => score 1.0
  const BAD_PENALTY = 2;             // score lost per bad egg caught
  const BASKET_W = 66, BASKET_H = 28;
  const BASKET_BOTTOM_GAP = 14;      // px from stage floor to basket bottom
  const EGG_W = 24, EGG_H = 30;
  const CATCH_BAND = 14;             // px of vertical tolerance around the basket rim
  const FALL_MS_RAMP = 20000;        // time to reach max fall speed / spawn rate
  const FALL_SPEED_START = 100, FALL_SPEED_MAX = 220;  // px/s
  const SPAWN_MS_START = 900, SPAWN_MS_MIN = 430;
  const BAD_CHANCE_START = 0.24, BAD_CHANCE_MAX = 0.4;
  const RESULT_HOLD_MS = 1300;

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-green-style")) { styleInjected = true; return; }
    const css = `
      .mg-green-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,#dff3d8 0%,#bfe3b4 55%,#8fc47f 100%);
        touch-action:none; user-select:none; font-family:inherit;
      }
      .mg-green-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#20401c;
        text-shadow:0 1px 0 rgba(255,255,255,.4); font-size:15px; pointer-events:none;
      }
      .mg-green-hud .mg-pill{
        background:rgba(255,255,255,.55); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
      }
      .mg-green-timebar{position:absolute; top:0; left:0; height:4px; background:#4c9a3f; z-index:3;
        transition:width .1s linear}
      .mg-green-egg{
        position:absolute; border-radius:50% 50% 46% 46% / 60% 60% 40% 40%; z-index:2;
      }
      .mg-green-egg.mg-green-good{
        background:radial-gradient(circle at 34% 28%, #fffaf0, #f4e6c8 60%, #e0c98f 100%);
        box-shadow:inset 0 0 0 1px rgba(150,120,60,.35);
      }
      .mg-green-egg.mg-green-bad{
        background:radial-gradient(circle at 34% 28%, #cbe08a, #93a852 55%, #5f6e33 100%);
        box-shadow:inset 0 0 0 1px rgba(40,50,10,.4);
      }
      .mg-green-egg.mg-green-pop{ animation:mg-green-pop-anim .22s ease-out forwards; }
      @keyframes mg-green-pop-anim{ 0%{transform:scale(1); opacity:1} 100%{transform:scale(1.5); opacity:0} }
      .mg-green-basket{
        position:absolute; z-index:3; border-radius:0 0 12px 12px;
        background:linear-gradient(180deg,#b9834a,#8a5d31); box-shadow:0 3px 6px rgba(0,0,0,.25);
      }
      .mg-green-basket::before{
        content:""; position:absolute; left:-4px; right:-4px; top:-6px; height:8px; border-radius:6px;
        background:#a3703e; box-shadow:0 2px 3px rgba(0,0,0,.2);
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

    const hud = document.createElement("div");
    hud.className = "mg-green-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-green-score">\u{1F95A} 0</span><span class="mg-pill">Catch the good eggs!</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-green-timebar";
    timebar.style.width = "100%";

    const basket = document.createElement("div");
    basket.className = "mg-green-basket";
    basket.style.width = BASKET_W + "px";
    basket.style.height = BASKET_H + "px";

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(basket);
    container.appendChild(stage);

    const scoreEl = hud.querySelector("#mg-green-score");
    const stageW = stage.clientWidth || 320;
    const stageH = stage.clientHeight || 420;
    const basketTop = stageH - BASKET_H - BASKET_BOTTOM_GAP;
    basket.style.top = basketTop + "px";

    let basketX = stageW / 2 - BASKET_W / 2;
    basket.style.left = basketX + "px";

    let running = true;
    let score = 0;
    let nextSpawnAt = 0;
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
      scoreEl.textContent = "\u{1F95A} " + Math.max(0, score);
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
        <div class="mg-sub">${Math.round(finalScore * 100)}% -- nice catching!</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(finalScore), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
