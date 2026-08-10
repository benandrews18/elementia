/* =========================================================================
   Bakery station mini-game: fill the order.
   -------------------------------------------------------------------------
   An order card shows a base flavor, a frosting flavor, and a fruit
   topping. Tap one option from each of the three rows to build that
   cake on the plate, then hit Send to push it down the conveyor belt.
   Match the card and it counts; whether it matched or not, a new order
   comes in and the plate resets. Fill as many correct orders as you
   can before time runs out.

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
  const DURATION_MS = 15000;      // total round length (standardized across all 8 games)
  const TARGET_CAKES = 3;         // matching this many orders => score 1.0
  const SEND_ANIM_MS = 950;       // conveyor slide-away duration (fully off-screen)
  const RESULT_HOLD_MS = 1300;
  const ORDER_QUEUE = 3;          // order cards shown: the live one + look-ahead
  const DICE_MIN = 3;             // dice awarded at score 0
  const DICE_MAX = 6;             // dice awarded at score 1
  const BACKDROP = "bakery";      // backdrops/<BACKDROP>.webp

  // Darker/more saturated than the original pastel set -- close pairs like
  // vanilla-vs-white or straw-vs-pink used to sit within a few percent
  // lightness of each other; this pass pushes every swatch further from
  // its neighbors so a glance (not a careful look) tells them apart.
  const BASES = [
    { key: "choc", label: "Chocolate", color: "#4a2a16" },
    { key: "vanilla", label: "Vanilla", color: "#e8b94f" },
    { key: "straw", label: "Strawberry", color: "#d43d5c" },
  ];
  const FROSTINGS = [
    { key: "white", label: "White", color: "#fdfaf3" },
    { key: "choc", label: "Chocolate", color: "#2e1a0d" },
    { key: "pink", label: "Pink", color: "#ff4fa0" },
  ];
  const FRUITS = [
    { key: "cherry", emoji: "\u{1F352}" },
    { key: "strawberry", emoji: "\u{1F353}" },
    { key: "blueberry", emoji: "\u{1FAD0}" },
    { key: "banana", emoji: "\u{1F34C}" },
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

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-bakery-style")) { styleInjected = true; return; }
    const css = `
      .mg-bakery-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,rgba(58,36,24,.76) 0%,rgba(43,26,16,.7) 60%,rgba(30,18,10,.8) 100%),
          var(--mg-backdrop, none);
        background-size:cover, cover; background-position:center, center;
        touch-action:manipulation; user-select:none; font-family:inherit;
        display:flex; flex-direction:column;
      }
      .mg-bakery-hud{
        display:flex; justify-content:space-between; align-items:center; padding:20px 28px 0;
        font-weight:800; color:#fbead9; text-shadow:0 2px 4px rgba(0,0,0,.5); font-size:28px;
      }
      .mg-bakery-hud .mg-pill{ background:rgba(255,255,255,.13); border-radius:999px; padding:8px 24px; }
      /* Dice earned shown as that many die-face emojis in a row, not a
         number -- 3x the surrounding HUD text size (em is relative to the
         parent's own font-size, so this scales correctly whatever that
         happens to be per game). */
      .mg-dice-pill{ font-size:3em; padding:2px 14px; line-height:1; }
      .mg-bakery-timebar{ height:8px; background:#e0a23d; margin:16px 0 0; transition:width .1s linear; width:100%; }
      /* Orders are square cards showing the FINISHED cake, not a row of
         swatches -- the player is matching a picture, so the brief should
         look like the thing they're building. The live order is the first
         card; the rest are look-ahead. */
      .mg-bakery-orders{
        margin:20px 28px 0; display:flex; gap:16px; align-items:stretch;
      }
      .mg-bakery-ordercard{
        flex:1; aspect-ratio:1/1; border-radius:24px; position:relative;
        background:rgba(255,255,255,.10); border:4px solid rgba(255,255,255,.16);
        display:flex; align-items:center; justify-content:center; overflow:hidden;
      }
      .mg-bakery-ordercard.mg-bakery-live{
        background:rgba(255,255,255,.17); border-color:#e0a23d;
        box-shadow:0 0 0 4px rgba(224,162,61,.35);
      }
      .mg-bakery-ordercard:not(.mg-bakery-live){ opacity:.55; }
      .mg-bakery-ordercard .mg-bakery-cake{ transform:scale(.62); }
      .mg-bakery-ordertag{
        position:absolute; top:8px; left:12px; font-size:18px; font-weight:800; letter-spacing:.4px;
        color:#f0d9b8; text-transform:uppercase; opacity:.85;
      }
      .mg-bakery-platezone{
        flex:1; display:flex; align-items:center; justify-content:center; position:relative; min-height:140px;
      }
      /* The conveyor belt as a pale line running behind the plate/cake,
         not a separate striped bar of its own -- appended before the
         plate (see runMinigame()) so it paints underneath it. */
      .mg-bakery-belt{
        position:absolute; left:0; right:0; top:50%; height:3px; transform:translateY(-50%);
        background:rgba(0,0,0,.35); z-index:0;
      }
      .mg-bakery-plate{
        width:192px; height:192px; border-radius:50%; background:radial-gradient(circle,#efe6d8 0%,#d8cbb4 100%);
        display:flex; align-items:center; justify-content:center; box-shadow:0 8px 20px rgba(0,0,0,.4);
        position:relative; z-index:1;
      }
      .mg-bakery-cake{ position:relative; width:128px; height:112px; }
      .mg-bakery-layer-base{
        position:absolute; left:0; right:0; bottom:0; height:64px; border-radius:16px 16px 8px 8px;
        box-shadow:inset 0 0 0 2px rgba(0,0,0,.15);
      }
      .mg-bakery-layer-frosting{
        position:absolute; left:4px; right:4px; bottom:52px; height:32px; border-radius:16px 16px 6px 6px;
        box-shadow:inset 0 0 0 2px rgba(0,0,0,.12);
      }
      .mg-bakery-layer-fruit{
        position:absolute; left:50%; bottom:76px; transform:translateX(-50%); font-size:40px;
      }
      /* Order-card cakes are shown at .62 scale (see .mg-bakery-ordercard
         .mg-bakery-cake above), which would otherwise shrink the fruit
         along with everything else -- bump the source font-size so the
         fruit renders twice as large as usual once that scale is applied. */
      .mg-bakery-ordercard .mg-bakery-layer-fruit{ font-size:80px; }
      /* Straight horizontal travel, no rotation or fade -- it's a conveyor
         carrying the cake out of the kitchen, so it simply leaves the frame.
         --fly is the full stage width plus a margin, set per cake in JS. */
      .mg-bakery-cake.mg-bakery-flying{
        position:absolute; left:50%; top:50%; margin-left:-64px; margin-top:-56px;
        transition:transform ${SEND_ANIM_MS}ms linear; z-index:5;
      }
      .mg-bakery-cake.mg-bakery-flying.mg-bakery-go{ transform:translateX(var(--fly,120vw)); }
      .mg-bakery-rows{ padding:16px 28px 20px; display:flex; flex-direction:column; gap:12px; }
      .mg-bakery-row{ display:flex; gap:12px; align-items:center; }
      .mg-bakery-row-label{ width:52px; font-size:22px; font-weight:800; color:#c9ac86; text-align:center; }
      .mg-bakery-opt{
        flex:1; height:68px; border-radius:18px; border:5px solid rgba(0,0,0,.6); cursor:pointer;
        display:flex; align-items:center; justify-content:center; font-size:36px;
        position:relative; overflow:hidden; background:rgba(255,255,255,.06);
      }
      .mg-bakery-opt.mg-bakery-selected{ border-color:#fff; box-shadow:0 0 0 4px rgba(255,255,255,.35) inset; }
      /* Base and icing swatches: the silhouette of a soft-serve swirl (the
         same reference shape as \u{1F4A9}, just the swirl-cone body -- no
         face) built from four tapering stacked blobs, filled in the
         topping's own color. Same shape language for both rows now,
         instead of a cylinder for base and a wider dollop-cluster for
         icing, so "this is a topping" reads consistently either way. */
      .mg-bakery-opt[data-category="base"], .mg-bakery-opt[data-category="frosting"]{
        background:
          radial-gradient(circle at 50% 12%, var(--swatch) 0 15%, transparent 16%),
          radial-gradient(circle at 45% 30%, var(--swatch) 0 23%, transparent 24%),
          radial-gradient(circle at 55% 50%, var(--swatch) 0 31%, transparent 32%),
          radial-gradient(circle at 50% 76%, var(--swatch) 0 42%, transparent 43%),
          rgba(255,255,255,.06);
      }
      .mg-bakery-sendwrap{ padding:0 28px 28px; }
      .mg-bakery-send{
        width:100%; padding:24px; border-radius:24px; border:none; font-weight:800; font-size:30px;
        background:#4c9a3f; color:#fff; cursor:pointer;
      }
      .mg-bakery-send:disabled{ background:#4a4038; color:#8a7f70; cursor:not-allowed; }
      .mg-bakery-stage.mg-bakery-ok .mg-bakery-belt{ box-shadow:0 0 24px 4px rgba(95,207,106,.55); }
      .mg-bakery-stage.mg-bakery-bad .mg-bakery-belt{ box-shadow:0 0 24px 4px rgba(230,86,79,.55); }
      .mg-bakery-result{
        position:absolute; inset:0; z-index:6; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:12px; background:rgba(20,12,6,.62); color:#fff; text-align:center;
        opacity:0; animation:mg-bakery-fade-in .25s ease forwards;
      }
      .mg-bakery-result .mg-big{font-size:60px; font-weight:800}
      .mg-bakery-result .mg-sub{font-size:28px; font-weight:700; opacity:.9}
      @keyframes mg-bakery-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-bakery-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

  function cakeInnerHTML(baseColor, frostingColor, fruitEmoji) {
    return `
      <div class="mg-bakery-layer-base" style="background:${baseColor}"></div>
      <div class="mg-bakery-layer-frosting" style="background:${frostingColor}"></div>
      <div class="mg-bakery-layer-fruit">${fruitEmoji}</div>`;
  }

  function runMinigame(container, onComplete) {
    injectStyle();
    container.innerHTML = "";

    const stage = document.createElement("div");
    stage.className = "mg-bakery-stage";
    stage.style.setProperty("--mg-backdrop", `url('${backdropURL()}')`);

    const hud = document.createElement("div");
    hud.className = "mg-bakery-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-bakery-count">\u{1F382} 0</span>` +
      `<span class="mg-pill mg-dice-pill" id="mg-bakery-dice">${"\u{1F3B2}".repeat(DICE_MIN)}</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-bakery-timebar";

    const orderRow = document.createElement("div");
    orderRow.className = "mg-bakery-orders";

    const plateZone = document.createElement("div");
    plateZone.className = "mg-bakery-platezone";
    const plate = document.createElement("div");
    plate.className = "mg-bakery-plate";
    const cake = document.createElement("div");
    cake.className = "mg-bakery-cake";
    plate.appendChild(cake);
    // Appended before the plate so it paints behind it (see .mg-bakery-belt).
    const belt = document.createElement("div");
    belt.className = "mg-bakery-belt";
    plateZone.appendChild(belt);
    plateZone.appendChild(plate);

    const rows = document.createElement("div");
    rows.className = "mg-bakery-rows";
    function buildRow(labelText, items, category) {
      const row = document.createElement("div");
      row.className = "mg-bakery-row";
      const label = document.createElement("div");
      label.className = "mg-bakery-row-label";
      label.textContent = labelText;
      row.appendChild(label);
      items.forEach(item => {
        const btn = document.createElement("button");
        btn.className = "mg-bakery-opt";
        btn.dataset.category = category;
        btn.dataset.key = item.key;
        if (item.color) { btn.style.setProperty("--swatch", item.color); }
        else { btn.textContent = item.emoji; btn.style.background = "rgba(255,255,255,.06)"; }
        row.appendChild(btn);
      });
      return row;
    }
    // Bottom-up to match how the cake is actually stacked: the base sits on
    // the bottom row, icing above it, fruit on top.
    rows.appendChild(buildRow("Top", FRUITS, "fruit"));
    rows.appendChild(buildRow("Icing", FROSTINGS, "frosting"));
    rows.appendChild(buildRow("Base", BASES, "base"));

    const sendWrap = document.createElement("div");
    sendWrap.className = "mg-bakery-sendwrap";
    const sendBtn = document.createElement("button");
    sendBtn.className = "mg-bakery-send";
    sendBtn.textContent = "▶ Send";
    sendBtn.disabled = true;
    sendWrap.appendChild(sendBtn);

    stage.appendChild(hud);
    stage.appendChild(timebar);
    stage.appendChild(orderRow);
    stage.appendChild(plateZone);
    stage.appendChild(rows);
    stage.appendChild(sendWrap);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-bakery-count");
    const diceEl = hud.querySelector("#mg-bakery-dice");

    let running = true;
    let matched = 0;
    let selected = { base: null, frosting: null, fruit: null };
    // queue[0] is the live order; the rest are shown dimmed as look-ahead.
    const queue = [];
    const target = () => queue[0];

    function randomOrder(avoid) {
      let next;
      do {
        next = { base: pick(BASES), frosting: pick(FROSTINGS), fruit: pick(FRUITS) };
      } while (avoid && next.base === avoid.base && next.frosting === avoid.frosting && next.fruit === avoid.fruit);
      return next;
    }

    function renderOrders() {
      orderRow.innerHTML = queue.map((o, i) => `
        <div class="mg-bakery-ordercard ${i === 0 ? "mg-bakery-live" : ""}">
          ${i === 0 ? '<span class="mg-bakery-ordertag">Now</span>' : ""}
          <div class="mg-bakery-cake">${cakeInnerHTML(o.base.color, o.frosting.color, o.fruit.emoji)}</div>
        </div>`).join("");
    }

    function advanceOrder() {
      queue.shift();
      while (queue.length < ORDER_QUEUE) queue.push(randomOrder(queue[queue.length - 1]));
      renderOrders();
    }

    function resetPlate() {
      selected = { base: null, frosting: null, fruit: null };
      cake.innerHTML = "";
      rows.querySelectorAll(".mg-bakery-opt").forEach(b => b.classList.remove("mg-bakery-selected"));
      sendBtn.disabled = true;
    }

    function refreshCake() {
      const b = selected.base, f = selected.frosting, u = selected.fruit;
      cake.innerHTML = cakeInnerHTML(
        b ? b.color : "transparent",
        f ? f.color : "transparent",
        u ? u.emoji : ""
      );
      sendBtn.disabled = !(b && f && u);
    }

    rows.addEventListener("click", (e) => {
      const btn = e.target.closest(".mg-bakery-opt");
      if (!btn || !running) return;
      const category = btn.dataset.category;
      const key = btn.dataset.key;
      const list = category === "base" ? BASES : category === "frosting" ? FROSTINGS : FRUITS;
      selected[category] = list.find(x => x.key === key);
      rows.querySelectorAll(`.mg-bakery-opt[data-category="${category}"]`).forEach(b => {
        b.classList.toggle("mg-bakery-selected", b === btn);
      });
      refreshCake();
    });

    sendBtn.addEventListener("click", () => {
      if (!running || sendBtn.disabled) return;
      const t = target();
      const isMatch = selected.base === t.base && selected.frosting === t.frosting && selected.fruit === t.fruit;

      // Each send is its own element travelling the full width of the stage,
      // so sending again before the last one has left simply puts a second
      // cake on the belt rather than interrupting the first.
      const flying = document.createElement("div");
      flying.className = "mg-bakery-cake mg-bakery-flying";
      flying.innerHTML = cake.innerHTML;
      flying.style.setProperty("--fly", (stage.clientWidth + 140) + "px");
      plateZone.appendChild(flying);
      requestAnimationFrame(() => flying.classList.add("mg-bakery-go"));
      setTimeout(() => flying.remove(), SEND_ANIM_MS + 80);

      stage.classList.remove("mg-bakery-ok", "mg-bakery-bad");
      void stage.offsetWidth;
      stage.classList.add(isMatch ? "mg-bakery-ok" : "mg-bakery-bad");

      if (isMatch) {
        matched++;
        countEl.textContent = "\u{1F382} " + matched;
        diceEl.textContent = "\u{1F3B2}".repeat(diceFor(matched / TARGET_CAKES));
      }
      resetPlate();
      advanceOrder();
    });

    while (queue.length < ORDER_QUEUE) queue.push(randomOrder(queue[queue.length - 1]));
    renderOrders();

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
      if (rafId) cancelAnimationFrame(rafId);

      const score = Math.max(0, Math.min(1, matched / TARGET_CAKES));
      const resultEl = document.createElement("div");
      resultEl.className = "mg-bakery-result";
      resultEl.innerHTML = `
        <div class="mg-big">\u{1F382} ${matched} order${matched === 1 ? "" : "s"} filled</div>
        <div class="mg-sub">\u{1F3B2} ${diceFor(score)} dice earned</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
