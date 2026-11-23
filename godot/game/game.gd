## The run: `state` (same JSON shape as the HTML game's state, so the same
## save loads in both), the globals outside it that rules read (`ctx`),
## and the player actions. What's kept across runs is in progress.gd.
## Screens call actions and redraw on state_changed; animations play from the result afterwards (in the HTML
## game they ran in between).
## Actions are named like the JS functions in snake_case (goStation ->
## go_station); tests/parity.gd finds them by that name.
extends Node

signal state_changed
signal crafted(name: String)  # after the redraw: the screen plays the craft (App)
var last_tax := {}  # the suit cost the last craft() paid (its elements): the craft animation shows them

var state: Dictionary = {}
var ctx: Dictionary = fresh_ctx()

func load_snapshot(s: Dictionary) -> void:
	state = s.get("state", s).duplicate(true)
	if s.has("ctx"):
		ctx = s.ctx.duplicate(true)
	state_changed.emit()


## After loading a save: back at the station you were visiting (the HTML
## game's resumeRun() puts you on the map, and its Shop then goes to the
## station before; Godot only, PLAN.md decisions 2026-11-21).
func resume() -> void:
	var at = Progress.prefs.get("atStation")
	if at and int(state.get("visits", 0)) > 0 and not state.get("ended") and Data.t("STATION_BY_NAME").has(at):
		ctx.current = at
		ctx.screen = "station"


func snapshot() -> Dictionary:
	return {"state": state, "ctx": ctx}


## The tracked item (the HTML's selectedJobItem; ctx.tracked): the pill by
## the 🔍 button, the badges and rings on what it still needs. Not saved,
## like the HTML; a new run starts with its capstone tracked.
func set_tracked(name: Variant) -> void:
	ctx.tracked = name
	state_changed.emit()


## A 📌 tap anywhere: pins the item and tracks it, or unpins it (and stops
## tracking it, if it was).
func toggle_pin(name: String) -> void:
	Progress.toggle_pin(name)
	if Progress.is_pinned(name):
		ctx.tracked = name
	elif ctx.get("tracked") == name:
		ctx.tracked = null
	_changed()


## pinSlotHTML()'s test: the tracked item still needs this one (and it
## isn't the tracked item itself).
func feeds_tracked(name: String) -> bool:
	var t = ctx.get("tracked")
	return t != null and t != name and Catalog.entry(t) != null and Catalog.still_needed(state, t).has(name)


func _changed() -> void:
	Progress.save_all()
	state_changed.emit()


## The globals outside the state at the start of a run (on the map, nothing
## picked).
static func fresh_ctx() -> Dictionary:
	return {"current": null, "screen": "map", "travelPromptFor": null, "selectedMapStation": null, "lockInCommitted": false}


## freshState()
func fresh_state() -> Dictionary:
	return {"elements": {}, "items": [], "visitLog": [], "visits": 0, "lastStation": null, "priorStation": null,
		"rolledHere": false, "pendingRoll": null, "lastRoll": null, "noRepeat": true, "ended": false, "mode": "classic",
		"visitedStations": {}, "collapseCraftedItems": true, "convertRevealed": false, "marketVisited": false,
		"finalCheckPending": false, "checkLog": [], "ecoStreak": 0, "starsEarned": 0, "marketUnseen": false, "mat": [],
		"bingoLayout": "rows", "bingoCard": null, "bingoLinesCompleted": [],
		"pendingBingoClears": [], "emptyElements": 0, "matChecked": false, "matBonusDice": 0, "quickSavedMat": null,
		"bingoCenterChosen": false, "finalGameOver": false, "craftedEverything": false, "runComplete": false,
		"reachedHardLimit": false, "bestMatScore": 0}


# ---- travel (travel.js)

## Arriving at a station. The screen then starts the visit's roll (the JS
## launchMinigame(): with mini-games off it sets state.pendingRoll = TAKE).
## notify false: the caller saves and redraws once, after its own changes.
func go_station(name: String, notify := true) -> void:
	ctx.lockInCommitted = false
	if state.ended:
		return
	if int(state.visits) == 0 and Data.t("STATION_BY_NAME").has(name):
		var cap: String = Catalog.station(name).capstone[1]
		if not Progress.is_pinned(cap):
			Progress.toggle_pin(cap)
	if state.get("lastStation") and not Catalog.is_map_connected(state.lastStation, name):
		state.heliTrips = Util.get_or(state, "heliTrips", 0) + 1
	ctx.current = name
	ctx.screen = "station"
	Progress.prefs.atStation = name  # resume() brings you back here
	state.visits += 1
	state.rolledHere = false
	Progress.record_play_day()
	state.pendingRoll = null
	state.lastRoll = null
	if state.get("visitLog") == null:
		state.visitLog = []
	state.visitLog.append({"station": name, "items": [], "elements": {}})
	state.visitedStations[name] = true
	if not state.get("allStationsPaid") and Data.t("DATA").stations.all(func(st): return state.visitedStations.has(st.name)):
		state.allStationsPaid = true
		state.emptyElements = Util.get_or(state, "emptyElements", 0) + 1
	if notify:
		_changed()


func go_map() -> void:
	if ctx.current:
		state.priorStation = state.get("lastStation")
		state.lastStation = ctx.current
	ctx.screen = "map"
	ctx.current = null
	Progress.prefs.atStation = null
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

## Crafting from a screen: an item with a suit cost needs its picks (the
## suit-spend balloon, {sym: n}); see craft_paying().
func craft(name: String, picks: Dictionary = {}) -> bool:
	last_tax = {} if suit_cost_need(name).is_empty() else picks.duplicate()
	return craft_raw(name) if suit_cost_need(name).is_empty() else craft_paying(name, picks)


## The rule as the HTML game's craft(): never checks suit costs (its
## buttons do). Only craft() and craft_paying() call it; the parity test
## replays the recorded craft() steps through it.
func craft_raw(name: String) -> bool:
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
	if e.tier == "CAPSTONE" and not Progress.prefs.capstonesEverCrafted.has(name):
		Progress.prefs.capstonesEverCrafted.append(name)
	if Progress.is_pinned(name):
		Progress.toggle_pin(name)
	if ctx.get("tracked") == name:  # crafting the tracked item stops tracking it
		ctx.tracked = null
	Market.check_lines(state)
	_check_crafted_everything()
	if state.get("visitLog"):
		state.visitLog[-1].items.append(name)
	_changed()
	crafted.emit(name)
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
## No save here: the trip's go_station() right after saves once.
func quiet_check() -> void:
	if not state.get("matChecked"):
		return
	var quiet: int = reward_of(Orders.reward_for(mat_score().total, int(state.visits))).dice
	state.tripDice = maxi(int(Util.get_or(state, "matBonusDice", 0)), quiet)


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


## The hand while a check is being played (its shutter opened this
## session, the final check, or the Combo Lab's Challenge Test), else null.
## state.hand is saved, so a check resumes as it was; it waits for its check
## to open again. Dealt by deal_hand() (the Challenge Test deals its own).
func check_hand() -> Variant:
	return state.get("hand") if _in_check() else null


func _in_check() -> bool:
	if ctx.get("challengeTest"):
		return true
	if ctx.get("comboLab"):
		return false
	return ctx.get("travelPromptFor") != null or bool(state.get("finalCheckPending"))


## Deals the check's hand if it has none yet (App.open_panel: the check's
## mat opening). Not in start_check_order(): the rules lock replays that
## against the HTML game.
func deal_hand() -> void:
	if _in_check() and state.get("hand") == null:
		state.hand = Hand.deal(state)
		Progress.save_all()  # at once: closing the app must not redeal


## Would locking in now end the run? (The screen asks first.)
func lock_in_ends_run() -> bool:
	var gated: bool = state.get("runComplete") or (int(state.visits) >= int(Data.t("BREAKPOINT_GATE_VISIT")) and Catalog.is_sunset_visit(state))
	return gated and Orders.reward_for(mat_score().total, Orders.check_round(state)) == 0


## What a reward tier (0-4) gives (diceDeltaForReward()): bonus dice, at
## most 3, and at the top tier an Unknown Element.
static func reward_of(tier: int) -> Dictionary:
	return {"dice": mini(tier, 3), "unknown": tier >= 4}


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
	state.erase("hand")
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
	var delta: int = reward_of(reward).dice
	state.matChecked = true
	state.matBonusDice = delta
	state.tripDice = delta
	if reward_of(reward).unknown:
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
	state.erase("hand")
	state.finalCheckPending = false
	ctx.lockInCommitted = false
	state.runComplete = true
	Progress.grant_stars(int(Data.t("STARS_RUN")))
	_changed()
	return total


# ---- starting a run (welcome.js startNewRun(), opening.js)

## A new run at the chosen capstone's station: the Market card is drawn
## around it, it's pinned, and that station's dice are the starting gift.
func start_run(capstone: String) -> void:
	state = fresh_state()
	Progress.prefs.pinnedItems = []
	ctx = fresh_ctx()
	Market.set_center(state, capstone)
	if not Progress.is_pinned(capstone):
		Progress.toggle_pin(capstone)
	var st: String = Data.t("CORE_ITEM_STATION")[capstone]
	var dice := Catalog.sorted_dice(Catalog.station(st))
	for d in dice:
		state.elements[d] = Catalog.count(state, d) + 1
	go_station(st, false)
	ctx.tracked = capstone  # confirmCapstoneChoice()
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


## Suit-cost picks for name, from each suit's elements with the most to
## spare beyond the recipe (as the simulator pays). {} if none needed or it
## can't be paid. For tests and the simulator: players choose (SuitSpend).
func suggest_suit_picks(name: String) -> Dictionary:
	var e = Catalog.entry(name)
	if e == null or not suit_cost_payable(name):
		return {}
	var reserved: Dictionary = Catalog.needs_of(e.reqs).els
	var picks := {}
	var need := suit_cost_need(name)
	for su in need:
		for i in need[su]:
			var best = null
			for el in Data.t("SUIT_CORE_ELEMENTS").get(su, []):
				var spare: float = Catalog.count(state, el) - reserved.get(el, 0) - picks.get(el, 0)
				if spare > 0 and (best == null or spare > Catalog.count(state, best) - reserved.get(best, 0) - picks.get(best, 0)):
					best = el
			if best == null:
				return {}
			picks[best] = picks.get(best, 0) + 1
	return picks


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
	return craft_raw(name)


## A finished Market row (or BINGO line) pays a "?" once its animation has
## played (runBingoSequence()). Returns how many were paid.
func collect_market_rewards() -> int:
	var lines: Array = Util.get_or(state, "pendingBingoClears", [])
	state.emptyElements = Util.get_or(state, "emptyElements", 0) + lines.size()
	state.pendingBingoClears = []
	_changed()
	return lines.size()


## computeTodoHint(): what to craft next for the pinned items. Only items
## whose components are all owned (advice that can be acted on), ranked by:
## craftable now, pinned items it feeds, unowned items using it directly,
## fewest missing elements, points, then by name. null when nothing's left.
## {name, entry, roots, can_now, missing, homes}
func todo_hint() -> Variant:
	var roots: Array = Progress.prefs.pinnedItems.filter(func(n): return Catalog.entry(n) != null and not Catalog.owns(state, n))
	var feeds := {}  # item -> the pinned items it feeds
	var parents := {}  # item -> the unowned items using it directly
	for root in roots:
		for name in [root] + Catalog.still_needed(state, root):
			if not feeds.has(name):
				feeds[name] = []
			if not feeds[name].has(root):
				feeds[name].append(root)
			var e = Catalog.entry(name)
			if e != null:
				for it in Catalog.needs_of(e.reqs).items:
					if Catalog.owns(state, it.name):
						continue
					if not parents.has(it.name):
						parents[it.name] = []
					if not parents[it.name].has(name):
						parents[it.name].append(name)
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var home: Dictionary = Data.t("CORE_ITEM_STATION")
	var best = null
	var best_key := []
	for name in feeds:
		var entry = null
		for e in Data.t("ENTRIES"):
			if e.name == name and e.station == home.get(name):
				entry = e
				break
		if entry == null:
			entry = Catalog.entry(name)
		if entry == null or not Catalog.needs_of(entry.reqs).items.all(func(it): return Catalog.owns(state, it.name)) 				or not Catalog.item_open(state, name):
			continue
		var els: Dictionary = Catalog.needs_of(entry.reqs).els
		var missing: Array = els.keys().filter(func(sym): return Catalog.count(state, sym) < els[sym])
		var can_now: bool = Catalog.can_craft(state, entry) and suit_cost_payable(name)
		var key := [1 if can_now else 0, feeds[name].size(), parents.get(name, []).size(), -missing.size(), pts.get(name, 0)]
		var better := best == null
		if not better:
			var diff := 0.0
			for i in key.size():
				if key[i] != best_key[i]:
					diff = key[i] - best_key[i]
					break
			better = diff > 0 or (diff == 0 and best.name.naturalnocasecmp_to(name) > 0)  # ties: alphabetical
		if better:
			best = {"name": name, "entry": entry, "roots": feeds[name], "can_now": can_now, "missing": missing}
			best_key = key
	if best != null:
		best.homes = Data.t("ENTRIES").filter(func(e): return e.name == best.name).map(func(e): return e.station)
	return best


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

