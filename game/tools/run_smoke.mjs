// Runs smoke_classic.js against game/elementia.html in headless Chrome and
// exits non-zero on any page error or a missed step.
//   node game/tools/run_smoke.mjs
// Needs Node 22+ and Chrome (set CHROME=<path> if it isn't in the default spot).
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { withGame, GAME, wait } from "./headless_game.mjs";

let code = 1;
try {
  code = await withGame(async (evalJS, errs) => {
    await evalJS(readFileSync(join(GAME, "tools", "smoke_classic.js"), "utf8"));
    let log = null;
    for (let i = 0; i < 60 && !log; i++) { await wait(1000); log = JSON.parse(await evalJS("JSON.stringify(window.__smoke || null)")); }
    console.log(JSON.stringify(log, null, 1));
    const problems = [...errs, ...(log ? log.errs : ["smoke test never finished"])];
    if (log && !log.rolled) problems.push("never rolled");
    if (log && !log.crafted) problems.push("never crafted");
    if (log && !/^station:/.test(log.afterTravel || "")) problems.push("travel did not reach a station");
    console.log(problems.length ? "FAIL:\n  " + problems.join("\n  ") : "PASS");
    return problems.length ? 1 : 0;
  });
} catch (e) { console.error(e); }
process.exit(code);
