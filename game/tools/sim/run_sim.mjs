// Plays whole Elementia runs with the real game code (headless Chrome) and
// a goal-directed player guided by real play (tools/sim/guide/), then
// compares them with the real runs.
//   node game/tools/sim/run_sim.mjs [--runs 100] [--seed 1] [--start guided|random|capstone] [--out file.json]
// guide/: every runs*.json (History exports: ⧉ Export or one run's ⧉) and
// layouts*.json (Saved Layouts ⧉). Each file holds one export as copied --
// a list or a single run -- and repeats across files are dropped.
// Writes every simulated run (History export format, plus `sim`) to --out
// (default tools/sim/out/sim_runs.json), the Breakpoint Tuner's data
// (out/tuner_data.js, and build/breakpoint_tuner.html with it built in), and
// prints the comparison.
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { withGame, GAME } from "../headless_game.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const arg = (k, d) => { const i = process.argv.indexOf("--" + k); return i > 0 ? process.argv[i + 1] : d; };
const RUNS = +arg("runs", 100), SEED = +arg("seed", 1), START = arg("start", "guided");
const OUT = arg("out", join(HERE, "out", "sim_runs.json"));
const readGuide = prefix => readdirSync(join(HERE, "guide")).filter(f => f.startsWith(prefix) && f.endsWith(".json"))
  .flatMap(f => [JSON.parse(readFileSync(join(HERE, "guide", f), "utf8"))].flat());
const uniq = (list, key) => [...new Map(list.map(x => [key(x), x])).values()];
const guide = {
  // Only runs with board-check scores (History from 2026-11-12 on).
  runs: uniq(readGuide("runs").filter(r => Array.isArray(r.checks) && r.checks.some(c => c.q != null) && Array.isArray(r.visitLog)), r => r.date),
  layouts: uniq(readGuide("layouts").filter(l => l && Array.isArray(l.items)), l => l.name + "|" + l.items.join(",")),
};
console.log(`guide: ${guide.runs.length} of your runs, ${guide.layouts.length} saved layouts`);

const BATCH = 10;
const t0 = Date.now();
const { sims, tiers, errs } = await withGame(async (evalJS, errs) => {
  await evalJS(`window.SIM_GUIDE = ${JSON.stringify(guide)};`);
  await evalJS(readFileSync(join(HERE, "sim_agent.js"), "utf8"));
  const sims = [];
  for (let i = 0; i < RUNS; i += BATCH) {
    const n = Math.min(BATCH, RUNS - i);
    sims.push(...await evalJS(`simPlay(${n}, ${JSON.stringify({ seed: SEED * 100003 + i, start: START, index: i })})`));
    process.stderr.write(`\r${sims.length}/${RUNS} runs`);
  }
  process.stderr.write("\n");
  return { sims, tiers: await evalJS("simTiers()"), errs };
}, { http: 8793, cdp: 9341 });

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(sims, null, 1));
// Breakpoint Tuner data (normal guided runs only): every sim run's mat score
// leaving each turn (sorted, per turn) and your runs' board checks.
if (START === "guided"){
  const tunerData = {
    made: new Date().toISOString().slice(0, 16).replace("T", " "), simRuns: sims.length,
    sim: Array.from({ length: 24 }, (_, i) => sims.map(r => r.sim.q[i]).filter(q => q != null).sort((a, b) => a - b)),
    you: guide.runs.map(r => ({ d: r.date.slice(0, 16).replace("T", " "), s: r.score, caps: r.capstones.length,
      checks: r.checks.filter(c => c.q != null).map(c => [c.v, c.q]) })),
  };
  const dataJS = `window.TUNER_DATA = ${JSON.stringify(tunerData)};`;
  writeFileSync(join(HERE, "out", "tuner_data.js"), dataJS);
  const tuner = readFileSync(join(GAME, "tools", "quark_breakpoint_tuner.html"), "utf8");
  const tag = '<script src="sim/out/tuner_data.js"></script>';
  if (!tuner.includes(tag)) throw new Error("tuner data tag missing");
  mkdirSync(join(GAME, "build"), { recursive: true });
  writeFileSync(join(GAME, "build", "breakpoint_tuner.html"), tuner.replace(tag, () => "<script>" + dataJS + "</script>"));
}

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
