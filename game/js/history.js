/* =====================================================================
   history.js -- Run history: recordHistory() on each finished run, the History
   overlay, and its export.
   ===================================================================== */
let history = [];
// Runs touched by Developer mode (state.dev, see dev.js) are kept apart, so
// testing never mixes into the real History or its exports.
const DEV_HISTORY_KEY = "elementia-devhistory-v1";
const loadDevHistory = () => { try { return JSON.parse(lsGet(DEV_HISTORY_KEY) || "[]"); } catch(e){ return []; } };
// Which list the History window shows: "runs" or (dev mode only) "dev".
let histTab = "runs";
const histRuns = () => histTab === "dev" && prefs.devMode ? loadDevHistory() : history;

function loadHistory(){
  try { history = JSON.parse(lsGet(HISTORY_KEY) || "[]"); } catch(e){ history = []; }
}
function saveHistory(){ lsSet(HISTORY_KEY, JSON.stringify(history)); }
/* Records the run about to be discarded (new run or reset). Skips an
   untouched session. */
function recordHistory(){
  if (state.visits <= 0) return;
  const list = state.dev ? loadDevHistory() : history;
  list.unshift({
    mode: state.mode,
    date: new Date().toISOString(),
    visits: state.visits,
    // The run's score is its top Quark score; item points are itemScore.
    // (Runs recorded before 2026-11-12 have only score = item points.)
    score: Math.round(state.bestMatScore || 0),
    itemScore: score(),
    checks: JSON.parse(JSON.stringify(state.checkLog || [])),
    capstones: CAPSTONES.filter(owns),
    // Deep copy: state is about to be wiped. Per visit: station, rolls, crafts.
    visitLog: JSON.parse(JSON.stringify(state.visitLog || [])),
    // Classic's BINGO card -- context for why items were prioritised.
    bingoCard: state.bingoCard ? [...state.bingoCard] : null,
    bingoLinesCompleted: [...(state.bingoLinesCompleted || [])],
  });
  list.length = Math.min(list.length, HISTORY_MAX);
  if (state.dev){ list[0].dev = true; lsSet(DEV_HISTORY_KEY, JSON.stringify(list)); }
  else saveHistory();
}

let histExpanded = new Set();
// {sym:count} -> "H×2, O" (count shown only above 1). Used by
// histTurnsHTML().
function elementTallyText(elements){
  const syms = Object.keys(elements || {});
  if (!syms.length) return null;
  return syms.map(sym => elements[sym] > 1 ? `${sym}×${elements[sym]}` : sym).join(", ");
}
function histTurnsHTML(h){
  if (!h.visitLog || !h.visitLog.length){
    return '<p class="empty">No turn-by-turn detail recorded for this run.</p>';
  }
  return `<div class="histturns">${h.visitLog.map((t, i) => {
    const st = STATION_BY_NAME[t.station];
    const elementsText = elementTallyText(t.elements);
    return `<div class="histturn">
      <div class="histturn-head">
        <span class="histturn-n">${i + 1}</span>
        <span class="histturn-station">${st ? em(st.emoji) : ""} ${esc(t.station)}</span>
      </div>
      <div class="histturn-line"><span class="histturn-label">Collected</span> ${elementsText ? esc(elementsText) : '<span class="histnone">—</span>'}</div>
      <div class="histturn-line"><span class="histturn-label">Crafted</span> ${t.items.length ? esc(t.items.join(", ")) : '<span class="histnone">—</span>'}</div>
    </div>`;
  }).join("")}</div>`;
}
function renderHistory(){
  const list = document.getElementById("historyList");
  const tabs = document.getElementById("historyTabs");
  tabs.hidden = !prefs.devMode;
  tabs.innerHTML = prefs.devMode ? ["runs", "dev"].map(t =>
    `<button type="button" class="hist-tab${histTab === t ? " on" : ""}" data-hist-tab="${t}">${t === "dev" ? "🛠 Dev runs" : "Runs"}</button>`).join("") : "";
  const runs = histRuns();
  if (!runs.length){
    list.innerHTML = histTab === "dev" && prefs.devMode
      ? '<p class="empty">No dev runs yet -- runs you change with the Dev Panel land here when they end.</p>'
      : '<p class="empty">No finished runs yet — they show up here once you start a new session.</p>';
    return;
  }
  list.innerHTML = `<div class="histrows">${runs.map((h, i) => {
    const open = histExpanded.has(i);
    return `<div class="histentry">
      <div class="histrow-line">
        <button type="button" class="histrow" data-hist-toggle="${i}" aria-expanded="${open}">
          <span class="histvisits">${h.visits} turn${h.visits === 1 ? "" : "s"}</span>
          <span class="histscore">${h.itemScore !== undefined ? `⚛️ ${h.score.toLocaleString()}` : `${h.score} pts`}</span>
          <span class="histcaps">${h.capstones.length
            ? h.capstones.map(n => em(ITEM_EMOJI[n])).join("")
            : '<span class="histnone">—</span>'}</span>
          <span class="histarrow">${open ? "▾" : "▸"}</span>
        </button>
        <button type="button" class="histrow-export" data-hist-export="${i}" title="Copy just this run as JSON" aria-label="Export this run">⧉</button>
      </div>
      <div class="histdetail" ${open ? "" : "hidden"}>${open ? histTurnsHTML(h) : ""}</div>
    </div>`;
  }).join("")}</div>`;
}

document.getElementById("historyBtn").addEventListener("click", () => {
  renderHistory();
  openOverlay("history");
});
document.getElementById("modeHistoryBtn").addEventListener("click", () => {
  renderHistory();
  openOverlay("history");
});
document.getElementById("historyClose").addEventListener("click", () => closeOverlay("history"));
document.getElementById("historyTabs").addEventListener("click", ev => {
  const b = ev.target.closest("[data-hist-tab]");
  if (!b) return;
  histTab = b.dataset.histTab; histExpanded = new Set();
  renderHistory();
});
document.getElementById("historyList").addEventListener("click", ev => {
  // Per-run export: just this run as JSON (the same shape #historyExport
  // uses for every run).
  const exportBtn = ev.target.closest("[data-hist-export]");
  if (exportBtn){
    const h = histRuns()[+exportBtn.dataset.histExport];
    if (!h) return;
    const json = JSON.stringify(h, null, 2);
    navigator.clipboard.writeText(json).then(() => {
      exportBtn.textContent = "✓";
      exportBtn.classList.add("done");
    }).catch(() => window.prompt("Copy this text:", json));
    setTimeout(() => { exportBtn.textContent = "⧉"; exportBtn.classList.remove("done"); }, 1800);
    return;
  }
  const btn = ev.target.closest("[data-hist-toggle]");
  if (!btn) return;
  const i = +btn.dataset.histToggle;
  if (histExpanded.has(i)) histExpanded.delete(i); else histExpanded.add(i);
  renderHistory();
});
// Whole history as pretty-printed JSON for analysis elsewhere. Falls back
// to manual selection if the clipboard API is unavailable.
document.getElementById("historyExport").addEventListener("click", async () => {
  const btn = document.getElementById("historyExport");
  const json = JSON.stringify(histRuns(), null, 2);
  try {
    await navigator.clipboard.writeText(json);
    btn.textContent = "✓ Copied!";
    btn.classList.add("done");
  } catch (e){
    window.prompt("Copy this text:", json);
  }
  setTimeout(() => { btn.textContent = "⧉ Export"; btn.classList.remove("done"); }, 1800);
});
