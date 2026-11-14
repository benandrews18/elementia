/* =====================================================================
   hints.js -- Hints and the mouse guide: tap hints, one-time mouse tips
   (showMouseTipOnce()) and the pending-tip queue that waits for overlays
   to close.
   ===================================================================== */
function hideHint(){ const h = document.getElementById("hint"); if (h) h.classList.remove("open"); }

/* Shared positioning for the #hint popover -- above its target, flipping
   below if that would run off the top of the viewport. */
function placeHint(target){
  const h = document.getElementById("hint");
  h.classList.add("open");
  const r = target.getBoundingClientRect();
  const hr = h.getBoundingClientRect();
  let left = r.left + window.scrollX + r.width / 2 - hr.width / 2;
  left = Math.max(8, Math.min(left, window.innerWidth - hr.width - 8));
  let top = r.top + window.scrollY - hr.height - 9;
  if (top < window.scrollY + 4) top = r.bottom + window.scrollY + 9;
  h.style.left = left + "px";
  h.style.top = top + "px";
}
function showHint(target, name, kind){
  let body;
  if (kind === "element"){
    const where = DATA.stations.filter(s => s.dice.includes(name));
    body = `<b>${esc(name)}</b> is rolled at:<br>` +
      where.map(s => `${em(s.emoji)} ${esc(s.name)}`).join("<br>");
  } else {
    const where = ENTRIES.filter(e => e.name === name)
      .map(e => STATION_BY_NAME[e.station]);
    body = `<b>${esc(name)}</b> is built at:<br>` +
      where.map(s => `${em(s.emoji)} ${esc(s.name)}`).join("<br>");
  }
  document.getElementById("hint").innerHTML = body;
  placeHint(target);
}
/* Professor Mouse (see #mouseTip). MOUSE_POSES lists each image path as a
   literal string because build_artifact.py finds images to inline with a
   static regex -- a computed "mouse/" + pose + ".webp" would 404 in the
   single-file build. showMouseTipOnce(): each tip id fires once per run,
   however often its call site re-renders. mouseTipsShown resets with the run
   (restartRun()). */
const MOUSE_POSES = {
  1: "mouse/1.webp", 2: "mouse/2.webp", 3: "mouse/3.webp", 4: "mouse/4.webp",
  5: "mouse/5.webp", 6: "mouse/6.webp", 7: "mouse/7.webp", 8: "mouse/8.webp",
  9: "mouse/9.webp", 10: "mouse/10.webp", 11: "mouse/11.webp", 12: "mouse/12.webp",
};
let mouseTipsShown = new Set();
const MOUSE_ANCHORS = ["bottom-left", "bottom-right", "top-left", "top-right", "center"];
/* anchor picks WHICH CORNER the bubble appears in (see #mouseTip's own
   comment for all 4 and when each applies) -- defaults to bottom-left
   for any call site that doesn't care. */
/* Positions the #mouseHighlight cutout snugly around targetSel's rect
   (like positionTutCoach()). Hides it when the selector is null or matches
   nothing, so a stale cutout never lingers. */
function positionMouseHighlight(targetSel){
  const spot = document.getElementById("mouseHighlight");
  const target = targetSel && document.querySelector(targetSel);
  if (!target){ spot.classList.remove("show"); return; }
  const r = target.getBoundingClientRect();
  const pad = 8;
  spot.style.left = (r.left - pad) + "px";
  spot.style.top = (r.top - pad) + "px";
  spot.style.width = (r.width + pad * 2) + "px";
  spot.style.height = (r.height + pad * 2) + "px";
  spot.classList.add("show");
}
// True while a full-screen moment (the card popup) is showing. Narrower than anyOverlayOpen(), which would also defer tips that
// are ABOUT Convert/Settings. Tips are marked seen when called, so one
// shown under these popups would be lost.
function blockingEventOpen(){
  return document.getElementById("cardPop").classList.contains("open");
}
// Tips that arrived while blocked, in order. A real queue: tips are marked
// seen when called, so overwriting a single slot lost them for good.
// flushPendingMouseTip() drains it one at a time -- when unblocked
// (closeOverlay()) and when the current tip is dismissed (hideMouseTip()).
let pendingMouseTips = [];
function showMouseTip(pose, html, anchor, targetSel){
  if (blockingEventOpen()){
    pendingMouseTips.push({pose, html, anchor, targetSel});
    return;
  }
  document.getElementById("mouseTipImg").src = MOUSE_POSES[pose];
  document.getElementById("mouseTipText").innerHTML = html;
  const el = document.getElementById("mouseTip");
  MOUSE_ANCHORS.forEach(a => el.classList.remove("anchor-" + a));
  el.classList.add("anchor-" + (MOUSE_ANCHORS.includes(anchor) ? anchor : "bottom-left"));
  el.classList.add("show");
  el.setAttribute("aria-hidden", "false");
  positionMouseHighlight(targetSel);
}
function flushPendingMouseTip(){
  if (!pendingMouseTips.length || blockingEventOpen()) return;
  const tip = pendingMouseTips.shift();
  showMouseTip(tip.pose, tip.html, tip.anchor, tip.targetSel);
}
function hideMouseTip(){
  const el = document.getElementById("mouseTip");
  el.classList.remove("show");
  el.setAttribute("aria-hidden", "true");
  positionMouseHighlight(null);
  // Dismissing the current tip is when the next queued one gets its turn
  // (see pendingMouseTips).
  flushPendingMouseTip();
}
/* Pressing Map (goHome()) skips the whole craft/tip pipeline: closes
   cardPop (and its timer) and drops queued tips. Uses classList directly rather than closeOverlay(), which
   would flush the very queue being discarded. goMap() re-renders
   afterward. */
function cancelPendingFullscreenEvents(){
  clearTimeout(cardPopTimer);
  capstoneMarketPending = false; // closed without closeOverlay(): don't open the Market later
  document.getElementById("cardPop").classList.remove("open");
  // Clear the queue BEFORE hideMouseTip(), which flushes the next tip on its
  // way out.
  pendingMouseTips = [];
  hideMouseTip();
}
function showMouseTipOnce(id, pose, html, anchor, targetSel){
  if (mouseTipsShown.has(id)) return false;
  mouseTipsShown.add(id);
  showMouseTip(pose, html, anchor, targetSel);
  return true;
}
/* Like showMouseTipOnce(), but "shown" persists in prefs
   (tutorialHintsSeen): for feature tips that play once ever, not once per
   run. Returns true/false so callers can try tips in order and stop at the
   first one that shows. */
function showTutorialHintOnce(id, pose, html, anchor, targetSel){
  if (prefs.guidedTutorialEnabled === false) return false;
  if (prefs.tutorialHintsSeen.includes(id)) return false;
  prefs.tutorialHintsSeen.push(id);
  savePrefs();
  showMouseTip(pose, html, anchor, targetSel);
  return true;
}
/* Like showTutorialHintOnce(), but QUEUES the tip behind whatever's showing
   (pushed straight onto pendingMouseTips), for a follow-up bubble.
   targetSel is resolved when it actually displays. */
function queueTutorialHintOnce(id, pose, html, anchor, targetSel){
  if (prefs.guidedTutorialEnabled === false) return false;
  if (prefs.tutorialHintsSeen.includes(id)) return false;
  prefs.tutorialHintsSeen.push(id);
  savePrefs();
  pendingMouseTips.push({pose, html, anchor, targetSel});
  return true;
}
/* New-player walkthrough. Professor Mouse covers the first few presses
   as they happen: Roll at a station, Craft, Convert, then the centre Home
   button back to the map, and later (goMap()) the Market. Each tip shows
   once per player (prefs.tutorialHintsSeen). It waits for an idle screen
   -- nothing modal open, no roll or mini-game, no other tip -- so it never
   blocks input or stacks; a tip that can't show yet is NOT marked seen and
   is retried on the next render(). */
function walkthroughIdle(){
  return !anyOverlayOpen() && !blockingEventOpen() && !openPanelName()
    && !pendingMouseTips.length && !rollAnimationInProgress
    && !document.body.hasAttribute("data-intro-sequence")
    && !document.getElementById("mouseTip").classList.contains("show")
    && !document.getElementById("rollPopup").classList.contains("open")
    && !document.getElementById("mgOverlay").classList.contains("show")
    && !document.getElementById("tour").classList.contains("open");
}
function tryWalkthroughTip(id, pose, html, anchor, targetSel){
  if (!walkthroughIdle()) return false;
  return showTutorialHintOnce(id, pose, html, anchor, targetSel);
}
// Called at the end of every render().
function maybeShowWalkthroughTip(){
  if (prefs.guidedTutorialEnabled === false || !walkthroughIdle()) return;
  if (screen !== "station" || !current) return;
  if (!state.rolledHere){
    if (state.pendingRoll != null)
      tryWalkthroughTip("firstroll", 3, `<span style="font-size:14.5px">Tap <b>Roll</b> to get elements!</span>`, "bottom-left", "#hubHome");
    return;
  }
  const craftable = document.querySelector("#screen .craftbtn.go");
  if (craftable){
    tryWalkthroughTip("firstcraft", 7, "Tap <b>Craft</b>!", "top-left", "#screen .craftbtn.go");
    return;
  }
  if (totalConvertibleCount() > 0 && tryWalkthroughTip("firstconvert", 5,
      "Convert Elements! <b>3:1</b>", "center", "#quickConvertBtn")){
    queueTutorialHintOnce("converttapmissing", 7,
      `<span style="font-size:12.5px">Tap to craft missing elements</span>`, "bottom-left", ".tok.el.need");
    return;
  }
  if (tryWalkthroughTip("gomap", 12, `<span style="font-size:15.5px">Onto the next station!<br>Tap the <b>Map</b>.</span>`, "bottom-left", "#hubHome")) return;
  // After the basics: the tracked item's badge on shop cards (itemHTML()).
  if (document.querySelector("#screen .item-pin-badge"))
    tryWalkthroughTip("pintrackshop", 7, "Your tracked item needs this one!", "bottom-right", "#screen .item-pin-badge");
}
document.getElementById("mouseTip").addEventListener("click", ev => {
  if (ev.target.closest("#mouseTipHide")){
    prefs.guidedTutorialEnabled = false; savePrefs();
    pendingMouseTips.length = 0;
    hideMouseTip();
    return;
  }
  if (ev.target.closest(".mouse-tip-close")) hideMouseTip();
});
// The next tap anywhere also dismisses the tip (capture phase, without
// stopping the tap itself). Not during the guided walkthrough, which only
// advances via its own Next button (endTutCoach()).
document.addEventListener("click", ev => {
  if (document.getElementById("tutCoach").classList.contains("open")) return;
  if (!ev.target.closest("#mouseTip")) hideMouseTip();
}, true);
