// Copies everything the Godot version needs from the HTML game (game/), so
// nothing is ever hand-copied (see PLAN.md, "Content and tables stay in one
// place"). Run it after any change to game/js or the game's art:
//   node godot/tools/export_from_game.mjs
// Writes:
//   godot/data/game_data.json   every plain-data ALL_CAPS constant in game/js
//                               (DATA and the rule tables), read from the
//                               running game, so derived tables come out
//                               exactly as the game computes them
//   godot/assets/icons/*        every item / suit icon (CUSTOM_ICONS, SUIT_ICON)
//                               plus icons.json: icon key -> file
//   godot/assets/<folder>/*     the game's art folders, copied as-is
// Constants holding functions are rules, not data: they're listed as skipped
// and ported by hand.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync, cpSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { withGame, GAME } from "../../game/tools/headless_game.mjs";

const GODOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const ART_FOLDERS = ["backdrops", "banners", "ui", "suits", "mouse", "tutorial"];

// Files under dir, as "a/b.png" paths.
const filesIn = dir => readdirSync(dir, { recursive: true }).map(f => String(f).replaceAll("\\", "/"))
  .filter(f => statSync(join(dir, f)).isFile());
// Deletes files in dir whose name (or, for a .import file, whose image) isn't
// in keep. Folders are never wiped: Godot's .import files hold each image's
// permanent ID, which scenes refer to.
function prune(dir, keep) {
  for (const f of filesIn(dir)) if (!keep.has(f.replace(/\.import$/, ""))) rmSync(join(dir, f));
}

// Every ALL_CAPS const in game/js, including `const A = 1, B = 2;` lines.
const names = [];
for (const f of readdirSync(join(GAME, "js")).filter(f => f.endsWith(".js"))) {
  for (const line of readFileSync(join(GAME, "js", f), "utf8").split("\n")) {
    if (!line.startsWith("const ")) continue;
    for (const m of line.matchAll(/(?:^const |,\s*)([A-Z][A-Z0-9_]+)\s*=(?!=)/g)) names.push(m[1]);
  }
}

const out = await withGame(async (evalJS, errs) => {
  const result = await evalJS(`(() => {
    const isMarkup = s => typeof s === "string" && /data:|<svg|<img/.test(s);
    // Plain JSON copy; throws on functions so rule tables are skipped whole.
    const plain = v => {
      if (typeof v === "function") throw "function";
      if (v instanceof Set) return [...v].map(plain);
      if (v instanceof Map) return Object.fromEntries([...v].map(([k, x]) => [k, plain(x)]));
      if (Array.isArray(v)) return v.map(plain);
      if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, plain(x)]));
      if (isMarkup(v)) throw "markup";
      return v;
    };
    const tables = {}, skipped = {};
    for (const n of ${JSON.stringify(names)}) {
      let v; try { v = eval(n); } catch (e) { skipped[n] = "not defined"; continue; }
      try { tables[n] = plain(v); } catch (e) { skipped[n] = String(e); }
    }
    // Icons: key -> {ext, data (base64 for images, text for svg)}.
    const icons = {};
    const grab = (key, html) => {
      const img = /src="data:image\\/(png|webp|jpeg);base64,([^"]+)"/.exec(html);
      if (img) return icons[key] = { ext: img[1] === "jpeg" ? "jpg" : img[1], b64: img[2] };
      const uri = /^data:image\\/svg\\+xml;base64,(.+)$/.exec(html);
      if (uri) return icons[key] = { ext: "svg", text: atob(uri[1]) };
      const svg = /<svg[\\s\\S]*<\\/svg>/.exec(html);
      if (svg) return icons[key] = { ext: "svg", text: svg[0].includes("xmlns=") ? svg[0] : svg[0].replace("<svg", '<svg xmlns="http://www.w3.org/2000/svg"') };
    };
    Object.entries(CUSTOM_ICONS).forEach(([k, html]) => grab(k, html));
    Object.entries(SUIT_ICON).forEach(([k, html]) => grab("suit:" + k, html));
    const missing = Object.keys(CUSTOM_ICONS).filter(k => !icons[k]);
    return { tables, skipped, icons, missing };
  })()`);
  return { ...result, errs };
}, { http: 8795, cdp: 9343 }); // own ports, so it can run beside the smoke test

// ---- data
mkdirSync(join(GODOT, "data"), { recursive: true });
writeFileSync(join(GODOT, "data", "game_data.json"), JSON.stringify(out.tables, null, 1) + "\n");

// ---- icons (written over the old ones; icons no longer in the game pruned)
const iconDir = join(GODOT, "assets", "icons");
mkdirSync(iconDir, { recursive: true });
const fileFor = key => {
  const m = /^__(.+)__$/.exec(key);
  if (m) return m[1].toLowerCase();
  if (key.startsWith("suit:")) return "suit_" + key.slice(5);
  return "u" + [...key].map(c => c.codePointAt(0).toString(16)).filter(h => h !== "fe0f").join("_");
};
const manifest = {};
for (const [key, ic] of Object.entries(out.icons)) {
  const file = `${fileFor(key)}.${ic.ext}`;
  writeFileSync(join(iconDir, file), ic.text ?? Buffer.from(ic.b64, "base64"));
  manifest[key] = `res://assets/icons/${file}`;
}
writeFileSync(join(iconDir, "icons.json"), JSON.stringify(manifest, null, 1) + "\n");
prune(iconDir, new Set([...Object.values(manifest).map(p => p.split("/").pop()), "icons.json"]));

// ---- art folders
for (const f of ART_FOLDERS) {
  const wanted = p => !p.endsWith(".b64.txt");
  cpSync(join(GAME, f), join(GODOT, "assets", f), { recursive: true, filter: wanted });
  prune(join(GODOT, "assets", f), new Set(filesIn(join(GAME, f)).filter(wanted)));
}

console.log(`tables: ${Object.keys(out.tables).length} exported, ${Object.keys(out.skipped).length} skipped (rules or markup):`);
console.log("  " + Object.entries(out.skipped).map(([n, why]) => `${n} (${why})`).join(", "));
console.log(`icons: ${Object.keys(manifest).length} written` + (out.missing.length ? `; NO IMAGE FOUND for: ${out.missing.join(" ")}` : ""));
console.log(`art: ${ART_FOLDERS.join(", ")} copied`);
if (out.errs.length) { console.log("PAGE ERRORS:\n  " + out.errs.join("\n  ")); process.exit(1); }
