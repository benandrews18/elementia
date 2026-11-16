// Records "golden" steps from the HTML game for the Godot parity test
// (PLAN.md, "Rules parity"). The simulator's player (game/tools/sim/
// sim_agent.js) plays whole runs through the game's own rule functions; each
// call to one of ACTIONS is recorded as state before, arguments, the random
// numbers it drew, and state after. Nested calls (confirmLockIn ->
// finishLockIn -> goStation) belong to the outer step.
//   node godot/tools/record_golden.mjs [--runs 24] [--seed 7] [--start capstone|random|guided]
// (capstone: run i chases capstone i % 8, so every capstone rule is played)
// Writes godot/tests/goldens/run_<i>.json (not committed: re-record after any
// rule change in game/js).
import { readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { withGame, GAME } from "../../game/tools/headless_game.mjs";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "tests", "goldens");
const arg = (k, d) => { const i = process.argv.indexOf("--" + k); return i > 0 ? process.argv[i + 1] : d; };
const RUNS = +arg("runs", 24), SEED = +arg("seed", 7), START = arg("start", "capstone");
// The rule functions the sim player calls (see sim_agent.js playRun()).
const ACTIONS = ["goStation", "doRoll", "craft", "startCheckOrder", "confirmLockIn", "quietCheck",
  "goMap", "confirmFinalLockIn", "setBingoCenter"];

const runs = await withGame(async (evalJS, errs) => {
  await evalJS("window.SIM_GUIDE = {runs: [], layouts: []};");
  await evalJS(readFileSync(join(GAME, "tools", "sim", "sim_agent.js"), "utf8"));
  // Installed after the sim, so it wraps the sim's seeded Math.random and
  // the real rule functions (the sim calls them by global name).
  await evalJS(`(() => {
    // Globals outside \`state\` that the actions read.
    const snap = () => JSON.parse(JSON.stringify({ state, ctx: { current, screen, travelPromptFor, selectedMapStation, lockInCommitted } }));
    let depth = 0, rand = null;
    window.GOLDEN = [];
    const random = Math.random;
    Math.random = () => { const r = random(); if (rand) rand.push(r); return r; };
    for (const name of ${JSON.stringify(ACTIONS)}) {
      const fn = window[name];
      window[name] = function (...args) {
        if (depth++ > 0) { try { return fn.apply(this, args); } finally { depth--; } }
        const before = snap(); rand = [];
        try { return fn.apply(this, args); }
        finally {
          // craft() takes an item entry: record its name (Godot looks it up).
          const a = args.map(x => x && typeof x === "object" && x.name ? { entry: x.name } : x);
          GOLDEN.push({ fn: name, args: JSON.parse(JSON.stringify(a)), before, rand, after: snap() });
          rand = null; depth--;
        }
      };
    }
  })()`);
  const runs = [];
  for (let i = 0; i < RUNS; i++) {
    await evalJS(`prefs.classicBingo = false; GOLDEN.length = 0; simPlay(1, {seed: ${SEED * 1000 + i}, start: "${START}", index: ${i}})`);
    // The trophies the HTML game awards this run, with varied across-run
    // totals (prefs) so the milestone and collection trophies get tested.
    await evalJS(`(() => {
      const ids = MAT_COLLECTIONS.map(c => c.id);
      prefs.lifetime = { runs: ${i * 5}, items: ${i * 100}, capCount: ${i}, caps: CAPSTONES.slice(0, ${i % 9}) };
      prefs.everUnlockedMatCollections = ids.slice(0, ${i * 3});
      GOLDEN.push({ fn: "__trophies", allIds: TROPHIES.map(t => t.id),
        before: JSON.parse(JSON.stringify({ state, prefs: { lifetime: prefs.lifetime,
          everUnlockedMatCollections: prefs.everUnlockedMatCollections, playDays: prefs.playDays } })),
        earned: TROPHIES.filter(t => t.test(state)).map(t => t.id) });
    })()`);
    runs.push(await evalJS("GOLDEN"));
  }
  if (errs.length) throw new Error("page errors:\n" + errs.join("\n"));
  return runs;
}, { http: 8794, cdp: 9342 });

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
runs.forEach((steps, i) => writeFileSync(join(OUT, `run_${i}.json`), JSON.stringify(steps)));
const count = {};
runs.flat().forEach(s => count[s.fn] = (count[s.fn] || 0) + 1);
console.log(`${runs.length} runs, ${runs.flat().length} steps -> ${OUT}`);
console.log("  " + Object.entries(count).map(([k, n]) => `${k} ${n}`).join(", "));
