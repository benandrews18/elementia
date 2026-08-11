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
  const DURATION_MS = 30000;      // total round length (Bakery/Power Plant/Observatory get 30s, the rest 15s)
  const TARGET_CAKES = 3;         // matching this many orders => score 1.0
  const SEND_ANIM_MS = 950;       // conveyor slide-away duration (fully off-screen)
  const RESULT_HOLD_MS = 1300;
  const ORDER_QUEUE = 3;          // order cards shown: the live one + look-ahead
  const DICE_MIN = 3;             // dice awarded at score 0
  const DICE_MAX = 6;             // dice awarded at score 1
  const TIMER_SHOW_MS = 10000;    // timer pill stays hidden until this much time remains
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
  // Icing is shown as one of the 3 real "cake middle" photos dropped into
  // game/minigames/ (see build_minigames.py's ASSETS map) instead of a CSS
  // swatch -- both on the option buttons and on the cake itself, so the
  // picture the player matches genuinely looks like the thing they tap.
  const FROSTINGS = [
    { key: "white", label: "White", img: "cake-middle-white.webp" },
    { key: "choc", label: "Chocolate", img: "cake-middle-brown.webp" },
    { key: "pink", label: "Pink", img: "cake-middle-pink.webp" },
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
  /* Same overridable-base trick as backdropURL(), for the cake-middle
     sprite photos (see deep-mine.js's spriteURL() for the same pattern). */
  function spriteURL(name) {
    return (global.MINIGAME_ASSETS && global.MINIGAME_ASSETS[name]) ||
           ((global.MINIGAME_ASSET_BASE || "./") + name);
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
        display:flex; justify-content:space-between; align-items:center; padding:10px 20px 0;
        font-weight:800; color:#fbead9; text-shadow:0 2px 4px rgba(0,0,0,.5); font-size:15px;
      }
      .mg-bakery-hud .mg-pill{
        background:rgba(255,255,255,.13); border-radius:999px; padding:4px 12px; white-space:nowrap;
      }
      /* Dice earned shown as that many die-face emojis in a 2-row-by-3
         grid (wraps automatically once a 4th die is earned), not a single
         line -- half the old single-line size so 6 dice stay compact in
         the corner. */
      .mg-dice-pill{
        display:grid; grid-template-columns:repeat(3,1fr); gap:0 4px; padding:3px 10px;
        font-size:1.5em; line-height:1.1;
      }
      .mg-bakery-hud .mg-timer-pill{ font-variant-numeric:tabular-nums; }
      .mg-bakery-timebar{ height:6px; background:#e0a23d; margin:9px 0 0; transition:width .1s linear; width:100%; }
      /* Orders are compact cards showing the FINISHED cake, not a row of
         swatches -- the player is matching a picture, so the brief should
         look like the thing they're building. The live order is the first
         card; the rest are look-ahead. Fixed height (not square) so this
         row stays a small strip regardless of how many cards/how wide the
         stage is -- the plate below is what deserves the real vertical
         space, not the look-ahead preview. */
      .mg-bakery-orders{
        margin:10px 18px 0; display:flex; gap:8px; align-items:stretch;
      }
      .mg-bakery-ordercard{
        flex:1; height:60px; border-radius:16px; position:relative;
        background:rgba(255,255,255,.10);
        display:flex; align-items:center; justify-content:center; overflow:visible;
      }
      .mg-bakery-ordercard.mg-bakery-live{
        background:rgba(255,255,255,.17); box-shadow:0 0 16px 3px rgba(224,162,61,.5);
      }
      .mg-bakery-ordercard:not(.mg-bakery-live){ opacity:.55; }
      .mg-bakery-ordercard .mg-bakery-cake{ transform:scale(.62); }
      .mg-bakery-ordertag{
        position:absolute; top:4px; left:8px; font-size:12px; font-weight:800; letter-spacing:.3px;
        color:#f0d9b8; text-transform:uppercase; opacity:.85;
      }
      .mg-bakery-platezone{
        flex:1; display:flex; align-items:center; justify-content:center; position:relative; min-height:110px;
      }
      /* The conveyor belt as a pale line running behind the plate/cake,
         not a separate striped bar of its own -- appended before the
         plate (see runMinigame()) so it paints underneath it. */
      .mg-bakery-belt{
        position:absolute; left:0; right:0; top:50%; height:3px; transform:translateY(-50%);
        background:rgba(0,0,0,.35); z-index:0;
      }
      .mg-bakery-plate{
        width:150px; height:150px; border-radius:50%; background:radial-gradient(circle,#efe6d8 0%,#d8cbb4 100%);
        display:flex; align-items:center; justify-content:center; box-shadow:0 8px 20px rgba(0,0,0,.4);
        position:relative; z-index:1;
      }
      .mg-bakery-cake{ position:relative; width:100px; height:104px; }
      /* Base layer: a plain coloured rectangle (matches the base option
         buttons below -- see .mg-bakery-opt[data-category="base"]), not a
         swirl silhouette. */
      .mg-bakery-layer-base{
        position:absolute; left:0; right:0; bottom:0; height:50px; border-radius:16px 16px 8px 8px;
        background:var(--swatch); box-shadow:inset 0 0 0 2px rgba(0,0,0,.15);
      }
      /* Icing layer: the real cake-middle photo (img element when a flavor
         is selected -- see cakeInnerHTML()), sized at the photo's own near-
         square aspect (matching the option button's object-fit:contain --
         see .mg-bakery-opt[data-category="frosting"] img) instead of being
         stretched into a thin band, and centered horizontally over the
         base with enough overlap to read as sitting on it. */
      .mg-bakery-layer-frosting{
        position:absolute; left:50%; bottom:34px; width:62px; height:58px;
        transform:translateX(-50%); display:block; object-fit:contain;
      }
      .mg-bakery-layer-fruit{
        position:absolute; left:50%; bottom:82px; transform:translateX(-50%); font-size:31px;
      }
      /* Order-card cakes are shown at .62 scale (see .mg-bakery-ordercard
         .mg-bakery-cake above), which would otherwise shrink the fruit
         along with everything else -- bump the source font-size so the
         fruit renders twice as large as usual once that scale is applied. */
      .mg-bakery-ordercard .mg-bakery-layer-fruit{ font-size:62px; }
      /* Straight horizontal travel, no rotation or fade -- it's a conveyor
         carrying the cake out of the kitchen, so it simply leaves the frame.
         --fly is the full stage width plus a margin, set per cake in JS. */
      .mg-bakery-cake.mg-bakery-flying{
        position:absolute; left:50%; top:50%; margin-left:-50px; margin-top:-52px;
        transition:transform ${SEND_ANIM_MS}ms linear; z-index:5;
      }
      .mg-bakery-cake.mg-bakery-flying.mg-bakery-go{ transform:translateX(var(--fly,120vw)); }
      .mg-bakery-rows{ padding:8px 20px 10px; display:flex; flex-direction:column; gap:7px; }
      .mg-bakery-row{ display:flex; gap:8px; align-items:center; }
      .mg-bakery-row-label{ width:42px; font-size:16px; font-weight:800; color:#c9ac86; text-align:center; }
      .mg-bakery-opt{
        flex:1; height:50px; border-radius:14px; border:4px solid rgba(0,0,0,.6); cursor:pointer;
        display:flex; align-items:center; justify-content:center; font-size:26px;
        position:relative; overflow:hidden; background:rgba(255,255,255,.06);
      }
      .mg-bakery-opt.mg-bakery-selected{ border-color:#fff; box-shadow:0 0 0 3px rgba(255,255,255,.35) inset; }
      /* Base: a plain coloured rectangle, matching the shape of the cake
         base it builds (see .mg-bakery-layer-base). */
      .mg-bakery-opt[data-category="base"]{ background:var(--swatch); border-radius:16px 16px 8px 8px; }
      /* Icing: no button chrome at all -- just the cake-middle photo
         (see FROSTINGS/spriteURL()), object-fit:contain so its own drawn
         outline reads as the button's whole silhouette. */
      .mg-bakery-opt[data-category="frosting"]{ border:none; background:transparent; padding:2px; }
      .mg-bakery-opt[data-category="frosting"] img{ width:100%; height:100%; object-fit:contain; }
      .mg-bakery-opt[data-category="frosting"].mg-bakery-selected{
        box-shadow:0 0 0 3px #fff; border-radius:14px;
      }
      /* Fruit: large emoji, no button border. */
      .mg-bakery-opt[data-category="fruit"]{ border:none; background:transparent; }
      .mg-bakery-opt[data-category="fruit"].mg-bakery-selected{
        box-shadow:0 0 0 3px #fff; border-radius:14px;
      }
      .mg-bakery-sendwrap{ padding:0 20px 14px; }
      .mg-bakery-send{
        width:100%; padding:14px; border-radius:18px; border:none; font-weight:800; font-size:22px;
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
      .mg-bakery-result .mg-big{font-size:30px; font-weight:800}
      .mg-bakery-result .mg-sub{font-size:14px; font-weight:700; opacity:.9}
      @keyframes mg-bakery-fade-in{ to{opacity:1} }
    `;
    const style = document.createElement("style");
    style.id = "mg-bakery-style";
    style.textContent = css;
    document.head.appendChild(style);
    styleInjected = true;
  }

  function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

  function cakeInnerHTML(baseColor, frostingImg, fruitEmoji) {
    const frostingHTML = frostingImg
      ? `<img class="mg-bakery-layer-frosting" src="${spriteURL(frostingImg)}" alt="">`
      : `<div class="mg-bakery-layer-frosting"></div>`;
    return `
      <div class="mg-bakery-layer-base" style="--swatch:${baseColor}"></div>
      ${frostingHTML}
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
    hud.innerHTML = `<span class="mg-pill mg-dice-pill" id="mg-bakery-dice">${diceGridHTML(DICE_MIN)}</span>` +
      `<span class="mg-pill mg-timer-pill" id="mg-bakery-timer" style="display:none"></span>` +
      `<span class="mg-pill mg-score-pill" id="mg-bakery-count">\u{1F35E} 0</span>`;

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
        if (item.color) {
          btn.style.setProperty("--swatch", item.color);
        } else if (item.img) {
          const img = document.createElement("img");
          img.src = spriteURL(item.img);
          img.alt = item.label || "";
          btn.appendChild(img);
        } else {
          btn.textContent = item.emoji;
        }
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
    const timerEl = hud.querySelector("#mg-bakery-timer");

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
          <div class="mg-bakery-cake">${cakeInnerHTML(o.base.color, o.frosting.img, o.fruit.emoji)}</div>
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
        f ? f.img : "",
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
        countEl.textContent = "\u{1F35E} " + matched;
        diceEl.innerHTML = diceGridHTML(diceFor(matched / TARGET_CAKES));
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
