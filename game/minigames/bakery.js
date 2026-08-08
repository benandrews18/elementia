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
  const DURATION_MS = 30000;      // total round length
  const TARGET_CAKES = 6;         // matching this many orders => score 1.0
  const SEND_ANIM_MS = 480;       // conveyor slide-away duration
  const RESULT_HOLD_MS = 1300;

  const BASES = [
    { key: "choc", label: "Chocolate", color: "#6b4226" },
    { key: "vanilla", label: "Vanilla", color: "#f0dcae" },
    { key: "straw", label: "Strawberry", color: "#f2a6b8" },
  ];
  const FROSTINGS = [
    { key: "white", label: "White", color: "#fffdf7" },
    { key: "choc", label: "Chocolate", color: "#4a2c17" },
    { key: "pink", label: "Pink", color: "#ff9ec7" },
  ];
  const FRUITS = [
    { key: "cherry", emoji: "\u{1F352}" },
    { key: "strawberry", emoji: "\u{1F353}" },
    { key: "blueberry", emoji: "\u{1FAD0}" },
    { key: "banana", emoji: "\u{1F34C}" },
  ];

  let styleInjected = false;
  function injectStyle() {
    if (styleInjected || document.getElementById("mg-bakery-style")) { styleInjected = true; return; }
    const css = `
      .mg-bakery-stage{
        position:relative; width:100%; height:100%; overflow:hidden; border-radius:16px;
        background:linear-gradient(180deg,#3a2418 0%,#2b1a10 60%,#1e120a 100%);
        touch-action:manipulation; user-select:none; font-family:inherit;
        display:flex; flex-direction:column;
      }
      .mg-bakery-hud{
        display:flex; justify-content:space-between; align-items:center; padding:10px 14px 0;
        font-weight:800; color:#fbead9; text-shadow:0 1px 2px rgba(0,0,0,.5); font-size:14px;
      }
      .mg-bakery-hud .mg-pill{ background:rgba(255,255,255,.13); border-radius:999px; padding:4px 12px; }
      .mg-bakery-timebar{ height:4px; background:#e0a23d; margin:8px 0 0; transition:width .1s linear; width:100%; }
      .mg-bakery-order{
        margin:10px 14px 0; padding:8px 12px; border-radius:12px; background:rgba(255,255,255,.08);
        display:flex; align-items:center; gap:10px;
      }
      .mg-bakery-order .mg-bakery-order-label{ font-size:11px; font-weight:800; color:#e0c8a8;
        text-transform:uppercase; letter-spacing:.5px; }
      .mg-bakery-swatch{
        width:26px; height:26px; border-radius:50%; box-shadow:inset 0 0 0 2px rgba(0,0,0,.25), 0 1px 2px rgba(0,0,0,.3);
      }
      .mg-bakery-order .mg-bakery-fruit{ font-size:20px; }
      .mg-bakery-platezone{
        flex:1; display:flex; align-items:center; justify-content:center; position:relative; min-height:70px;
      }
      .mg-bakery-plate{
        width:96px; height:96px; border-radius:50%; background:radial-gradient(circle,#efe6d8 0%,#d8cbb4 100%);
        display:flex; align-items:center; justify-content:center; box-shadow:0 4px 10px rgba(0,0,0,.4);
        position:relative;
      }
      .mg-bakery-cake{ position:relative; width:64px; height:56px; }
      .mg-bakery-layer-base{
        position:absolute; left:0; right:0; bottom:0; height:32px; border-radius:8px 8px 4px 4px;
        box-shadow:inset 0 0 0 1px rgba(0,0,0,.15);
      }
      .mg-bakery-layer-frosting{
        position:absolute; left:2px; right:2px; bottom:26px; height:16px; border-radius:8px 8px 3px 3px;
        box-shadow:inset 0 0 0 1px rgba(0,0,0,.12);
      }
      .mg-bakery-layer-fruit{
        position:absolute; left:50%; bottom:38px; transform:translateX(-50%); font-size:20px;
      }
      .mg-bakery-cake.mg-bakery-flying{
        position:absolute; left:50%; top:50%; margin-left:-32px; margin-top:-28px;
        transition:transform ${SEND_ANIM_MS}ms ease-in, opacity ${SEND_ANIM_MS}ms ease-in; z-index:5;
      }
      .mg-bakery-cake.mg-bakery-flying.mg-bakery-go{ transform:translate(220px,10px) rotate(12deg); opacity:0; }
      .mg-bakery-belt{
        height:10px; margin:0 14px; border-radius:5px;
        background:repeating-linear-gradient(90deg,#5a4534 0 14px,#4a3728 14px 28px);
      }
      .mg-bakery-rows{ padding:8px 14px 10px; display:flex; flex-direction:column; gap:6px; }
      .mg-bakery-row{ display:flex; gap:6px; align-items:center; }
      .mg-bakery-row-label{ width:26px; font-size:11px; font-weight:800; color:#c9ac86; text-align:center; }
      .mg-bakery-opt{
        flex:1; height:34px; border-radius:9px; border:2px solid rgba(255,255,255,.18); cursor:pointer;
        display:flex; align-items:center; justify-content:center; font-size:18px;
      }
      .mg-bakery-opt.mg-bakery-selected{ border-color:#fff; box-shadow:0 0 0 2px rgba(255,255,255,.35) inset; }
      .mg-bakery-sendwrap{ padding:0 14px 14px; }
      .mg-bakery-send{
        width:100%; padding:12px; border-radius:12px; border:none; font-weight:800; font-size:15px;
        background:#4c9a3f; color:#fff; cursor:pointer;
      }
      .mg-bakery-send:disabled{ background:#4a4038; color:#8a7f70; cursor:not-allowed; }
      .mg-bakery-stage.mg-bakery-ok .mg-bakery-belt{ box-shadow:0 0 24px 4px rgba(95,207,106,.55); }
      .mg-bakery-stage.mg-bakery-bad .mg-bakery-belt{ box-shadow:0 0 24px 4px rgba(230,86,79,.55); }
      .mg-bakery-result{
        position:absolute; inset:0; z-index:6; display:flex; flex-direction:column; align-items:center;
        justify-content:center; gap:6px; background:rgba(20,12,6,.62); color:#fff; text-align:center;
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

    const hud = document.createElement("div");
    hud.className = "mg-bakery-hud";
    hud.innerHTML = `<span class="mg-pill" id="mg-bakery-count">\u{1F382} 0</span><span class="mg-pill">Fill the order!</span>`;

    const timebar = document.createElement("div");
    timebar.className = "mg-bakery-timebar";

    const orderRow = document.createElement("div");
    orderRow.className = "mg-bakery-order";
    orderRow.innerHTML = `
      <span class="mg-bakery-order-label">Order</span>
      <span class="mg-bakery-swatch" id="mg-bakery-order-base"></span>
      <span class="mg-bakery-swatch" id="mg-bakery-order-frosting"></span>
      <span class="mg-bakery-fruit" id="mg-bakery-order-fruit"></span>`;

    const plateZone = document.createElement("div");
    plateZone.className = "mg-bakery-platezone";
    const plate = document.createElement("div");
    plate.className = "mg-bakery-plate";
    const cake = document.createElement("div");
    cake.className = "mg-bakery-cake";
    plate.appendChild(cake);
    plateZone.appendChild(plate);

    const belt = document.createElement("div");
    belt.className = "mg-bakery-belt";

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
        if (item.color) { btn.style.background = item.color; }
        else { btn.textContent = item.emoji; btn.style.background = "rgba(255,255,255,.06)"; }
        row.appendChild(btn);
      });
      return row;
    }
    rows.appendChild(buildRow("Base", BASES, "base"));
    rows.appendChild(buildRow("Icing", FROSTINGS, "frosting"));
    rows.appendChild(buildRow("Top", FRUITS, "fruit"));

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
    stage.appendChild(belt);
    stage.appendChild(rows);
    stage.appendChild(sendWrap);
    container.appendChild(stage);

    const countEl = hud.querySelector("#mg-bakery-count");
    const orderBaseEl = orderRow.querySelector("#mg-bakery-order-base");
    const orderFrostingEl = orderRow.querySelector("#mg-bakery-order-frosting");
    const orderFruitEl = orderRow.querySelector("#mg-bakery-order-fruit");

    let running = true;
    let matched = 0;
    let target = null;
    let selected = { base: null, frosting: null, fruit: null };

    function newOrder() {
      let next;
      do {
        next = { base: pick(BASES), frosting: pick(FROSTINGS), fruit: pick(FRUITS) };
      } while (target && next.base === target.base && next.frosting === target.frosting && next.fruit === target.fruit);
      target = next;
      orderBaseEl.style.background = target.base.color;
      orderFrostingEl.style.background = target.frosting.color;
      orderFruitEl.textContent = target.fruit.emoji;
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
      const isMatch = selected.base === target.base && selected.frosting === target.frosting && selected.fruit === target.fruit;

      const flying = document.createElement("div");
      flying.className = "mg-bakery-cake mg-bakery-flying";
      flying.innerHTML = cake.innerHTML;
      plate.appendChild(flying);
      requestAnimationFrame(() => flying.classList.add("mg-bakery-go"));
      setTimeout(() => flying.remove(), SEND_ANIM_MS + 60);

      stage.classList.remove("mg-bakery-ok", "mg-bakery-bad");
      void stage.offsetWidth;
      stage.classList.add(isMatch ? "mg-bakery-ok" : "mg-bakery-bad");

      if (isMatch) {
        matched++;
        countEl.textContent = "\u{1F382} " + matched;
      }
      resetPlate();
      newOrder();
    });

    newOrder();

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
        <div class="mg-sub">${Math.round(score * 100)}% -- nice baking!</div>`;
      stage.appendChild(resultEl);

      setTimeout(() => onComplete(score), RESULT_HOLD_MS);
    }

    rafId = requestAnimationFrame(tick);
  }

  global.runMinigame = runMinigame;
})(window);
