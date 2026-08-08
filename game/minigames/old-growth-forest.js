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
  const DURATION_MS = 24000;        // total round length
  const TARGET_TREES = 4;           // planting this many => score 1.0
  const SWEEP_MS_START = 1500;      // full left-right-left cycle, tree #1
  const SWEEP_MS_MIN = 950;         // cycle time floor as difficulty ramps
  const SWEEP_MS_STEP = 130;        // cycle time lost per tree planted
  const GREEN_HALF_DEG_START = 20;  // green zone half-width in degrees, tree #1
  const GREEN_HALF_DEG_MIN = 11;    // half-width floor as difficulty ramps
  const GREEN_HALF_DEG_STEP = 2;    // half-width lost per tree planted
  const RESULT_HOLD_MS = 1300;      // how long the "time's up" card sits before onComplete

  const STEPS = [
    { key: "dig", icon: "\u{1FA8F}", label: "Dig the hole" },
    { key: "plant", icon: "\u{1F331}", label: "Plant the tree" },
    { key: "water", icon: "\u{1F4A7}", label: "Water it" },
  ];

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-forest-style")) { styleInjected = true; return; }
    const css = `
      .mg-forest-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,#1f3d24 0%,#173420 55%,#0f2417 100%);
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
        position:absolute; left:50%; top:52%; transform:translate(-50%,-50%); width:78%; max-width:320px;
      }
      .mg-forest-needle{ transform-origin:110px 120px; transition:none; }
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

  function gaugeSVG(greenHalfDeg) {
    const gStart = 90 - greenHalfDeg, gEnd = 90 + greenHalfDeg;
    return `
      <svg viewBox="0 0 220 132" width="100%" height="100%" style="overflow:visible">
        <path d="${arcPath(0, gStart, R)}" stroke="#e6564f" stroke-width="${TRACK_W}" fill="none" stroke-linecap="round"/>
        <path d="${arcPath(gEnd, 180, R)}" stroke="#e6564f" stroke-width="${TRACK_W}" fill="none" stroke-linecap="round"/>
        <path d="${arcPath(gStart, gEnd, R)}" stroke="#4cd471" stroke-width="${TRACK_W}" fill="none" stroke-linecap="round"/>
        <line class="mg-forest-needle" id="mg-forest-needle" x1="${CX}" y1="${CY}" x2="${CX}" y2="${CY - (R - 6)}"
          stroke="#fff" stroke-width="4" stroke-linecap="round"/>
        <circle cx="${CX}" cy="${CY}" r="7" fill="#fff"/>
      </svg>`;
  }

  function rand(min, max) { return min + Math.random() * (max - min); }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-forest-stage";

    const hud = document.createElement("div");
    hud.className = "mg-forest-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-forest-count">\u{1F332} 0</span><span class="mg-pill" id="mg-forest-task">${STEPS[0].icon} ${STEPS[0].label}</span>`;

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

    const toast = document.createElement("div");
    toast.className = "mg-forest-toast";

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(stepsRow);
    stage.appendChild(gaugeWrap);
    stage.appendChild(toast);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-forest-count");
    const taskEl = hud.querySelector("#mg-forest-task");
    const dotEls = () => Array.from(stepsRow.querySelectorAll(".mg-forest-step-dot"));

    let treesPlanted = 0;
    let stepIndex = 0;
    let running = true;
    let sweepMs = SWEEP_MS_START;
    let greenHalfDeg = GREEN_HALF_DEG_START;
    let stepStart = Date.now();
    let needleEl = null;

    function drawGauge() {
      gaugeWrap.innerHTML = gaugeSVG(greenHalfDeg);
      needleEl = gaugeWrap.querySelector("#mg-forest-needle");
    }
    drawGauge();

    function currentAngle() {
      const elapsed = (Date.now() - stepStart) % sweepMs;
      const t = elapsed / sweepMs;
      const tri = t < 0.5 ? t * 2 : 2 - t * 2;
      return tri * 180;
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
      const hitGreen = angle >= 90 - greenHalfDeg && angle <= 90 + greenHalfDeg;
      flash(hitGreen);
      if (!hitGreen) return;

      stepIndex++;
      if (stepIndex >= STEPS.length) {
        treesPlanted++;
        countEl.textContent = "\u{1F332} " + treesPlanted;
        showToast("\u{1F333} Tree planted!");
        stepIndex = 0;
        sweepMs = Math.max(SWEEP_MS_MIN, SWEEP_MS_START - treesPlanted * SWEEP_MS_STEP);
        greenHalfDeg = Math.max(GREEN_HALF_DEG_MIN, GREEN_HALF_DEG_START - treesPlanted * GREEN_HALF_DEG_STEP);
        drawGauge();
      }
      taskEl.innerHTML = `${STEPS[stepIndex].icon} ${STEPS[stepIndex].label}`;
      refreshDots();
      stepStart = Date.now();
    }
    stage.addEventListener("pointerdown", onTap);

    const start = Date.now();
    let rafId = null;
    function tick() {
      if (needleEl) {
        const angle = currentAngle();
        needleEl.setAttribute("transform", `rotate(${90 - angle} ${CX} ${CY})`);
      }
      const elapsed = Date.now() - start;
      const left = Math.max(0, 1 - elapsed / DURATION_MS);
      timebar.style.width = (left * 100) + "%";
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
        <div class="mg-sub">${Math.round(score * 100)}% -- nice work!</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
