/* =====================================================================
   empty-elements.js -- "?" (Empty Element) picker and cash-in.

   "?" elements (Empty Elements): earned at the top Quark breakpoint and from
   BINGO lines. A held "?" trades 1-for-1 for any element of the CURRENT
   station (or, off a station, the one the player stands at on the map),
   whenever the player likes (openEmptyElPicker()).
   ===================================================================== */
// The shared "?" square (.empty-el-square), used everywhere this currency
// appears. px sets the size and scales the "?" and corner badge.
function emptyElSquareHTML(px){
  const suitBadgePx = Math.round(px * 0.42);
  return `<span class="empty-el-square" style="width:${px}px; height:${px}px; font-size:${Math.round(px * 0.55)}px" title="Empty Element">?<span class="el-suit-badge" style="--suit:#000; width:${suitBadgePx}px; height:${suitBadgePx}px"></span></span>`;
}
// Classic only: the "?" counter by the station title, always shown
// (disabled at 0). Icon on top, count below; the icon is sized to match the
// element chips (syncEmptyElBadgeSize()).
function emptyElBadgeHTML(){
  const n = state.emptyElements || 0;
  return `<button type="button" class="empty-el-badge${n > 0 ? " active" : ""}" id="emptyElBadgeBtn"
      ${n > 0 ? "" : 'disabled aria-disabled="true"'}
      title="${n} Empty Element${n === 1 ? "" : "s"} held${n > 0 ? " -- tap to cash one in for an element found here" : ""}"
      aria-label="${n} Empty Elements held">${emptyElSquareHTML(24)}<b>${n}</b></button>`;
}
// The "?" counter in the Convert tray's top-right (#convertEmptyEl), so a
// "?" can be cashed in from anywhere Convert opens (map, Marketplace).
function renderConvertEmptyEl(){
  const el = document.getElementById("convertEmptyEl");
  if (!el) return;
  el.innerHTML = emptyElBadgeHTML();
}
document.getElementById("convertEmptyEl").addEventListener("click", ev => {
  if (!ev.target.closest("#emptyElBadgeBtn")) return;
  if (!((state.emptyElements || 0) > 0)) return;
  closeOverlay("convert");
  openEmptyElPicker();
});
/* The first time a player ever holds a "?" (prefs.sawEmptyElTip), a short
   popout explains it -- once whatever handed it over (BINGO reward,
   Lock-In) has finished. Called from render(); polls while busy. */
let emptyElTipTimer = null;
function maybeShowEmptyElTip(){
  if (prefs.sawEmptyElTip || !((state.emptyElements || 0) > 0) || emptyElTipTimer) return;
  const busy = anyOverlayOpen() || bingoClearInProgress || startingGiftInProgress
    || document.body.classList.contains("lockin-playing") || !!state.ended;
  if (busy){
    emptyElTipTimer = setTimeout(() => { emptyElTipTimer = null; maybeShowEmptyElTip(); }, 500);
    return;
  }
  prefs.sawEmptyElTip = true; savePrefs();
  showEmptyElTip();
}
function showEmptyElTip(){
  document.getElementById("emptyElTipBody").innerHTML = `
    <div class="eet-icon">${emptyElSquareHTML(56)}</div>
    <h2 id="emptyElTipTitle">Unknown Element!</h2>
    <p>An Unknown Element can become <b>any element</b> from the station you're at.</p>
    <p class="eet-where">Use it from the <span class="eet-convert">${em("__CONVERT__")}</span> <b>Convert</b> menu.</p>
    <p class="eet-where">Earn one by finishing a 🛒 Market row, visiting all 8 stations, or reaching the top ⚛️ breakpoint.</p>
    <div class="btnrow" style="justify-content:center"><button type="button" class="bigbtn" id="emptyElTipOk">Got it</button></div>`;
  openOverlay("emptyElTip");
}
document.getElementById("emptyElTip").addEventListener("click", ev => {
  if (ev.target.closest("#emptyElTipOk")) closeOverlay("emptyElTip");
});
/* Spending a "?" opens a popout with the current station's element pool --
   the same .gather/.gcol/.gchip row as the shop -- and the picked element
   flies into the inventory. */
function openEmptyElPicker(){
  const s = STATION_BY_NAME[current || state.lastStation];
  if (!s || !((state.emptyElements || 0) > 0)) return;
  const pool = sortedDice(s);
  const row = pool.map((sym, i) =>
    `<div class="gcol"><button type="button" class="gchip" data-pick-elem="${esc(sym)}" title="${esc(ELEMENT_NAMES[sym] || sym)}" style="--suit:${ELEMENT_COLOR[sym] || "#8a94a6"}"><span class="gnum">${ATOMIC_NUMBER[sym]}</span><span class="gsym">${esc(sym)}</span>${elSuitBadgeHTML(sym)}</button><span class="gname">${esc(ELEMENT_NAMES[sym] || sym)}</span>${dieFace(i + 1)}</div>`).join("");
  document.getElementById("emptyElPickBody").innerHTML = `
    <h2 id="emptyElPickTitle">${emptyElSquareHTML(34)} Pick an element</h2>
    <div class="gather">${row}</div>
    <div class="btnrow" style="justify-content:center"><button type="button" class="bigbtn sec" id="emptyElPickCancel">Cancel</button></div>`;
  openOverlay("emptyElPick");
}
document.getElementById("emptyElPick").addEventListener("click", ev => {
  if (ev.target === ev.currentTarget || ev.target.closest("#emptyElPickCancel")){ closeOverlay("emptyElPick"); return; }
  const chip = ev.target.closest("[data-pick-elem]");
  if (!chip || !((state.emptyElements || 0) > 0)) return;
  const sym = chip.dataset.pickElem;
  const fly = lowMotion() ? null : flightClone(chip);
  closeOverlay("emptyElPick");
  state.emptyElements -= 1;
  state.elements[sym] = (state.elements[sym] || 0) + 1;
  save();
  if (!fly){ render(); return; }
  const {c, r} = fly;
  c.style.boxShadow = "0 6px 16px rgba(0,0,0,.35)";
  const hub = document.getElementById("hubInv").getBoundingClientRect();
  const dx = hub.left + hub.width / 2 - (r.left + r.width / 2), dy = hub.top + hub.height / 2 - (r.top + r.height / 2);
  c.animate([
    { transform: "translate(0,0) scale(1)", opacity: 1, offset: 0 },
    { transform: `translate(${dx * .15}px, ${dy * .15 - 40}px) scale(1.1)`, opacity: 1, offset: .25 },
    { transform: `translate(${dx}px, ${dy}px) scale(.45)`, opacity: 1, offset: .72 },
    { transform: `translate(${dx}px, ${dy}px) scale(.12)`, opacity: 0, offset: 1 },
  ], { duration: 640, easing: "cubic-bezier(.4,.1,.3,1)", fill: "forwards" }).onfinish = () => c.remove();
  setTimeout(() => { punchInventory(); render(); }, 460);
});
// Size the title's "?" icon to 67% of a real element chip (measured after
// layout, since the chips flex with the pool size). Called from render();
// does nothing where there's no badge.
function syncEmptyElBadgeSize(){
  const square = document.querySelector("#emptyElBadgeBtn .empty-el-square");
  const chip = document.querySelector(".gather .gchip");
  if (!square || !chip) return;
  const px = chip.getBoundingClientRect().width * .67;
  if (!px) return;
  square.style.width = px + "px";
  square.style.height = px + "px";
  square.style.fontSize = Math.round(px * 0.55) + "px";
  const suitBadge = square.querySelector(".el-suit-badge");
  if (suitBadge){
    const suitPx = Math.round(px * 0.42);
    suitBadge.style.width = suitPx + "px";
    suitBadge.style.height = suitPx + "px";
  }
}
