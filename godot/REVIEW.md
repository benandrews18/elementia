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
