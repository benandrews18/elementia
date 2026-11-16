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
	save_all()
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


# ---- starting a run (welcome.js startNewRun(), opening.js)

## A new run at the chosen capstone's station: the Market card is drawn
## around it, it's pinned, and that station's dice are the starting gift.
func start_run(capstone: String) -> void:
	state = fresh_state()
	prefs.pinnedItems = []
	ctx = {"current": null, "screen": "map", "travelPromptFor": null, "selectedMapStation": null, "lockInCommitted": false}
	Market.set_center(state, capstone)
	if not is_pinned(capstone):
		toggle_pin(capstone)
	var st: String = Data.t("CORE_ITEM_STATION")[capstone]
	var dice := Catalog.sorted_dice(Catalog.station(st))
	for d in dice:
		state.elements[d] = Catalog.count(state, d) + 1
	go_station(st)
	for d in dice:  # the gift is part of what was collected on visit 1
		state.visitLog[-1].elements[d] = state.visitLog[-1].elements.get(d, 0) + 1
	_changed()


# ---- player actions that only exist in the HTML game's buttons
# (no golden steps: tested in tests/rules_test.gd)

## Convert: 3 of one element for 1 of another.
func convert_elements(from: String, to: String) -> bool:
	var rate: int = Data.t("CONVERT_RATE")
	if from == to or Catalog.count(state, from) < rate:
		return false
	state.elements[from] = Catalog.count(state, from) - rate
	if state.elements[from] <= 0:
		state.elements.erase(from)
	state.elements[to] = Catalog.count(state, to) + 1
	state.converts = Util.get_or(state, "converts", 0) + 1
	_changed()
	return true


## Spend a "?" on one of this station's elements (or the last station's,
## on the map).
func spend_unknown(sym: String) -> bool:
	var at = ctx.current if ctx.current else state.get("lastStation")
	if not at or Util.get_or(state, "emptyElements", 0) <= 0 or not Catalog.station(at).dice.has(sym):
		return false
	state.emptyElements -= 1
	state.qSpent = Util.get_or(state, "qSpent", 0) + 1
	state.elements[sym] = Catalog.count(state, sym) + 1
	_changed()
	return true


## Elements of `suit` free after what the recipe itself needs
## (suitSurplusOfSuit()).
func suit_surplus(suit: String, reserved: Dictionary) -> float:
	var n := 0.0
	for el in Data.t("SUIT_CORE_ELEMENTS").get(suit, []):
		n += maxf(0, Catalog.count(state, el) - reserved.get(el, 0))
	return n


## suitCostNeed(): {suit: n} for an item's suit cost.
func suit_cost_need(name: String) -> Dictionary:
	var need := {}
	for su in Data.t("ITEM_SUIT_COST_TABLE").get(name, []):
		need[su] = need.get(su, 0) + 1
	return need


func suit_cost_payable(name: String) -> bool:
	var need := suit_cost_need(name)
	var reserved: Dictionary = Catalog.needs_of(Catalog.entry(name).reqs).els
	return need.keys().all(func(su): return suit_surplus(su, reserved) >= need[su])


## Crafting an item with a suit cost: picks {sym: n} are the elements paid
## (the suit-spend balloon). They must cover each suit exactly, from that
## suit's elements, without touching what the recipe needs.
func craft_paying(name: String, picks: Dictionary) -> bool:
	var e = Catalog.entry(name)
	if e == null or Catalog.owns(state, name) or not Catalog.can_craft(state, e):
		return false
	var need := suit_cost_need(name)
	var reserved: Dictionary = Catalog.needs_of(e.reqs).els
	var paid := {}
	var core: Dictionary = Data.t("SUIT_CORE_ELEMENTS")
	for sym in picks:
		var n := int(picks[sym])
		var suit = null
		for su in need:
			if core.get(su, []).has(sym):
				suit = su
		if n <= 0 or suit == null or n > Catalog.count(state, sym) - reserved.get(sym, 0):
			return false
		paid[suit] = paid.get(suit, 0) + n
	if need.keys().any(func(su): return paid.get(su, 0) != need[su]) or paid.size() != need.size():
		return false
	for sym in picks:
		state.elements[sym] = Catalog.count(state, sym) - picks[sym]
		if state.elements[sym] <= 0:
			state.elements.erase(sym)
	return craft(name)


## A finished Market row (or BINGO line) pays a "?" once its animation has
## played (runBingoSequence()). Returns how many were paid.
func collect_market_rewards() -> int:
	var lines: Array = Util.get_or(state, "pendingBingoClears", [])
	state.emptyElements = Util.get_or(state, "emptyElements", 0) + lines.size()
	state.pendingBingoClears = []
	_changed()
	return lines.size()


## Swap the challenge in force for another, for one "?".
func reroll_order() -> bool:
	var o = Orders.current(state)
	if o == null or o.id == "grand" or ctx.lockInCommitted or Util.get_or(state, "emptyElements", 0) <= 0:
		return false
	var next = Orders.draw(state, int(o.round), o)
	if next == null:
		return false
	state.emptyElements -= 1
	state.qSpent = Util.get_or(state, "qSpent", 0) + 1
	Orders.set_order(state, next)
	_changed()
	return true


# ---- arranging the Display Mat (display-mat.js, mat-layouts.js)

## Puts an owned card on the mat or takes it off. Returns "" or why not.
func toggle_mat_card(name: String) -> String:
	var st := Mat.stage(state)
	if state.mat.has(name):
		var rest: Array = state.mat.filter(func(n): return n != name).map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
		if not Mat.fits(rest, st):
			return "Make room first -- without %s the rest won't fit." % name
		state.mat.erase(name)
		_changed()
		return ""
	var card = Catalog.mat_card(name)
	if card == null or not Catalog.owns(state, name):
		return "Not owned."
	if not Mat.fits(Mat.on_mat(state) + [card], st):
		return "A capstone needs two free slots." if Mat.is_capstone(card) else "The display mat is full."
	state.mat.append(name)
	_changed()
	return ""


## placeMatCards(): as many of these (owned) cards as fit, in order.
func place_mat_cards(names: Array) -> void:
	var kept := []
	var st := Mat.stage(state)
	for n in names:
		if Catalog.mat_card(n) != null and Catalog.owns(state, n) \
				and Mat.fits((kept + [n]).map(func(x): return Catalog.mat_card(x)), st):
			kept.append(n)
	state.mat = kept
	_changed()


## The mat's "Last" button: back to the last locked-in mat, quick-saving
## this one; tapped again, the quick-saved mat comes back.
func mat_last_tap() -> void:
	if state.get("quickSavedMat") != null:
		var back: Array = state.quickSavedMat
		state.quickSavedMat = null
		place_mat_cards(back)
		return
	state.quickSavedMat = state.mat.duplicate()
	place_mat_cards(Util.get_or(state, "lastCheckedMat", []))


func clear_mat() -> void:
	state.mat = []
	_changed()


func add_collection_to_mat(id: String) -> bool:
	var col = null
	for c in Mat.collections():
		if c.id == id:
			col = c
	if col == null or not col.items.all(func(n): return Catalog.owns(state, n)):
		return false
	var missing: Array = col.items.filter(func(n): return not state.mat.has(n))
	if missing.is_empty() or not Mat.fits(Mat.on_mat(state) + missing.map(func(n): return Catalog.mat_card(n)), Mat.stage(state)):
		return false
	state.mat += missing
	_changed()
	return true


func remove_collection_from_mat(id: String) -> void:
	for c in Mat.collections():
		if c.id == id:
			state.mat = state.mat.filter(func(n): return not c.items.has(n))
	_trim_mat_to_fit()
	_changed()


## trimMatToFit(): drops the last-placed cards until the mat fits.
func _trim_mat_to_fit() -> void:
	while not state.mat.is_empty() and not Mat.fits(Mat.on_mat(state), Mat.stage(state)):
		state.mat.pop_back()


# ---- saving (state.js) and what's kept across runs (trophies.js, history.js)

const SAVE_PATH := "user://save.json"
const PREFS_PATH := "user://prefs.json"
const TROPHY_PATH := "user://trophies.json"
const HISTORY_PATH := "user://history.json"

## Off in tests, so they never touch the player's files.
var autosave := true
## id -> {at, last, n}: first day earned, latest day, times earned.
var trophies: Dictionary = {}
## Finished runs, newest first (HISTORY_MAX kept).
var history: Array = []


static func _read(path: String, default: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return default
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return default if v == null else v


static func _write(path: String, value: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(value))


## loadAll(): the saved run (if any), prefs, trophies and history.
func load_all() -> void:
	prefs.merge(_read(PREFS_PATH, {}), true)
	trophies = _read(TROPHY_PATH, {})
	history = _read(HISTORY_PATH, [])
	var saved = _read(SAVE_PATH, null)
	state = fresh_state()
	if saved is Dictionary:
		state.merge(saved, true)


func save_all() -> void:
	if not autosave:
		return
	if state.get("mode"):
		_write(SAVE_PATH, state)
	_write(PREFS_PATH, prefs)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Awards every trophy this completed run qualifies for that wasn't already
## earned today; returns them (with "again": n on a repeat). The run counts
## toward the across-run totals once (state.lifetimeCounted).
func award_trophies() -> Array:
	if state.get("dev") or (not state.get("runComplete") and not state.get("craftedEverything")):
		return []
	if not state.get("lifetimeCounted"):
		if not prefs.get("lifetime") is Dictionary:
			prefs.lifetime = {"runs": 0, "items": 0, "capCount": 0, "caps": []}
		var L: Dictionary = prefs.lifetime
		L.runs += 1
		L.items += state.items.size()
		for c in Trophies.run_caps(state):
			L.capCount += 1
			if not L.caps.has(c):
				L.caps.append(c)
		state.lifetimeCounted = true
	var day := Trophies.local_day(0)
	var won := []
	var stars := 0
	for t in Trophies.all():
		var g = trophies.get(t.id)
		if (g != null and Util.get_or(g, "last", g.at) == day) or not t.test.call(state, prefs):
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
	_grant_stars(stars)
	_changed()
	return won


## recordHistory(): the finished run, for the History screen and exports.
func record_history() -> void:
	if int(state.visits) <= 0:
		return
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var item_score := 0.0
	for n in state.items:
		item_score += pts.get(n, 0)
	history.push_front({"mode": state.get("mode"), "date": Time.get_datetime_string_from_system(true) + "Z",
		"visits": state.visits, "score": Util.js_round(Util.get_or(state, "bestMatScore", 0)), "itemScore": item_score,
		"checks": Util.get_or(state, "checkLog", []).duplicate(true), "capstones": Trophies.run_caps(state),
		"visitLog": Util.get_or(state, "visitLog", []).duplicate(true),
		"bingoCard": state.bingoCard.duplicate() if state.get("bingoCard") != null else null,
		"bingoLinesCompleted": Util.get_or(state, "bingoLinesCompleted", []).duplicate(), "dev": state.get("dev") == true})
	history = history.slice(0, int(Data.t("HISTORY_MAX")))
	if autosave:
		_write(HISTORY_PATH, history)


# ---- collections, Stars and clues; saved layouts (mat-layouts.js; prefs)

func _found() -> Array:
	if prefs.get("everUnlockedMatCollections") == null:
		prefs.everUnlockedMatCollections = []
	return prefs.everUnlockedMatCollections


## A collection complete on the mat that hasn't been discovered yet (the
## screen shows "New collection!"), or null.
func undiscovered_on_mat() -> Variant:
	for c in Mat.completed_in(Mat.on_mat(state)):
		if not _found().has(c.id):
			return c
	return null


## "Add to Collections": discovered for good, one Star.
func discover_collection(id: String) -> void:
	if not _found().has(id):
		_found().append(id)
	if prefs.get("collectionClues") is Dictionary:
		prefs.collectionClues.erase(id)
	_grant_stars(int(Data.t("STARS_DISCOVERY")))
	_changed()


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
	_changed()
	return got


func save_layout(name: String) -> void:
	if name.strip_edges() == "":
		return
	if prefs.get("savedMatLayouts") == null:
		prefs.savedMatLayouts = []
	prefs.savedMatLayouts.append({"name": name.strip_edges(), "items": state.mat.duplicate()})
	_changed()


func load_layout(i: int) -> void:
	var L: Array = Util.get_or(prefs, "savedMatLayouts", [])
	if i >= 0 and i < L.size():
		place_mat_cards(L[i].items)


func delete_layout(i: int) -> void:
	var L: Array = Util.get_or(prefs, "savedMatLayouts", [])
	if i >= 0 and i < L.size():
		L.remove_at(i)
		_changed()
