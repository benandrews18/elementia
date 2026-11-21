## Developer mode (dev.js): changes to a run to test a scenario without
## playing up to it. The panel is ui/overlays/dev_panel.tscn.
##
## Hidden: 5 taps on Settings' version line show Settings -> Dev Tools
## (prefs.devUnlocked), whose switch (prefs.devMode) shows the 🛠 button.
## Any change marks the run (state.dev): it goes to History's Dev runs and
## earns no Stars or trophies (Progress). The save from just before the
## first change is kept (BACKUP_PATH) for "Restore my real save".
## shortcut: the HTML panel's Board and Events tabs aren't ported (the mat
## and challenges, replaying windows); add them when testing needs them.
class_name Dev

static var snap_path := "user://dev_snapshots.json"  # tests point it at a scratch file
const BACKUP_PATH := "user://save_backup_dev.json"


## devTouch(): marks the run as a dev run, keeping the real save the first time.
static func touch() -> void:
	if Game.state.get("dev"):
		return
	Progress.save_all()
	if Progress.autosave and FileAccess.file_exists(Progress.SAVE_PATH):
		var err := DirAccess.copy_absolute(Progress.SAVE_PATH, BACKUP_PATH)
		if err != OK:
			push_error("Can't keep the real save for Restore: %s" % error_string(err))
	Game.state.dev = true


static func has_backup() -> bool:
	return FileAccess.file_exists(BACKUP_PATH)


## "Restore my real save": the backup becomes the save, then it's loaded.
static func restore() -> void:
	if not has_backup():
		return
	var err := DirAccess.rename_absolute(BACKUP_PATH, Progress.SAVE_PATH)
	if err != OK:  # the dev run stays; the backup is still there to try again
		push_error("Can't restore the real save: %s" % error_string(err))
		return
	Game.ctx = Game.fresh_ctx()
	Progress.load_all()
	Game.state_changed.emit()


## Clear Cache (clearAllGameData()): every file this game keeps, then a
## fresh start on the title screen, as on a first launch.
static func clear_all() -> void:
	for f in DirAccess.get_files_at("user://"):
		if f.ends_with(".json") or f.ends_with(".tmp"):
			DirAccess.remove_absolute("user://" + f)
	Progress.prefs = Progress.DEFAULT_PREFS.duplicate(true)
	Game.ctx = Game.fresh_ctx()
	App.current.get_tree().reload_current_scene()  # main.gd loads (nothing) and opens the title screen


# ---- Jump

## devSetTurn(): arrive at turn n: the clock, mat size, breakpoints and this
## stretch's challenge (drawn for the check that started it) all follow.
static func set_turn(n: int) -> void:
	var every := int(Data.t("MAT_CHECK_EVERY"))
	n = clampi(n, 1, int(Data.t("MAX_VISITS")))
	touch()
	var s := Game.state
	s.visits = n
	s.matChecked = n > every
	s.runComplete = false
	s.ended = false
	s.finalGameOver = false
	s.finalCheckPending = false
	var c := (n - 1) / every * every  # the last check before this turn
	s.checkRound = c if c >= every else null
	s.order = null
	if c >= every:
		Orders.set_order(s, Orders.draw(s, c, null))
	Game.ctx.erase("endShown")
	Game._changed()


## devTeleport(): at a station without spending a turn (and rolling there again).
static func teleport(name: String) -> void:
	touch()
	var s := Game.state
	Game.ctx.current = name
	Game.ctx.screen = "station"
	s.lastStation = name
	s.visitedStations[name] = true
	s.rolledHere = false
	s.pendingRoll = null
	Game._changed()


## devNextCheck(): the next turn that's a board check when you leave it.
static func next_check() -> void:
	var every := int(Data.t("MAT_CHECK_EVERY"))
	set_turn(maxi(every, ceili(float(Game.state.visits) / every) * every))
	Game.go_map()


## The end screens (Run Complete, Game Over).
static func end_screen(complete: bool) -> void:
	touch()
	if complete:
		Game.state.runComplete = true
	else:
		Game.state.finalGameOver = true
		Game.state.ended = true
	Game._changed()


# ---- Inventory

static func element(sym: String, d: int) -> void:
	touch()
	var n := maxi(0, int(Catalog.count(Game.state, sym)) + d)
	if n:
		Game.state.elements[sym] = n
	else:
		Game.state.elements.erase(sym)
	Game._changed()


## Every core element to n (0 clears them).
static func all_elements(n: int) -> void:
	touch()
	Game.state.elements = {}
	if n:
		for sym in Data.t("CORE_ELEMENT_SYMS"):
			Game.state.elements[sym] = n
	Game._changed()


## The "?" (Unknown Elements).
static func unknown(d: int) -> void:
	touch()
	Game.state.emptyElements = maxi(0, int(Util.get_or(Game.state, "emptyElements", 0)) + d)
	Game._changed()


## devGrant(): straight to the inventory: nothing spent, no reveal.
static func grant(names: Array) -> void:
	var core: Array = Data.t("CORE_ITEM_NAMES")
	var add := names.filter(func(n): return core.has(n) and not Catalog.owns(Game.state, n))
	if add.is_empty():  # nothing to give: the run stays as it was (not marked dev)
		return
	touch()
	Game.state.items.append_array(add)
	Game._changed()


## The item with everything in its recipe tree.
static func grant_tree(name: String) -> void:
	grant(Catalog.component_closure(name) + [name])


static func remove(name: String) -> void:
	if not Catalog.owns(Game.state, name):
		return
	touch()
	Game.state.items.erase(name)
	Game.state.mat.erase(name)
	Game._changed()


## devFillMat(): owned cards, biggest points first, while they fit.
static func fill_mat() -> void:
	touch()
	var s := Game.state
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var owned: Array = s.items.filter(func(n): return Catalog.mat_card(n) != null)
	owned.sort_custom(func(a, b): return pts.get(a, 0) > pts.get(b, 0))
	s.mat = []
	for n in owned:
		if Mat.fits((s.mat + [n]).map(func(x): return Catalog.mat_card(x)), Mat.stage(s)):
			s.mat.append(n)
	Game._changed()


# ---- Snapshots (named copies of the whole run, kept on this device)

static func snaps() -> Array:
	return Progress._read(snap_path, [])


static func _save_snaps(list: Array) -> void:
	Progress._write(snap_path, list)


static func _now() -> String:
	return Time.get_datetime_string_from_system().substr(0, 16).replace("T", " ")


static func snap_save(name: String) -> void:
	var list := snaps()
	list.push_front({"name": name if name != "" else "Turn %d" % int(Game.state.visits), "at": _now(), "state": Game.state.duplicate(true)})
	_save_snaps(list)


static func snap_delete(i: int) -> void:
	var list := snaps()
	if i >= 0 and i < list.size():
		list.remove_at(i)
		_save_snaps(list)


## devSnapLoad(): the snapshot's run, on the map.
static func snap_load(i: int) -> void:
	var list := snaps()
	if i < 0 or i >= list.size():
		return
	touch()
	var st := Game.fresh_state()
	st.merge(list[i].state.duplicate(true), true)
	st.dev = true
	Game.state = st
	Game.ctx = Game.fresh_ctx()
	Game._changed()


## A pasted snapshot: one copied from here ({name, state}) or a bare state.
## False when it isn't one.
static func snap_import(text: String) -> bool:
	var snap = JSON.parse_string(text)
	if snap is Dictionary and not snap.has("state") and snap.get("items") is Array:
		snap = {"name": "Pasted", "state": snap}
	if not (snap is Dictionary and snap.get("state") is Dictionary and snap.state.get("items") is Array):
		return false
	var list := snaps()
	list.push_front({"name": str(snap.get("name", "Pasted")), "at": str(snap.get("at", _now())), "state": snap.state})
	_save_snaps(list)
	return true


# ---- Scenarios (each starts a new dev run)

const SCENARIOS := [["firstCheck", "First board check (turn 3)"], ["weak15", "Weak mat before turn 15"],
	["capReady", "Capstone one craft away"], ["late", "Turn 23, strong board"], ["lastStation", "One station left to visit"]]


## devFresh(): a fresh dev run at the Ocean.
static func _fresh() -> void:
	touch()
	var st := Game.fresh_state()
	st.dev = true
	st.lastStation = "The Ocean"
	st.visitedStations["The Ocean"] = true
	Market.ensure_card(st)
	Game.state = st
	Game.ctx = Game.fresh_ctx()


## Each sets the turn before filling the mat (the mat's size follows the turn).
static func scenario(id: String, cap: String) -> void:
	_fresh()
	match id:
		"firstCheck":
			grant(["Water", "Sand", "Seaweed", "Clay", "Tools"])
			set_turn(3)
			fill_mat()
		"weak15":
			grant(["Water", "Sand", "Seaweed", "Clay", "Tools", "Limestone", "Sugar", "Natural Gas", "Bone", "Soil"])
			set_turn(14)
			fill_mat()
			all_elements(2)
		"capReady":
			grant(Catalog.component_closure(cap))
			set_turn(15)
			fill_mat()
			all_elements(5)
			Game.state.emptyElements = 2
			teleport(Data.t("CORE_ITEM_STATION")[cap])
		"late":
			for c in ["Maglev Train", "Metropolis", "Robot"]:
				grant_tree(c)
			set_turn(23)
			fill_mat()
			all_elements(3)
		"lastStation":
			for st in Data.t("DATA").stations:
				if st.name != "The City":
					Game.state.visitedStations[st.name] = true
			set_turn(9)

