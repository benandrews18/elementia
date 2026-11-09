/* =====================================================================
   bingo.js -- BINGO: line checks, the ordered completion sequence, and the "?"
   reward picker.

   BINGO progress sequence. Runs once whatever else a craft started (fly-in,
   card popup, item reveal) has finished:
     1. the BINGO tray drops in from the top (if it isn't already open),
     2. each newly owned square bounces, one after another,
     3. each completed line bounces as a whole, one line at a time,
     4. one popup hands over the reward for every line,
     5. the tray hides again (only if this sequence opened it).
   The tray is locked throughout (#jobSheet.bingo-clearing), and
   closeJobBoard() refuses mid-sequence.
   ===================================================================== */
let bingoClearInProgress = false;
let bingoPendingSquares = [];  // card indices newly owned, not yet bounced (runtime only)
let bingoCraftHold = false;    // a craft's own reveal hasn't opened its popup yet
let bingoCraftHoldTimer = null;
let bingoSeqTimer = null;
let bingoSeqAutoOpened = false;
const BINGO_TRAY_SETTLE_MS = 450;   // tray slide-in before anything bounces
const BINGO_SQUARE_BOUNCE_MS = 560;
const BINGO_SQUARE_STAGGER_MS = 320;
const BINGO_LINE_GAP_MS = 650;      // pause between one line's bounce and the next (element pops play here)
const BINGO_TRAY_HOLD_MS = 1600;    // tray stays on screen this long once everything resolves
function holdBingoForCraftReveal(){
  bingoCraftHold = true;
  clearTimeout(bingoCraftHoldTimer);
  bingoCraftHoldTimer = setTimeout(releaseBingoCraftHold, 6000); // safety net
}
function releaseBingoCraftHold(){
  bingoCraftHold = false;
  clearTimeout(bingoCraftHoldTimer);
  scheduleBingoSequence();
}
function bingoSequenceBlocked(){
  return bingoCraftHold || anyOverlayOpen() || startingGiftInProgress || bingoRevealInProgress
    || document.getElementById("rollPopup").classList.contains("open")
    || state.ended;
}
/* Polls (cheaply) until nothing else is on screen, then runs. Safe to call
   any number of times -- only one wait is ever pending. */
function scheduleBingoSequence(){
  if (bingoClearInProgress) return;
  if (!bingoPendingSquares.length && !(state.pendingBingoClears || []).length) return;
  clearTimeout(bingoSeqTimer);
  bingoSeqTimer = setTimeout(() => {
    if (bingoSequenceBlocked()){ scheduleBingoSequence(); return; }
    runBingoSequence();
  }, 300);
}
function bingoBounceCell(cell, scale){
  if (!cell || lowMotion()) return;
  cell.animate([
    { transform: "scale(1)", boxShadow: "0 0 0 0 rgba(242,196,77,0)", offset: 0 },
    { transform: `scale(${scale})`, boxShadow: "0 0 0 6px rgba(242,196,77,.9), 0 0 22px 6px rgba(242,196,77,.7)", offset: .4 },
    { transform: "scale(.94)", boxShadow: "0 0 0 3px rgba(242,196,77,.5)", offset: .75 },
    { transform: "scale(1)", boxShadow: "0 0 0 0 rgba(242,196,77,0)", offset: 1 },
  ], { duration: BINGO_SQUARE_BOUNCE_MS, easing: "ease-out", composite: "replace" });
}
// The element a completed line's square pays out pops up out of that
// square, so the reward visibly comes FROM the card before the popup.
function bingoElementPop(cell, el){
  if (!cell || lowMotion()) return;
  const r = cell.getBoundingClientRect();
  const chip = document.createElement("div");
  chip.className = "bingo-el-pop";
  chip.style.setProperty("--suit", ELEMENT_COLOR[el] || "#8a94a6");
  chip.textContent = el;
  chip.style.left = (r.left + r.width / 2 - 18) + "px";
  chip.style.top = (r.top + r.height / 2 - 18) + "px";
  document.body.appendChild(chip);
  chip.animate([
    { transform: "translateY(0) scale(.3)", opacity: 0, offset: 0 },
    { transform: "translateY(-26px) scale(1.15)", opacity: 1, offset: .35 },
    { transform: "translateY(-40px) scale(1)", opacity: 1, offset: .8 },
    { transform: "translateY(-52px) scale(.9)", opacity: 0, offset: 1 },
  ], { duration: 1000, easing: "ease-out", fill: "forwards" }).onfinish = () => chip.remove();
}
function runBingoSequence(){
  if (bingoClearInProgress) return;
  ensureBingoCard();
  const squares = bingoPendingSquares.filter((i, k, a) => a.indexOf(i) === k);
  const lines = [...(state.pendingBingoClears || [])];
  bingoPendingSquares = [];
  if (!squares.length && !lines.length) return;
  bingoClearInProgress = true;

  // 1. Tray in from the top, on the BINGO page.
  const alreadyOpen = jobSheet.classList.contains("open") && jobSheetVariant === "full";
  bingoSeqAutoOpened = !alreadyOpen;
  bingoTab = "bingo";
  if (alreadyOpen) renderJobBoard(); else openJobSelectTray();
  jobSheet.classList.add("bingo-clearing");

  const reduced = lowMotion();
  const cellFor = i => document.querySelector(`#jobSheetBody .bingo-cell[data-cell-idx="${i}"]`);
  let t = alreadyOpen ? 150 : (reduced ? 150 : BINGO_TRAY_SETTLE_MS);

  // 2. Each new square, one after another.
  squares.forEach(i => {
    setTimeout(() => bingoBounceCell(cellFor(i), 1.3), t);
    t += BINGO_SQUARE_STAGGER_MS;
  });
  if (squares.length) t += BINGO_SQUARE_BOUNCE_MS - BINGO_SQUARE_STAGGER_MS + 200;

  // 3. Each completed line bounces in turn and a "?" pops out of its middle
  // square. A line pays ONE "?" (state.emptyElements), not an element per
  // square -- Marketplace crafting was snowballing.
  lines.forEach(lineIdx => {
    const cells = bingoLines()[lineIdx];
    setTimeout(() => {
      cells.forEach(i => bingoBounceCell(cellFor(i), 1.22));
      bingoElementPop(cellFor(cells[Math.floor(cells.length / 2)]), "?");
    }, t);
    t += BINGO_SQUARE_BOUNCE_MS + BINGO_LINE_GAP_MS;
  });

  setTimeout(() => {
    if (!lines.length){ finishBingoSequence(); return; }
    // 4. Every line's "?" at once.
    state.emptyElements = (state.emptyElements || 0) + lines.length;
    state.pendingBingoClears = (state.pendingBingoClears || []).filter(i => !lines.includes(i));
    save();
    render();
    openBingoClearOverlay(lines.length);
  }, t);
}
// 5. Runs once the reward popup is dismissed (or straight after the
// square bounces when no line was completed).
function finishBingoSequence(){
  bingoClearInProgress = false;
  jobSheet.classList.remove("bingo-clearing");
  if (bingoSeqAutoOpened){
    bingoSeqAutoOpened = false;
    setTimeout(closeJobBoard, lowMotion() ? 400 : BINGO_TRAY_HOLD_MS);
  }
  // Anything that landed while this was playing gets its own turn next.
  scheduleBingoSequence();
}
/* The reward popup for however many lines just completed: one "?" per line
   plus the line bonus. */
function openBingoClearOverlay(lineCount){
  const qs = Array.from({length: lineCount}, () => emptyElSquareHTML(48)).join("");
  document.getElementById("bingoClearOverlayBody").innerHTML = `
    <h2 id="bingoClearTitle">🎉 BINGO!</h2>
    <p>${lineCount === 1 ? "Line complete" : `${lineCount} lines complete`} · +${lineCount * BINGO_LINE_BONUS} pts</p>
    <div class="bingo-q-reward"><span>+${lineCount}</span>${qs}</div>
    <div class="btnrow"><button type="button" class="bigbtn" id="bingoClearOkBtn">Nice!</button></div>`;
  openOverlay("bingoClearOverlay");
}
document.getElementById("bingoClearOverlayBody").addEventListener("click", ev => {
  if (!ev.target.closest("#bingoClearOkBtn")) return;
  closeOverlay("bingoClearOverlay");
  finishBingoSequence();
});

/* BINGO card flip-in (runBingoRevealSequence()): from edge-on (rotateY
   -100deg) to flat, with .bingo-grid's perspective for 3D depth. Separate
   from bounceCardAppear(), which the crafted strip uses. */
function bingoCellFlipAppear(cell){
  if (!cell || lowMotion()) return;
  cell.animate([
    { transform: "rotateY(-100deg) scale(.85)", opacity: 0, offset: 0 },
    { transform: "rotateY(20deg) scale(1.05)", opacity: 1, offset: .7 },
    { transform: "rotateY(0deg) scale(1)", opacity: 1, offset: 1 },
  ], { duration: 480, easing: "cubic-bezier(.3,1.1,.4,1)" });
}

/* Called from craft() with the item just crafted. Classic never re-crafts
   an owned item, so this runs once per item per run. Queues the square for
   the BINGO sequence (no toast). */
function checkBingoCompletion(name){
  if (!state.bingoCard || !state.bingoCard.includes(name)) return;
  // No toast any more -- the square bounces on the BINGO tray instead
  // (see runBingoSequence()).
  bingoPendingSquares.push(state.bingoCard.indexOf(name));
  scheduleBingoSequence();
}
/* Checks every line after every craft (12 lines x 5 lookups) -- one craft
   can complete several (the centre is on 4). Each line pays once, ever
   (state.bingoLinesCompleted). */
function checkBingoLines(){
  if (!state.bingoCard) return;
  if (!state.pendingBingoClears) state.pendingBingoClears = []; // old saves predate this field
  bingoLines().forEach((line, i) => {
    if (state.bingoLinesCompleted.includes(i)) return;
    if (!line.every(idx => owns(state.bingoCard[idx]))) return;
    state.bingoLinesCompleted.push(i);
    state.pendingBingoClears.push(i);
  });
  scheduleBingoSequence();
}
/* The element a square's item would pay: the majority suit of its suit
   tags (itemSuitCosts(), ties at random), else any Classic element
   (CLASSIC_ELEMENTS). No longer used by the BINGO sequence, which pays "?"
   elements. */
function elementForBingoClear(name){
  const pips = itemSuitCosts(name);
  let suit = null;
  if (pips.length){
    const counts = {};
    pips.forEach(s => { counts[s] = (counts[s] || 0) + 1; });
    const top = Math.max(...Object.values(counts));
    const tied = Object.keys(counts).filter(k => counts[k] === top);
    suit = tied[Math.floor(Math.random() * tied.length)];
  }
  const pool = (suit ? CLASSIC_ELEMENTS.filter(el => ELEMENT_SUIT[el] === suit) : null) || [];
  const finalPool = pool.length ? pool : CLASSIC_ELEMENTS;
  return finalPool[Math.floor(Math.random() * finalPool.length)];
}
