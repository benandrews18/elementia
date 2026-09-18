# Elementia Landscape Edition — Implementation Plan

Goal: a complete, separate landscape version of Elementia (all mechanics, all modes, all features), shipped as its own artifact/page. The portrait game stays untouched and loadable exactly as it is today.

Design rule (from user): stick to portrait UI logic, backgrounds, styles, borders, text. Landscape is mostly rearranging large chunks, not redesigning. Reference: `game/landscape_mockups.html` (approved layouts) and the portrait screens.

## 1. Architecture decision

- Fork `game/elementia.html` -> `game/elementia_landscape.html` (single-file, same conventions: embedded DATA between markers, inline JS/CSS).
- Portrait file is never edited by landscape work. Separate save key (`elementia_landscape_save` etc.) so the two versions don't overwrite each other's localStorage.
- Shared-logic drift is the main risk (balance/recipe/collection edits made in portrait must also land in landscape). Mitigation: a small script `game/sync_landscape_data.py` that copies the DATA block, balance constants (LOCKIN_ROUND_ANCHORS, MAT_COLLECTIONS_RAW, ITEM_POINTS, etc.) from portrait into landscape, so data changes are made once.
- Build/ship: extend `build_artifact.py` (or add `build_landscape.py`) to emit `game/build/elementia_landscape_artifact.html`; publish as a NEW Artifact (new URL, don't touch 936a165e...); copy to `elementia-site/landscape/index.html` (portrait remains `index.html`). Add a link between the two on each welcome screen only if user wants it.
- Mini-games (`build_minigames.py`, `minigames/`) must be embedded in the landscape file too; extend the sync check to cover both files.

## 2. Phases

### Phase 0 — Setup (small)
1. Copy file, change title/manifest/app-name, separate storage keys, add `landscape` body class.
2. Wrap the app in a fixed 915x412 stage scaled to fit the window (transform scale, centered, letterboxed); no orientation handling.
3. Add `.claude/launch.json` entry for previewing it; verify it boots identically to portrait before any layout changes.

### Phase 1 — Global layout shell
- Fixed 915x412 design canvas (Pixel 9a landscape); position:fixed elements become stage-relative (position:absolute inside the scaled stage, or fixed within a transformed ancestor).
- Hub bar: keep the single connecting bar; 3 groups (To-Do + Inventory left, center button, Items + Settings right); reuse real `#hub/.hubbtn/#hubHome` CSS, just widen. Update `--hub-h` and every overlay that reserves hub space.
- Audit every `position:fixed` / `100vh` / bottom-padding assumption; landscape height is ~430px so all vertical budgets shrink.

### Phase 2 — Map screen
- Rotate map art 90 degrees (`diamond_map_full.webp`) and convert `MAP_NODE_POS` -> `(100-y, x)`; keep `.map-node`, capstone badge (now to the right of node), tracked badge, path lines (`MAP_EDGES` need same transform), here/reachable/selected states.
- Map canvas fills the space above the hub; no scrolling.
- Station preview: top tray sliding down over the map (map background stays), tracked-item chip retained.
- Marketplace tray from the map: top tray, stations-visited header first, square 5x5 bingo grid (size driven by available height), map stays behind it.

### Phase 3 — Station screen
- Header: station icon + title (+ Empty Element badge inline with same gap) with the elements-found row inline beside the title, not below.
- Roll/dice UI, playbar, roll animation, flyToInventory targets: re-check all geometry.
- Item shop: portrait row style (`.item`, `.craftbtn`, tokens) laid out as 2 columns; capstone box; crafted-items collapse row; station backdrop art kept (portrait behavior).
- Empty Element cash-in spotlight + scrim: verify with the new header.

### Phase 4 — Inventory / Display Mat
- Split the portrait vertical stack at its existing divider: left = Quark Meter card, Clear/Save/tabs, mat grid; right = search + collections + inventory card grid (own scroll region, ~38% width), sort/filter buttons bottom-left/right of that pane.
- Sort/Filter trays: open within the inventory pane bounds, above the hub, icon-only, same content as portrait.
- Elements tab, saved layouts tray, arrange screen, mat drag/reorder, capstone 2-slot cards, combo chips: re-test with the narrower mat width and shorter height.
- Card inspection popup, Item Reference (codex), Collections overlay: re-fit for 430px height (scroll inside, keep portrait styling).

### Phase 4b — Lock-In flow
- Lock-in banner, peeked (half-view) drawer state, score reveal sequence, reward modal, game over/end-game screens, breakpoint gate notice: the "half-view" concept (drawer peeking from bottom) needs a landscape equivalent — probably peek = mat pane only with the inventory pane collapsed.

### Phase 5 — To-Do list + tracker
- Left slide-in tray (portrait pinned list + full breakdown), tracker chip row at the bottom of the same tray (combines the To-Do tray and the tracker/pins tray). Hub stays visible.

### Phase 6 — Everything else (checklist; each must be reachable and correct)
- Welcome/tour screen, guided tutorial + mouse hints (`showTutorialHintOnce`, anchor selectors), Settings + sub-screens, Combo Lab, Mini-Games mode + arcade map, Zen/Hard/Classic modes (Hard/Zen-only UIs: quests, trade, adventure tray), Job/Bingo tray incl. bingo line-clear sequence + gathered-elements popup, capstone picker overlay, confirm dialogs, toasts/event toast queue, celebrate/confetti overlays, end-game stats, history/export, dev tools.
- Toasts/pills/banners currently anchored top/bottom: re-anchor for landscape.

### Phase 7 — QA + ship
- Full playthrough in each mode at the 915x412 canvas, plus a scaled-down and a desktop-window check.
- Regression: portrait file byte-identical to pre-work (git diff empty for `game/elementia.html`), portrait artifact still loads.
- Run `build_minigames.py --check` for both files; publish new artifact; copy to `elementia-site/landscape/`; commit (portrait repo files unchanged).

## 3. Decisions (confirmed by user)
1. Separate copy (fork) + data sync script. Non-data code changes are made in each file separately.
2. Fixed-shape stage sized for the Pixel 9a in landscape: ~915x412 CSS px (~20:9, 2.22:1; physical 2424x1080 at 2.625 DPR). The whole game renders in that fixed design canvas and scales uniformly to fit any window (letterboxed on desktop). Replaces the 932x430 mockup frame; mockup layouts get re-checked at 915x412.
3. No links between the two editions.
4. No rotate prompt / auto-rotate handling for portrait-held devices.

Consequence of #2: all layout can use fixed px against a known 915x412 canvas (no fluid-width rewrite of fixed/vh assumptions), with one scale transform on a stage wrapper. Safe-area insets still apply on the real device edges.

## 4. Suggested execution order for the big session
Phase 0 -> 1 -> 2 -> 3 -> 4 -> 4b -> 5 -> 6 -> 7, committing (locally) at the end of each phase and screenshot-verifying each screen in the Browser pane before moving on. Estimated size: very large (the file is ~7MB / ~18k lines); expect this to span the whole usage window. Use parallel Explore agents for the Phase 6 audit of fixed/bottom-anchored UI.
