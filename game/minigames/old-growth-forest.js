/* =========================================================================
   Old Growth Forest station mini-game: plant trees.
   -------------------------------------------------------------------------
   A needle sweeps back and forth across a half-circle gauge split into
   3 zones (red / green / red). Tapping while the needle is in the green
   zone advances the current step; 3 steps in a row -- dig, plant, water --
   plants one tree. Missing doesn't end anything, it just doesn't advance;
   the needle keeps bouncing so the player gets another shot immediately.

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
  const DURATION_MS = 15000;        // total round length (standardized across all 8 games)
  const TARGET_TREES = 3;           // planting this many => score 1.0
  const SWEEP_MS_START = 1500;      // full left-right-left cycle, tree #1
  const SWEEP_MS_MIN = 1150;        // cycle time floor as difficulty ramps
  const SWEEP_MS_STEP = 130;        // cycle time lost per tree planted
  const GREEN_HALF_DEG_START = 30;  // green zone half-width in degrees, tree #1
  const GREEN_HALF_DEG_MIN = 11;    // half-width floor as difficulty ramps
  const GREEN_HALF_DEG_STEP = 2;    // half-width lost per tree planted
  const RESULT_HOLD_MS = 1300;      // how long the "time's up" card sits before onComplete
  const DICE_MIN = 3;               // dice awarded at score 0
  const DICE_MAX = 6;               // dice awarded at score 1
  const BACKDROP = "old-growth-forest"; // backdrops/<BACKDROP>.webp

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

  const STEPS = [
    { key: "dig", icon: "\u{1FA8F}", label: "Dig the hole" },
    { key: "plant", icon: "\u{1F333}", label: "Plant the tree" },
    { key: "water", icon: "\u{1F4A7}", label: "Water it" },
  ];

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-forest-style")) { styleInjected = true; return; }
    const css = `
      .mg-forest-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,rgba(31,61,36,.72) 0%,rgba(23,52,32,.66) 55%,rgba(15,36,23,.74) 100%),
          var(--mg-backdrop, none);
        background-size:cover, cover; background-position:center, center;
        touch-action:manipulation; user-select:none; font-family:inherit;
      }
      .mg-forest-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#eafff0;
        text-shadow:0 1px 2px rgba(0,0,0,.4); font-size:14px; pointer-events:none; gap:8px;
      }
      .mg-forest-hud .mg-pill{
        background:rgba(255,255,255,.14); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
        white-space:nowrap;
      }
      .mg-forest-hud .mg-dice-pill{
        display:grid; grid-template-columns:repeat(3,1fr); gap:0 4px; padding:3px 10px;
        font-size:1.5em; line-height:1.1;
      }
      .mg-forest-hud .mg-timer-pill{ font-variant-numeric:tabular-nums; }
      .mg-forest-timebar{position:absolute; top:0; left:0; height:4px; background:#ffb648; z-index:3;
        transition:width .1s linear}
      .mg-forest-steps{
        position:absolute; top:44px; left:0; right:0; z-index:3; display:flex; justify-content:center;
        gap:10px; pointer-events:none;
      }
      .mg-forest-step-dot{
        width:30px; height:30px; border-radius:50%; display:flex; align-items:center; justify-content:center;
        font-size:16px; background:rgba(255,255,255,.10); border:1.5px solid rgba(255,255,255,.25);
        opacity:.55; transition:opacity .2s ease, transform .2s ease, background .2s ease, border-color .2s ease;
      }
      .mg-forest-step-dot.mg-forest-current{opacity:1; transform:scale(1.12); border-color:#7be495; background:rgba(123,228,149,.18)}
      .mg-forest-step-dot.mg-forest-done{opacity:1; background:rgba(123,228,149,.35); border-color:#7be495}
      .mg-forest-gauge-wrap{
        position:absolute; left:50%; top:60%; transform:translate(-50%,-50%);
        width:96%; height:170px;
      }
      /* Rotating "Dig a hole / Plant the tree / Water it" instruction,
         between the big step image and the target gauge below it. */
      .mg-forest-steplabel{
        position:absolute; left:50%; top:45%; transform:translate(-50%,-50%); z-index:2;
        font-size:16px; font-weight:800; color:#eafff0; text-shadow:0 1px 3px rgba(0,0,0,.5);
        text-align:center; white-space:nowrap; pointer-events:none;
      }
      /* Large step image -- swaps instantly on each successful hit (see
         onTap()), planted above the gauge so the shovel/tree/water
         progression is the thing a player is actually looking at, not the
         small HUD pill. */
      .mg-forest-bigicon{
        position:absolute; left:50%; top:26%; transform:translate(-50%,-50%); z-index:2;
        font-size:min(30vw,150px); line-height:1; pointer-events:none;
        filter:drop-shadow(0 6px 14px rgba(0,0,0,.4));
      }
      /* No transform-origin here on purpose. The needle is rotated with the
         SVG transform ATTRIBUTE, rotate(deg CX CY), which already carries
         its own pivot -- and in SVG2 that attribute IS the CSS transform
         property, so a transform-origin would be applied on top of it and
         swing the arm off its pivot entirely. */
      .mg-forest-needle{ transition:none; }
      .mg-forest-flash-ok circle, .mg-forest-flash-bad circle{ pointer-events:none; }
      .mg-forest-stage.mg-forest-ok{ animation:mg-forest-pulse-ok .25s ease; }
      .mg-forest-stage.mg-forest-bad{ animation:mg-forest-pulse-bad .25s ease; }
      @keyframes mg-forest-pulse-ok{ 0%{ box-shadow: inset 0 0 0 0 rgba(123,228,149,0) } 30%{ box-shadow: inset 0 0 40px 6px rgba(123,228,149,.55) } 100%{ box-shadow: inset 0 0 0 0 rgba(123,228,149,0) } }
      @keyframes mg-forest-pulse-bad{ 0%{ box-shadow: inset 0 0 0 0 rgba(230,86,79,0) } 30%{ box-shadow: inset 0 0 40px 6px rgba(230,86,79,.55) } 100%{ box-shadow: inset 0 0 0 0 rgba(230,86,79,0) } }
      .mg-forest-toast{
        position:absolute; left:50%; top:66%; transform:translate(-50%,0); z-index:3; pointer-events:none;
        font-size:15px; font-weight:800; color:#eafff0; opacity:0; text-shadow:0 1px 3px rgba(0,0,0,.5);
      }
      .mg-forest-toast.mg-forest-show{ animation:mg-forest-toast-anim .7s ease forwards; }
      @keyframes mg-forest-toast-anim{
        0%{ opacity:0; transform:translate(-50%,10px) }
        20%{ opacity:1; transform:translate(-50%,0) }
        100%{ opacity:0; transform:translate(-50%,-18px) }
      }
      .mg-forest-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(10,30,18,.6); color:#fff; text-align:center;
        opacity:0; animation:mg-forest-fade-in .25s ease forwards;
      }
      .mg-forest-result .mg-big{font-size:30px; font-weight:800}
      .mg-forest-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-forest-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-forest-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  /* R is the arc's CENTRELINE radius, so the track band spans R±TRACK_W/2.
     The needle is exactly R long and pivots at (CX,CY), so its free end
     traces the arc itself -- the arm and the target share one radius and
     the tap lands on whatever segment the tip is over. */
  const CX = 110, CY = 120, R = 92, TRACK_W = 16;

  function pointAt(angleDeg, radius) {
    const rad = (angleDeg * Math.PI) / 180;
    return { x: CX - radius * Math.cos(rad), y: CY - radius * Math.sin(rad) };
  }
  function arcPath(startDeg, endDeg, radius) {
    const p1 = pointAt(startDeg, radius);
    const p2 = pointAt(endDeg, radius);
    return `M ${p1.x.toFixed(2)},${p1.y.toFixed(2)} A ${radius},${radius} 0 0,1 ${p2.x.toFixed(2)},${p2.y.toFixed(2)}`;
  }

  function gaugeSVG(greenHalfDeg, greenCenter) {
    const gStart = greenCenter - greenHalfDeg, gEnd = greenCenter + greenHalfDeg;
    return `
      <svg viewBox="0 0 220 132" width="100%" height="100%" preserveAspectRatio="none" style="overflow:visible">
        <path d="${arcPath(0, gStart, R)}" stroke="#e6564f" stroke-width="${TRACK_W}" fill="none" stroke-linecap="round"/>
        <path d="${arcPath(gEnd, 180, R)}" stroke="#e6564f" stroke-width="${TRACK_W}" fill="none" stroke-linecap="round"/>
        <path d="${arcPath(gStart, gEnd, R)}" stroke="#4cd471" stroke-width="${TRACK_W}" fill="none" stroke-linecap="round"/>
        <line class="mg-forest-needle" id="mg-forest-needle" x1="${CX}" y1="${CY}" x2="${CX}" y2="${CY - R}"
          stroke="#fff" stroke-width="4" stroke-linecap="round"/>
        <circle class="mg-forest-needle" id="mg-forest-tip" cx="${CX}" cy="${CY - R}" r="6.5"
          fill="#fff" stroke="rgba(0,0,0,.35)" stroke-width="1.5"/>
        <circle cx="${CX}" cy="${CY}" r="7" fill="#fff"/>
      </svg>`;
  }

  function rand(min, max) { return min + Math.random() * (max - min); }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-forest-stage";
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);

    const hud = document.createElement("div");
    hud.className = "mg-forest-hud";
    hud.innerHTML = `<span class="mg-pill mg-dice-pill" id="mg-forest-dice">${diceGridHTML(DICE_MIN)}</span>` +
      `<span class="mg-pill mg-timer-pill" id="mg-forest-timer">${Math.ceil(DURATION_MS / 1000)}s</span>` +
      `<span class="mg-pill mg-score-pill" id="mg-forest-count">\u{1F332} 0</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-forest-timebar";
    timebar.style.width = "100%";

    const stepsRow = document.createElement("div");
    stepsRow.className = "mg-forest-steps";
    stepsRow.innerHTML = STEPS.map((s, i) =>
      `<div class="mg-forest-step-dot${i === 0 ? " mg-forest-current" : ""}" data-step="${i}">${s.icon}</div>`
    ).join("");

    const gaugeWrap = document.createElement("div");
    gaugeWrap.className = "mg-forest-gauge-wrap";

    const bigIcon = document.createElement("div");
    bigIcon.className = "mg-forest-bigicon";
    bigIcon.textContent = STEPS[0].icon;

    const stepLabel = document.createElement("div");
    stepLabel.className = "mg-forest-steplabel";
    stepLabel.textContent = STEPS[0].label;

    const toast = document.createElement("div");
    toast.className = "mg-forest-toast";

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(stepsRow);
    stage.appendChild(bigIcon);
    stage.appendChild(stepLabel);
    stage.appendChild(gaugeWrap);
    stage.appendChild(toast);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-forest-count");
    const diceEl = hud.querySelector("#mg-forest-dice");
    const timerEl = hud.querySelector("#mg-forest-timer");
    const dotEls = () => Array.from(stepsRow.querySelectorAll(".mg-forest-step-dot"));

    let treesPlanted = 0;
    let stepIndex = 0;
    let running = true;
    let sweepMs = SWEEP_MS_START;
    let greenHalfDeg = GREEN_HALF_DEG_START;
    let greenCenter = 90; // target zone starts centered; re-rolled every tree planted (see onTap)
    let stepStart = Date.now();
    let sweepFromRight = Math.random() < 0.5;
    let needleEl = null, tipEl = null;

    function drawGauge() {
      gaugeWrap.innerHTML = gaugeSVG(greenHalfDeg, greenCenter);
      needleEl = gaugeWrap.querySelector("#mg-forest-needle");
      tipEl = gaugeWrap.querySelector("#mg-forest-tip");
    }
    drawGauge();

    /* Triangle wave 0->180->0, optionally mirrored so the arm starts its
       sweep from the right-hand end of the arc instead of the left. Re-rolled
       per step (see onTap), so a player can't just learn one fixed rhythm. */
    function currentAngle() {
      const elapsed = (Date.now() - stepStart) % sweepMs;
      const t = elapsed / sweepMs;
      const tri = t < 0.5 ? t * 2 : 2 - t * 2;
      const a = tri * 180;
      return sweepFromRight ? 180 - a : a;
    }

    function refreshDots() {
      dotEls().forEach((el, i) => {
        el.classList.toggle("mg-forest-done", i < stepIndex);
        el.classList.toggle("mg-forest-current", i === stepIndex);
      });
    }

    function showToast(text) {
      toast.textContent = text;
      toast.classList.remove("mg-forest-show");
      void toast.offsetWidth; // restart animation
      toast.classList.add("mg-forest-show");
    }

    function flash(ok) {
      stage.classList.remove("mg-forest-ok", "mg-forest-bad");
      void stage.offsetWidth;
      stage.classList.add(ok ? "mg-forest-ok" : "mg-forest-bad");
    }

    function onTap() {
      if (!running) return;
      const angle = currentAngle();
      const hitGreen = angle >= greenCenter - greenHalfDeg && angle <= greenCenter + greenHalfDeg;
      flash(hitGreen);
      if (!hitGreen) return;

      stepIndex++;
      if (stepIndex >= STEPS.length) {
        treesPlanted++;
        countEl.textContent = "\u{1F332} " + treesPlanted;
        diceEl.innerHTML = diceGridHTML(diceFor(treesPlanted / TARGET_TREES));
        showToast("\u{1F333} Tree planted!");
        stepIndex = 0;
        sweepMs = Math.max(SWEEP_MS_MIN, SWEEP_MS_START - treesPlanted * SWEEP_MS_STEP);
        greenHalfDeg = Math.max(GREEN_HALF_DEG_MIN, GREEN_HALF_DEG_START - treesPlanted * GREEN_HALF_DEG_STEP);
        // New target position along the arc every tree planted (every 3
        // successful taps), kept fully inside 0-180 with a small margin.
        greenCenter = rand(greenHalfDeg + 8, 180 - greenHalfDeg - 8);
        drawGauge();
      }
      bigIcon.textContent = STEPS[stepIndex].icon; // swap the instant the hit registers
      stepLabel.textContent = STEPS[stepIndex].label;
      refreshDots();
      stepStart = Date.now();
      sweepFromRight = Math.random() < 0.5;
    }
    stage.addEventListener("pointerdown", onTap);

    const start = Date.now();
    let rafId = null;
    function tick() {
      if (needleEl) {
        const angle = currentAngle();
        const rot = `rotate(${90 - angle} ${CX} ${CY})`;
        needleEl.setAttribute("transform", rot);
        if (tipEl) tipEl.setAttribute("transform", rot);
      }
      const elapsed = Date.now() - start;
      const left = Math.max(0, 1 - elapsed / DURATION_MS);
      timebar.style.width = (left * 100) + "%";
      timerEl.textContent = Math.max(0, Math.ceil((DURATION_MS - elapsed) / 1000)) + "s";
      if (elapsed >= DURATION_MS) { endRound(); return; }
      rafId = requestAnimationFrame(tick);
    }

    function endRound() {
      if (!running) return;
      running = false;
      stage.removeEventListener("pointerdown", onTap);
      if (rafId) cancelAnimationFrame(rafId);

      const score = Math.max(0, Math.min(1, treesPlanted / TARGET_TREES));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-forest-result";
      resultEl.innerHTML = `
        <div class="mg-big">\u{1F332} ${treesPlanted} tree${treesPlanted === 1 ? "" : "s"} planted</div>
        <div class="mg-sub">\u{1F3B2} ${diceFor(score)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
