/* =========================================================================
   Ocean station mini-game: pop the bubbles.
   -------------------------------------------------------------------------
   Public interface (the shape every station mini-game should share, so
   dropping a new one into elementia.html later is a copy-paste, not a
   redesign):

       runMinigame(container, onComplete)
         container   - a DOM element to render into. Cleared and owned for
                        the duration of the run; left empty when it ends.
         onComplete  - called once with (score, meta) when the round is
                        over. score is a single number, 0..1 -- the caller
                        decides what that becomes (e.g. bonus dice =
                        round(score * MAX_BONUS)). meta is
                        {raw, label} -- the same result in the game's own
                        terms (e.g. {raw:17, label:"bubbles popped"}), for
                        anything that wants to show or log the real number
                        instead of the normalized score (see the Arcade's
                        own high-score tracking in elementia.html). A
                        caller that only reads the first argument (the
                        real game's own launchMinigame(), which just wants
                        a dice count) needs no changes at all.

   Everything else here is private. No external assets, no dependencies --
   this has to survive being pasted into a single portable HTML file later,
   same as the rest of the game.
   ========================================================================= */
(function (global) {
  "use strict";

  /* ---- tunables --------------------------------------------------------
     These are the knobs to turn while play-testing. Nothing else in this
     file should need to change to retune difficulty/feel. */
  const DURATION_MS = 10000;      // total round length (standardized across all 8 games, minus 5s)
  const SPAWN_MIN_MS = 260;       // gap between bubble spawns -- fewer bubbles
  const SPAWN_MAX_MS = 950;       // on screen at once than before, easier to track/tap
  const SIZE_MIN_PX = 80;         // bubble diameter range
  const SIZE_MAX_PX = 110;
  // Rise time is INVERSE speed: the floor is the FASTEST bubble. 1700ms
  // against the 6000ms slowest is roughly a 3.5x spread, so a round mixes
  // lazy drifters with ones that streak past in well under two seconds.
  const RISE_MIN_MS = 1700;       // time for a bubble to float bottom to top
  const RISE_MAX_MS = 6000;
  const TARGET_POPS = 17;         // popping this many => score 1.0 (fewer bubbles spawn now)
  const RESULT_HOLD_MS = 1200;    // how long the "time's up" card sits before onComplete
  // Spawn placement: this many candidate x positions are tried per bubble
  // and the one furthest from the bubbles still low on screen wins, so a
  // fast spawn rate spreads across the width instead of stacking a column.
  const SPREAD_CANDIDATES = 7;
  const SPREAD_RECENT_MS = 900;   // a bubble only "blocks" a slot this long
  const DICE_MIN = 3;             // dice awarded at score 0
  const DICE_MAX = 6;             // dice awarded at score 1
  const TIMER_SHOW_MS = 10000;    // timer pill stays hidden until this much time remains
  const BACKDROP = "ocean";       // backdrops/<BACKDROP>.webp

  /* Station art behind the stage. The base is overridable so one file works
     both from game/minigames/ (sandbox + tuning lab) and from the built
     single-file game, where backdrops/ sits alongside the HTML instead. */
  function backdropURL() {
    const f = BACKDROP + ".webp";
    return (global.MINIGAME_ASSETS && global.MINIGAME_ASSETS[f]) ||
           ((global.MINIGAME_BACKDROP_BASE || "../backdrops/") + f);
  }
  /* Dice this run has earned so far. Shown live in the HUD so effort in the
     mini-game visibly feeds the roll it pays out into, rather than the
     connection only landing at the end. */
  function diceFor(score) {
    return Math.round(DICE_MIN + (DICE_MAX - DICE_MIN) * Math.max(0, Math.min(1, score)));
  }
  /* 2-row-of-3 dice grid (see .mg-dice-pill), half the old single-line size. */
  function diceGridHTML(n) {
    return "<span class=\"mg-die\">\u{1F3B2}</span>".repeat(n);
  }

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-ocean-style")) { styleInjected = true; return; }
    const css = `
      .mg-ocean-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,rgba(191,228,251,.62) 0%,rgba(143,208,242,.55) 55%,rgba(87,179,224,.6) 100%),
          var(--mg-backdrop, none);
        background-size:cover, cover; background-position:center, center;
        touch-action:manipulation; user-select:none; font-family:inherit;
      }
      .mg-ocean-hud{
        position:absolute; top:0; left:0; right:0; z-index:3; display:flex; justify-content:space-between;
        align-items:center; padding:10px 14px; font-weight:800; color:#0b3a55;
        text-shadow:0 1px 0 rgba(255,255,255,.5); font-size:15px; pointer-events:none;
      }
      .mg-ocean-hud .mg-pill{
        background:rgba(255,255,255,.55); border-radius:999px; padding:4px 12px; backdrop-filter:blur(2px);
        white-space:nowrap;
      }
      .mg-ocean-hud .mg-dice-pill{
        display:grid; grid-template-columns:repeat(3,1fr); gap:0 4px; padding:3px 10px;
        font-size:1.5em; line-height:1.1;
      }
      .mg-ocean-hud .mg-timer-pill{ font-variant-numeric:tabular-nums; }
      .mg-ocean-timebar{position:absolute; top:0; left:0; height:4px; background:#ff8a3d; z-index:3;
        transition:width .1s linear}
      .mg-bubble{
        position:absolute; bottom:-10%; border-radius:50%; cursor:pointer;
        background:radial-gradient(circle at 30% 26%, rgba(255,255,255,.95), rgba(255,255,255,.18) 42%,
          rgba(140,215,255,.35) 70%, rgba(70,170,225,.55) 100%);
        border:2.5px solid rgba(8,40,60,.65);
        box-shadow:0 0 10px rgba(255,255,255,.25) inset, 0 2px 6px rgba(10,60,90,.25);
        will-change:transform, opacity;
        box-sizing:border-box;
        /* border-radius only rounds the PAINT -- the actual hit-test area
           stays the full square box unless clipped. Bubbles are appended
           to the DOM in spawn order, so a newer bubble (often still low
           on screen) sits on top in stacking order; without this, its
           invisible square CORNERS -- well outside its visible circle --
           could silently steal a tap aimed at a completely different,
           older bubble overlapping that corner, which read as "the wrong
           bubble popped" with no visual explanation why. clip-path makes
           the hit-test region match the visible circle exactly. */
        clip-path:circle(50%);
        -webkit-clip-path:circle(50%);
      }
      /* --pop-origin (set in pop(), right before this class is added) is
         the translate() commitStyles() just froze into the bubble's own
         inline transform -- referenced here, NOT re-derived, because a
         CSS animation's keyframes don't COMPOSE with whatever transform
         was already on the element, they REPLACE it outright. Without
         the variable, these keyframes' own "transform:scale(...)" would
         overwrite the frozen translate() the instant the pop animation
         starts, snapping the bubble back to translate(0,0) -- its literal
         spawn point at the bottom of the stage -- a split second before
         visibly popping there. Multiplying the scale onto --pop-origin
         instead keeps the pop anchored exactly where the tap landed. */
      .mg-bubble.mg-pop{animation:mg-pop-anim .22s ease-out forwards}
      @keyframes mg-pop-anim{
        0%{transform:var(--pop-origin, translate(0,0)) scale(1); opacity:1}
        100%{transform:var(--pop-origin, translate(0,0)) scale(1.5); opacity:0}
      }
      .mg-ocean-result{
        position:absolute; inset:0; z-index:4; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(8,40,60,.55); color:#fff; text-align:center;
        opacity:0; animation:mg-fade-in .25s ease forwards;
      }
      .mg-ocean-result .mg-big{font-size:30px; font-weight:800}
      .mg-ocean-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-fade-in{ to{opacity:1} }
      /* A faded scatter of whatever the player has already crafted at this
         station, sitting behind the actual game -- see craftedBgHTML().
         z-index 0 (the HUD/game elements all sit above it, most at 3+) and
         appended before anything else in the stage either way, so it reads
         as a textural backdrop, not something competing for attention. */
      .mg-crafted-bg{position:absolute; inset:0; z-index:0; overflow:hidden; pointer-events:none}
      .mg-crafted-bg span{position:absolute; font-size:34px; line-height:1; opacity:.16; filter:grayscale(.2)}
    `;
    const style = document.createElement("style");
    style.id = "mg-ocean-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function rand(min, max) { return min + Math.random() * (max - min); }

  /* 8 scattered spots (x%, y%, rotation deg), shared across every minigame
     file for one consistent "textural background" language -- see
     global.MINIGAME_CRAFTED_ITEMS (set by launchMinigame() in
     elementia.html right before this file's own runMinigame() is called).
     Cycles through the crafted list if there are more spots than items;
     renders nothing at all if the player hasn't crafted anything here yet. */
  const CRAFTED_BG_SPOTS = [
    [10,16,-14],[86,12,12],[14,42,10],[88,40,-10],
    [10,70,8],[90,68,-16],[50,18,-6],[50,90,14],
  ];
  function craftedBgHTML() {
    const items = global.MINIGAME_CRAFTED_ITEMS;
    if (!items || !items.length) return "";
    return `<div class="mg-crafted-bg">${CRAFTED_BG_SPOTS.map((spot, i) => {
      const [x, y, rot] = spot;
      return `<span style="left:${x}%;top:${y}%;transform:translate(-50%,-50%) rotate(${rot}deg)">${items[i % items.length]}</span>`;
    }).join("")}</div>`;
  }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-ocean-stage";
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);
    stage.insertAdjacentHTML("beforeend", craftedBgHTML());
    const hud = document.createElement("div");
    hud.className = "mg-ocean-hud";
    hud.innerHTML = `<span class="mg-pill mg-dice-pill" id="mg-dice">${diceGridHTML(DICE_MIN)}</span>` +
      `<span class="mg-pill mg-timer-pill" id="mg-ocean-timer" style="display:none"></span>` +
      `<span class="mg-pill mg-score-pill" id="mg-pop-count">\u{1F30A} 0</span>`;
    const timebar = document.createElement("div");
    timebar.className = "mg-ocean-timebar";
    timebar.style.width = "100%";
    stage.appendChild(hud);
    stage.appendChild(timebar);
    container.appendChild(stage);

    const popCountEl = hud.querySelector("#mg-pop-count");
    const diceEl = hud.querySelector("#mg-dice");
    const timerEl = hud.querySelector("#mg-ocean-timer");
    let popped = 0;
    let spawnTimer = null;
    let running = true;
    const liveBubbles = new Set();

    /* Centre-to-centre horizontal gap to the nearest bubble that's still
       near the bottom of its rise -- older ones have climbed clear of the
       spawn line and shouldn't keep a slot reserved. Bigger is better. */
    function clearanceAt(centre, now) {
      let worst = Infinity;
      liveBubbles.forEach(other => {
        if (now - other.__t > SPREAD_RECENT_MS) return;
        worst = Math.min(worst, Math.abs(centre - other.__centre));
      });
      return worst;
    }

    function spawnBubble() {
      if (!running) return;
      const size = rand(SIZE_MIN_PX, SIZE_MAX_PX);
      const stageW = stage.clientWidth || 320;
      const maxLeft = Math.max(4, stageW - size - 4);
      const now = Date.now();

      // Best-of-N placement rather than a flat random x: at these spawn
      // rates a plain random would routinely stack bubbles on top of each
      // other, which both looks wrong and makes them impossible to pick
      // out individually.
      let left = rand(4, maxLeft), best = -1;
      for (let i = 0; i < SPREAD_CANDIDATES; i++) {
        const cand = rand(4, maxLeft);
        const score = clearanceAt(cand + size / 2, now);
        if (score > best) { best = score; left = cand; }
      }

      const riseMs = rand(RISE_MIN_MS, RISE_MAX_MS);
      const drift = rand(-18, 18); // px of horizontal wobble over the rise

      const b = document.createElement("div");
      b.className = "mg-bubble";
      b.style.width = size + "px";
      b.style.height = size + "px";
      b.style.left = left + "px";
      b.__centre = left + size / 2;
      b.__t = now;
      // Poppable immediately on spawn -- no arm delay. An earlier version
      // held pointer-events:none until a bubble cleared the bottom safety
      // zone (to stop it "popping itself" when a finger landed nearby for
      // a DIFFERENT bubble), but that showed as a visible dashed-outline
      // pause before every bubble turned tappable, which read as
      // unresponsive rather than deliberate.
      b.style.touchAction = "none";
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
        // commitStyles() BEFORE cancel() -- canceling a WAAPI animation on
        // its own snaps the element straight back to its pre-animation
        // transform (here, translate(0,0) -- literally its spawn point at
        // the bottom of the stage), an instant before the .mg-pop scale/
        // fade keyframes take over. That read as a SECOND bubble popping
        // at the bottom every time, when it was actually the same one
        // jumping there first. commitStyles() bakes the animation's
        // CURRENT mid-flight transform into the element's own inline
        // style, so canceling the (now-redundant) animation afterward is
        // a no-op visually -- the pop plays exactly where the bubble
        // already was.
        try { anim.commitStyles(); } catch (err) { /* not connected/no effect -- fall through to cancel() alone */ }
        anim.cancel();
        // Hand that frozen translate() to the .mg-pop keyframes via a
        // custom property (see its own comment) -- committing it to
        // b.style.transform alone isn't enough, since the keyframes'
        // own "transform:scale(...)" would still clobber it outright the
        // instant the animation class is added below.
        b.style.setProperty("--pop-origin", b.style.transform || "translate(0px,0px)");
        popped++;
        popCountEl.textContent = "\u{1F30A} " + popped;
        diceEl.innerHTML = diceGridHTML(diceFor(popped / TARGET_POPS));
        b.classList.add("mg-pop");
        setTimeout(() => b.remove(), 250);
      };
      // pointerUP, not pointerdown -- popping on first contact means a tap
      // that lands on a bubble mid-scroll/mid-drag pops it before intent is
      // even clear, which read as bubbles popping themselves unprompted.
      // Capturing the pointer on down is what makes that reliable rather
      // than flaky: without it, the up event fires on whatever element the
      // finger is physically over when it lifts, and any tiny drift between
      // down and up (extremely common with fast/imprecise mobile taps)
      // lands the up on a neighboring bubble or empty water instead of this
      // one -- reading as the game just not responding to a tap that
      // visually landed dead-center. Capture pins the up event to THIS
      // bubble regardless of where the finger ends up, and since capture is
      // per pointerId, simultaneous multi-finger tapping across several
      // bubbles works independently with no cross-talk.
      b.addEventListener("pointerdown", e => {
        try { b.setPointerCapture(e.pointerId); } catch (err) { /* unsupported -- fall back to normal hit-testing */ }
      });
      b.addEventListener("pointerup", pop);

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
      clearTimeout(spawnTimer);
      if (rafId) cancelAnimationFrame(rafId);
      liveBubbles.forEach(b => b.remove());
      liveBubbles.clear();

      const score = Math.max(0, Math.min(1, popped / TARGET_POPS));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-ocean-result";
      resultEl.innerHTML = `
        <div class="mg-big">🫧 ${popped} popped</div>
        <div class="mg-sub">🎲 ${diceFor(score)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score, {raw: popped, label: "bubbles popped"}), RESULT_HOLD_MS);
    }

    scheduleSpawn();
    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
