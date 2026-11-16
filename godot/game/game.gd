## The run: `state` (same JSON shape as the HTML game's state, so the same
## save loads in both), the globals outside it that rules read (`ctx`),
## `prefs`, and the player actions. Screens call actions and redraw on
## state_changed; animations play from the result afterwards (in the HTML
## game they ran in between).
## Actions are named like the JS functions in snake_case (goStation ->
## go_station); tests/parity.gd finds them by that name.
extends Node

signal state_changed

var state: Dictionary = {}
var ctx: Dictionary = {"current": null, "screen": "map", "travelPromptFor": null,
	"selectedMapStation": null, "lockInCommitted": false}
## Kept across runs (the HTML game's prefs); not part of parity.
var prefs: Dictionary = {"pinnedItems": [], "capstonesEverCrafted": [], "playDays": [], "stars": 0,
	"classicBingo": false, "minigamesEnabled": false}


func load_snapshot(s: Dictionary) -> void:
	state = s.get("state", s).duplicate(true)
	if s.has("ctx"):
		ctx = s.ctx.duplicate(true)
	state_changed.emit()


func snapshot() -> Dictionary:
	return {"state": state, "ctx": ctx}


func _changed() -> void:
	state_changed.emit()


## freshState()
func fresh_state() -> Dictionary:
	return {"elements": {}, "items": [], "visitLog": [], "visits": 0, "lastStation": null, "priorStation": null,
		"rolledHere": false, "pendingRoll": null, "lastRoll": null, "noRepeat": true, "ended": false, "mode": "classic",
		"visitedStations": {}, "collapseCraftedItems": true, "convertRevealed": false, "marketVisited": false,
		"finalCheckPending": false, "checkLog": [], "ecoStreak": 0, "starsEarned": 0, "marketUnseen": false, "mat": [],
		"bingoLayout": "bingo" if prefs.classicBingo else "rows", "bingoCard": null, "bingoLinesCompleted": [],
		"pendingBingoClears": [], "emptyElements": 0, "matChecked": false, "matBonusDice": 0, "quickSavedMat": null,
		"bingoCenterChosen": false, "finalGameOver": false, "craftedEverything": false, "runComplete": false,
		"reachedHardLimit": false, "bestMatScore": 0}


# ---- pins (prefs)

func is_pinned(name: String) -> bool:
	return prefs.pinnedItems.has(name)


func toggle_pin(name: String) -> void:
	if prefs.pinnedItems.has(name):
		prefs.pinnedItems.erase(name)
	else:
		prefs.pinnedItems.append(name)


func _record_play_day() -> void:
	if state.get("dev"):
		return
	var d := Time.get_date_string_from_system()
	if prefs.playDays.is_empty() or prefs.playDays[-1] != d:
		prefs.playDays.append(d)
		if prefs.playDays.size() > 60:
			prefs.playDays = prefs.playDays.slice(-60)


func _grant_stars(n: int) -> void:
	if n == 0 or state.get("dev"):
		return
	prefs.stars += n
	state.starsEarned = Util.get_or(state, "starsEarned", 0) + n


# ---- travel (travel.js)

## Arriving at a station. The screen then starts the visit's roll (the JS
## launchMinigame(): with mini-games off it sets state.pendingRoll = TAKE).
func go_station(name: String) -> void:
	ctx.lockInCommitted = false
	if state.ended:
		return
	if int(state.visits) == 0 and Data.t("STATION_BY_NAME").has(name):
		var cap: String = Catalog.station(name).capstone[1]
		if not is_pinned(cap):
			toggle_pin(cap)
	if state.get("lastStation") and not Catalog.is_map_connected(state.lastStation, name):
		state.heliTrips = Util.get_or(state, "heliTrips", 0) + 1
	ctx.current = name
	ctx.screen = "station"
	state.visits += 1
	state.rolledHere = false
	_record_play_day()
	state.pendingRoll = null
	state.lastRoll = null
	if state.get("visitLog") == null:
		state.visitLog = []
	state.visitLog.append({"station": name, "items": [], "elements": {}})
	state.visitedStations[name] = true
	if not state.get("allStationsPaid") and Data.t("DATA").stations.all(func(st): return state.visitedStations.has(st.name)):
		state.allStationsPaid = true
		state.emptyElements = Util.get_or(state, "emptyElements", 0) + 1
	_changed()


func go_map() -> void:
	if ctx.current:
		state.priorStation = state.get("lastStation")
		state.lastStation = ctx.current
	ctx.screen = "map"
	ctx.current = null
	state.lastRoll = null
	ctx.selectedMapStation = null
	if int(state.visits) >= int(Data.t("MAX_VISITS")) and not state.ended:
		state.ended = true
		state.reachedHardLimit = true
	elif int(state.visits) >= int(Data.t("RUN_COMPLETE_VISIT")) and not state.get("runComplete") and not state.ended:
		_start_final_check()
	_changed()


# ---- dice (roll.js)

## The visit's roll. Returns [{face, sym}] for the animation.
func do_roll(roll_count: Variant = null) -> Array:
	if state.rolledHere:
		return []
	var dice := Catalog.sorted_dice(Catalog.station(ctx.current))
	var base: int = Data.t("TAKE") if roll_count == null else int(roll_count)
	var bonus: float = state.tripDice if state.get("tripDice") != null else Util.get_or(state, "matBonusDice", 0)
	var n := int(base + bonus) if state.get("matChecked") else maxi(int(Data.t("MAT_PRE_CHECK_DICE")), base)
	var out := []
	for i in n:
		var sym: String = dice[int(floor(Rng.next() * 6))]
		state.elements[sym] = Catalog.count(state, sym) + 1
		out.append({"face": dice.find(sym) + 1, "sym": sym})
	state.rolledHere = true
	state.lastRoll = out
	if state.get("visitLog"):
		var turn: Dictionary = state.visitLog[-1]
		if turn.get("elements") == null:
			turn.elements = {}
		for r in out:
			turn.elements[r.sym] = turn.elements.get(r.sym, 0) + 1
	_changed()
	return out


# ---- crafting (crafting.js)

func craft(name: String) -> bool:
	var e = Catalog.entry(name)
	if e == null or Catalog.owns(state, name) or not Catalog.can_craft(state, e):
		return false
	var n := Catalog.needs_of(e.reqs)
	for sym in n.els:
		var is_cat: bool = e.reqs.any(func(r): return r.name == sym and r.kind == "element" and r.catalyst)
		if not is_cat:
			state.elements[sym] = Catalog.count(state, sym) - n.els[sym]
	for k in state.elements.keys():
		if state.elements[k] <= 0:
			state.elements.erase(k)
	state.items.append(name)
	# Auto-place a run's first crafts on the mat while they'd all still fit.
	var card = Catalog.mat_card(name)
	var st := Mat.stage(state)
	if card != null and not state.mat.has(name) \
			and Mat.fits(state.items.map(func(x): return Catalog.mat_card(x)).filter(func(c): return c != null), st) \
			and Mat.fits(Mat.on_mat(state) + [card], st):
		state.mat.append(name)
	if e.tier == "CAPSTONE" and not prefs.capstonesEverCrafted.has(name):
		prefs.capstonesEverCrafted.append(name)
	if is_pinned(name):
		toggle_pin(name)
	Market.check_lines(state)
	_check_crafted_everything()
	if state.get("visitLog"):
		state.visitLog[-1].items.append(name)
	_changed()
	return true


## checkCraftedEverything(): the run's end follows on screen once the
## Market animations are done (the JS scheduleCraftedEverythingEnd()).
func _check_crafted_everything() -> void:
	if state.ended or state.get("craftedEverything"):
		return
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	if Data.t("CORE_ITEM_NAMES").all(func(n): return Catalog.owns(state, n) or unlocked.has(n)):
		state.craftedEverything = true


# ---- Market

func set_bingo_center(name: String) -> void:
	Market.set_center(state, name)
	_changed()


# ---- board checks (lock-in.js)

func mat_score() -> Dictionary:
	return Mat.score(Mat.on_mat(state), state, ctx)


## Every trip that isn't a board check: the mat sets this trip's dice.
func quiet_check() -> void:
	if not state.get("matChecked"):
		return
	var quiet := mini(Orders.reward_for(mat_score().total, int(state.visits)), 3)
	state.tripDice = maxi(int(Util.get_or(state, "matBonusDice", 0)), quiet)
	_changed()


## A board check's shutter: draw its challenge once.
func start_check_order() -> void:
	state.checkRound = state.visits
	var o = state.get("order")
	if o != null and int(o.round) == int(state.visits):
		return
	Orders.set_order(state, Orders.draw(state, int(state.visits), o))
	_changed()


func _start_final_check() -> void:
	state.finalCheckPending = true
	start_check_order()


## Would locking in now end the run? (The screen asks first.)
func lock_in_ends_run() -> bool:
	var gated: bool = state.get("runComplete") or (int(state.visits) >= int(Data.t("BREAKPOINT_GATE_VISIT")) and Catalog.is_sunset_visit(state))
	return gated and Orders.reward_for(mat_score().total, Orders.check_round(state)) == 0


## Scores the mat and travels to ctx.selectedMapStation, or ends the run on a
## missed gate (the player already confirmed: see lock_in_ends_run()).
## Returns the reward tier (0-4).
func confirm_lock_in() -> int:
	if ctx.lockInCommitted:
		return 0
	var total: float = mat_score().total
	state.bestMatScore = maxf(Util.get_or(state, "bestMatScore", 0), total)
	var reward := Orders.reward_for(total, Orders.check_round(state))
	ctx.lockInCommitted = true
	if reward == 0 and lock_in_ends_run():
		state.finalGameOver = true
		state.ended = true
		ctx.travelPromptFor = null
		_changed()
		return 0
	_finish_lock_in(reward)
	return reward


func _finish_lock_in(reward: int) -> void:
	var cards := Mat.on_mat(state)
	var o = state.get("order")
	var order = o if o != null and int(o.round) == int(state.visits) else null
	var entry := {"v": state.visits, "q": mat_score().total}
	if order != null:
		entry.o = order.id
		entry.ok = Orders.met(order, cards, 0, state)
	if state.get("checkLog") == null:
		state.checkLog = []
	state.checkLog.append(entry)
	# Trend Shift's station: the biggest station combo (first one on a tie).
	var top = null
	var st: Dictionary = Mat.groups(cards).st
	for k in st:
		if st[k] >= 3 and (top == null or st[k] > st[top]):
			top = k
	state.lastTopStation = top
	state.lastCheckedMat = state.mat.duplicate()
	_note_mat_feats()
	state.ecoStreak = int(Util.get_or(state, "ecoStreak", 0)) + 1 if Mat.has(cards, "Ecosystem") else 0
	var delta := mini(reward, 3)
	state.matChecked = true
	state.matBonusDice = delta
	state.tripDice = delta
	if reward >= 4:
		state.emptyElements = Util.get_or(state, "emptyElements", 0) + 1
	var dest = ctx.selectedMapStation
	ctx.travelPromptFor = null
	go_station(dest)


## The Display Mat trophies' feats this run (noteMatFeats()).
func _note_mat_feats() -> void:
	var cards := Mat.on_mat(state)
	var sc := mat_score()
	var feats: Array = Util.get_or(state, "matFeats", []).duplicate()
	var add := func(f): if not feats.has(f): feats.append(f)
	var full: bool = Mat.stage(state) == Data.t("MAT_GROW_ROUNDS").size() and not Mat.has_empty_slot(cards, Mat.stage(state))
	if full: add.call("full")
	if sc.mult >= 5: add.call("combo5")
	if cards.any(func(c): return Mat.is_complete(c, cards)): add.call("recipe")
	if Data.t("ELEMENT_SUIT_LABEL").keys().all(func(su): return cards.any(func(c): return c.pips.has(su))): add.call("suits4")
	if full and Mat.has(cards, "Metropolis"): add.call("metro10")
	if Mat.has(cards, "Maglev Train") and cards.filter(Mat.is_tier1).size() >= 9: add.call("freight9")
	if sc.layered: add.call("layered")
	state.matFeats = feats


## The final score after turn 24's shopping, then Run Complete.
func confirm_final_lock_in() -> float:
	if ctx.lockInCommitted:
		return 0
	var total: float = mat_score().total
	state.bestMatScore = maxf(Util.get_or(state, "bestMatScore", 0), total)
	if state.get("checkLog") == null:
		state.checkLog = []
	state.checkLog.append({"v": state.visits, "q": Util.js_round(total), "final": true})
	_note_mat_feats()
	state.finalCheckPending = false
	ctx.lockInCommitted = false
	state.runComplete = true
	_grant_stars(int(Data.t("STARS_RUN")))
	_changed()
	return total
