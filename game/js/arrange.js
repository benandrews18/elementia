/* =====================================================================
   arrange.js -- Arrange Items sticker canvas.

   Arrange Items: every crafted item is a sticker the player can drag around
   the canvas, then rotate and scale with the toolbar. The 12 backgrounds are
   the game's own palette (8 station colours + 4 suit colours).
   ===================================================================== */
const ARRANGE_COLORS = (() => {
  const seen = new Set();
  const out = [];
  Object.values(DATA.suits).forEach(s => { if (!seen.has(s.color)){ seen.add(s.color); out.push(s.color); } });
  Object.values(ELEMENT_COLOR).forEach(c => { if (!seen.has(c)){ seen.add(c); out.push(c); } });
  return out;
})();

let selectedStickerId = null;

let arrTrayTab = "items"; // "items" | "elements" -- which source list #arrTray shows
function openArrangeScreen(){
  document.getElementById("arrangeScreen").classList.add("open");
  document.getElementById("arrTrayPanel").classList.remove("collapsed");
  document.getElementById("arrTrayHandle").setAttribute("aria-expanded", "true");
  arrTrayTab = "items";
  document.querySelectorAll(".arr-tray-tab").forEach(t => t.classList.toggle("active", t.dataset.tab === "items"));
  renderArrangeTray();
  renderArrangeBgPicker();
  renderArrangeCanvas();
}
function closeArrangeScreen(){
  document.getElementById("arrangeScreen").classList.remove("open");
  selectedStickerId = null;
}
document.getElementById("arrangeClose").addEventListener("click", closeArrangeScreen);
// Collapse/expand the tray as an overlay slide (.arr-tray-panel.collapsed);
// the canvas never resizes.
document.getElementById("arrTrayHandle").addEventListener("click", () => {
  const panel = document.getElementById("arrTrayPanel");
  const collapsed = panel.classList.toggle("collapsed");
  document.getElementById("arrTrayHandle").setAttribute("aria-expanded", String(!collapsed));
});

function renderArrangeTray(){
  const tray = document.getElementById("arrTray");
  if (arrTrayTab === "elements"){
    // Same "only what you actually have" rule as the item tab -- every
    // element currently sitting at 1+ in state.elements, not the full
    // 16-element roster regardless of ownership.
    const owned = Object.keys(state.elements || {}).filter(sym => state.elements[sym] > 0).sort();
    if (!owned.length){
      tray.innerHTML = '<div class="arr-empty">Collect some elements first, then come back to arrange them.</div>';
      return;
    }
    tray.innerHTML = owned.map(sym => {
      const suit = ELEMENT_COLOR[sym] || "#8a94a6";
      return `<button type="button" class="arr-tray-card el" style="--suit:${suit}" data-add-el="${esc(sym)}">
        <span class="nm">${esc(sym)}</span>
      </button>`;
    }).join("");
    return;
  }
  const unique = [...new Set(state.items)];
  if (!unique.length){
    tray.innerHTML = '<div class="arr-empty">Craft some items first, then come back to arrange them.</div>';
    return;
  }
  tray.innerHTML = unique.map(name => {
    const emoji = ITEM_EMOJI[name];
    return `<button type="button" class="arr-tray-card" data-add="${esc(name)}">
      <span class="em">${em(emoji)}</span>
      <span class="nm">${esc(name)}</span>
    </button>`;
  }).join("");
}
document.getElementById("arrTray").addEventListener("click", ev => {
  const itemBtn = ev.target.closest("[data-add]");
  if (itemBtn){ addSticker(itemBtn.dataset.add, "item"); return; }
  const elBtn = ev.target.closest("[data-add-el]");
  if (elBtn) addSticker(elBtn.dataset.addEl, "element");
});
document.getElementById("arrTrayTabs").addEventListener("click", ev => {
  const tab = ev.target.closest("[data-tab]");
  if (!tab) return;
  arrTrayTab = tab.dataset.tab;
  document.querySelectorAll(".arr-tray-tab").forEach(t => t.classList.toggle("active", t === tab));
  renderArrangeTray();
});

function renderArrangeBgPicker(){
  const picker = document.getElementById("arrBgPicker");
  const bg = state.arrangement.bg;
  picker.innerHTML = '<span class="arr-bg-label">BACKGROUND</span>' +
    ARRANGE_COLORS.map(c => `<button type="button" class="arr-swatch${c === bg ? " active" : ""}" data-bg="${esc(c)}" style="background:${esc(c)}" aria-label="Background color"></button>`).join("");
}
document.getElementById("arrBgPicker").addEventListener("click", ev => {
  const sw = ev.target.closest("[data-bg]");
  if (!sw) return;
  state.arrangement.bg = sw.dataset.bg;
  save();
  renderArrangeBgPicker();
  applyArrangeBg();
});
function applyArrangeBg(){
  document.getElementById("arrCanvas").style.background = state.arrangement.bg || "var(--sunken)";
}

/* New stickers land near the centre with a small random scatter. Position
   is stored as a 0-100 percentage of the canvas, so scenes survive size
   and orientation changes. */
function addSticker(name, kind){
  const id = "s" + Date.now() + Math.random().toString(36).slice(2, 7);
  state.arrangement.stickers.push({
    id, name, kind: kind || "item", // kind is new -- see renderArrangeCanvas()'s fallback for stickers saved before this existed
    x: 42 + Math.random() * 16,
    y: 42 + Math.random() * 16,
    rot: 0,
    scale: 1,
  });
  save();
  selectedStickerId = id;
  renderArrangeCanvas();
}

function renderArrangeCanvas(){
  const canvas = document.getElementById("arrCanvas");
  applyArrangeBg();
  canvas.innerHTML = state.arrangement.stickers.map(s => {
    // kind is undefined on any sticker saved before Elements existed --
    // those were always items, so the fallback keeps old scenes rendering
    // exactly as they did before this.
    const isEl = s.kind === "element";
    const cls = "arr-sticker" + (isEl ? " el" : "") + (s.id === selectedStickerId ? " selected" : "");
    const suitStyle = isEl ? `--suit:${ELEMENT_COLOR[s.name] || "#8a94a6"};` : "";
    const content = isEl ? esc(s.name) : em(ITEM_EMOJI[s.name]);
    return `<div class="${cls}" data-sticker="${esc(s.id)}"` +
      ` style="${suitStyle}left:${s.x}%; top:${s.y}%; transform:translate(-50%,-50%) rotate(${s.rot}deg) scale(${s.scale})">${content}</div>`;
  }).join("");
  canvas.querySelectorAll("[data-sticker]").forEach(attachStickerDrag);
  updateArrangeToolbar();
}
// Always visible; its handler does nothing until a sticker is selected.
function updateArrangeToolbar(){
  document.getElementById("arrToolbar").classList.add("show");
}
function findSticker(id){ return state.arrangement.stickers.find(s => s.id === id); }

function attachStickerDrag(el){
  const id = el.dataset.sticker;
  el.addEventListener("pointerdown", ev => {
    ev.preventDefault();
    const s = findSticker(id);
    if (!s) return;
    const canvas = document.getElementById("arrCanvas");
    const rect = canvas.getBoundingClientRect();
    const startX = ev.clientX, startY = ev.clientY;
    const origX = s.x, origY = s.y;
    try { el.setPointerCapture(ev.pointerId); } catch(e){}
    function onMove(e){
      const dx = e.clientX - startX, dy = e.clientY - startY;
      s.x = Math.min(100, Math.max(0, origX + dx / rect.width * 100));
      s.y = Math.min(100, Math.max(0, origY + dy / rect.height * 100));
      el.style.left = s.x + "%";
      el.style.top = s.y + "%";
    }
    function onUp(){
      el.removeEventListener("pointermove", onMove);
      el.removeEventListener("pointerup", onUp);
      selectSticker(id);
      save();
    }
    el.addEventListener("pointermove", onMove);
    el.addEventListener("pointerup", onUp);
  });
}
function selectSticker(id){
  selectedStickerId = id;
  document.querySelectorAll("#arrCanvas .arr-sticker").forEach(el =>
    el.classList.toggle("selected", el.dataset.sticker === id));
  updateArrangeToolbar();
}
// Tapping empty canvas (not a sticker) clears the selection.
document.getElementById("arrCanvas").addEventListener("click", ev => {
  if (ev.target.closest("[data-sticker]")) return;
  selectedStickerId = null;
  document.querySelectorAll("#arrCanvas .arr-sticker.selected").forEach(el => el.classList.remove("selected"));
  updateArrangeToolbar();
});

document.getElementById("arrToolbar").addEventListener("click", ev => {
  const s = findSticker(selectedStickerId);
  if (!s) return;
  if (ev.target.closest("#arrRotL")) s.rot -= 15;
  else if (ev.target.closest("#arrRotR")) s.rot += 15;
  else if (ev.target.closest("#arrBigger")) s.scale = Math.min(3, s.scale * 1.15);
  else if (ev.target.closest("#arrSmaller")) s.scale = Math.max(0.4, s.scale / 1.15);
  else if (ev.target.closest("#arrDelete")){
    state.arrangement.stickers = state.arrangement.stickers.filter(x => x.id !== s.id);
    selectedStickerId = null;
    save();
    renderArrangeCanvas();
    return;
  } else return;
  save();
  renderArrangeCanvas();
});
