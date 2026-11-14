# Elementia: the game

A chemistry crafting game (Classic edition, portrait). Plain HTML, CSS and
JavaScript, with no framework and no build step to play: open
`elementia.html` from a local server or straight from disk.

## Layout

| Path | What it holds |
|---|---|
| `elementia.html` | The page: `<head>`, all markup, and the tags that load everything below, in order. |
| `css/*.css` | Styles, one file per area (station, inventory, overlays, ...). Loaded in cascade order, so a later file wins ties. |
| `assets/images.js` | Embedded icon and art data (data URIs). Generated in part by `tools/fetch_noto_icons.py`. |
| `js/*.js` | Game code, one file per area (see below). |
| `js/data.js` | Game data (`DATA`): dice per roll, version, station suits, each station's dice, shop and capstone. **The source of truth**: edit it by hand. |
| `minigames/*.js` | The 8 station mini-games. Each is a self-contained IIFE that sets `window.runMinigame`. |
| `backdrops/`, `banners/`, `tutorial/`, `mouse/` | Images referenced by path. |

## How the scripts fit together

The `js/` files are **classic scripts**, not ES modules. They share one
global scope and load in the order `elementia.html` lists them. A file may
use anything declared in an earlier file. It may also use anything at all
inside a function body that only runs after boot. A file must **not**, while
it is loading, use a name declared in a later file: no top-level calls
into, and no direct references to, later functions, `const`s or `let`s.
That would throw a ReferenceError on load. Wrap such a reference in an arrow
(`() => laterFn()`) or move it.

Classic scripts were kept so the game still runs from `file://`, which ES
modules can't do, and so the split could be a pure move of existing code.

Load order, by area:

1. **Data and rules:** `data`, `model` (rules, elements, suits, item catalog), `mat-scoring`, `map-graph`
2. **State:** `state` (state, prefs, save/load), `low-motion`, `history`, `crafting`
3. **Rendering core:** `render-helpers`, `overlays`, `hints`, `render`, `hub`, `drawer`
4. **Screens:** `map`, `station`, `reference`, `pins`, `job-board` (the BINGO / To-Do tray)
5. **Moments:** `card-popup`, `craft-animations`, `roll`, `travel`, `minigames`, `suit-spend`
6. **Display Mat and Lock-In:** `display-mat`, `mat-layouts`, `combo-lab`, `lock-in`, `empty-elements`
7. **Run flow:** `opening`, `bingo`, `end-game`, `trophies`, `welcome`
8. **Settings and input:** `settings`, `convert`, `tour`, `input`
9. **Startup:** `pwa` (manifest + service worker), `boot` (load save, first render). `boot` must stay last.

Each file starts with a header that says what it owns.

## Builds and tools

| Command | What it does |
|---|---|
| `python build_artifact.py` | Builds `build/elementia_artifact.html`, a single self-contained file. It inlines every CSS/JS file and image, and drops `js/pwa.js`. This is what the website and the Claude artifact serve. |
| `python deploy.py "message"` | Smoke test, build, then publish the build to the website repo (`../../elementia-site`). |
| `node tools/run_smoke.mjs` | Plays a short Classic run in headless Chrome (start, roll, craft, panels, travel, Lock-In). Prints PASS or the errors. |
| `game_source.py` | `read_game_data()`: the `DATA` object from `js/data.js`. `read_game_source()`: the page plus every file it loads, as one string, for finding constants like `CORE_SET`. The print pipeline (`../print/`) uses both. |

CSS `url()` paths are relative to the stylesheet (`url("../backdrops/x.webp")`).
`build_artifact.py` rewrites them for the inlined copy.
