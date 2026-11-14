"""Builds game/build/tip_workshop.html: the real game (the single-file build,
game/build/elementia_artifact.html) in a phone-sized frame, with a panel
listing every tip / tutorial window. Open one, edit its text in place, tune
line spacing, paragraph gap and text size, then "Copy changes" to paste the
edits back into a chat. Edits persist in the browser (localStorage).

Run after building the game:  python game/build_artifact.py
                               python game/tools/build_tip_workshop.py
Then open game/build/tip_workshop.html.
"""
import html
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent
SRC = GAME / "build" / "elementia_artifact.html"
OUT = GAME / "build" / "tip_workshop.html"

# [group, label, code run inside the game frame to open it]
TIPS = [
    ["Windows", "How to Play — slide 1", "openClassicTutorial(null, true)"],
    ["Windows", "How to Play — slide 2", "openClassicTutorial(null, true); ctIdx = 1; renderClassicTut()"],
    ["Windows", "How to Play — slide 3", "openClassicTutorial(null, true); ctIdx = 2; renderClassicTut()"],
    ["Windows", "Pin Items to your To-Do List", 'openOverlay("pinTip")'],
    ["Windows", "Display Mat rules — page 1", "openMatRules()"],
    ["Windows", "Display Mat rules — page 2", 'openMatRules(); document.getElementById("matRulesNext").click()'],
    ["Windows", "Display Mat Challenges (intro)", "openOrderTip()"],
    ["Windows", "Unknown Element", "showEmptyElTip()"],
    ["Windows", "Clock (round info)", "openClockInfo()"],
    ["Windows", "Bonus Dice (Lock-In reward)", "showLockInRewardModal(2, true, () => {})"],
    ["Windows", "Capstone complete", 'celebrate(ENTRIES.find(e => e.name === "Robot")); capstoneMarketPending = false'],
    ["Windows", "New Items Unlocked!", 'queueUnlockReveal("Robot")'],
    ["Windows", "Run Complete", "state.runComplete = true; state.ended = false; showEndGame()"],
    ["Windows", "Board check shutter", 'playShutter("Display Mat Challenge!", () => {}, "Request: Rainbow (×1.5)")'],
    ["Challenges", "The Ocean Request (Station Week)", 'twOrder("stationWeek", "The Ocean", 6)'],
    ["Challenges", "Rainbow Request", 'twOrder("rainbow", null, 6)'],
    ["Challenges", "Collector Request", 'twOrder("collector", null, 6)'],
    ["Challenges", "Fresh Faces Restriction", 'twOrder("freshFaces", null, 15)'],
    ["Challenges", "Drought Restriction", 'twOrder("drought", "organic", 15)'],
    ["Challenges", "Short Table Restriction", 'twOrder("shortTable", null, 15)'],
    ["Challenges", "Trend Shift Restriction", 'twOrder("trendShift", "The Ocean", 15)'],
    ["Challenges", "Grand Exhibition", 'twOrder("grand", null, 24)'],
    ["Professor Mouse", "Roll", 'showMouseTip(3, "Tap <b>Roll</b> to roll this station\'s dice!", "bottom-left")'],
    ["Professor Mouse", "Craft", 'showMouseTip(7, "You have what you need. Tap <b>Craft</b>!", "top-left")'],
    ["Professor Mouse", "Convert", 'showMouseTip(5, "Convert Elements! Trade 3 of one element for 1 of another.", "center")'],
    ["Professor Mouse", "Convert: tap a missing element", 'showMouseTip(7, "Tap on a missing element to create it!", "bottom-left")'],
    ["Professor Mouse", "Head back to the map", 'showMouseTip(12, "All done here? Tap the <b>Map</b> button to head back.", "bottom-left")'],
    ["Professor Mouse", "Tracked badge", 'showMouseTip(7, "This badge marks what it feeds!", "bottom-right")'],
    ["Professor Mouse", "Check out the Market", 'showMouseTip(1, "Check out the Market from here!", "bottom-right")'],
    ["Professor Mouse", "Mini-game", 'showMouseTip(1, "Quick challenge! Do your best.", "top-left")'],
    ["Professor Mouse", "Pin to track", 'showMouseTip(10, "Tap a pin to start tracking!", "bottom-left")'],
    ["Guided tour", "Elements", 'openOverlay("tutElements")'],
    ["Guided tour", "Hub steps (tap Next in the bubble)",
     'tutCoachIdx = 0; document.getElementById("tutCoach").classList.add("open"); renderTutCoach()'],
]

PAGE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tip Workshop</title>
<style>
:root{--bg:#f3efe6; --panel:#fffdf8; --ink:#2b2418; --mute:#7a6c55; --line:#ded3bf; --accent:#2f7a4f; --gold:#b8862b}
*{box-sizing:border-box}
body{margin:0; background:var(--bg); color:var(--ink); font:14px/1.45 system-ui, sans-serif; display:flex; height:100vh; overflow:hidden}
aside{width:300px; flex:none; display:flex; flex-direction:column; background:var(--panel); border-right:1px solid var(--line)}
aside header{padding:14px 16px 10px; border-bottom:1px solid var(--line)}
aside h1{font-size:17px; margin:0 0 2px}
aside header p{margin:0; color:var(--mute); font-size:12px}
#list{flex:1; overflow-y:auto; padding:6px 8px 12px}
.grp{font-size:11px; font-weight:800; letter-spacing:.08em; text-transform:uppercase; color:var(--mute); margin:12px 8px 4px}
.tip{display:flex; align-items:center; gap:8px; width:100%; text-align:left; border:0; background:none; padding:7px 10px;
  border-radius:8px; font:inherit; color:inherit; cursor:pointer}
.tip:hover{background:#f1ead9}
.tip.on{background:#e4f0e7; font-weight:700}
.tip .dot{width:8px; height:8px; border-radius:50%; flex:none; background:transparent}
.tip.edited .dot{background:var(--gold)}
main{flex:1; display:flex; flex-direction:column; min-width:0}
.bar{display:flex; flex-wrap:wrap; align-items:center; gap:14px; padding:10px 16px; background:var(--panel); border-bottom:1px solid var(--line)}
.bar label{display:flex; align-items:center; gap:6px; font-size:12.5px; color:var(--mute)}
.bar input[type=range]{width:110px}
.bar output{font-variant-numeric:tabular-nums; width:42px; color:var(--ink); font-weight:700}
button.act{border:1px solid var(--line); background:#fff; border-radius:8px; padding:6px 12px; font:inherit; font-weight:700; cursor:pointer}
button.act.primary{background:var(--accent); border-color:var(--accent); color:#fff}
button.act:focus-visible, .tip:focus-visible{outline:2px solid var(--accent); outline-offset:2px}
#status{margin-left:auto; font-size:12px; color:var(--mute)}
.stage{flex:1; display:flex; justify-content:center; align-items:center; overflow:auto; padding:16px}
iframe{width:390px; height:820px; max-height:100%; border:10px solid #2b2418; border-radius:28px; background:#000; flex:none}
@media (max-width:760px){ body{flex-direction:column; height:auto; overflow:auto} aside{width:auto; max-height:40vh} iframe{width:100%; height:720px} }
</style></head>
<body>
<aside>
  <header><h1>Tip Workshop</h1><p>Pick a window, then tap into its text to edit. Gold dot = edited.</p></header>
  <div id="list"></div>
</aside>
<main>
  <div class="bar">
    <label>Line height <input type="range" id="lh" min="1" max="2.2" step="0.05"><output id="lhO">—</output></label>
    <label>Paragraph gap <input type="range" id="gap" min="0" max="28" step="1"><output id="gapO">—</output></label>
    <label>Text size <input type="range" id="fs" min="10" max="24" step="0.5"><output id="fsO">—</output></label>
    <button class="act" id="reset">Reset this tip</button>
    <button class="act primary" id="copy">Copy changes</button>
    <span id="status">Loading the game…</span>
  </div>
  <div class="stage"><iframe id="game" title="Elementia" srcdoc="__SRCDOC__"></iframe></div>
</main>
<script>
const TIPS = __TIPS__;
const KEY = "tip-workshop-v1";
let edits = {}; try { edits = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) {}
const saveEdits = () => { try { localStorage.setItem(KEY, JSON.stringify(edits)); } catch (e) {} };
const $ = id => document.getElementById(id);
let w = null, cur = null, target = null;

$("list").innerHTML = TIPS.map((t, i) => (i === 0 || TIPS[i - 1][0] !== t[0] ? `<div class="grp">${t[0]}</div>` : "") +
  `<button class="tip" data-i="${i}"><span class="dot"></span>${t[1]}</button>`).join("");
const markEdited = () => document.querySelectorAll(".tip").forEach(b => b.classList.toggle("edited", !!edits[TIPS[b.dataset.i][1]]));
markEdited();

$("game").addEventListener("load", () => {
  w = $("game").contentWindow;
  const d = w.document;
  // Get past the menu into a sample run on the map.
  setTimeout(() => {
    try {
      const logo = d.getElementById("introLogo"); if (logo) logo.style.display = "none";
      w.eval(`endTour(); document.querySelectorAll(".overlay.open").forEach(o => o.classList.remove("open"));
        state.items = [...CORE_ITEM_NAMES].filter(n => ITEM_TIER[n] !== "CAPSTONE").slice(0, 40);
        state.lastStation = "The Ocean"; state.visits = 6; state.matChecked = true; state.emptyElements = 1;
        state.lastCheckedMat = state.items.slice(0, 4); state.mat = state.items.slice(2, 8);
        screen = "map"; current = null; render();
        window.twOrder = (id, p, round) => { state.visits = round; state.lastTopStation = "The Ocean";
          state.order = {id, p, round}; openOrderInfo(); };`);
      const st = d.createElement("style");
      st.textContent = `.tw-target [contenteditable]{outline:1px dashed rgba(47,122,79,.6); outline-offset:2px}
        .tw-target.tw-lh :is(p, li, div, span, h2){line-height:var(--tw-lh) !important}
        .tw-target.tw-gap p, .tw-target.tw-gap .mct-line{margin-top:0 !important; margin-bottom:var(--tw-gap) !important}
        .tw-target.tw-fs :is(p, .mct-line, .ct-line, .ct-sub, .ord-desc, #mouseTipText){font-size:var(--tw-fs) !important}`;
      d.head.appendChild(st);
      // While editing, taps place the caret instead of reaching the game.
      d.addEventListener("click", ev => { if (target && target.contains(ev.target) && ev.target.closest("[contenteditable]")) ev.stopPropagation(); }, true);
      d.addEventListener("input", () => { if (cur) { record(); } }, true);
      $("status").textContent = "Ready";
    } catch (e) { $("status").textContent = "Couldn't reach the game frame: " + e.message; }
  }, 1800);
});

function closeAll(){
  w.eval(`document.querySelectorAll(".overlay.open").forEach(o => closeOverlay(o.id));
    hideMouseTip(); document.getElementById("classicTut").classList.remove("open");
    const tc = document.getElementById("tutCoach"); if (tc) tc.classList.remove("open");
    document.getElementById("shutter").classList.remove("on", "closed");
    if (typeof closeDrawer === "function") closeDrawer(); if (jobSheet.classList.contains("open")) closeJobBoard();`);
}
function findTarget(){
  const d = w.document;
  const ct = d.getElementById("classicTut");
  if (ct.classList.contains("open")) return ct.querySelector(".ct-box");
  const mt = d.getElementById("mouseTip");
  if (mt.classList.contains("show")) return mt.querySelector(".mouse-bubble");
  const sh = d.getElementById("shutter");
  if (sh.classList.contains("on")) return sh.querySelector(".sh-label");
  const ov = [...d.querySelectorAll(".overlay.open")].pop();
  return ov ? (ov.querySelector(".sheetbox, .ur-box, .ct-box") || ov) : null;
}
// Text-bearing leaves become editable (not buttons' click handling, see the
// capture listener above).
function makeEditable(el){
  el.querySelectorAll("p, h2, h3, .mct-line, .ct-line, .ct-sub, .ord-desc, #mouseTipText, .sh-l1, .sh-l2, .sh-l3, .lre-line span, .ur-title, .ur-sub, .ur-tap, .cp-celeb, .bigbtn, .end-sec-h, .ct-title")
    .forEach(n => n.setAttribute("contenteditable", "true"));
}
function open(i){
  if (!w) return;
  const t = TIPS[i];
  cur = t[1];
  document.querySelectorAll(".tip").forEach(b => b.classList.toggle("on", +b.dataset.i === i));
  if (target) target.classList.remove("tw-target", "tw-lh", "tw-gap", "tw-fs");
  closeAll();
  setTimeout(() => {
    try { w.eval(t[2]); } catch (e) { $("status").textContent = "Couldn't open: " + e.message; return; }
    setTimeout(() => {
      target = findTarget();
      if (!target) { $("status").textContent = "Window didn't open"; return; }
      // Skip the pop-in animations so the window is still while editing.
      target.getAnimations({subtree: true}).forEach(a => a.finish());
      const e = edits[cur];
      if (e && e.html) target.innerHTML = e.html;
      target.classList.add("tw-target");
      makeEditable(target);
      applyStyles(e || {});
      $("status").textContent = e ? "Showing your edits" : "Original";
    }, 450);
  }, 120);
}
function applyStyles(e){
  [["lh", "--tw-lh", ""], ["gap", "--tw-gap", "px"], ["fs", "--tw-fs", "px"]].forEach(([k, v, u]) => {
    const on = e[k] != null;
    target.classList.toggle("tw-" + k, on);
    if (on) target.style.setProperty(v, e[k] + u);
    $(k).value = on ? e[k] : $(k).min;
    $(k + "O").textContent = on ? e[k] + u : "—";
  });
}
function record(){
  const e = edits[cur] || (edits[cur] = {});
  e.html = target.innerHTML;
  e.text = [...target.querySelectorAll("[contenteditable]")].map(n => n.innerText.trim()).filter(Boolean);
  saveEdits(); markEdited();
  $("status").textContent = "Saved";
}
["lh", "gap", "fs"].forEach(k => $(k).addEventListener("input", () => {
  if (!target || !cur) return;
  const e = edits[cur] || (edits[cur] = {});
  e[k] = +$(k).value;
  applyStyles(e); record();
}));
$("reset").addEventListener("click", () => {
  if (!cur) return;
  delete edits[cur]; saveEdits(); markEdited();
  open(TIPS.findIndex(t => t[1] === cur));
});
$("copy").addEventListener("click", async () => {
  const names = Object.keys(edits);
  if (!names.length) { $("status").textContent = "No changes yet"; return; }
  const out = names.map(n => {
    const e = edits[n], lines = [`## ${n}`];
    if (e.lh != null) lines.push(`line height: ${e.lh}`);
    if (e.gap != null) lines.push(`paragraph gap: ${e.gap}px`);
    if (e.fs != null) lines.push(`text size: ${e.fs}px`);
    if (e.text) lines.push("text:", ...e.text.map(s => "  - " + s.replace(/\n+/g, " / ")));
    return lines.join("\n");
  }).join("\n\n");
  try { await navigator.clipboard.writeText(out); $("status").textContent = `Copied ${names.length} tip${names.length > 1 ? "s" : ""}`; }
  catch (e) { prompt("Copy this:", out); }
});
$("list").addEventListener("click", ev => { const b = ev.target.closest(".tip"); if (b) open(+b.dataset.i); });
</script>
</body></html>
"""


def main():
    import json
    game = SRC.read_text(encoding="utf-8")
    page = PAGE.replace("__TIPS__", json.dumps(TIPS, ensure_ascii=False)).replace(
        "__SRCDOC__", html.escape(game, quote=True))
    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
