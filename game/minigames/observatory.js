/* =========================================================================
   Observatory station mini-game: fly the rocket.
   -------------------------------------------------------------------------
   The rocket climbs UP the screen from the bottom; the world scrolls down
   past it. Tap and hold the LEFT or RIGHT half of the stage to thrust that
   way -- there's no up/down control and no gravity pulling to one side, so
   the whole game is steering between asteroids falling toward you. Let go
   and the rocket coasts back to a stop (DRIFT_DECEL). Sense of speed comes
   from the parallax star layers and the planets/galaxies drifting past at
   different rates behind the asteroids.

   The side edges are soft: the rocket can fly almost entirely off either
   one and still steer back in. Only an asteroid ends the round.

   Same public interface as every station mini-game (see ocean-bubbles.js
   for the fuller contract note):

       runMinigame(container, onComplete)
         container   - DOM element to render into, cleared/owned for the run.
         onComplete  - called once with a score in 0..1 when the round ends.

   No external assets beyond the shared station backdrop.
   ========================================================================= */
(function (global) {
  "use strict";

  /* ---- tunables -------------------------------------------------------- */
  const DURATION_MS = 30000;         // absolute round cap (Bakery/Power Plant/Observatory get 30s, the rest 15s)
  const TARGET_SURVIVE_MS = 30000;   // surviving this long => score 1.0 (== DURATION_MS: a full
                                      // clean run should actually be able to hit max score)
  const THRUST_ACCEL = 800;          // px/s^2 sideways while a side is held
  const DRIFT_DECEL = 300;           // px/s^2 bleeding speed off when released
  const MAX_VX = 1190;               // px/s, terminal sideways speed
  const ROCKET_SIZE = 66;            // px, square hit-box side
  const ROCKET_BOTTOM = 192;         // px, fixed distance from the stage floor (lifted 100px per user request)
  const OOB_SLACK = 0.8;             // fraction of the rocket allowed off-edge
  const ROCK_SPAWN_MS_START = 1250;  // ms between asteroid spawns at t=0
  const ROCK_SPAWN_MS_MIN = 700;     // floor as difficulty ramps
  const ROCK_SPEED_START = 300;      // px/s at t=0
  const ROCK_SPEED_MAX = 310;        // px/s cap as difficulty ramps
  const ROCK_RAMP_MS = 2000;         // time to reach max spawn-rate/speed
  const ROCK_R_MIN = 40;             // px, smallest asteroid radius
  const ROCK_R_MAX = 70;             // px, largest asteroid radius
  const BODY_SPAWN_MS = 2600;        // ms between background planets/galaxies
  const RESULT_HOLD_MS = 1300;       // how long the result card sits before onComplete
  const DICE_MIN = 3;                // dice awarded at score 0
  const DICE_MAX = 6;                // dice awarded at score 1
  const TIMER_SHOW_MS = 10000;       // timer pill stays hidden until this much time remains
  const BACKDROP = "observatory";    // backdrops/<BACKDROP>.webp

  // Purely decorative scenery, drifting slower than the asteroids so the
  // depth reads correctly.
  const BODIES = ["\u{1FA90}", "\u{1F30C}", "\u{1F311}", "\u{2604}️", "\u{1F320}"];

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
    if (styleInjected || document.getElementById("mg-obs-style")) { styleInjected = true; return; }
    const css = `
      .mg-obs-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,rgba(11,15,46,.82) 0%,rgba(22,27,61,.78) 55%,rgba(30,20,64,.85) 100%),
          var(--mg-backdrop, none);
        background-size:cover, cover; background-position:center, center;
        touch-action:none; user-select:none; font-family:inherit;
      }
      /* Three star layers scrolling down at different rates -- the cheapest
         honest cue that the rocket is actually moving, and the thing that
         makes the asteroids' own speed legible by comparison. */
      .mg-obs-stars{
        position:absolute; inset:-100% 0 0 0; height:200%; z-index:0; pointer-events:none;
        background-repeat:repeat;
      }
      .mg-obs-stars.s1{
        background-image:
          radial-gradient(1px 1px at 15% 8%, rgba(255,255,255,.55), transparent),
          radial-gradient(1px 1px at 68% 22%, rgba(255,255,255,.45), transparent),
          radial-gradient(1px 1px at 38% 41%, rgba(255,255,255,.5), transparent),
          radial-gradient(1px 1px at 86% 63%, rgba(255,255,255,.4), transparent);
        background-size:100% 220px; animation:mg-obs-scroll 9s linear infinite;
      }
      .mg-obs-stars.s2{
        background-image:
          radial-gradient(1.6px 1.6px at 27% 14%, rgba(255,255,255,.8), transparent),
          radial-gradient(1.6px 1.6px at 74% 52%, rgba(255,255,255,.7), transparent),
          radial-gradient(1.4px 1.4px at 48% 77%, rgba(255,255,255,.65), transparent);
        background-size:100% 300px; animation:mg-obs-scroll 5s linear infinite;
      }
      .mg-obs-stars.s3{
        background-image:
          radial-gradient(2.4px 2.4px at 55% 30%, rgba(200,225,255,.95), transparent),
          radial-gradient(2.2px 2.2px at 12% 70%, rgba(255,240,220,.9), transparent);
        background-size:100% 420px; animation:mg-obs-scroll 2.6s linear infinite;
      }
      @keyframes mg-obs-scroll{ from{transform:translateY(0)} to{transform:translateY(50%)} }
      .mg-obs-body{
        position:absolute; z-index:1; pointer-events:none; line-height:1;
        will-change:transform; filter:drop-shadow(0 0 10px rgba(120,160,255,.35));
      }
      .mg-obs-hud{
        position:absolute; top:0; left:0; right:0; z-index:4; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#eef1ff;
        text-shadow:0 1px 2px rgba(0,0,0,.5); font-size:15px; pointer-events:none;
      }
      .mg-obs-hud .mg-pill{
        background:rgba(255,255,255,.14); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
        white-space:nowrap;
      }
      .mg-obs-hud .mg-dice-pill{
        display:grid; grid-template-columns:repeat(3,1fr); gap:0 4px; padding:3px 10px;
        font-size:1.5em; line-height:1.1;
      }
      .mg-obs-hud .mg-timer-pill{ font-variant-numeric:tabular-nums; }
      .mg-obs-timebar{position:absolute; top:0; left:0; height:4px; background:#7ea8ff; z-index:4;
        transition:width .1s linear}
      /* Faint tap zones so it's discoverable that the halves steer. */
      .mg-obs-zone{
        position:absolute; top:0; bottom:0; width:50%; z-index:2; pointer-events:none;
        opacity:0; transition:opacity .12s ease;
      }
      .mg-obs-zone.l{ left:0; background:linear-gradient(90deg, rgba(126,168,255,.22), transparent); }
      .mg-obs-zone.r{ right:0; background:linear-gradient(270deg, rgba(126,168,255,.22), transparent); }
      .mg-obs-zone.on{ opacity:1; }
      .mg-obs-rocket{
        position:absolute; line-height:1; z-index:3;
        will-change:transform; filter:drop-shadow(0 2px 6px rgba(0,0,0,.5));
      }
      .mg-obs-rock{
        position:absolute; border-radius:50%; z-index:3;
        background:radial-gradient(circle at 34% 30%, #9a917f 0%, #6d6558 52%, #443f36 100%);
        box-shadow:inset 0 0 12px rgba(0,0,0,.45), 0 2px 8px rgba(0,0,0,.4);
        will-change:transform;
      }
      .mg-obs-flash{ animation:mg-obs-hit .3s ease; }
      @keyframes mg-obs-hit{
        0%{ box-shadow: inset 0 0 0 0 rgba(230,86,79,0) } 30%{ box-shadow: inset 0 0 60px 10px rgba(230,86,79,.6) }
        100%{ box-shadow: inset 0 0 0 0 rgba(230,86,79,0) }
      }
      .mg-obs-result{
        position:absolute; inset:0; z-index:6; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(8,10,26,.62); color:#fff; text-align:center;
        opacity:0; animation:mg-obs-fade-in .25s ease forwards;
      }
      .mg-obs-result .mg-big{font-size:30px; font-weight:800}
      .mg-obs-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-obs-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-obs-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function rand(min, max) { return min + Math.random() * (max - min); }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-obs-stage";
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);
    ["s1", "s2", "s3"].forEach(cls => {
      const layer = document.createElement("div");
      layer.className = "mg-obs-stars " + cls;
      stage.appendChild(layer);
    });

    const zoneL = document.createElement("div"); zoneL.className = "mg-obs-zone l";
    const zoneR = document.createElement("div"); zoneR.className = "mg-obs-zone r";

    const hud = document.createElement("div");
    hud.className = "mg-obs-hud";
    hud.innerHTML = `<span class="mg-pill mg-dice-pill" id="mg-obs-dice">${diceGridHTML(DICE_MIN)}</span>` +
      `<span class="mg-pill mg-timer-pill" id="mg-obs-timer" style="display:none"></span>` +
      `<span class="mg-pill mg-score-pill" id="mg-obs-time">\u{1F52D} 0.0s</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-obs-timebar";
    timebar.style.width = "100%";

    const rocket = document.createElement("div");
    rocket.className = "mg-obs-rocket";
    rocket.textContent = "\u{1F680}";
    // Set directly on the element, not baked into the shared injected
    // <style> block (see injectStyle()) -- that block is only ever
    // written once per page and then reused on every later run, so a
    // font-size embedded in it would silently keep showing whatever
    // ROCKET_SIZE was in effect on the FIRST run, no matter what a
    // retuned value (e.g. in the tuning lab) later changes it to.
    rocket.style.fontSize = ROCKET_SIZE + "px";

    stage.appendChild(zoneL);
    stage.appendChild(zoneR);
    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(rocket);
    container.appendChild(stage);

    const timeEl = hud.querySelector("#mg-obs-time");
    const diceEl = hud.querySelector("#mg-obs-dice");
    const timerEl = hud.querySelector("#mg-obs-timer");
    const stageW = stage.clientWidth || 320;
    const stageH = stage.clientHeight || 420;

    const rocketY = stageH - ROCKET_BOTTOM;
    // Soft side limits: most of the rocket may leave the frame before it's
    // stopped, so drifting wide is recoverable rather than fatal.
    const minX = -ROCKET_SIZE * OOB_SLACK;
    const maxX = stageW - ROCKET_SIZE * (1 - OOB_SLACK);

    let running = true;
    let x = stageW / 2 - ROCKET_SIZE / 2;
    let vx = 0;
    let holding = 0;               // -1 left, +1 right, 0 released
    const rocks = [];
    const bodies = [];
    let nextRockAt = 600;
    let nextBodyAt = 300;

    function drawRocket() {
      // 🚀 is drawn pointing up-and-right, so -45deg squares its nose with
      // the direction of travel; the bank is only a lean, never a turn.
      const bank = (vx / MAX_VX) * 20;
      rocket.style.transform = `translate(${x}px, ${rocketY}px) rotate(${-45 + bank}deg)`;
    }
    drawRocket();

    function setHold(e) {
      const rect = stage.getBoundingClientRect();
      holding = (e.clientX - rect.left) < rect.width / 2 ? -1 : 1;
      zoneL.classList.toggle("on", holding === -1);
      zoneR.classList.toggle("on", holding === 1);
    }
    function clearHold() {
      holding = 0;
      zoneL.classList.remove("on");
      zoneR.classList.remove("on");
    }
    stage.addEventListener("pointerdown", e => { e.preventDefault(); setHold(e); });
    stage.addEventListener("pointermove", e => { if (holding) setHold(e); });
    stage.addEventListener("pointerup", clearHold);
    stage.addEventListener("pointercancel", clearHold);
    stage.addEventListener("pointerleave", clearHold);

    function spawnRock(ramp) {
      const r = rand(ROCK_R_MIN, ROCK_R_MAX);
      const el = document.createElement("div");
      el.className = "mg-obs-rock";
      el.style.width = el.style.height = (r * 2) + "px";
      stage.appendChild(el);
      const rock = {
        el, r,
        x: rand(-r * 0.3, stageW - r * 1.7),
        y: -r * 2,
        speed: ROCK_SPEED_START + (ROCK_SPEED_MAX - ROCK_SPEED_START) * ramp,
      };
      el.style.transform = `translate(${rock.x}px, ${rock.y}px)`;
      rocks.push(rock);
    }

    function spawnBody() {
      const el = document.createElement("div");
      el.className = "mg-obs-body";
      el.textContent = BODIES[(Math.random() * BODIES.length) | 0];
      const size = rand(18, 54);
      el.style.fontSize = size + "px";
      el.style.opacity = String(rand(0.25, 0.6));
      stage.appendChild(el);
      const body = { el, x: rand(-10, stageW - size), y: -size * 1.5, speed: rand(28, 80) };
      el.style.transform = `translate(${body.x}px, ${body.y}px)`;
      bodies.push(body);
    }

    function hits(rock) {
      // Circle vs the rocket's square hit-box, treated as a circle of the
      // same width -- close enough at these sizes and forgiving at corners.
      const rcx = x + ROCKET_SIZE / 2, rcy = rocketY + ROCKET_SIZE / 2;
      const cx = rock.x + rock.r, cy = rock.y + rock.r;
      const dx = rcx - cx, dy = rcy - cy;
      const reach = rock.r + ROCKET_SIZE * 0.42;
      return dx * dx + dy * dy < reach * reach;
    }

    const start = Date.now();
    let lastFrame = start;
    let rafId = null;

    function tick() {
      const now = Date.now();
      const dt = Math.min(0.05, (now - lastFrame) / 1000);
      lastFrame = now;
      const elapsed = now - start;
      const ramp = Math.min(1, elapsed / ROCK_RAMP_MS);

      if (holding) {
        vx += holding * THRUST_ACCEL * dt;
      } else if (vx !== 0) {
        // Coast to a stop rather than drifting forever -- this is what the
        // old vertical build spent "gravity" on.
        const drop = DRIFT_DECEL * dt;
        vx = Math.abs(vx) <= drop ? 0 : vx - Math.sign(vx) * drop;
      }
      vx = Math.max(-MAX_VX, Math.min(MAX_VX, vx));
      x += vx * dt;
      if (x < minX) { x = minX; vx = 0; }
      if (x > maxX) { x = maxX; vx = 0; }
      drawRocket();

      if (elapsed >= nextRockAt) {
        spawnRock(ramp);
        nextRockAt = elapsed + (ROCK_SPAWN_MS_START + (ROCK_SPAWN_MS_MIN - ROCK_SPAWN_MS_START) * ramp);
      }
      if (elapsed >= nextBodyAt) { spawnBody(); nextBodyAt = elapsed + BODY_SPAWN_MS; }

      for (let i = bodies.length - 1; i >= 0; i--) {
        const b = bodies[i];
        b.y += b.speed * dt;
        b.el.style.transform = `translate(${b.x}px, ${b.y}px)`;
        if (b.y > stageH + 80) { b.el.remove(); bodies.splice(i, 1); }
      }

      for (let i = rocks.length - 1; i >= 0; i--) {
        const rock = rocks[i];
        rock.y += rock.speed * dt;
        rock.el.style.transform = `translate(${rock.x}px, ${rock.y}px)`;
        if (hits(rock)) { endRound(elapsed, true); return; }
        if (rock.y > stageH + rock.r * 2) { rock.el.remove(); rocks.splice(i, 1); }
      }

      timeEl.textContent = "\u{1F52D} " + (elapsed / 1000).toFixed(1) + "s";
      diceEl.innerHTML = diceGridHTML(diceFor(elapsed / TARGET_SURVIVE_MS));
      const remainMs = DURATION_MS - elapsed;
      if (remainMs <= TIMER_SHOW_MS) {
        timerEl.style.display = "";
        timerEl.textContent = Math.max(0, Math.ceil(remainMs / 1000)) + "s";
      }
      timebar.style.width = Math.max(0, 1 - elapsed / DURATION_MS) * 100 + "%";
      if (elapsed >= DURATION_MS) { endRound(elapsed, false); return; }
      rafId = requestAnimationFrame(tick);
    }

    function endRound(elapsed, crashed) {
      if (!running) return;
      running = false;
      clearHold();
      if (rafId) cancelAnimationFrame(rafId);

      if (crashed) {
        stage.classList.remove("mg-obs-flash");
        void stage.offsetWidth;
        stage.classList.add("mg-obs-flash");
      }

      const score = Math.max(0, Math.min(1, elapsed / TARGET_SURVIVE_MS));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-obs-result";
      resultEl.innerHTML = `
        <div class="mg-big">\u{1F680} ${(elapsed / 1000).toFixed(1)}s ${crashed ? "before impact" : "clear"}</div>
        <div class="mg-sub">\u{1F3B2} ${diceFor(score)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
