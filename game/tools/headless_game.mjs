// Opens game/elementia.html in headless Chrome (fresh profile, local http
// server) and hands back evalJS(expression) -> value. Shared by the smoke
// test and the simulator.
// Needs Node 22+ and Chrome (set CHROME=<path> if it isn't in the default spot).
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

export const GAME = join(dirname(fileURLToPath(import.meta.url)), "..");
const CHROME = process.env.CHROME || "C:/Program Files/Google/Chrome/Application/chrome.exe";
export const wait = ms => new Promise(r => setTimeout(r, ms));

// fn(evalJS, errs, send) runs with the game booted; returns fn's result. errs
// collects uncaught page exceptions; send(method, params) is a raw DevTools
// call (screenshots, viewport size).
// page: which page under game/ to open (default the game itself).
export async function withGame(fn, { http = 8791, cdp = 9339, page = "elementia.html" } = {}) {
  const profile = mkdtempSync(join(tmpdir(), "elementia-headless-"));
  const server = spawn("python", ["-m", "http.server", String(http)], { cwd: GAME, stdio: "ignore" });
  const chrome = spawn(CHROME, ["--headless=new", "--disable-gpu", `--remote-debugging-port=${cdp}`,
    `--user-data-dir=${profile}`, "about:blank"], { stdio: "ignore" });
  try {
    let tabs;
    for (let i = 0; i < 60 && !tabs; i++) { try { tabs = await (await fetch(`http://127.0.0.1:${cdp}/json`)).json(); } catch { await wait(250); } }
    const ws = new WebSocket(tabs.find(t => t.type === "page").webSocketDebuggerUrl);
    await new Promise(r => ws.onopen = r);
    let id = 0; const pending = {}; const errs = [];
    ws.onmessage = m => {
      const d = JSON.parse(m.data);
      if (d.id && pending[d.id]) { pending[d.id](d); delete pending[d.id]; }
      if (d.method === "Runtime.exceptionThrown") errs.push(d.params.exceptionDetails.exception?.description || d.params.exceptionDetails.text);
    };
    const send = (method, params = {}) => new Promise(r => { const i = ++id; pending[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
    const evalJS = async (expression, awaitPromise = false) => {
      const res = (await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise })).result;
      if (res.exceptionDetails) throw new Error(res.exceptionDetails.exception?.description || res.exceptionDetails.text);
      return res.result.value;
    };
    await send("Runtime.enable");
    await send("Page.navigate", { url: `http://127.0.0.1:${http}/${page}` });
    await wait(3000);
    await evalJS("localStorage.clear(); sessionStorage.clear(); location.reload()");
    // Wait for boot, not a fixed time.
    for (let i = 0; i < 60; i++) {
      await wait(500);
      try { if (await evalJS("document.readyState === 'complete' && typeof state !== 'undefined' && typeof render === 'function'")) break; } catch {}
    }
    await wait(500);
    return await fn(evalJS, errs, send);
  } finally {
    chrome.kill(); server.kill();
    await wait(500);
    try { rmSync(profile, { recursive: true, force: true }); } catch {}
  }
}
