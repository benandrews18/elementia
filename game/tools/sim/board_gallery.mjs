// The simulator's best Display Mats, drawn by the game's own Saved Layouts
// list (points, combo chips, card icons) into one self-contained page:
// build/sim_boards.html. Run after run_sim.mjs (needs the game build:
// python build_artifact.py, which deploy.py also runs).
//   node game/tools/sim/board_gallery.mjs [--in tools/sim/out/sim_runs.json]
import { readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { withGame, GAME } from "../headless_game.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const arg = (k, d) => { const i = process.argv.indexOf("--" + k); return i > 0 ? process.argv[i + 1] : d; };
const runs = JSON.parse(readFileSync(arg("in", join(HERE, "out", "sim_runs.json")), "utf8"));
const ORDER = { stationWeek: "Station Week", collector: "Collector", rainbow: "Rainbow", drought: "Drought",
  shortTable: "Short Table", trendShift: "Trend Shift", freshFaces: "Fresh Faces", grand: "Grand Exhibition" };

// Every board check of every run: {run, v, q, o, items}.
const all = runs.flatMap((r, i) => (r.sim.mats || []).map(m => ({ ...m, run: i + 1, caps: r.capstones })));
if (!all.length) throw new Error("no boards: re-run run_sim.mjs (older output didn't keep them)");
const best = (list, n) => [...list].sort((a, b) => b.q - a.q).slice(0, n);
const seen = new Set(), pick = [];
const add = (m, why) => { const k = m.items.slice().sort().join(","); if (seen.has(k)) return; seen.add(k); pick.push({ ...m, why }); };
best(all, 8).forEach(m => add(m, "Top score"));
for (const v of [3, 6, 9, 12, 15, 18, 21]) best(all.filter(m => m.v === v), 2).forEach(m => add(m, `Best at turn ${v}`));
const CAPS = ["Coral Reef", "Robot", "Homestead", "Maglev Train", "Ecosystem", "Fruit Cake", "Metropolis", "Space Station"];
CAPS.forEach(c => { const m = best(all.filter(m => m.items.includes(c)), 1)[0]; if (m) add(m, `Best with ${c}`); });
const layouts = pick.map(m => ({ name: `${m.why} · ${m.q.toLocaleString()} at turn ${m.v}${m.o && m.o !== "grand" ? ` (${ORDER[m.o] || m.o})` : ""} · run ${m.run}`, items: m.items }));

const { styles, body } = await withGame(async evalJS => {
  await evalJS(`(() => {
    state = freshState(); state.mode = "classic"; state.visits = 24; // full-size mat, no challenge
    prefs.savedMatLayouts = ${JSON.stringify(layouts)};
    renderMatLayoutsList();
  })()`);
  return evalJS(`({
    styles: [...document.querySelectorAll("style")].map(s => s.textContent).join(String.fromCharCode(10)),
    body: document.getElementById("matLayoutsList").innerHTML,
  })`);
}, { http: 8794, cdp: 9342, page: "build/elementia_artifact.html" });

// Each icon is a data URI repeated on every card that shows it: keep one
// copy of each and fill the images in on load.
const uris = [];
const slim = body.replace(/src="(data:[^"]+)"/g, (_, u) => {
  let i = uris.indexOf(u); if (i < 0) i = uris.push(u) - 1;
  return `data-u="${i}"`;
});
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Simulator Display Mats</title>
<style>${styles}</style>
<style>
  body{overflow:auto !important; background:#0f2733}
  .sim-wrap{max-width:480px; margin:0 auto; padding:18px 16px 40px}
  .sim-wrap h1{font-size:22px; margin:0 0 4px; color:#e8edf4}
  .sim-wrap p.note{color:#b3becd; font-size:13px; line-height:1.5; margin:0 0 14px}
  .ml-del{display:none !important}
  .sim-wrap, .sim-wrap *{visibility:visible !important} /* the game hides #matLayoutsOverlay until opened */
</style></head>
<body><div class="sim-wrap" id="matLayoutsOverlay">
  <h1>💾 Simulator Display Mats</h1>
  <p class="note">${runs.length} simulated runs. The gold badge is each mat's score with today's rules (full-size mat, no challenge). The title gives the score the simulator got at that board check, which includes that check's challenge (×1.5 / ×0.75). Sorted by the badge.</p>
  <div id="matLayoutsList">${slim}</div>
</div>
<script>const U = ${JSON.stringify(uris)}; document.querySelectorAll("[data-u]").forEach(i => i.src = U[+i.dataset.u]);</script>
</body></html>`;
writeFileSync(join(GAME, "build", "sim_boards.html"), html);
console.log(`${pick.length} boards -> build/sim_boards.html (${Math.round(html.length / 1024)} KB)`);
