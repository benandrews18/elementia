// Side-by-side screen comparison (PLAN.md, "Screen comparison"): draws the
// same thing in the HTML game (headless Chrome) and in Godot at 390x844, 2x,
// and writes godot/build/compare.html with both pictures plus every tagged
// element whose position or size differs by more than TOL px.
//   node godot/tools/compare.mjs
// Elements are matched by name: data-cmp in the HTML page, meta "cmp" on a
// Godot node (tests/shot.gd --rects).
import { spawnSync } from "node:child_process";
import { writeFileSync, readFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { withGame, wait } from "../../game/tools/headless_game.mjs";

const GODOT_DIR = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(GODOT_DIR, "build");
const GODOT = process.env.GODOT || "C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe";
const TOL = 2;
mkdirSync(OUT, { recursive: true });

// ---- the gallery: item cards as the Inventory grid shows them, by tier
const items = { tiers: [["Water", "Sand", "Clay", "Steel", "Soil"], ["Battery", "Magnet", "Glass", "Dough"],
  ["Fossil", "Light Bulb", "Log Cabin", "Rocket"], ["Coral Reef", "Fruit Cake"]] };
writeFileSync(join(OUT, "gallery_items.json"), JSON.stringify(items));
const galleryHTML = `(() => {
  const tiers = ${JSON.stringify(items.tiers)};
  state.mat = [];
  const box = document.createElement("div");
  box.style.cssText = "position:fixed;left:0;top:0;width:390px;height:844px;z-index:99999;background:var(--bg);padding:12px;overflow:hidden";
  box.innerHTML = '<div style="container-type:inline-size">' + tiers.map(names => {
    const t1 = MAT_CARD_BY_NAME[names[0]].tier === "MATERIAL";
    return '<div class="mat-tier-section"><div class="mat-results-grid ' + (t1 ? "half" : "") + '">' +
      names.map(n => matCardHTML(n, { tray: true, complete: n === "Light Bulb", cls: t1 ? "small mini" : "small" })).join("") + "</div></div>";
  }).join("") + '<div class="st-card-sel" data-cmp="bench" style="margin-top:14px"><div data-cmp="bench:content" style="height:80px"></div></div></div>';
  document.body.appendChild(box);
  box.querySelectorAll(".mm-card").forEach(c => {
    const n = c.dataset.matCard;
    c.dataset.cmp = n;
    const tag = (sel, k) => { const e = c.querySelector(sel); if (e) e.dataset.cmp = n + ":" + k; };
    tag(".mm-pts", "pts"); tag(".mm-icon img, .mm-icon svg", "icon"); tag(".mm-name", "name"); tag(".mm-stations", "stations");
    c.querySelectorAll(".mm-pip").forEach((p, i) => p.dataset.cmp = n + ":pip" + i);
    c.querySelectorAll(".mm-station").forEach((b, i) => { b.dataset.cmp = n + ":st" + i; const im = b.querySelector("img,svg"); if (im) im.dataset.cmp = n + ":st" + i + "icon"; });
  });
})()`;

// ---- HTML side
const html = await withGame(async (evalJS, errs, send) => {
  await send("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  await evalJS(galleryHTML);
  await wait(800);
  const rects = await evalJS(`Object.fromEntries([...document.querySelectorAll("[data-cmp]")].filter(e => e.offsetParent || e.getClientRects().length)
    .map(e => { const r = e.getBoundingClientRect(); return [e.dataset.cmp, [r.x, r.y, r.width, r.height].map(v => Math.round(v * 10) / 10)]; }))`);
  const shot = (await send("Page.captureScreenshot", { format: "png", clip: { x: 0, y: 0, width: 390, height: 844, scale: 1 } })).result.data;
  if (errs.length) console.log("page errors:", errs);
  return { rects, png: Buffer.from(shot, "base64") };
}, { http: 8796, cdp: 9344 });
writeFileSync(join(OUT, "gallery_html.png"), html.png);

// ---- Godot side
const gRects = join(OUT, "gallery_godot.json"), gPng = join(OUT, "gallery_godot.png");
const r = spawnSync(GODOT, ["--path", GODOT_DIR, "--quit-after", "300", "res://tests/shot.tscn", "--",
  "--screen", "res://tests/gallery.gd", "--out", gPng, "--scale", "2", "--rects", gRects, "--items", join(OUT, "gallery_items.json")],
  { encoding: "utf8" });
if (r.status !== 0) { console.log(r.stdout, r.stderr); process.exit(1); }
const godot = JSON.parse(readFileSync(gRects, "utf8"));

// ---- differences
const rows = [];
for (const k of new Set([...Object.keys(html.rects), ...Object.keys(godot)])) {
  const a = html.rects[k], b = godot[k];
  if (!a || !b) { rows.push([k, a ? "only in HTML" : "only in Godot", a, b]); continue; }
  const d = a.map((v, i) => Math.round((b[i] - v) * 10) / 10);
  if (d.some(v => Math.abs(v) > TOL)) rows.push([k, "dx dy dw dh " + d.join(" "), a, b]);
}
const page = `<!doctype html><meta charset="utf-8"><title>Elementia: HTML vs Godot</title>
<style>body{background:#0b1d26;color:#e8edf4;font:14px system-ui;margin:16px} .pair{display:flex;gap:16px;flex-wrap:wrap}
figure{margin:0} img{width:390px;border:1px solid #2a5a72} td,th{padding:2px 8px;text-align:left;font-variant-numeric:tabular-nums}</style>
<h1>Gallery: HTML (left) vs Godot (right)</h1>
<div class="pair"><figure><img src="gallery_html.png"><figcaption>HTML game</figcaption></figure>
<figure><img src="gallery_godot.png"><figcaption>Godot</figcaption></figure></div>
<h2>${rows.length} elements off by more than ${TOL}px</h2>
<table><tr><th>element</th><th>difference (Godot − HTML)</th><th>HTML x y w h</th><th>Godot x y w h</th></tr>
${rows.map(r => `<tr><td>${r[0]}</td><td>${r[1]}</td><td>${r[2] || ""}</td><td>${r[3] || ""}</td></tr>`).join("")}</table>`;
writeFileSync(join(OUT, "compare.html"), page);
console.log(`${Object.keys(html.rects).length} HTML elements, ${Object.keys(godot).length} Godot; ${rows.length} differ by > ${TOL}px -> ${join(OUT, "compare.html")}`);
rows.slice(0, 25).forEach(r => console.log("  " + r[0].padEnd(24) + r[1]));
