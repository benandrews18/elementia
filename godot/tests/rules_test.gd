## Hand-written rule tests for actions the golden runs don't play (PLAN.md,
## "Rules parity"), with expectations taken from the HTML game's code.
##   G --headless --path godot --quit-after 600 res://tests/rules_test.tscn
extends Node

var fails := 0


func parity_diff(a: Variant, b: Variant) -> String:
	return load("res://tests/parity.gd").diff(a, b, "")


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL " + what)


## A run in progress at `station` on visit 5, before rolling.
func fresh(station := "The Ocean") -> Dictionary:
	Game.state = Game.fresh_state()
	Game.state.visits = 5
	Game.state.mat = []
	Game.ctx = {"current": station, "screen": "station", "travelPromptFor": null, "selectedMapStation": null, "lockInCommitted": false}
	return Game.state


func _ready() -> void:
	Progress.autosave = false
	# Util
	check(Util.js_round(2.5) == 3 and Util.js_round(-2.5) == -2, "js_round halves up like Math.round")
	check(Util.stable_sort([[1, "a"], [0, "b"], [1, "c"]], func(x, y): return x[0] - y[0]).map(func(x): return x[1]) == ["b", "a", "c"], "stable_sort keeps ties in order")
	check(Orders.key({"id": "collector", "p": null}) == "collector:null", "order keys match JS")

	# Convert 3:1
	var s := fresh()
	s.elements = {"H": 4}
	check(Game.convert_elements("H", "O") and s.elements == {"H": 1.0, "O": 1.0} and s.converts == 1, "convert 3 H -> 1 O")
	check(not Game.convert_elements("H", "O"), "convert needs 3")
	check(not Game.convert_elements("O", "O"), "convert to itself refused")

	# "?" spend: only this station's elements
	s = fresh("The Ocean")
	s.emptyElements = 1
	var ocean_die: String = Catalog.station("The Ocean").dice[0]
	check(not Game.spend_unknown("Zz"), "? refuses an element the station doesn't have")
	check(Game.spend_unknown(ocean_die) and s.emptyElements == 0 and Catalog.count(s, ocean_die) == 1 and s.qSpent == 1, "? spent on a station element")
	check(not Game.spend_unknown(ocean_die), "no ? left")

	# Suit costs: paid exactly, from the suit's own elements, sparing the recipe
	var item := ""
	for n in Data.t("ITEM_SUIT_COST_TABLE"):
		var e = Catalog.entry(n)
		if e != null and Data.t("ITEM_SUIT_COST_TABLE")[n].size() == 1:
			item = n
			break
	check(item != "", "found an item with one suit cost")
	s = fresh()
	var e = Catalog.entry(item)
	var suit: String = Data.t("ITEM_SUIT_COST_TABLE")[item][0]
	var need: Dictionary = Catalog.needs_of(e.reqs).els
	s.items = Catalog.needs_of(e.reqs).items.map(func(x): return x.name)
	for sym in need:
		s.elements[sym] = need[sym]
	var payer: String = Data.t("SUIT_CORE_ELEMENTS")[suit].filter(func(x): return not need.has(x))[0]
	check(not Game.suit_cost_payable(item), "%s: suit cost not payable with only the recipe" % item)
	s.elements[payer] = 1
	check(Game.suit_cost_payable(item), "%s: payable with one spare %s" % [item, payer])
	check(not Game.craft_paying(item, {}), "unpaid suit cost refused")
	check(not Game.craft_paying(item, {payer: 2}), "overpaying refused")
	check(Game.craft_paying(item, {payer: 1}) and Catalog.owns(s, item) and Catalog.count(s, payer) == 0, "%s crafted, %s paid" % [item, payer])

	# Market row rewards
	s = fresh()
	s.pendingBingoClears = [0, 2]
	check(Game.collect_market_rewards() == 2 and s.emptyElements == 2 and s.pendingBingoClears.is_empty(), "two finished rows pay two ?")

	# Challenge reroll: a ? for a different challenge
	s = fresh()
	s.visits = 12
	s.lastCheckedMat = ["Water"]
	s.order = {"id": "drought", "p": "organic", "round": 12}
	s.usedOrders = ["drought:organic"]
	s.emptyElements = 1
	check(Game.reroll_order() and Orders.key(s.order) != "drought:organic" and s.emptyElements == 0 and s.usedOrders.size() == 2, "reroll swaps the challenge for a ?")
	check(not Game.reroll_order(), "no reroll without a ?")

	# Mat: placing, full mat, capstone room, Last
	s = fresh()
	s.visits = 19  # fully grown
	var t2: Array = Data.t("MAT_CARDS").filter(func(c): return c.tier == "CREATION").map(func(c): return c.name).slice(0, 9)
	var cap: String = Data.t("CAPSTONES")[0]
	s.items = t2 + [cap]
	for i in 8:
		check(Game.toggle_mat_card(t2[i]) == "", "place card %d" % i)
	check(Game.toggle_mat_card(t2[8]) == "The display mat is full.", "9th card refused")
	check(Game.toggle_mat_card(cap) == "A capstone needs two free slots.", "capstone needs two slots")
	check(Game.toggle_mat_card(t2[0]) == "" and Game.toggle_mat_card(t2[1]) == "" and Game.toggle_mat_card(cap) == "", "capstone fits in two freed slots")
	s.lastCheckedMat = [t2[0]]
	var before: Array = s.mat.duplicate()
	Game.mat_last_tap()
	check(s.mat == [t2[0]] and s.quickSavedMat == before, "Last: back to the locked-in mat, this one quick-saved")
	Game.mat_last_tap()
	check(s.mat == before and s.quickSavedMat == null, "Last again: the quick-saved mat is back")

	# Starting a run
	var capstone: String = Data.t("CAPSTONES")[2]
	Game.start_run(capstone)
	s = Game.state
	var home: String = Data.t("CORE_ITEM_STATION")[capstone]
	var gift := Catalog.sorted_dice(Catalog.station(home))
	check(int(s.visits) == 1 and Game.ctx.current == home, "run starts at the capstone's station")
	check(s.bingoCard.size() == 12 and s.bingoCard.has(capstone) and s.bingoCenterChosen, "Market rows drawn around the capstone")
	check(Progress.is_pinned(capstone), "capstone pinned")
	var logged := 0
	for k in s.visitLog[0].elements:
		logged += s.visitLog[0].elements[k]
	check(logged == gift.size() and s.elements.keys().size() > 0, "starting gift given and logged on turn 1")

	# Trophies: awarded once a day, repeats count, the run counts toward totals once
	Game.state.runComplete = true
	Progress.trophies = {}
	Progress.prefs.erase("lifetime")
	var stars_before: int = Progress.prefs.stars
	var won := Progress.award_trophies()
	check(won.size() > 0 and Progress.trophies.has("first-run") and Progress.prefs.stars == stars_before + won.size() * int(Data.t("STARS_TROPHY")), "trophies awarded with Stars")
	check(Progress.prefs.lifetime.runs == 1 and Game.state.lifetimeCounted, "run counted toward totals")
	check(Progress.award_trophies().is_empty() and Progress.prefs.lifetime.runs == 1, "same day: nothing again, not counted twice")
	Progress.trophies["first-run"].last = "2000-01-01"
	var again := Progress.award_trophies()
	check(again.size() == 1 and again[0].again == 2 and Progress.trophies["first-run"].n == 2, "a new day earns it again (x2)")

	# History and a save round trip (a scratch file, never the real save)
	Progress.history = []
	Progress.record_history()
	check(Progress.history.size() == 1 and Progress.history[0].capstones == [] and int(Progress.history[0].visits) == 1, "run recorded in history")
	Progress._write("user://_rules_test.json", Game.state)
	var back: Dictionary = Progress._read("user://_rules_test.json", {})
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_rules_test.json"))
	check(parity_diff(back, Game.state) == "", "save round trip: " + parity_diff(back, Game.state))

	# Overtime: every Lock-In risks the run; visit 40 ends it
	s = fresh()
	s.visits = 26  # not a regular check visit: only Overtime makes it risky
	s.runComplete = true
	s.matChecked = true
	check(Game.lock_in_ends_run(), "Overtime: an empty mat's Lock-In ends the run")
	Game.ctx.selectedMapStation = "The City"
	Game.confirm_lock_in()
	check(s.ended and s.finalGameOver and int(s.visits) == 26, "Overtime game over, no travel")
	s = fresh()
	s.visits = int(Data.t("MAX_VISITS"))
	s.runComplete = true
	Game.go_map()
	check(s.ended and s.reachedHardLimit, "visit 40: the run ends")

	# craft() asks for suit-cost picks; craft_raw() is only the replayed rule
	s = fresh()
	var costly := ""
	for n in Data.t("ITEM_SUIT_COST_TABLE"):
		if Catalog.entry(n) != null and not Data.t("ITEM_SUIT_COST_TABLE")[n].is_empty():
			costly = n
			break
	for it in Catalog.needs_of(Catalog.entry(costly).reqs).items:  # its item components, owned
		s.items.append(it.name)
	for sym in Catalog.needs_of(Catalog.entry(costly).reqs).els:
		s.elements[sym] = 5
	for su in Game.suit_cost_need(costly):
		for el in Data.t("SUIT_CORE_ELEMENTS")[su]:
			s.elements[el] = Catalog.count(s, el) + 5
	check(not Game.craft(costly), "%s: craft() refuses without paying its suit cost" % costly)

	# Collections: discovery pays a Star; clues cost Stars and can discover
	s = fresh()
	s.visits = 19
	var col: Dictionary = Mat.collections()[0]
	s.items = col.items.duplicate()
	s.mat = col.items.duplicate()
	Progress.prefs.everUnlockedMatCollections = []
	Progress.prefs.stars = 0
	check(Progress.undiscovered_on_mat() != null and Progress.undiscovered_on_mat().id == col.id, "a completed collection waits to be discovered")
	Progress.discover_collection(col.id)
	check(Progress.undiscovered_on_mat() == null and Progress.prefs.stars == int(Data.t("STARS_DISCOVERY")), "discovered, one Star")
	Progress.prefs.stars = int(Data.t("CLUE_COST")) * 2 + 1
	var clues := Progress.buy_clues(5)
	check(clues.size() == 2 and Progress.prefs.stars == 1, "two clues bought with the Stars there were")
	check(clues.all(func(c): return not c.c.id == col.id), "clues are for hidden collections")

	# Saved layouts
	Progress.prefs.savedMatLayouts = []
	Progress.save_layout("  Mine ")
	s.mat = []
	Progress.load_layout(0)
	check(Progress.prefs.savedMatLayouts[0].name == "Mine" and s.mat == col.items, "a saved layout loads back")

	# The To-Do List's hint (computeTodoHint()); the HTML game answers Glass,
	# craftable now, for Metropolis, on this state with these pins.
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/station_visit7.json")))
	Progress.prefs.pinnedItems = ["Metropolis", "Plastic"]
	var hint = Game.todo_hint()
	check(hint != null and hint.name == "Glass" and hint.can_now and hint.roots == ["Metropolis"] and hint.homes.has("The City"), "the hint: %s" % [hint])
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mat_visit18.json")))
	for t in [[["Space Station", "Fruit Cake", "Speedboat"], "Apple", ["Space Station", "Fruit Cake"]],
			[["Metropolis"], "Wheel", ["Metropolis"]], [["Homestead", "Coral Reef"], "Farm", ["Homestead"]]]:
		Progress.prefs.pinnedItems = t[0]
		var h = Game.todo_hint()
		check(h != null and h.name == t[1] and h.can_now and h.roots == t[2], "the hint for %s: %s (the HTML game: %s)" % [t[0], h.name if h else null, t[1]])
	Progress.prefs.pinnedItems = ["Glass"]
	Game.state.items.append("Glass")
	check(Game.todo_hint() == null, "no hint once everything pinned is owned")

	# Tracking (selectedJobItem): a 📌 tap pins and tracks; unpinning the
	# tracked item, or crafting it, stops tracking it; what it still needs
	# "feeds" it.
	fresh()
	Progress.prefs.pinnedItems = []
	Game.toggle_pin("Metropolis")
	check(Progress.is_pinned("Metropolis") and Game.ctx.tracked == "Metropolis", "a pin tracks the item")
	var still: Array = Catalog.still_needed(Game.state, "Metropolis")
	check(not still.is_empty() and Game.feeds_tracked(still[0]) and not Game.feeds_tracked("Metropolis"), "what the tracked item still needs feeds it (not itself)")
	Game.toggle_pin("Metropolis")
	check(not Progress.is_pinned("Metropolis") and Game.ctx.tracked == null, "unpinning the tracked item stops tracking it")
	var leaf := ""  # an item made of elements only
	for x in Data.t("ENTRIES"):
		if Catalog.needs_of(x.reqs).items.is_empty() and Data.t("ITEM_SUIT_COST_TABLE").get(x.name, []).is_empty():
			leaf = x.name
			break
	s = fresh()
	for sym in Catalog.needs_of(Catalog.entry(leaf).reqs).els:
		s.elements[sym] = 9
	Game.toggle_pin(leaf)
	check(Game.craft(leaf) and Game.ctx.tracked == null, "crafting the tracked item (%s) stops tracking it" % leaf)

	# A save made mid-visit resumes at that station (Godot only); leaving
	# for the map forgets it.
	fresh()
	Game.go_station("The City")
	Game.ctx = {"current": null, "screen": "map", "travelPromptFor": null, "selectedMapStation": null, "lockInCommitted": false}
	Game.resume()
	check(Game.ctx.current == "The City" and Game.ctx.screen == "station", "a mid-visit save resumes at the station")
	Game.go_map()
	Game.resume()
	check(Game.ctx.current == null and Game.ctx.screen == "map", "after leaving, a save resumes on the map")

	# Saving: the temp file is swapped in over the old save; a write cut off
	# half-way (only the temp file) leaves the last good save; a file of the
	# wrong kind reads as the default.
	var path := "user://rules_test_save.json"
	Progress._write(path, {"visits": 3})
	Progress._write(path, {"visits": 4})
	check(Progress._read(path, null) == {"visits": 4.0} and not FileAccess.file_exists(path + ".tmp"), "a save replaces the last one")
	FileAccess.open(path + ".tmp", FileAccess.WRITE).store_string("{\"visi")
	check(Progress._read(path, null) == {"visits": 4.0}, "a cut-off write keeps the last good save")
	FileAccess.open(path, FileAccess.WRITE).store_string("[1]")
	check(Progress._read(path, {}) == {} and Progress._read(path, null) == null, "a file of the wrong kind reads as the default")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")

	print("rules_test: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(0 if fails == 0 else 1)
