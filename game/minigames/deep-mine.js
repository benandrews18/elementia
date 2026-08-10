/* =========================================================================
   Deep Mine station mini-game: break the rocks.
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

   The rock is a 24-frame sprite strip (deep-mine-rock.webp, built from
   images/'Deep Mine gif.png'). Frames 1-6 are the rock cracking further
   open with each tap; frames 7-24 are the shatter/explosion/dust-settle
   that plays once the last tap lands, after which a fresh rock appears.
   ========================================================================= */
(function (global) {
  "use strict";

  /* ---- tunables -------------------------------------------------------- */
  const DURATION_MS = 15000;        // total round length (standardized across all 8 games)
  const TARGET_ROCKS = 6;           // breaking this many => score 1.0
  const HITS_START = 2;             // taps needed for rock #1
  const HITS_STEP = 1;              // extra taps needed per subsequent rock
  const HITS_MAX = 12;              // taps-needed ceiling
  const DECAY_PER_SEC = 0;          // progress lost per second of no tapping
  const SHATTER_MS = 560;           // full frames 7-24 explosion before the next rock
  const RESULT_HOLD_MS = 1300;
  const GEMS_PER_ROCK = 5;          // diamonds that burst out of each broken rock
  const GEM_BURST_MS = 260;         // outward scatter before they home to the tray
  const GEM_FLY_MS = 460;           // scatter point -> corner tray
  const DICE_MIN = 3;               // dice awarded at score 0
  const DICE_MAX = 6;               // dice awarded at score 1
  const BACKDROP = "deep-mine";     // backdrops/<BACKDROP>.webp

  /* Sprite strip geometry: 24 frames laid out left-to-right in one row. */
  const SPRITE = "deep-mine-rock.webp";
  const FRAMES = 24;
  const BREAK_FRAMES = 6;           // frames 1-6: the rock cracking apart
  // frames 7-24 (indices 6..23) are the explosion; derived, not tunable.
  const BOOM_FIRST = BREAK_FRAMES, BOOM_LAST = FRAMES - 1;

  /* Both bases are overridable so one file works from game/minigames/
     (sandbox + tuning lab) and from the built single-file game, where the
     assets sit alongside the HTML instead. */
  function backdropURL() {
    const f = BACKDROP + ".webp";
    return (global.MINIGAME_ASSETS && global.MINIGAME_ASSETS[f]) ||
           ((global.MINIGAME_BACKDROP_BASE || "../backdrops/") + f);
  }
  function spriteURL() {
    return (global.MINIGAME_ASSETS && global.MINIGAME_ASSETS[SPRITE]) ||
           ((global.MINIGAME_ASSET_BASE || "./") + SPRITE);
  }
  /* Dice this run has earned so far -- shown live in the HUD so effort in
     the mini-game visibly feeds the roll it pays out into. */
  function diceFor(score) {
    return Math.round(DICE_MIN + (DICE_MAX - DICE_MIN) * Math.max(0, Math.min(1, score)));
  }

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-mine-style")) { styleInjected = true; return; }
    const css = `
      .mg-mine-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,rgba(58,50,41,.72) 0%,rgba(36,31,25,.66) 55%,rgba(20,17,13,.76) 100%),
          var(--mg-backdrop, none);
        background-size:cover, cover; background-position:center, center;
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
      /* Dice earned shown as that many die-face emojis in a row, not a
         number -- 3x the surrounding HUD text size (em is relative to the
         parent's own font-size). */
      .mg-dice-pill{ font-size:3em; padding:1px 8px; line-height:1; }
      .mg-mine-timebar{position:absolute; top:0; left:0; height:4px; background:#e0a23d; z-index:3;
        transition:width .1s linear}
      /* Finer-grained than the 6 sprite frames can show -- with up to 12
         taps per rock the bar is what tells you a tap actually landed. */
      .mg-mine-crackbar-wrap{
        position:absolute; left:16px; right:16px; top:42px; z-index:3; height:8px; border-radius:5px;
        background:rgba(255,255,255,.12); overflow:hidden;
      }
      .mg-mine-crackbar{ height:100%; width:0%; background:linear-gradient(90deg,#e0a23d,#f4c860);
        transition:width .08s linear; }
      /* Full-screen now -- fills the whole stage rather than sitting as a
         small centered panel, so the rock art itself is the backdrop.
         .mg-mine-stage's own border-radius/overflow:hidden still clips the
         corners, same as every other station's full-bleed background. */
      .mg-mine-rockwrap{
        position:absolute; inset:0;
        background-image:var(--mg-sprite, none);
        background-repeat:no-repeat;
        background-size:${FRAMES * 100}% 100%;
        background-position-x:0%;
      }
      /* Diamond tray: where the gems from every broken rock pile up. */
      .mg-mine-tray{
        position:absolute; right:12px; bottom:12px; z-index:4; display:flex; align-items:center; gap:6px;
        padding:6px 12px; border-radius:999px; background:rgba(255,255,255,.14);
        backdrop-filter:blur(2px); color:#eaf6ff; font-weight:800; font-size:15px; pointer-events:none;
        text-shadow:0 1px 2px rgba(0,0,0,.5);
      }
      .mg-mine-tray.mg-mine-tray-pop{ animation:mg-mine-tray-anim .28s ease; }
      @keyframes mg-mine-tray-anim{ 0%{transform:scale(1)} 45%{transform:scale(1.18)} 100%{transform:scale(1)} }
      .mg-mine-gem{
        position:absolute; z-index:5; font-size:20px; line-height:1; pointer-events:none;
        will-change:transform, opacity;
      }
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
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);

    const hud = document.createElement("div");
    hud.className = "mg-mine-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-mine-count">⛏️ 0</span>` +
      `<span class="mg-pill mg-dice-pill" id="mg-mine-dice">${"\u{1F3B2}".repeat(DICE_MIN)}</span>`;

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
    rockWrap.style.setProperty("--mg-sprite", `url('${spriteURL()}')`);

    const tray = document.createElement("div");
    tray.className = "mg-mine-tray";
    tray.innerHTML = `\u{1F48E} <span id="mg-mine-gems">0</span>`;

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(crackbarWrap);
    stage.appendChild(rockWrap);
    stage.appendChild(tray);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-mine-count");
    const diceEl = hud.querySelector("#mg-mine-dice");
    const gemsEl = tray.querySelector("#mg-mine-gems");

    let running = true;
    let broken = 0;
    let gems = 0;
    let hitsNeeded = HITS_START;
    let progress = 0;
    let shattering = false;

    /* Frame i of a 24-wide strip sits at i/(24-1) of the background's own
       travel, since background-size is 2400% and position is a percentage
       of (image width - box width). */
    function showFrame(i) {
      rockWrap.style.backgroundPositionX = (i / (FRAMES - 1)) * 100 + "%";
    }
    showFrame(0);

    function updateCrackbar() {
      const frac = Math.max(0, Math.min(1, progress / hitsNeeded));
      crackbar.style.width = (frac * 100) + "%";
      // Frames 1-6 only while the rock is still intact; the explosion
      // frames are played by playShatter(), never by tap progress.
      if (!shattering) showFrame(Math.min(BREAK_FRAMES - 1, Math.floor(frac * BREAK_FRAMES)));
    }

    /* Diamonds burst from the rock, scatter, then home into the corner
       tray -- the running total there is this station's read on "how much
       have I actually earned so far". */
    function burstGems() {
      const stageRect = stage.getBoundingClientRect();
      const rockRect = rockWrap.getBoundingClientRect();
      const ox = rockRect.left - stageRect.left + rockRect.width / 2;
      const oy = rockRect.top - stageRect.top + rockRect.height / 2;
      const trayRect = tray.getBoundingClientRect();
      const tx = trayRect.left - stageRect.left + trayRect.width / 2;
      const ty = trayRect.top - stageRect.top + trayRect.height / 2;

      for (let i = 0; i < GEMS_PER_ROCK; i++) {
        const gem = document.createElement("div");
        gem.className = "mg-mine-gem";
        gem.textContent = "\u{1F48E}";
        gem.style.left = ox + "px";
        gem.style.top = oy + "px";
        stage.appendChild(gem);

        const sx = rand(-70, 70), sy = rand(-80, -20);
        const delay = i * 45;
        const anim = gem.animate(
          [
            { transform: "translate(-50%,-50%) scale(.4)", opacity: 0, offset: 0 },
            { transform: `translate(calc(-50% + ${sx}px), calc(-50% + ${sy}px)) scale(1.1)`, opacity: 1,
              offset: GEM_BURST_MS / (GEM_BURST_MS + GEM_FLY_MS) },
            { transform: `translate(calc(-50% + ${tx - ox}px), calc(-50% + ${ty - oy}px)) scale(.45)`, opacity: .9,
              offset: 1 },
          ],
          { duration: GEM_BURST_MS + GEM_FLY_MS, delay: delay, easing: "cubic-bezier(.35,.7,.4,1)", fill: "forwards" }
        );
        anim.onfinish = () => {
          gem.remove();
          if (!running) return;
          gems++;
          gemsEl.textContent = gems;
          tray.classList.remove("mg-mine-tray-pop");
          void tray.offsetWidth;
          tray.classList.add("mg-mine-tray-pop");
        };
      }
    }

    /* Frames 7-24, evenly spread across SHATTER_MS, then a fresh rock. */
    let shatterRaf = null;
    function playShatter() {
      const boomStart = Date.now();
      const span = BOOM_LAST - BOOM_FIRST;
      function step() {
        if (!running) return;
        const t = Math.min(1, (Date.now() - boomStart) / SHATTER_MS);
        showFrame(BOOM_FIRST + Math.round(t * span));
        if (t < 1) { shatterRaf = requestAnimationFrame(step); return; }
        newRock();
      }
      shatterRaf = requestAnimationFrame(step);
    }

    function newRock() {
      shattering = false;
      progress = 0;
      updateCrackbar();
      showFrame(0);
    }

    function onTap() {
      if (!running || shattering) return;
      progress = Math.min(hitsNeeded, progress + 1);
      updateCrackbar();

      if (progress >= hitsNeeded) {
        shattering = true;
        broken++;
        countEl.textContent = "⛏️ " + broken;
        diceEl.textContent = "\u{1F3B2}".repeat(diceFor(broken / TARGET_ROCKS));
        hitsNeeded = Math.min(HITS_MAX, HITS_START + broken * HITS_STEP);
        burstGems();
        playShatter();
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

      if (DECAY_PER_SEC > 0 && !shattering && progress > 0) {
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
      if (shatterRaf) cancelAnimationFrame(shatterRaf);

      const score = Math.max(0, Math.min(1, broken / TARGET_ROCKS));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-mine-result";
      resultEl.innerHTML = `
        <div class="mg-big">⛏️ ${broken} rock${broken === 1 ? "" : "s"} broken</div>
        <div class="mg-sub">\u{1F3B2} ${diceFor(score)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    updateCrackbar();
    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
