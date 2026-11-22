## What's kept across runs (state.js prefs, trophies.js, history.js,
## mat-layouts.js): prefs (pins, Stars, collections found, totals),
## trophies, run history, saved layouts; and saving it all, with the run
## (Game.state). Rules of a run live in game.gd.
extends Node

## Kept across runs (the HTML game's prefs); not part of parity.
const DEFAULT_PREFS := {"pinnedItems": [], "capstonesEverCrafted": [], "playDays": [], "stars": 0,
	"minigamesEnabled": false, "guidedTutorialEnabled": false}  # Professor Mouse off until his tips are fixed (the user, 2026-11-21)
var prefs: Dictionary = DEFAULT_PREFS.duplicate(true)


# ---- pins (prefs)

## Tips hidden for good with their ✕ (tipHidden() / hideTipForever()).
func tip_hidden(id: String) -> bool:
	return Util.get_or(prefs, "hiddenTips", []).has(id)


func hide_tip(id: String) -> void:
	if not tip_hidden(id):
		prefs.hiddenTips = Util.get_or(prefs, "hiddenTips", []) + [id]
	save_all()


func is_pinned(name: String) -> bool:
	return prefs.pinnedItems.has(name)


func toggle_pin(name: String) -> void:
	if prefs.pinnedItems.has(name):
		prefs.pinnedItems.erase(name)
	else:
		prefs.pinnedItems.append(name)


func record_play_day() -> void:
	if Game.state.get("dev"):
		return
	var d := Time.get_date_string_from_system()
	if prefs.playDays.is_empty() or prefs.playDays[-1] != d:
		prefs.playDays.append(d)
		if prefs.playDays.size() > 60:
			prefs.playDays = prefs.playDays.slice(-60)


func grant_stars(n: int) -> void:
	if n == 0 or Game.state.get("dev"):
		return
	prefs.stars += n
	Game.state.starsEarned = Util.get_or(Game.state, "starsEarned", 0) + n



# ---- saving (Game.state.js) and what's kept across runs (trophies.js, history.js)

const SAVE_PATH := "user://save.json"
const PREFS_PATH := "user://prefs.json"
const TROPHY_PATH := "user://trophies.json"
const HISTORY_PATH := "user://history.json"
const DEV_HISTORY_PATH := "user://history_dev.json"  # runs changed with the Dev Panel (dev.gd)

## Off in tests, so they never touch the player's files.
var autosave := true
## id -> {at, last, n}: first day earned, latest day, times earned.
var trophies: Dictionary = {}
## Finished runs, newest first (HISTORY_MAX kept).
var history: Array = []
## Dev runs (state.dev), kept apart so testing never mixes into History.
var dev_history: Array = []


## The file's JSON, or default when it's missing, unreadable or the wrong
## kind (default null: any object).
static func _read(path: String, default: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return default
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	var want := TYPE_DICTIONARY if default == null else typeof(default)
	return v if typeof(v) == want else default


## Writes a temporary file, then swaps it in: an app killed mid-write leaves
## the last good save, never an empty one.
static func _write(path: String, value: Variant) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Can't save %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(value))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Can't save %s: %s" % [path, error_string(err)])


## loadAll(): the saved run (if any), prefs, trophies and history.
func load_all() -> void:
	prefs.merge(_read(PREFS_PATH, {}), true)
	trophies = _read(TROPHY_PATH, {})
	history = _read(HISTORY_PATH, [])
	dev_history = _read(DEV_HISTORY_PATH, [])
	var saved = _read(SAVE_PATH, null)
	Game.state = Game.fresh_state()
	if saved is Dictionary:
		Game.state.merge(saved, true)
	Game.resume()


func save_all() -> void:
	if not autosave:
		return
	if Game.state.get("mode") and not Game.ctx.get("comboLab"):  # Combo Lab's throwaway run is never saved
		_write(SAVE_PATH, Game.state)
	_write(PREFS_PATH, prefs)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Awards every trophy this completed run qualifies for that wasn't already
## earned today; returns them (with "again": n on a repeat). The run counts
## toward the across-run totals once (Game.state.lifetimeCounted).
func award_trophies() -> Array:
	if Game.state.get("dev") or (not Game.state.get("runComplete") and not Game.state.get("craftedEverything")):
		return []
	if not Game.state.get("lifetimeCounted"):
		if not prefs.get("lifetime") is Dictionary:
			prefs.lifetime = {"runs": 0, "items": 0, "capCount": 0, "caps": []}
		var L: Dictionary = prefs.lifetime
		L.runs += 1
		L.items += Game.state.items.size()
		for c in Trophies.run_caps(Game.state):
			L.capCount += 1
			if not L.caps.has(c):
				L.caps.append(c)
		Game.state.lifetimeCounted = true
	var day := Trophies.local_day(0)
	var won := []
	var stars := 0
	for t in Trophies.all():
		var g = trophies.get(t.id)
		if (g != null and Util.get_or(g, "last", g.at) == day) or not t.test.call(Game.state, prefs):
			continue
		var w: Dictionary = t.duplicate()
		if g != null:
			g.n = Util.get_or(g, "n", 1) + 1
			g.last = day
			stars += int(Data.t("STARS_TROPHY_AGAIN"))
			w.again = g.n
		else:
			trophies[t.id] = {"at": day, "last": day, "n": 1}
			stars += int(Data.t("STARS_TROPHY"))
		won.append(w)
	if autosave:
		_write(TROPHY_PATH, trophies)
	grant_stars(stars)
	Game._changed()
	return won


## recordHistory(): the finished run, for the History screen and exports.
func record_history() -> void:
	if int(Game.state.get("visits", 0)) <= 0:  # also no run at all (first launch)
		return
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var item_score := 0.0
	for n in Game.state.items:
		item_score += pts.get(n, 0)
	var dev: bool = Game.state.get("dev") == true
	var list := dev_history if dev else history
	list.push_front({"mode": Game.state.get("mode"), "date": Time.get_datetime_string_from_system(true) + "Z",
		"visits": Game.state.visits, "score": Util.js_round(Util.get_or(Game.state, "bestMatScore", 0)), "itemScore": item_score,
		"checks": Util.get_or(Game.state, "checkLog", []).duplicate(true), "capstones": Trophies.run_caps(Game.state),
		"visitLog": Util.get_or(Game.state, "visitLog", []).duplicate(true),
		"bingoCard": Game.state.bingoCard.duplicate() if Game.state.get("bingoCard") != null else null,
		"bingoLinesCompleted": Util.get_or(Game.state, "bingoLinesCompleted", []).duplicate()})
	if dev:
		list[0].dev = true
	list.resize(mini(list.size(), int(Data.t("HISTORY_MAX"))))
	if autosave:
		_write(DEV_HISTORY_PATH if dev else HISTORY_PATH, list)



# ---- collections, Stars and clues; saved layouts (mat-layouts.js; prefs)

func _found() -> Array:
	if prefs.get("everUnlockedMatCollections") == null:
		prefs.everUnlockedMatCollections = []
	return prefs.everUnlockedMatCollections


## A collection complete on the mat that hasn't been discovered yet (the
## screen shows "New collection!"), or null.
func undiscovered_on_mat() -> Variant:
	for c in Mat.completed_in(Mat.on_mat(Game.state)):
		if not _found().has(c.id):
			return c
	return null


## "Add to Collections": discovered for good, one Star.
func discover_collection(id: String) -> void:
	if not _found().has(id):
		_found().append(id)
	if prefs.get("collectionClues") is Dictionary:
		prefs.collectionClues.erase(id)
	grant_stars(int(Data.t("STARS_DISCOVERY")))
	Game._changed()


## drawCollectionClue(): one more item of a random hidden collection,
## preferring ones without a clue yet; its last item discovers it.
func _draw_clue() -> Variant:
	if not prefs.get("collectionClues") is Dictionary:
		prefs.collectionClues = {}
	var clues: Dictionary = prefs.collectionClues
	var hidden := Mat.collections().filter(func(c): return not _found().has(c.id))
	if hidden.is_empty():
		return null
	var fresh := hidden.filter(func(c): return not clues.has(c.id))
	var c: Dictionary = Rng.pick(fresh if not fresh.is_empty() else hidden)
	var known: Array = clues.get(c.id, [])
	var item = Market.shuffle(c.items.filter(func(n): return not known.has(n)))[0]
	clues[c.id] = known + [item]
	var discovered: bool = clues[c.id].size() >= c.items.size()
	if discovered:
		_found().append(c.id)
		clues.erase(c.id)
	return {"c": c, "item": item, "known": c.items if discovered else clues[c.id], "discovered": discovered}


## buyClues(n): CLUE_COST Stars each, as many as Stars allow. Returns the clues.
func buy_clues(n: int) -> Array:
	n = mini(n, int(Util.get_or(prefs, "stars", 0)) / int(Data.t("CLUE_COST")))
	var got := []
	for i in n:
		var clue = _draw_clue()
		if clue == null:
			break
		got.append(clue)
	prefs.stars -= got.size() * int(Data.t("CLUE_COST"))
	Game._changed()
	return got


func save_layout(name: String) -> void:
	if name.strip_edges() == "":
		return
	if prefs.get("savedMatLayouts") == null:
		prefs.savedMatLayouts = []
	prefs.savedMatLayouts.append({"name": name.strip_edges(), "items": Game.state.mat.duplicate()})
	Game._changed()


func load_layout(i: int) -> void:
	var L: Array = Util.get_or(prefs, "savedMatLayouts", [])
	if i >= 0 and i < L.size():
		Game.place_mat_cards(L[i].items)


func delete_layout(i: int) -> void:
	var L: Array = Util.get_or(prefs, "savedMatLayouts", [])
	if i >= 0 and i < L.size():
		L.remove_at(i)
		Game._changed()
