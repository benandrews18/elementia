// Plays whole Elementia runs with the real game code (headless Chrome) and
// a goal-directed player guided by real play (tools/sim/guide/), then
// compares them with the real runs.
//   node game/tools/sim/run_sim.mjs [--runs 100] [--seed 1] [--start guided|random] [--out file.json]
// guide/runs.json: History exports (an array; add more runs to it).
// guide/layouts.json: Saved Layouts exports.
// Writes every simulated run (History export format, plus `sim`) to --out
// (default tools/sim/out/sim_runs.json) and prints the comparison.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { withGame } from "../headless_game.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const arg = (k, d) => { const i = process.argv.indexOf("--" + k); return i > 0 ? process.argv[i + 1] : d; };
const RUNS = +arg("runs", 100), SEED = +arg("seed", 1), START = arg("start", "guided");
const OUT = arg("out", join(HERE, "out", "sim_runs.json"));
const guide = {
  runs: JSON.parse(readFileSync(join(HERE, "guide", "runs.json"), "utf8")),
  layouts: JSON.parse(readFileSync(join(HERE, "guide", "layouts.json"), "utf8")),
};

const BATCH = 10;
const t0 = Date.now();
const { sims, tiers, errs } = await withGame(async (evalJS, errs) => {
  await evalJS(`window.SIM_GUIDE = ${JSON.stringify(guide)};`);
  await evalJS(readFileSync(join(HERE, "sim_agent.js"), "utf8"));
  const sims = [];
  for (let i = 0; i < RUNS; i += BATCH) {
    const n = Math.min(BATCH, RUNS - i);
    sims.push(...await evalJS(`simPlay(${n}, ${JSON.stringify({ seed: SEED * 100003 + i, start: START })})`));
    process.stderr.write(`\r${sims.length}/${RUNS} runs`);
  }
  process.stderr.write("\n");
  return { sims, tiers: await evalJS("simTiers()"), errs };
}, { http: 8793, cdp: 9341 });

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(sims, null, 1));

// ---- report
const pct = (a, p) => { if (!a.length) return "-"; const s = [...a].sort((x, y) => x - y); return Math.round(s[Math.min(s.length - 1, Math.floor(p * s.length))]); };
const mean = a => a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0;
const fmt = (a) => a.length ? `${pct(a, .1)} / ${pct(a, .5)} / ${pct(a, .9)}` : "-";
const pad = (s, n) => String(s).padEnd(n);
function summary(runs, label) {
  console.log(`\n== ${label}: ${runs.length} runs ==`);
  const done = runs.filter(r => !(r.sim && r.sim.gameOver));
  console.log(`completed 24 turns: ${done.length}/${runs.length}` + (runs.length > done.length
    ? `  (game over at: ${runs.filter(r => r.sim && r.sim.gameOver).map(r => r.visits).join(", ")})` : ""));
  console.log(`final score (p10 / median / p90): ${fmt(runs.map(r => r.score))}`);
  console.log(`item points: ${fmt(runs.map(r => r.itemScore))}   items crafted: ${fmt(runs.map(r => r.visitLog.flatMap(t => t.items).length))}`);
  console.log(`capstones per run: ${mean(runs.map(r => r.capstones.length)).toFixed(2)}`);
  console.log(pad("check", 7) + pad("Quarks p10/med/p90", 22) + pad("breakpoints (1 2 3 top dice)", 30) + "share reaching 0/1/2/3/top");
  for (let v = 3; v <= 24; v += 3) {
    const qs = runs.map(r => (r.checks.find(c => c.v === v) || {}).q).filter(q => q != null);
    const t = tiers.find(x => x.v === v);
    const bp = [t.one, t.two, t.three, t.four];
    const tierOf = q => bp.filter(b => q >= b).length;
    const share = [0, 1, 2, 3, 4].map(k => Math.round(100 * qs.filter(q => tierOf(q) === k).length / (qs.length || 1)) + "%").join(" ");
    console.log(pad(v, 7) + pad(fmt(qs), 22) + pad(bp.map(Math.round).join(" "), 30) + (v < 24 ? share : `Grand Exhibition 4000: ${Math.round(100 * qs.filter(q => q >= 4000).length / (qs.length || 1))}%`));
  }
  const orders = runs.flatMap(r => r.checks.filter(c => c.o));
  const byKind = {};
  orders.forEach(c => { const k = byKind[c.o] || (byKind[c.o] = [0, 0]); k[0] += c.ok ? 1 : 0; k[1]++; });
  console.log("challenges met: " + Object.entries(byKind).map(([k, [ok, n]]) => `${k} ${ok}/${n}`).join(", "));
}
summary(guide.runs, "Your runs");
summary(sims, "Simulated");
const capCount = {};
sims.forEach(r => r.capstones.forEach(c => capCount[c] = (capCount[c] || 0) + 1));
console.log("\ncapstones crafted (sim): " + Object.entries(capCount).sort((a, b) => b[1] - a[1]).map(([k, n]) => `${k} ${n}`).join(", "));
const planCount = {};
sims.forEach(r => r.sim.plans.forEach(p => planCount[p] = (planCount[p] || 0) + 1));
console.log("plans chased (sim): " + Object.entries(planCount).sort((a, b) => b[1] - a[1]).map(([k, n]) => `${k} ${n}`).join(", "));
console.log(`\n${sims.length} runs in ${((Date.now() - t0) / 1000).toFixed(0)}s -> ${OUT}`);
if (errs.length) { console.log("PAGE ERRORS:\n  " + [...new Set(errs)].slice(0, 10).join("\n  ")); process.exit(1); }
