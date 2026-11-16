## Plays a whole run through the screens (App and its hub), the way a player
## taps: roll, craft what's craftable, go to the map, pick a reachable
## station, travel (locking in on check turns), until the run is over.
## Checks the screens follow and nothing errors.
##   G --path godot --quit-after 3000 res://tests/ui_play.tscn
extends Node

var fails := 0
var balloon_done := false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL " + what)


func _ready() -> void:
	Progress.autosave = false
	Engine.time_scale = 20.0  # the Lock-In count and fades, fast
	seed(7)
	var app := App.new()
	add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.start_run("Coral Reef")
	await get_tree().process_frame
	var turns := 0
	while not Game.state.get("ended") and not Game.state.get("runComplete") and turns < 60:
		turns += 1
		check(app._screen is StationScreen, "turn %d: at a station" % turns)
		check(app.home_face() == "roll", "turn %d: Home says Roll" % turns)
		app._on_hub("home")  # roll
		if not balloon_done:
			balloon_done = _craft_through_balloon(app)
		for e in StationScreen.shop_entries(Game.ctx.current):
			if not Catalog.owns(Game.state, e.name) and Catalog.can_craft(Game.state, e) and Game.suit_cost_payable(e.name):
				Game.craft(e.name, Game.suggest_suit_picks(e.name))
		app._on_hub("home")  # map
		await get_tree().process_frame
		check(app._screen is MapScreen, "turn %d: on the map" % turns)
		if Game.state.get("finalCheckPending"):
			check(app.home_face() == "final", "final check face")
			app._on_hub("home")
			check(await _until(func(): return Game.state.get("runComplete")), "the final count ends the run")
			break
		var options: Array = Data.t("MAP_NODE_POS").keys().filter(func(n): return app.can_travel_to(n))
		Game.ctx.selectedMapStation = options[randi() % options.size()]
		Game.state_changed.emit()
		check(app.home_face() == "travel", "turn %d: Home says Travel" % turns)
		app._on_hub("home")  # travel
		if app.panel == "drawer":
			check(app.home_face() == "lockin", "turn %d: check turn, Home says Lock In" % turns)
			app._on_hub("home")
			var ask := app.get_children().filter(func(c): return c is ConfirmDialog)
			if not ask.is_empty():  # "your run ends here": yes
				check(Game.lock_in_ends_run(), "asked only when the Lock-In ends the run")
				ask[0].on_yes.call()
				ask[0].queue_free()
			else:  # the count, then the Bonus Dice window; Nice travels
				var reward := Orders.reward_for(Game.mat_score().total, Orders.check_round(Game.state))
				check(await _until(func(): return app.get_children().any(func(c): return c is LockInReward)), "turn %d: the Bonus Dice window opens" % turns)
				var dlg: LockInReward = app.get_children().filter(func(c): return c is LockInReward)[0]
				check(dlg.dice == mini(reward, 3) and dlg.unknown == (reward >= 4), "turn %d: shows the reward" % turns)
				dlg._done()
				check(await _until(func(): return app._screen is StationScreen and app.panel == ""), "turn %d: the fade lands at the station" % turns)
		await get_tree().process_frame
	print("ui_play: %d turns, visits %d, %s, %d items, best mat %d" % [turns, Game.state.visits,
		"run complete" if Game.state.get("runComplete") else "game over" if Game.state.get("finalGameOver") else "?", Game.state.items.size(), Game.state.bestMatScore])
	check(Game.state.get("runComplete") or Game.state.get("finalGameOver"), "the run ended properly")
	check(balloon_done, "crafted something through the suit-spend balloon")
	print("ui_play: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(0 if fails == 0 else 1)


## Waits (up to ~600 frames) until cond() is true.
func _until(cond: Callable) -> bool:
	for i in 600:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


## Crafts the first craftable item here that has a suit cost through the
## balloon, tapping like a player (one more from the element with the most
## spare each time). Checks it's crafted and exactly recipe + cost was spent.
func _craft_through_balloon(app: App) -> bool:
	for e in StationScreen.shop_entries(Game.ctx.current):
		if Catalog.owns(Game.state, e.name) or Game.suit_cost_need(e.name).is_empty() 				or not Catalog.can_craft(Game.state, e) or not Game.suit_cost_payable(e.name):
			continue
		var before := 0.0
		for v in Game.state.elements.values():
			before += v
		var n := Catalog.needs_of(e.reqs)
		var spend := 0.0
		for sym in n.els:
			if not e.reqs.any(func(r): return r.name == sym and r.kind == "element" and r.catalyst):
				spend += n.els[sym]
		var need := Game.suit_cost_need(e.name)
		for su in need:
			spend += need[su]
		app.craft_tap(e.name, Rect2(100, 400, 60, 35))
		var b: SuitSpend = app.get_children().filter(func(c): return c is SuitSpend)[0]
		var guard := 0
		while is_instance_valid(b) and not b.is_queued_for_deletion() and guard < 20:
			guard += 1
			var tapped := false
			for su in need:
				if b._picked_for(su) >= need[su]:
					continue
				var best := ""
				var spare := 0.0
				for el in Data.t("SUIT_CORE_ELEMENTS")[su]:
					var left: float = Catalog.count(Game.state, el) - b._reserved().get(el, 0) - b._picks.get(el, 0)
					if left > spare:
						best = el
						spare = left
				b._tap(best, su, int(Catalog.count(Game.state, best) - b._reserved().get(best, 0)))
				tapped = true
				break
			if not tapped:
				break
		var after := 0.0
		for v in Game.state.elements.values():
			after += v
		check(Catalog.owns(Game.state, e.name), "balloon crafted " + e.name)
		check(is_equal_approx(before - after, spend), "%s: spent %d elements, recipe + suit cost is %d" % [e.name, before - after, spend])
		return true
	return false
