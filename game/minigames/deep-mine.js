/* =========================================================================
   Deep Mine station mini-game: break the rocks.
   -------------------------------------------------------------------------
   Tap rapidly anywhere on the stage to crack the rock in the middle.
   Each tap chips a bit of progress; progress slowly decays if you stop
   tapping, so a slow steady rhythm won't cut it -- it has to be a real
   rapid mash. Crack lines reveal as progress builds, then the rock
   shatters and a tougher one appears. Break as many as you can before
   time runs out.

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
  const DURATION_MS = 26000;        // total round length
  const TARGET_ROCKS = 6;           // breaking this many => score 1.0
  const HITS_START = 8;             // taps needed for rock #1
  const HITS_STEP = 2;              // extra taps needed per subsequent rock
  const HITS_MAX = 18;              // taps-needed ceiling
  const DECAY_PER_SEC = 2.6;        // progress lost per second of no tapping
  const SHATTER_MS = 420;           // shatter animation before the next rock
  const RESULT_HOLD_MS = 1300;

  const CRACK_COUNT = 6;
  // Each crack line as [x1,y1,x2,y2] in a 0..100 box, roughly radiating
  // out from an off-center point so the reveal doesn't look too uniform.
  const CRACK_LINES = [
    [50, 46, 30, 20], [50, 46, 70, 14], [50, 46, 18, 55],
    [50, 46, 82, 50], [50, 46, 38, 86], [50, 46, 66, 82],
  ];

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-mine-style")) { styleInjected = true; return; }
    const css = `
      .mg-mine-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:radial-gradient(ellipse at 50% 30%, #3a3229 0%, #241f19 55%, #14110d 100%);
        touch-action:manipulation; user-select:none; font-family:inherit;
      }
      .mg-mine-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#f3ead9;
        text-shadow:0 1px 2px rgba(0,0,0,.5); font-size:15px; pointer-events:none;
      }
      .mg-mine-hud .mg-pill{
        background:rgba(255,255,255,.13); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
      }
      .mg-mine-timebar{position:absolute; top:0; left:0; height:4px; background:#e0a23d; z-index:3;
        transition:width .1s linear}
      .mg-mine-crackbar-wrap{
        position:absolute; left:16px; right:16px; top:42px; z-index:3; height:8px; border-radius:5px;
        background:rgba(255,255,255,.12); overflow:hidden;
      }
      .mg-mine-crackbar{ height:100%; width:0%; background:linear-gradient(90deg,#e0a23d,#f4c860);
        transition:width .08s linear; }
      .mg-mine-rockwrap{
        position:absolute; left:50%; top:56%; transform:translate(-50%,-50%); width:62%; max-width:230px;
        aspect-ratio:1/1;
      }
      .mg-mine-rock{
        width:100%; height:100%;
        clip-path:polygon(50% 2%, 78% 10%, 96% 34%, 92% 66%, 70% 94%, 34% 96%, 8% 72%, 4% 40%, 22% 12%);
        background:radial-gradient(circle at 35% 28%, #9c8a6c 0%, #6b5c48 45%, #453a2c 100%);
        box-shadow:0 10px 24px rgba(0,0,0,.45), inset 0 0 24px rgba(0,0,0,.35);
        position:relative;
      }
      .mg-mine-fleck{ position:absolute; border-radius:50%; opacity:.85; }
      .mg-mine-crack-svg{ position:absolute; inset:0; width:100%; height:100%; pointer-events:none; }
      .mg-mine-crack-line{ opacity:0; transition:opacity .15s ease; }
      .mg-mine-crack-line.mg-mine-crack-on{ opacity:.9; }
      .mg-mine-rockwrap.mg-mine-punch{ animation:mg-mine-punch-anim .1s ease; }
      @keyframes mg-mine-punch-anim{ 0%{transform:translate(-50%,-50%) scale(1)} 50%{transform:translate(-50%,-50%) scale(.94) rotate(-1.5deg)} 100%{transform:translate(-50%,-50%) scale(1)} }
      .mg-mine-rockwrap.mg-mine-shatter{ animation:mg-mine-shatter-anim ${SHATTER_MS}ms ease-in forwards; }
      @keyframes mg-mine-shatter-anim{
        0%{ transform:translate(-50%,-50%) scale(1); opacity:1 }
        100%{ transform:translate(-50%,-50%) scale(1.5) rotate(12deg); opacity:0 }
      }
      .mg-mine-chip{ position:absolute; border-radius:2px; pointer-events:none; z-index:5; }
      .mg-mine-chip.mg-mine-chip-fly{ transition:transform .4s ease-out, opacity .4s ease-out; }
      .mg-mine-result{
        position:absolute; inset:0; z-index:6; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(15,12,8,.6); color:#fff; text-align:center;
        opacity:0; animation:mg-mine-fade-in .25s ease forwards;
      }
      .mg-mine-result .mg-big{font-size:30px; font-weight:800}
      .mg-mine-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-mine-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-mine-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function rand(min, max) { return min + Math.random() * (max - min); }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-mine-stage";

    const hud = document.createElement("div");
    hud.className = "mg-mine-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-mine-count">⛏️ 0</span><span class="mg-pill">Tap fast!</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-mine-timebar";
    timebar.style.width = "100%";

    const crackbarWrap = document.createElement("div");
    crackbarWrap.className = "mg-mine-crackbar-wrap";
    const crackbar = document.createElement("div");
    crackbar.className = "mg-mine-crackbar";
    crackbarWrap.appendChild(crackbar);

    const rockWrap = document.createElement("div");
    rockWrap.className = "mg-mine-rockwrap";
    const rock = document.createElement("div");
    rock.className = "mg-mine-rock";
    rockWrap.appendChild(rock);

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(crackbarWrap);
    stage.appendChild(rockWrap);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-mine-count");

    // decorative ore flecks, purely visual
    [
      { x: 30, y: 32, s: 7, c: "#f4c860" }, { x: 66, y: 24, s: 5, c: "#8fd0f2" },
      { x: 60, y: 62, s: 6, c: "#f4c860" }, { x: 32, y: 70, s: 4, c: "#8fd0f2" },
    ].forEach(f => {
      const el = document.createElement("div");
      el.className = "mg-mine-fleck";
      el.style.left = f.x + "%"; el.style.top = f.y + "%";
      el.style.width = f.s + "px"; el.style.height = f.s + "px";
      el.style.background = f.c;
      rock.appendChild(el);
    });

    // crack lines, SVG so they read cleanly at any rock size
    const svgNS = "http://www.w3.org/2000/svg";
    const crackSvg = document.createElementNS(svgNS, "svg");
    crackSvg.setAttribute("viewBox", "0 0 100 100");
    crackSvg.setAttribute("class", "mg-mine-crack-svg");
    const crackEls = CRACK_LINES.map(([x1, y1, x2, y2]) => {
      const line = document.createElementNS(svgNS, "line");
      line.setAttribute("x1", x1); line.setAttribute("y1", y1);
      line.setAttribute("x2", x2); line.setAttribute("y2", y2);
      line.setAttribute("stroke", "#1a1610");
      line.setAttribute("stroke-width", "2.2");
      line.setAttribute("stroke-linecap", "round");
      line.setAttribute("class", "mg-mine-crack-line");
      crackSvg.appendChild(line);
      return line;
    });
    rock.appendChild(crackSvg);

    let running = true;
    let broken = 0;
    let hitsNeeded = HITS_START;
    let progress = 0;
    let shattering = false;

    function updateCrackbar() {
      const frac = Math.max(0, Math.min(1, progress / hitsNeeded));
      crackbar.style.width = (frac * 100) + "%";
      const onCount = Math.floor(frac * CRACK_COUNT);
      crackEls.forEach((el, i) => el.classList.toggle("mg-mine-crack-on", i < onCount));
    }

    function spawnChip(cx, cy) {
      const chip = document.createElement("div");
      chip.className = "mg-mine-chip";
      const size = rand(4, 8);
      chip.style.width = size + "px";
      chip.style.height = size + "px";
      chip.style.left = cx + "px";
      chip.style.top = cy + "px";
      chip.style.background = "#c9b48a";
      stage.appendChild(chip);
      const dx = rand(-40, 40), dy = rand(-50, -10);
      requestAnimationFrame(() => {
        chip.classList.add("mg-mine-chip-fly");
        chip.style.transform = `translate(${dx}px, ${dy}px)`;
        chip.style.opacity = "0";
      });
      setTimeout(() => chip.remove(), 450);
    }

    function newRock() {
      shattering = false;
      progress = 0;
      rockWrap.classList.remove("mg-mine-shatter");
      crackEls.forEach(el => el.classList.remove("mg-mine-crack-on"));
      updateCrackbar();
    }

    function onTap(e) {
      if (!running || shattering) return;
      progress = Math.min(hitsNeeded, progress + 1);
      updateCrackbar();
      rockWrap.classList.remove("mg-mine-punch");
      void rockWrap.offsetWidth;
      rockWrap.classList.add("mg-mine-punch");

      const rect = stage.getBoundingClientRect();
      const cx = (e.clientX != null ? e.clientX - rect.left : rect.width / 2);
      const cy = (e.clientY != null ? e.clientY - rect.top : rect.height / 2);
      spawnChip(cx, cy);

      if (progress >= hitsNeeded) {
        shattering = true;
        broken++;
        countEl.textContent = "⛏️ " + broken;
        rockWrap.classList.add("mg-mine-shatter");
        hitsNeeded = Math.min(HITS_MAX, HITS_START + broken * HITS_STEP);
        setTimeout(() => { if (running) newRock(); }, SHATTER_MS);
      }
    }
    stage.addEventListener("pointerdown", onTap);

    const start = Date.now();
    let lastFrame = start;
    let rafId = null;

    function tick() {
      const now = Date.now();
      const dt = Math.min(0.05, (now - lastFrame) / 1000);
      lastFrame = now;

      if (!shattering && progress > 0) {
        progress = Math.max(0, progress - DECAY_PER_SEC * dt);
        updateCrackbar();
      }

      const elapsed = now - start;
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

      const score = Math.max(0, Math.min(1, broken / TARGET_ROCKS));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-mine-result";
      resultEl.innerHTML = `
        <div class="mg-big">⛏️ ${broken} rock${broken === 1 ? "" : "s"} broken</div>
        <div class="mg-sub">${Math.round(score * 100)}% -- nice mining!</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    updateCrackbar();
    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
