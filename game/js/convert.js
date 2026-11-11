/* =====================================================================
   convert.js -- Element conversion tray.

   Element conversion: 3 of one element for 1 of another. The from/to boxes
   share one picker (convertPickMode = whichever was tapped). Neither side
   can pick the other side's element, so X-for-X can't happen.
   ===================================================================== */
let convertFrom = null, convertTo = null, convertPickMode = null;  // "from" | "to"
// The item whose recipe sent the player into Convert (.tok.el.need
// handler), kept as an entry so renderConvertGoalCard() re-renders it live
// on every render().
let convertGoalEntry = null;

function openConvertScreen(){
  convertFrom = null; convertTo = null; convertGoalEntry = null;
  // Cleared so every other way into Convert starts with no goal card; only
  // the .tok.el.need handler sets it, right after calling this.
  document.getElementById("convertGoalCard").innerHTML = "";
  updateConvertUI();
  openOverlay("convert");
}
/* Re-renders #convertGoalCard from convertGoalEntry on every render(), so
   its Craft button and tokens stay live while Convert is open. */
function renderConvertGoalCard(){
  const goalCardEl = document.getElementById("convertGoalCard");
  if (!goalCardEl) return;
  if (!convertGoalEntry){ goalCardEl.innerHTML = ""; return; }
  const idx = ENTRIES.indexOf(convertGoalEntry);
  goalCardEl.innerHTML = itemHTML(convertGoalEntry, idx);
  // See the .tok.el.need click handler's own comment on why --suit has
  // to be set explicitly here.
  const su = DATA.suits[STATION_BY_NAME[convertGoalEntry.station].suit];
  goalCardEl.style.setProperty("--suit", su.color);
}
/* Quick-pick grid (#convertQuickGrid): the drawer's element boxes, where a
   tap sets convertFrom. Elements under 3 are faded (.elbox.invalid), like
   the picker's FROM list. */
function renderConvertQuickGrid(){
  const grid = document.getElementById("convertQuickGrid");
  if (!grid) return;
  const syms = Object.keys(state.elements).filter(k => state.elements[k] > 0)
    .sort((a, b) => (ATOMIC_NUMBER[a] || 999) - (ATOMIC_NUMBER[b] || 999));
  grid.innerHTML = syms.map(s => {
    const valid = count(s) >= CONVERT_RATE;
    return `<button type="button" class="elbox ${valid ? "" : "invalid"}" data-elem="${esc(s)}" ${valid ? "" : "disabled"} style="--suit:${ELEMENT_COLOR[s]}">` +
      `<span class="elsym">${esc(s)}${elSuitBadgeHTML(s)}</span><span class="elqty">${count(s)}</span></button>`;
  }).join("");
}
document.getElementById("convertQuickGrid").addEventListener("click", ev => {
  const btn = ev.target.closest("[data-elem]");
  if (!btn) return;
  convertFrom = btn.dataset.elem;
  updateConvertUI();
});
function updateConvertUI(){
  renderConvertQuickGrid();
  renderConvertEmptyEl();
  const fromStack = document.getElementById("convFromStack");
  const fromBox = document.getElementById("convFromBox");
  const toBox = document.getElementById("convToBox");
  fromStack.classList.toggle("filled", !!convertFrom);
  document.getElementById("convFromSym").textContent = convertFrom || "+";
  document.getElementById("convFromLabel").textContent =
    convertFrom ? (ELEMENT_NAMES[convertFrom] || convertFrom) : "Pick element";
  paintElement(fromBox, convertFrom);
  fromStack.querySelectorAll(".convert-ghost").forEach(g => paintElement(g, convertFrom));

  toBox.classList.toggle("filled", !!convertTo);
  document.getElementById("convToSym").textContent = convertTo || "+";
  document.getElementById("convToLabel").textContent =
    convertTo ? (ELEMENT_NAMES[convertTo] || convertTo) : "Pick element";
  paintElement(toBox, convertTo);

  const ready = convertFrom && convertTo && convertFrom !== convertTo && count(convertFrom) >= CONVERT_RATE;
  document.getElementById("convertGo").disabled = !ready;
}
function renderConvertPicker(){
  const isFrom = convertPickMode === "from";
  document.getElementById("convertPickerKicker").textContent = isFrom ? "Inventory" : "Choose an element";
  document.getElementById("convertPickerSub").textContent = isFrom
    ? "Elements with 3 or more can be converted."
    : "Pick what you'd like to convert into.";

  // FROM shows every element the player has (even under 3) so they can see
  // what's close/not just what already qualifies; TO offers the full set.
  let syms = isFrom
    ? Object.keys(state.elements).filter(s => count(s) > 0)
    : CLASSIC_ELEMENTS;
  // Grouped by suit (ELEMENT_SUIT's key order), not atomic number, so Ni sits
  // with the earth elements.
  const ELEMENT_DISPLAY_ORDER = Object.keys(ELEMENT_SUIT);
  syms = syms.filter(s => s !== (isFrom ? convertTo : convertFrom))
    .sort((a, b) => ELEMENT_DISPLAY_ORDER.indexOf(a) - ELEMENT_DISPLAY_ORDER.indexOf(b));

  const grid = document.getElementById("convertPickerGrid");
  if (!syms.length){
    grid.innerHTML = `<p class="empty">${isFrom ? "You don't have any elements yet." : "No other elements to pick."}</p>`;
    return;
  }
  grid.innerHTML = syms.map(s => {
    // --suit, because .elsym builds its border from var(--suit).
    const suitStyle = `style="--suit:${ELEMENT_COLOR[s] || "#8a94a6"}"`;
    if (!isFrom) return `<button type="button" class="convert-pick" data-sym="${esc(s)}" title="${esc(ELEMENT_NAMES[s] || s)}">
        <span class="elsym" ${suitStyle}>${esc(s)}${elSuitBadgeHTML(s)}</span>
        <span class="pickqty">×${count(s)}</span>
      </button>`;
    const valid = count(s) >= CONVERT_RATE;
    return `<button type="button" class="convert-pick ${valid ? "" : "invalid"}" data-sym="${esc(s)}" ${valid ? "" : "disabled"} title="${esc(ELEMENT_NAMES[s] || s)}">
        <span class="elsym" ${suitStyle}>${esc(s)}${elSuitBadgeHTML(s)}</span>
        <span class="pickqty">×${count(s)}</span>
      </button>`;
  }).join("");
}
document.getElementById("convFromBox").addEventListener("click", () => {
  convertPickMode = "from"; renderConvertPicker(); openOverlay("convertPicker");
});
document.getElementById("convToBox").addEventListener("click", () => {
  convertPickMode = "to"; renderConvertPicker(); openOverlay("convertPicker");
});
document.getElementById("convertPickerGrid").addEventListener("click", ev => {
  const btn = ev.target.closest("[data-sym]");
  if (!btn) return;
  if (convertPickMode === "from") convertFrom = btn.dataset.sym; else convertTo = btn.dataset.sym;
  closeOverlay("convertPicker");
  updateConvertUI();
});
document.getElementById("convertPickerClose").addEventListener("click", () => closeOverlay("convertPicker"));
document.getElementById("convertGo").addEventListener("click", () => {
  if (!convertFrom || !convertTo || convertFrom === convertTo || count(convertFrom) < CONVERT_RATE) return;
  state.elements[convertFrom] = count(convertFrom) - CONVERT_RATE;
  if (state.elements[convertFrom] <= 0) delete state.elements[convertFrom];
  state.elements[convertTo] = count(convertTo) + 1;
  save();
  playConvertAnimation(convertTo);
  // "Convert Elements!" no longer fires here -- see updateHub(), it now
  // fires the moment the floating button first appears, not after the
  // player's already found and used it once.
});
document.getElementById("convertClose").addEventListener("click", () => closeOverlay("convert"));
document.getElementById("convertScrim").addEventListener("click", () => closeOverlay("convert"));

/* Convert confirm: the button punches, the FROM stack pops away while the
   result flies from the TO box into the inventory icon (which punches on
   contact, like flyToInventory()). render()/reset waits for the flight to
   land. */
function playConvertAnimation(toSym){
  const goBtn = document.getElementById("convertGo");
  goBtn.disabled = true;
  goBtn.animate([
    { transform: "scale(1)" }, { transform: "scale(1.12)" }, { transform: "scale(1)" },
  ], { duration: 260, easing: "cubic-bezier(.3,1.4,.4,1)" });

  // Animate the whole stack wrapper -- the ghost squares are siblings, so they
  // wouldn't follow the button.
  const fromStack = document.getElementById("convFromStack");
  const fromPop = fromStack.animate([
    { transform: "scale(1)", opacity: 1 }, { transform: "scale(1.08)", opacity: 1, offset: .25 },
    { transform: "scale(.2)", opacity: 0 },
  ], { duration: 420, easing: "cubic-bezier(.3,.6,.4,1)", fill: "forwards" });

  const toBox = document.getElementById("convToBox");
  const rect = toBox.getBoundingClientRect();
  toBox.style.visibility = "hidden"; // the clone below takes its place visually

  const clone = document.createElement("div");
  clone.className = "convert-box filled convert-fly-clone";
  clone.innerHTML = `<span class="convert-sym">${esc(toSym)}</span>` +
    `<span class="convert-label">${esc(ELEMENT_NAMES[toSym] || toSym)}</span>`;
  paintElement(clone, toSym);
  clone.style.left = rect.left + "px";
  clone.style.top = rect.top + "px";
  clone.style.width = rect.width + "px";
  clone.style.height = rect.height + "px";
  clone.style.margin = "0";
  document.body.appendChild(clone);

  const hub = document.getElementById("hubInv");
  const target = hub.getBoundingClientRect();
  const tx = target.left + target.width / 2, ty = target.top + target.height / 2;
  const dx = tx - (rect.left + rect.width / 2), dy = ty - (rect.top + rect.height / 2);
  const FLY_MS = 520, CONTACT_FRACTION = .72;

  const anim = clone.animate([
    { transform: "translate(0,0) scale(1)", opacity: 1, offset: 0 },
    { transform: `translate(${dx}px, ${dy}px) scale(.55)`, opacity: 1, offset: CONTACT_FRACTION },
    { transform: `translate(${dx}px, ${dy}px) scale(.15)`, opacity: 0, offset: 1 },
  ], { duration: FLY_MS, easing: "cubic-bezier(.4,.1,.3,1)", fill: "forwards" });
  setTimeout(punchInventory, FLY_MS * CONTACT_FRACTION); // as soon as it makes contact, not at full finish
  anim.onfinish = () => {
    clone.remove();
    // Reset state and repaint the empty boxes FIRST, so un-hiding them doesn't
    // flash the old elements for a frame.
    convertFrom = null; convertTo = null;
    updateConvertUI();
    toBox.style.visibility = "";
    // Reverse fromPop rather than .cancel(), which would snap the stack back to
    // full opacity in one frame.
    fromPop.cancel();
    fromStack.animate(
      [{ transform: "scale(.2)", opacity: 0 }, { transform: "scale(1)", opacity: 1 }],
      { duration: 260, easing: "cubic-bezier(.3,1.4,.4,1)" }
    );
    render();
  };
}

// The icon is set in updateHub() (__CONVERT__, or the current conversion
// tool's icon), which runs on every render.
document.getElementById("quickConvertBtn").addEventListener("click", () => {
  if (bingoCraftEntry){
    document.getElementById("convert").classList.contains("open") ? closeOverlay("convert") : openConvertScreen();
    updateHub();
    return;
  }
  hubPanelClick("convert", openConvertScreen);
});
