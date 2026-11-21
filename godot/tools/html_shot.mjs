// Screenshot of the HTML game in a given state: a golden step's "before"
// (or any {state, ctx}) loaded, then a snippet run to open a screen.
//   node godot/tools/html_shot.mjs <state.json> <out.png> "<js to open the screen>"
// Also used by compare.mjs. Prints the page's errors, if any.
import { readFileSync, writeFileSync } from "node:fs";
import { withGame, wait } from "../../game/tools/headless_game.mjs";

export async function htmlShot(snap, open, { rectsJS = "({})", http = 8797, cdp = 9345, keep = [] } = {}) {
  return withGame(async (evalJS, errs, send) => {
    await send("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
    await evalJS(`(() => {
      const s = ${JSON.stringify(snap)};
      if (s) state = Object.assign(freshState(), s.state || s);
      const c = (s && s.ctx) || {};
      current = c.current ?? null; screen = c.screen || "map";
      travelPromptFor = c.travelPromptFor ?? null; selectedMapStation = c.selectedMapStation ?? null;
      prefs.everUnlockedMatCollections = MAT_COLLECTIONS.map(c => c.id); // no "New collection!" pop-ups
      document.getElementById("tour").style.display = "none"; // the home screen, as the smoke test does
      document.querySelectorAll(".overlay.open").forEach(o => closeOverlay(o.id));
      save(); render();
    })()`);
    await wait(400);
    await evalJS(open);
    await wait(1200);
    // Tips that pop up over the screen (they'd only show once to a player);
    // `keep`: the overlays the shot itself opened.
    await evalJS(`document.querySelectorAll(".overlay.open").forEach(o => { if (!${JSON.stringify(keep)}.includes(o.id)) closeOverlay(o.id); })`);
    await wait(400);
    const rects = await evalJS(rectsJS);
    const png = Buffer.from((await send("Page.captureScreenshot", { format: "png", clip: { x: 0, y: 0, width: 390, height: 844, scale: 1 } })).result.data, "base64");
    return { png, rects, errs };
  }, { http, cdp });
}

if (process.argv[1] && process.argv[1].endsWith("html_shot.mjs")) {
  const [file, out, open] = process.argv.slice(2);
  const r = await htmlShot(JSON.parse(readFileSync(file, "utf8")), open || "0");
  writeFileSync(out, r.png);
  if (r.errs.length) console.log("page errors:", r.errs);
  console.log("saved", out);
}
