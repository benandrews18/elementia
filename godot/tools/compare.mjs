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
const TAG_CARDS = `((root, pre = "") => root.querySelectorAll(".mm-card").forEach(c => {
  const n = pre + c.dataset.matCard;
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
      const hub = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      hub("#hub", "hub"); hub("#hubHome", "hub:home"); hub("#hubJobs", "hub:jobs"); hub("#hubInv", "hub:inv");
      hub("#hubMarket", "hub:market"); hub("#hubCodex", "hub:codex");
      ${TAG_CARDS}(document.getElementById("matGrid"));
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "open_panel:drawer", "--save", MAT_STATE] },
  { name: "station", note: "The City at turn 7 of a recorded run, just rolled", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => {
      render();
      const t = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      t("#quarkTopBar", "qtop"); t("#settingsBtn", "settings"); t(".stationhead", "st:head"); t(".station-title-text", "st:title");
      document.querySelectorAll(".gchip").forEach((e, i) => e.dataset.cmp = "st:chip" + i);
      ${TAG_CARDS}(document.querySelector(".st-cards"), "st:");
      document.querySelectorAll(".st-cell").forEach(c => { const n = c.querySelector(".mm-card").dataset.matCard;
        c.querySelector(".st-acts > :first-child").dataset.cmp = "st:pin:" + n; c.querySelector(".craftbtn").dataset.cmp = "st:craft:" + n; });
      const hub = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      hub("#hub", "hub"); hub("#hubHome", "hub:home"); hub("#hubJobs", "hub:jobs"); hub("#hubInv", "hub:inv");
      hub("#hubMarket", "hub:market"); hub("#hubCodex", "hub:codex");
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "map", note: "The map at turn 7 of a recorded run, The Power Plant picked", snap: join(GODOT_DIR, "tests", "fixtures", "map_visit7.json"),
    open: `(() => {
      render();
      const t = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      t("#quarkTopBar", "qtop"); t(".map-card", "map:card"); t(".mn-here-label", "map:here");
      document.querySelectorAll(".map-node").forEach(n => n.dataset.cmp = "map:" + n.dataset.mapNode);
      const hub = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      hub("#hub", "hub"); hub("#hubHome", "hub:home"); hub("#hubJobs", "hub:jobs"); hub("#hubInv", "hub:inv");
      hub("#hubMarket", "hub:market"); hub("#hubCodex", "hub:codex");
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--save", join(GODOT_DIR, "tests", "fixtures", "map_visit7.json")] },
  { name: "bench", note: "The City at turn 7 with Bridge on the Crafting Bench", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => {
      stationCardOpen = "Bridge"; render();
      const t = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      t(".st-card-sel", "bench"); t(".st-card-sel .item", "row:Bridge"); t(".st-card-sel .iname", "row:name");
      t(".st-card-sel .craftbtn", "row:craft"); t(".st-card-sel .shop-pin", "row:pin");
      ${TAG_CARDS}(document.querySelector(".st-cards"), "st:");
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "open_card:Bridge", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "codex", note: "The Items screen (Item Reference) at turn 7 of a recorded run", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => {
      screen = "codex"; current = null; render(true); window.scrollTo(0, 0);
      const t = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      t(".map-head h1", "ref:title"); t("#refFilter", "ref:search"); t("#refSort", "ref:sort");
      t(".ref-pinned-heading", "ref:pinhead");
      document.querySelectorAll(".refrow").forEach((r, i) => { if (i > 5) return; const k = "ref:row" + i; r.dataset.cmp = k;
        const q = (sel, n) => { const e = r.querySelector(sel); if (e) e.dataset.cmp = k + ":" + n; };
        q(".refem", "icon"); q(".refname", "name"); q(".refpts", "pts"); q(".refwhere", "where"); q(".refexpand", "expand"); q(".refpin", "pin"); q(".refsuits", "suits"); });
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "open_items", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "codex_open", note: "The Items screen with Bridge's breakdown open (Item Info from its card)", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { goToRefItem("Bridge"); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "open_items:Bridge", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "settings", keep: ["settings"], note: "Step 3 window: settings", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { openSettings(); const b = document.querySelector("#settings .sheetbox"); if (b) b.dataset.cmp = "win"; document.querySelectorAll("#settings h2").forEach(h => { if (h.offsetParent) h.dataset.cmp = "win:title"; });
      document.querySelectorAll("#settings .setting-row").forEach((r, i) => r.dataset.cmp = "row" + i); document.querySelectorAll("#settings .bigbtn").forEach((r, i) => { if (r.offsetParent) r.dataset.cmp = "btn" + i; }); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "open_settings", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "rules", keep: ["settingsRules"], note: "Step 3 window: rules", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { openSettingsRules(); const b = document.querySelector("#settingsRules .sheetbox"); if (b) b.dataset.cmp = "win"; document.querySelectorAll("#settingsRules h2").forEach(h => { if (h.offsetParent) h.dataset.cmp = "win:title"; });
      document.querySelectorAll("#settingsRules .setting-row").forEach((r, i) => r.dataset.cmp = "row" + i); document.querySelectorAll("#settingsRules .bigbtn").forEach((r, i) => { if (r.offsetParent) r.dataset.cmp = "btn" + i; }); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "open_settings:rules", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "tuts", keep: ["settingsTuts"], note: "Step 3 window: tuts", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { openSettingsScreen("settingsTuts"); const b = document.querySelector("#settingsTuts .sheetbox"); if (b) b.dataset.cmp = "win"; document.querySelectorAll("#settingsTuts h2").forEach(h => { if (h.offsetParent) h.dataset.cmp = "win:title"; });
      document.querySelectorAll("#settingsTuts .setting-row").forEach((r, i) => r.dataset.cmp = "row" + i); document.querySelectorAll("#settingsTuts .bigbtn").forEach((r, i) => { if (r.offsetParent) r.dataset.cmp = "btn" + i; }); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "open_settings:tuts", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "matrules", keep: ["matRulesOverlay"], note: "Step 3 window: matrules", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { openMatRules(); const b = document.querySelector("#matRulesOverlay .sheetbox"); if (b) b.dataset.cmp = "win"; document.querySelectorAll("#matRulesOverlay h2").forEach(h => { if (h.offsetParent) h.dataset.cmp = "win:title"; });
      document.querySelectorAll("#matRulesOverlay .setting-row").forEach((r, i) => r.dataset.cmp = "row" + i); document.querySelectorAll("#matRulesOverlay .bigbtn").forEach((r, i) => { if (r.offsetParent) r.dataset.cmp = "btn" + i; }); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "show_tip:mat_rules", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "matrules2", keep: ["matRulesOverlay"], note: "Step 3 window: matrules2", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { openMatRules(); document.getElementById("matRulesNext").click(); const b = document.querySelector("#matRulesOverlay .sheetbox"); if (b) b.dataset.cmp = "win"; document.querySelectorAll("#matRulesOverlay h2").forEach(h => { if (h.offsetParent) h.dataset.cmp = "win:title"; });
      document.querySelectorAll("#matRulesOverlay .setting-row").forEach((r, i) => r.dataset.cmp = "row" + i); document.querySelectorAll("#matRulesOverlay .bigbtn").forEach((r, i) => { if (r.offsetParent) r.dataset.cmp = "btn" + i; }); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "show_tip:mat_rules2", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "ordertip", keep: ["orderTip"], note: "Step 3 window: ordertip", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { openOrderTip(); const b = document.querySelector("#orderTip .sheetbox"); if (b) b.dataset.cmp = "win"; document.querySelectorAll("#orderTip h2").forEach(h => { if (h.offsetParent) h.dataset.cmp = "win:title"; });
      document.querySelectorAll("#orderTip .setting-row").forEach((r, i) => r.dataset.cmp = "row" + i); document.querySelectorAll("#orderTip .bigbtn").forEach((r, i) => { if (r.offsetParent) r.dataset.cmp = "btn" + i; }); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "show_tip:order", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "eltip", keep: ["emptyElTip"], note: "Step 3 window: eltip", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => { showEmptyElTip(); const b = document.querySelector("#emptyElTip .sheetbox"); if (b) b.dataset.cmp = "win"; document.querySelectorAll("#emptyElTip h2").forEach(h => { if (h.offsetParent) h.dataset.cmp = "win:title"; });
      document.querySelectorAll("#emptyElTip .setting-row").forEach((r, i) => r.dataset.cmp = "row" + i); document.querySelectorAll("#emptyElTip .bigbtn").forEach((r, i) => { if (r.offsetParent) r.dataset.cmp = "btn" + i; }); })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "show_tip:unknown", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "cardpop", keep: ["cardPop"], note: "Bridge's card pop-up (tapped at The City, turn 7)", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => {
      showCardPop(ENTRIES.find(e => e.name === "Bridge"), false);
      const t = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      t("#cpCard", "cp:card"); t("#cpName", "cp:name"); t("#cpIcon img, #cpIcon svg", "cp:icon"); t("#cardPop .pc-badge", "cp:pts");
      t("#cpStationBadge", "cp:station"); t("#cardPop .pc-label", "cp:label"); t("#cardPop .pc-divider", "cp:divider");
      t("#cpTreeBtn", "cp:info"); t("#cpPinBtn", "cp:pin"); t("#cpCloseX", "cp:close");
      document.querySelectorAll("#cpIngredients .pc-ping").forEach((e, i) => e.dataset.cmp = "cp:ing" + i);
      document.querySelectorAll("#cpSuitCosts .pc-suitcost-badge").forEach((e, i) => e.dataset.cmp = "cp:cost" + i);
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "show_card:Bridge", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "cardcap", keep: ["cardPop"], note: "A capstone's card: landscape, with its Display Mat rule", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => {
      showCardPop(ENTRIES.find(e => e.name === "Robot"), false);
      const t = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      t("#cpCard", "cp:card"); t("#cpName", "cp:name"); t("#cpIcon img, #cpIcon svg", "cp:icon"); t("#cpSig", "cp:sig");
      t("#cardPop .pc-label", "cp:label"); t("#cardPop .pc-divider", "cp:divider");
      document.querySelectorAll("#cpIngredients .pc-ping").forEach((e, i) => e.dataset.cmp = "cp:ing" + i);
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "show_card:Robot", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
  { name: "elcard", keep: ["elCardPop"], note: "Iron's element card", snap: join(GODOT_DIR, "tests", "fixtures", "station_visit7.json"),
    open: `(() => {
      showElCardPop("Fe");
      const t = (sel, k) => { const e = document.querySelector(sel); if (e) e.dataset.cmp = k; };
      t("#ecCard", "ec:card"); t("#ecNum", "ec:num"); t("#ecNum2", "ec:num2"); t("#ecSym", "ec:sym"); t("#ecName", "ec:name");
      t("#ecPill", "ec:pill"); t("#ecIconTR", "ec:iconTR"); t("#ecIconBL", "ec:iconBL");
    })()`,
    godot: ["--screen", "res://ui/app.gd", "--call", "show_element_card:Fe", "--save", join(GODOT_DIR, "tests", "fixtures", "station_visit7.json")] },
];

// ---- run each shot on both sides
const pick = process.argv.slice(2);
const results = [];
for (const shot of SHOTS.filter(s => !pick.length || pick.includes(s.name))) {
  const snap = shot.snap ? JSON.parse(readFileSync(shot.snap, "utf8")) : null;
  const html = await htmlShot(snap, shot.open, { rectsJS: RECTS, keep: shot.keep || [] });
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
