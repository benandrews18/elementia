/* =========================================================================
   Observatory station mini-game: fly the rocket.
   -------------------------------------------------------------------------
   Hold to thrust up, release to fall -- a flappy-bird/helicopter-game
   flyer. Asteroids scroll in from the right at a fixed x; the rocket
   never moves horizontally, only up and down. Touching an asteroid OR
   the top/bottom edge ends the round immediately (faithful to the
   named genre, where the ceiling/floor are hazards too, not just the
   obstacles). Survive longer to score higher; a full-length clean run
   scores 1.0.

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
  const DURATION_MS = 32000;         // absolute round cap
  const TARGET_SURVIVE_MS = 20000;   // surviving this long => score 1.0
  const UP_ACCEL = -1600;            // px/s^2 while held (thrust)
  const DOWN_ACCEL = 950;            // px/s^2 while released (gravity)
  const MAX_VY = 520;                // px/s, terminal velocity either direction
  const ROCKET_SIZE = 34;            // px, square hit-box side
  const ROCKET_X = 56;               // px, fixed distance from the left edge
  const ROCK_SPAWN_MS_START = 1350;  // ms between asteroid spawns at t=0
  const ROCK_SPAWN_MS_MIN = 700;     // floor as difficulty ramps
  const ROCK_SPEED_START = 165;      // px/s at t=0
  const ROCK_SPEED_MAX = 330;        // px/s cap as difficulty ramps
  const ROCK_RAMP_MS = 18000;        // time to reach max spawn-rate/speed
  const ROCK_R_MIN = 15, ROCK_R_MAX = 29; // px, asteroid radius range
  const RESULT_HOLD_MS = 1300;       // how long the result card sits before onComplete

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-obs-style")) { styleInjected = true; return; }
    const css = `
      .mg-obs-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:
          radial-gradient(1.5px 1.5px at 15% 20%, rgba(255,255,255,.8), transparent),
          radial-gradient(1.5px 1.5px at 70% 15%, rgba(255,255,255,.6), transparent),
          radial-gradient(1px 1px at 40% 65%, rgba(255,255,255,.7), transparent),
          radial-gradient(1.5px 1.5px at 85% 45%, rgba(255,255,255,.5), transparent),
          radial-gradient(1px 1px at 25% 80%, rgba(255,255,255,.6), transparent),
          radial-gradient(1.5px 1.5px at 60% 85%, rgba(255,255,255,.5), transparent),
          linear-gradient(180deg,#0b0f2e 0%,#161b3d 55%,#1e1440 100%);
        touch-action:manipulation; user-select:none; font-family:inherit;
      }
      .mg-obs-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#eef1ff;
        text-shadow:0 1px 2px rgba(0,0,0,.5); font-size:15px; pointer-events:none;
      }
      .mg-obs-hud .mg-pill{
        background:rgba(255,255,255,.14); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
      }
      .mg-obs-timebar{position:absolute; top:0; left:0; height:4px; background:#7ea8ff; z-index:3;
        transition:width .1s linear}
      .mg-obs-rocket{
        position:absolute; font-size:${ROCKET_SIZE}px; line-height:1; z-index:2;
        will-change:transform; filter:drop-shadow(0 2px 4px rgba(0,0,0,.4));
      }
      .mg-obs-rock{
        position:absolute; border-radius:50%; z-index:1;
        background:radial-gradient(circle at 32% 30%, #9a9490, #5c574f 65%, #3c3833 100%);
        box-shadow:inset 0 0 0 1px rgba(0,0,0,.3);
      }
      .mg-obs-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(10,12,35,.6); color:#fff; text-align:center;
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

    const hud = document.createElement("div");
    hud.className = "mg-obs-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-obs-time">\u{1F680} 0s</span><span class="mg-pill">Hold to fly!</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-obs-timebar";
    timebar.style.width = "100%";

    const rocket = document.createElement("div");
    rocket.className = "mg-obs-rocket";
    rocket.textContent = "\u{1F680}";

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(rocket);
    container.appendChild(stage);

    const timeEl = hud.querySelector("#mg-obs-time");
    const stageW = stage.clientWidth || 320;
    const stageH = stage.clientHeight || 420;

    let running = true;
    let held = false;
    let vy = 0;
    let y = stageH / 2 - ROCKET_SIZE / 2;
    rocket.style.left = ROCKET_X + "px";
    rocket.style.top = y + "px";

    const rocks = [];
    let nextSpawnAt = 0;

    function spawnRock(elapsedSurvive) {
      const ramp = Math.min(1, elapsedSurvive / ROCK_RAMP_MS);
      const r = rand(ROCK_R_MIN, ROCK_R_MAX);
      const el = document.createElement("div");
      el.className = "mg-obs-rock";
      el.style.width = el.style.height = r * 2 + "px";
      const cy = rand(r + 4, stageH - r - 4);
      el.style.left = (stageW + r) + "px";
      el.style.top = (cy - r) + "px";
      stage.appendChild(el);
      rocks.push({ el, x: stageW + r, y: cy, r, speed: ROCK_SPEED_START + (ROCK_SPEED_MAX - ROCK_SPEED_START) * ramp });
      const spawnMs = ROCK_SPAWN_MS_START + (ROCK_SPAWN_MS_MIN - ROCK_SPAWN_MS_START) * ramp;
      nextSpawnAt = elapsedSurvive + spawnMs;
    }

    function onDown(e) { e.preventDefault(); held = true; }
    function onUp() { held = false; }
    stage.addEventListener("pointerdown", onDown);
    stage.addEventListener("pointerup", onUp);
    stage.addEventListener("pointercancel", onUp);
    stage.addEventListener("pointerleave", onUp);

    const roundStart = Date.now();
    let lastFrame = roundStart;
    let rafId = null;

    function tick() {
      const now = Date.now();
      const dt = Math.min(0.05, (now - lastFrame) / 1000); // clamp dt to avoid huge jumps on throttled frames
      lastFrame = now;
      const elapsed = now - roundStart;

      vy += (held ? UP_ACCEL : DOWN_ACCEL) * dt;
      vy = Math.max(-MAX_VY, Math.min(MAX_VY, vy));
      y += vy * dt;

      if (y <= 0 || y + ROCKET_SIZE >= stageH) {
        y = Math.max(0, Math.min(stageH - ROCKET_SIZE, y));
        rocket.style.top = y + "px";
        crash(elapsed);
        return;
      }
      rocket.style.top = y + "px";
      const tilt = Math.max(-25, Math.min(40, vy / 12));
      rocket.style.transform = `rotate(${tilt}deg)`;

      if (elapsed >= nextSpawnAt) spawnRock(elapsed);

      const rocketCx = ROCKET_X + ROCKET_SIZE / 2, rocketCy = y + ROCKET_SIZE / 2;
      const rocketR = ROCKET_SIZE * 0.34;
      for (let i = rocks.length - 1; i >= 0; i--) {
        const rock = rocks[i];
        rock.x -= rock.speed * dt;
        rock.el.style.left = (rock.x - rock.r) + "px";
        if (rock.x < -rock.r - 4) {
          rock.el.remove();
          rocks.splice(i, 1);
          continue;
        }
        const dx = rock.x - rocketCx, dy = rock.y - rocketCy;
        if (Math.sqrt(dx * dx + dy * dy) < rock.r + rocketR) {
          crash(elapsed);
          return;
        }
      }

      timeEl.textContent = "\u{1F680} " + Math.floor(elapsed / 1000) + "s";
      const left = Math.max(0, 1 - elapsed / DURATION_MS);
      timebar.style.width = (left * 100) + "%";

      if (elapsed >= DURATION_MS) { finish(elapsed); return; }
      rafId = requestAnimationFrame(tick);
    }

    function cleanup() {
      running = false;
      stage.removeEventListener("pointerdown", onDown);
      stage.removeEventListener("pointerup", onUp);
      stage.removeEventListener("pointercancel", onUp);
      stage.removeEventListener("pointerleave", onUp);
      if (rafId) cancelAnimationFrame(rafId);
    }

    function showResult(survivedMs, crashed) {
      const score = Math.max(0, Math.min(1, survivedMs / TARGET_SURVIVE_MS));
      const secs = (survivedMs / 1000).toFixed(1);
      const resultEl = document.createElement("div");
      resultEl.className = "mg-obs-result";
      resultEl.innerHTML = `
        <div class="mg-big">${crashed ? "\u{1F4A5}" : "\u{1F680}"} ${secs}s survived</div>
        <div class="mg-sub">${Math.round(score * 100)}% -- ${crashed ? "watch those rocks!" : "nice flying!"}</div>`;
      stage.appendChild(resultEl);
      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    function crash(elapsed) {
      if (!running) return;
      cleanup();
      showResult(elapsed, true);
    }
    function finish(elapsed) {
      if (!running) return;
      cleanup();
      showResult(elapsed, false);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
