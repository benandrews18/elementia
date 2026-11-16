// Side-by-side screen comparison (PLAN.md, "Screen comparison"): each shot
// is drawn in the HTML game (headless Chrome) and in Godot at 390x844, 2x;
// godot/build/compare.html shows both pictures plus every tagged element
// whose position or size differs by more than TOL px.
//   node godot/tools/compare.mjs [shot name ...]
// Elements are matched by name: data-cmp in the HTML page (tagged by each
// shot's `open` script), meta "cmp" on a Godot node (tests/shot.gd --rects).
import { spawnSync } from "node:child_process";
import { writeFileSync, readFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { htmlShot } from "./html_shot.mjs";

const GODOT_DIR = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(GODOT_DIR, "build");
const GODOT = process.env.GODOT || "C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe";
const TOL = 2;
mkdirSync(OUT, { recursive: true });

// Tags an item card's parts (matCardHTML()) by the card's name.
const TAG_CARDS = `(root => root.querySelectorAll(".mm-card").forEach(c => {
  const n = c.dataset.matCard;
  c.dataset.cmp = n;
  const tag = (sel, k) => { const e = c.querySelector(sel); if (e) e.dataset.cmp = n + ":" + k; };
  tag(".mm-pts", "pts"); tag(".mm-icon img, .mm-icon svg", "icon"); tag(".mm-name", "name"); tag(".mm-stations", "stations");
  c.querySelectorAll(".mm-pip").forEach((p, i) => p.dataset.cmp = n + ":pip" + i);
  c.querySelectorAll(".mm-station").forEach((b, i) => { b.dataset.cmp = n + ":st" + i; const im = b.querySelector("img,svg"); if (im) im.dataset.cmp = n + ":st" + i + "icon"; });
}))`;
const RECTS = `Object.fromEntries([...document.querySelectorAll("[data-cmp]")].filter(e => e.getClientRects().length)
  .map(e => { const r = e.getBoundingClientRect(); return [e.dataset.cmp, [r.x, r.y, r.width, r.height].map(v => Math.round(v * 10) / 10)]; }))`;

// ---- the shots
const gallery = { tiers: [["Water", "Sand", "Clay", "Steel", "Soil"], ["Battery", "Magnet", "Glass", "Dough"],
  ["Fossil", "Light Bulb", "Log Cabin", "Rocket"], ["Coral Reef", "Fruit Cake"]] };
writeFileSync(join(OUT, "gallery_items.json"), JSON.stringify(gallery));
// A mid-run mat (a recorded run's visit-18 board check, grown to full size),
// kept as a fixture so screenshots stay comparable after goldens are re-recorded.
const MAT_STATE = join(GODOT_DIR, "tests", "fixtures", "mat_visit18.json");

const SHOTS = [
  { name: "gallery", note: "Item cards as the Inventory grid shows them, and the Crafting Bench",
    open: `(() => {
      const tiers = ${JSON.stringify(gallery.tiers)};
      state.mat = [];
      const box = document.createElement("div");
      box.style.cssText = "position:fixed;left:0;top:0;width:390px;height:844px;z-index:99999;background:var(--bg);padding:12px;overflow:hidden";
      box.innerHTML = '<div style="container-type:inline-size">' + tiers.map(names => {
        const t1 = MAT_CARD_BY_NAME[names[0]].tier === "MATERIAL";
        return '<div class="mat-tier-section"><div class="mat-results-grid ' + (t1 ? "half" : "") + '">' +
          names.map(n => matCardHTML(n, { tray: true, complete: n === "Light Bulb", cls: t1 ? "small mini" : "small" })).join("") + "</div></div>";
      }).join("") + '<div class="st-card-sel" data-cmp="bench" style="margin-top:14px"><div data-cmp="bench:content" style="height:80px"></div></div></div>';
      document.body.appendChild(box);
      ${TAG_CARDS}(box);
    })()`,
    godot: ["--screen", "res://tests/gallery.gd", "--items", join(OUT, "gallery_items.json")] },
  { name: "mat", note: "The Display Mat at the visit-18 board check of recorded run 1", snap: MAT_STATE,
    open: `(() => {
      openDrawer();
      const top = document.getElementById("drawerTop");
      const tag = (sel, k) => top.querySelectorAll(sel).forEach((e, i) => e.dataset.cmp = k.replace("#", i));
      tag(".qm-total", "qm:total"); tag(".qm-seg", "qm:seg#"); tag(".qm-seg-label", "qm:label#");
      tag(".qm-break .qm-break-dice, .qm-break .empty-el-square", "qm:break#");
      tag(".mat-combos .mm-combo", "chip#"); tag(".mat-zone-page", "mat:page");
      ${TAG_CARDS}(document.getElementById("matGrid"));
    })()`,
    godot: ["--screen", "res://ui/screens/display_mat.gd", "--save", MAT_STATE] },
];

// ---- run each shot on both sides
const pick = process.argv.slice(2);
const results = [];
for (const shot of SHOTS.filter(s => !pick.length || pick.includes(s.name))) {
  const snap = shot.snap ? JSON.parse(readFileSync(shot.snap, "utf8")) : null;
  const html = await htmlShot(snap, shot.open, { rectsJS: RECTS });
  if (html.errs.length) console.log(`${shot.name}: page errors`, html.errs);
  writeFileSync(join(OUT, `${shot.name}_html.png`), html.png);
  const gRects = join(OUT, `${shot.name}_godot.json`);
  const r = spawnSync(GODOT, ["--path", GODOT_DIR, "--quit-after", "300", "res://tests/shot.tscn", "--",
    ...shot.godot, "--out", join(OUT, `${shot.name}_godot.png`), "--scale", "2", "--rects", gRects], { encoding: "utf8" });
  if (r.status !== 0) { console.log(r.stdout, r.stderr); process.exit(1); }
  const godot = JSON.parse(readFileSync(gRects, "utf8"));
  const rows = [];
  let untagged = 0; // parts Godot names that this shot doesn't tag in the HTML page
  for (const k of new Set([...Object.keys(html.rects), ...Object.keys(godot)])) {
    const a = html.rects[k], b = godot[k];
    if (!a) { untagged++; continue; }
    if (!b) { rows.push([k, "only in HTML", a, b]); continue; }
    const d = a.map((v, i) => Math.round((b[i] - v) * 10) / 10);
    if (d.some(v => Math.abs(v) > TOL)) rows.push([k, "dx dy dw dh " + d.join(" "), a, b]);
  }
  results.push({ shot, rows });
  console.log(`${shot.name}: ${Object.keys(html.rects).length} HTML elements checked (${untagged} more in Godot not tagged in HTML); ${rows.length} differ by > ${TOL}px`);
  rows.slice(0, 24).forEach(r => console.log("  " + r[0].padEnd(26) + r[1]));
}

const page = `<!doctype html><meta charset="utf-8"><title>Elementia: HTML vs Godot</title>
<style>body{background:#0b1d26;color:#e8edf4;font:14px system-ui;margin:16px} .pair{display:flex;gap:16px;flex-wrap:wrap}
figure{margin:0} img{width:390px;border:1px solid #2a5a72} td,th{padding:2px 8px;text-align:left;font-variant-numeric:tabular-nums}</style>
${results.map(({ shot, rows }) => `<h1>${shot.name}: HTML (left) vs Godot (right)</h1><p>${shot.note}</p>
<div class="pair"><figure><img src="${shot.name}_html.png"><figcaption>HTML game</figcaption></figure>
<figure><img src="${shot.name}_godot.png"><figcaption>Godot</figcaption></figure></div>
<h2>${rows.length} elements off by more than ${TOL}px</h2>
<table><tr><th>element</th><th>difference (Godot − HTML)</th><th>HTML x y w h</th><th>Godot x y w h</th></tr>
${rows.map(r => `<tr><td>${r[0]}</td><td>${r[1]}</td><td>${r[2] || ""}</td><td>${r[3] || ""}</td></tr>`).join("")}</table>`).join("")}`;
writeFileSync(join(OUT, "compare.html"), page);
console.log("-> " + join(OUT, "compare.html"));
