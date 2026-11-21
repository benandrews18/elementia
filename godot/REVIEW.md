# godot-prompter review: findings (temporary)

Working file for the review in PLAN.md ("Review with the godot-prompter
plugin"). One section per pass, appended as each pass ends. Deleted once the
user has picked the fixes and the decisions are in PLAN.md.

## Pass 1: code (2026-11-21)
Skills: godot-code-review, gdscript-advanced (gdscript-patterns and
godot-debugging not loaded: nothing here needed them; patterns are the
basics of the advanced one, debugging is for a live bug).
Read: game/game.gd, game/progress.gd, game/rng.gd, core/data.gd,
core/util.gd, core/catalog.gd, core/market.gd, main.gd, ui/app.gd; grep
across ui/ for signal hookups to the autoloads, awaits, lambdas on signals.

**Must**
1. **A crash while saving wipes the run and everything kept across runs**
   (`game/progress.gd:76-79`, `:84`). `FileAccess.open(WRITE)` empties the
   file first, then writes. If the app is killed in between (phone OS
   closing it, battery dies), the file is empty or cut off; next launch
   `_read` gets nothing, uses the default, and the run, Stars, pins, found
   collections and hidden tips are silently gone. Every action saves (often
   2-3 times), so it's written very often. Also, a prefs file that isn't an
   object would crash `prefs.merge`. **Fix:** write to `path + ".tmp"`, then
   rename it over the real file; in `_read`, ignore anything that doesn't
   parse to the expected type. ~8 lines, one file. No conflict.

**Should**
2. **Closing the app mid-visit loses that visit** (`main.gd:9-10`,
   `game/game.gd:58,77-78`; the HTML game's `resumeRun()` does the same).
   Arriving sets only `ctx.current`, which isn't saved; `lastStation` is set
   when you leave. Resume puts you on the map with `lastStation` = the
   station *before*. Case: travel to Mine (visit 7 spent, dice rolled), the
   app is closed, reopen: Shop takes you back to the previous station, and
   going to Mine again costs visit 8. **Fix:** remember the station you're
   at in the save and resume into it. Small in Godot (~5 lines).
   **CONFLICT:** parity with the HTML (same bug there; fix both, or keep).
3. **One action saves and redraws 2-3 times** (`game/game.gd:72` inside
   `start_run` `:322-325`; `_finish_lock_in` -> `go_station`;
   `ui/app.gd:346-347` quiet_check + go_station). Each `_changed()` writes
   the whole save + prefs and every open screen rebuilds. Case: starting a
   run writes the files 3 times and rebuilds the screens 3 times. **Fix:**
   inner calls skip `_changed()` (the outer action calls it once), or one
   coalesced save + emit per frame. ~6-10 lines; the deferred version
   changes timing, so tests decide. Cost to be measured in pass 4. No
   conflict.

**Nice**
4. **The Market sequence waits for "Nice" by polling every frame**
   (`ui/app.gd:99-100`). `await rw.tree_exited` says the same in one line.
   No conflict.

**Kept (good as is):** every screen hooks `Game.state_changed` to a method
of its own (freed screens disconnect themselves; no lambdas left behind);
tweens are made with `node.create_tween()`, so they die with their node;
awaits that could outlive their node were already handled
(`capstone_choice.gd:226`); all randomness goes through `Rng` (tests feed
it); the Web export includes the data JSON.

**Not checked in this pass:** the rule files core/mat.gd, orders.gd,
trophies.gd in depth (the parity test replays 3604 recorded steps against
the HTML game); the screen and window scripts beyond app.gd (pass 3 reads
them).

## Pass 2: architecture (2026-11-21)
Skills loaded: save-load, event-bus. Judged by their criteria without
loading (not worth the cost here): state-machine (the flow is worked out
from the saved state by `App.home_face()`; a state machine would be a second
copy of that state), dependency-injection (four autoloads plus
`App.current` suit a one-screen app), resource-pattern (data stays JSON
exported from game/js by decision; colours are already a Resource,
tokens.tres), scene-organization (M5.5 did it; pass 3 looks at the scenes).
Read: game/progress.gd load/save, the HTML `loadAll()` (game/js/state.js),
PLAN.md decisions on saves.

**Should**
5. **App saves have no version and no upgrade step** (`game/progress.gd:83-90`).
   The plan decided "no old-save migration", meaning HTML saves carried into
   the app. But once the app ships, its own saves outlive data changes. The
   HTML `loadAll()` already needs 6 clean-ups for exactly this (items cut
   from the game, a challenge that no longer exists, an overfull mat...).
   Case: after release an item is cut (as Oven was on 2026-11-14); a
   player's save still lists it; `Catalog.entry()` returns null and screens
   that read it break. **Fix:** a `saveVersion` number in the save and an
   upgrade step in `load_all()` with the HTML's clean-ups; also report failed
   writes (`push_error`) instead of skipping them silently (`:77`). ~20 lines,
   best before M9. **Plan wording:** the decision should say it covers HTML
   saves only (needs your OK).

**Nice / for M8**
6. **One signal for every change, and a listener that fires it again**
   (`ui/app.gd:123-125`). `_maybe_end()` runs inside the `state_changed`
   handler and calls `Game._changed()`, which emits `state_changed` again
   in the middle of the first one. Case: crafting the last item rebuilds
   every open screen twice. Harmless now. **Fix:** `Game._changed.call_deferred()`
   there (1 line). For M8: sound needs to know *what* happened (crafted,
   rolled, row done, checked), which one `state_changed` can't say. Add a
   few named signals on Game when sound arrives, not before.

**Kept (good as is):** saves are JSON, not Resource files (the save-load
skill's rule: a Resource file can run code, so player files must not be
one); rules (Game), what's kept across runs (Progress) and the screens are
cleanly apart; core/ is pure functions of the state, which is why the
parity test works; screens are worked out from the state rather than kept
in a separate state machine.

## Pass 3: UI and touch (2026-11-21)
Skills loaded: input-handling, responsive-ui. Judged without loading:
godot-ui and hud-system (their core advice, containers and a project
Theme, is what the plan decided against for pixel parity; the hub is
already a scene), localization (only its cost is asked, counted below).
Read: project.godot (display, input), the tap checks across ui/, the
scroll areas, ref_row.tscn and hub_bar.gd sizes.

**Must**
7. **A tap fires on finger-up even after a drag** (64 tap checks in 22
   files, e.g. `ui/overlays/convert_tray.gd:97-98`). A tap is "left button
   released", nothing more. On a phone, touches arrive as mouse events
   (Godot's default). Case: on the Items screen, a To-Do list or the
   station's shop, a finger that lands on a card and drags to scroll either
   doesn't scroll (the card keeps the touch) or opens that card when the
   finger lifts. **First:** confirm on a touch device (the web preview on a
   phone). **Fix:** one shared tap helper that remembers where the press
   started and ignores the release if the finger moved more than ~10px,
   used by all 22 files; tappables inside scroll areas let the drag through
   to the scroll (mouse filter Pass). Mechanical, 22 files. No conflict.

**Should (before M9)**
8. **Notches and home bars aren't avoided** (nothing reads the safe area).
   Case: in the iPhone app, the Quark bar sits under the notch and the hub
   buttons under the home-swipe bar (swiping up to Home closes the game
   instead of pressing Home). The web preview is fine (the browser keeps
   clear). **Fix:** at start, read `DisplayServer.get_display_safe_area()`
   and inset App top and bottom; every screen is inside App. ~10 lines.
   No conflict (no change on screens without a notch).

**Nice**
9. **Small tap targets for small fingers** (e.g. the 📌 on Items rows,
   34x34, `ui/pieces/ref_row.tscn:167-175`; the HTML's size). Platform
   guides say 44 or more. **Fix:** grow the invisible tap area, not the
   look. No conflict that way.
10. **Translating later would be its own milestone.** 44 text lines in
   scripts plus the scene texts, and 51 places that measure text to place
   things (each would need checking per language). Not planned; no action,
   just the size.

**Kept (good as is):** one design size with canvas_items + expand (the
skill's choice for a UI game like this), portrait locked, wide screens
handled (the Market keeps phone-sized squares, the map scales with its
width).
