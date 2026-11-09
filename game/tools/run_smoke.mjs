// Runs smoke_classic.js against game/elementia.html in headless Chrome and
// exits non-zero on any page error or a missed step.
//   node game/tools/run_smoke.mjs
// Needs Node 22+ and Chrome (set CHROME=<path> if it isn't in the default spot).
import { spawn } from "node:child_process";
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const GAME = join(dirname(fileURLToPath(import.meta.url)), "..");
const CHROME = process.env.CHROME || "C:/Program Files/Google/Chrome/Application/chrome.exe";
const HTTP = 8791, CDP = 9339;
const wait = ms => new Promise(r => setTimeout(r, ms));
const profile = mkdtempSync(join(tmpdir(), "elementia-smoke-"));
const server = spawn("python", ["-m", "http.server", String(HTTP)], { cwd: GAME, stdio: "ignore" });
const chrome = spawn(CHROME, ["--headless=new", "--disable-gpu", `--remote-debugging-port=${CDP}`,
  `--user-data-dir=${profile}`, "about:blank"], { stdio: "ignore" });
const done = code => { chrome.kill(); server.kill(); setTimeout(() => { try { rmSync(profile, { recursive: true, force: true }); } catch {} process.exit(code); }, 500); };

try {
  let tabs;
  for (let i = 0; i < 60 && !tabs; i++) { try { tabs = await (await fetch(`http://127.0.0.1:${CDP}/json`)).json(); } catch { await wait(250); } }
  const ws = new WebSocket(tabs.find(t => t.type === "page").webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);
  let id = 0; const pending = {}; const errs = [];
  ws.onmessage = m => {
    const d = JSON.parse(m.data);
    if (d.id && pending[d.id]) { pending[d.id](d); delete pending[d.id]; }
    if (d.method === "Runtime.exceptionThrown") errs.push(d.params.exceptionDetails.exception?.description || d.params.exceptionDetails.text);
  };
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pending[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
  const evalJS = async expression => (await send("Runtime.evaluate", { expression, returnByValue: true })).result.result.value;
  await send("Runtime.enable");
  await send("Page.navigate", { url: `http://127.0.0.1:${HTTP}/elementia.html` });
  await wait(3000);
  await evalJS("localStorage.clear(); sessionStorage.clear(); location.reload()");
  await wait(3000);
  await evalJS(readFileSync(join(GAME, "tools", "smoke_classic.js"), "utf8"));
  let log = null;
  for (let i = 0; i < 60 && !log; i++) { await wait(1000); log = JSON.parse(await evalJS("JSON.stringify(window.__smoke || null)")); }
  console.log(JSON.stringify(log, null, 1));
  const problems = [...errs, ...(log ? log.errs : ["smoke test never finished"])];
  if (log && !log.rolled) problems.push("never rolled");
  if (log && !log.crafted) problems.push("never crafted");
  if (log && !/^station:/.test(log.afterTravel || "")) problems.push("travel did not reach a station");
  console.log(problems.length ? "FAIL:\n  " + problems.join("\n  ") : "PASS");
  done(problems.length ? 1 : 0);
} catch (e) { console.error(e); done(1); }
