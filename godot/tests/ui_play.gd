## Plays a whole run through the screens (App and its hub), the way a player
## taps: roll, craft what's craftable, go to the map, pick a reachable
## station, travel (locking in on check turns), until the run is over.
## Checks the screens follow and nothing errors. Then the Final Score, the
## Market and the To-Do List, each from a fresh run.
##   G --headless --path godot --quit-after 20000 res://tests/ui_play.tscn [-- --only run|final_score|market|todo|cards|items|settings]
## Headless runs at a fixed frame rate, as fast as the PC allows (no window).
extends Node

var fails := 0
var balloon_done := false
var expansions := 0
var convert_done := false
var finished := {}  # section -> true once it ran to its end (a script error stops one quietly)



func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL " + what)


func _ready() -> void:
	Progress.autosave = false
	Progress.prefs.hints = false  # no 💡 hints (the tips section turns them on)
	Progress.prefs.tutorialSeen = true  # New Game skips the first-play tutorial (its own section plays it)
	Engine.time_scale = 20.0  # the Lock-In count and fades, fast
	seed(7)
	var app := App.new()
	add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var only: String = load("res://tests/shot.gd")._args().get("only", "")
	var parts: Array = ["run", "final_score", "market", "todo", "cards", "items", "settings", "welcome", "pins", "tips", "tutorial", "layouts", "collections", "dev"] if only == "" else [only]
	for part in parts:
		await call("_" + part, app)
	for part in parts:
		check(finished.has(part), "the %s section ran to its end (else a script error stopped it)" % part)
	print("ui_play: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(0 if fails == 0 else 1)


## The opening, then a whole run turn by turn, then the end screen.
func _run(app: App) -> void:
	# The opening: New Game, pick Coral Reef, confirm; the gift flies in and
	# the run starts at its station.
	Progress.prefs.hiddenTips = []
	app.new_game()
	check(await _until(func(): return app.get_children().any(func(c): return c is CapstoneChoice)), "the logo, then the capstone choice (no how-to-play slides)")
	var pick: CapstoneChoice = app.get_children().filter(func(c): return c is CapstoneChoice)[0]
	check(Game.state.visits == 0 and app._screen is MapScreen, "the opening waits on the bare map")
	pick._confirm("Coral Reef")
	pick._start("Coral Reef", pick._card)
	check(await _until(func(): return app._screen is StationScreen), "the opening lands at a station")
	check(Game.ctx.current == Data.t("CORE_ITEM_STATION")["Coral Reef"] and Progress.is_pinned("Coral Reef"), "at Coral Reef's station, Coral Reef pinned")
	var turns := 0
	while not Game.state.get("ended") and not Game.state.get("runComplete") and turns < 60:
		turns += 1
		check(app._screen is StationScreen, "turn %d: at a station" % turns)
		check(app.home_face() == "roll", "turn %d: Home says Roll" % turns)
		app._on_hub("home")  # roll
		var pop: Array = app.get_children().filter(func(c): return c is RollPopup)
		check(pop.size() == 1 and app.home_face() == "gather" and pop[0].has_node("Gather"), "turn %d: the roll's window up, Home says Gather in its spotlight" % turns)
		if not pop.is_empty():
			for t in get_tree().get_processed_tweens():  # the reveal, done: Collect shows
				t.custom_step(10)
			app._on_hub("home")  # tap twice to gather
			check(pop[0].collecting and app.home_face() == "map", "turn %d: Gather collects, Home back to its own face" % turns)
		if not balloon_done:
			balloon_done = _craft_through_balloon(app)
		if not convert_done:
			convert_done = await _convert(app)
		for e in StationScreen.shop_entries(Game.ctx.current):
			if not Catalog.owns(Game.state, e.name) and Catalog.can_craft(Game.state, e) and Game.suit_cost_payable(e.name):
				Game.craft(e.name, Game.suggest_suit_picks(e.name))
		app._on_hub("home")  # map
		await get_tree().process_frame
		check(app._screen is MapScreen, "turn %d: on the map" % turns)
		await _settle_market(app)  # a crafted Market square: its sequence and its "?" (Nice)
		if app.panel == "market":
			app.close_panel()
		if Game.state.get("finalCheckPending"):
			check(await _until(func(): return app.panel == "drawer" and not _busy(app)), "the Final Score shutter opens the mat")
			_dismiss(app)
			check(app.home_face() == "play" and Game.check_hand() != null, "the final check is played with a hand")
			app.hand_lock_in()
			check(await _until(func(): return Game.state.get("runComplete")), "the final count ends the run")
			break
		var options: Array = Data.t("MAP_NODE_POS").keys().filter(func(n): return app.can_travel_to(n))
		Game.ctx.selectedMapStation = options[randi() % options.size()]
		Game.state_changed.emit()
		if turns == 1:  # a tap on the map (not a station) puts the card away
			app._screen.gui_input.emit(_press(Vector2(5, 300)))
			app._screen.gui_input.emit(_release(Vector2(5, 300)))
			check(Game.ctx.selectedMapStation == null, "a tap on the map hides the station card")
			check(app._screen.get_children().any(func(c): return c.has_meta("dust")), "a tap on the map puffs dust")
			Tap._down = null  # the press is remembered: later test taps land elsewhere
			Game.ctx.selectedMapStation = options[0]
			Game.state_changed.emit()
		check(app.home_face() == "travel", "turn %d: Home says Travel" % turns)
		var check_turn := Catalog.is_mat_check_visit(Game.state)
		app._on_hub("home")  # travel
		if check_turn:
			check(await _until(func(): return app.panel == "drawer" and not _busy(app)), "turn %d: the shutter opens the mat" % turns)
			check(not app.get_children().any(func(c): return c is MatRules or (c is ParchDialog and c.tip_id == "orderTip")), "turn %d: no rules or challenge tip windows (they're hints)" % turns)
			if Orders.current(Game.state) != null:
				check(await _until(func(): return app.get_children().any(func(c): return c is OrderInfo or c is MatExpand)), "turn %d: the challenge (or the expansion) shows" % turns)
			_dismiss(app)
		if app.panel == "drawer":
			var hd = Game.check_hand()
			check(hd != null and hd.hand.size() == mini(Hand.start(), hd.hand.size() + hd.deck.size()) and app.home_face() == "play" and app._hub.hand, "turn %d: check turn: a hand (up to %d), Play in the middle" % [turns, Hand.start()])
			check(Game.state.mat.size() == Util.get_or(Game.state, "matPlays", []).reduce(func(a, p): return a + p.size(), 0), "turn %d: the mat cleared for the check (only this check's plays on it)" % turns)
			# Play a card at a time while one fits (the hand refills), as a player would.
			var mat := app._hand_mat()
			while hd != null and mat != null and Game.check_hand() != null and not mat.playing:
				var fit: Array = hd.hand.filter(func(n): return Hand.gain(Game.state, Game.ctx, [n]) != null)
				if fit.is_empty():
					break
				mat.picks = [fit[0]]
				mat.hand_play()
				for c in app.get_children():  # a collection the play found: its window first; Add
					if c is CollectionFound and not c.is_queued_for_deletion():
						c.get_node("Window/Content/Add").gui_input.emit(_release())
						await get_tree().process_frame
						await get_tree().process_frame
			if mat != null:
				mat.picks = []
			app.hand_lock_in()
			var ask := app.get_children().filter(func(c): return c is ConfirmDialog)
			if not ask.is_empty():  # "your run ends here": yes
				check(Game.lock_in_ends_run(), "asked only when the Lock-In ends the run")
				ask[0].on_yes.call()
				ask[0].queue_free()
			else:  # the count, then the Bonus Dice window; Nice travels
				var reward := Orders.reward_for(Game.mat_score().total, Orders.check_round(Game.state))
				check(app._hub.greyed, "turn %d: Lock In greys while it counts" % turns)
				check(await _until(func(): return app.get_children().any(func(c): return c is LockInReward)), "turn %d: the Bonus Dice window opens" % turns)
				var dlg: LockInReward = app.get_children().filter(func(c): return c is LockInReward)[0]
				check(dlg.dice == mini(reward, 3) and dlg.unknown == (reward >= 4), "turn %d: shows the reward" % turns)
				var qm := dlg.get_node_or_null("MeterBar/Meter") as QuarkMeter
				check(qm != null and qm._passed == reward, "turn %d: the reward's quark meter shows the breakpoints passed" % turns)
				check(not app._hub.greyed, "turn %d: Lock In back to colour after the count" % turns)
				dlg._done()
				check(await _until(func(): return app._screen is StationScreen and app.panel == ""), "turn %d: the fade lands at the station" % turns)
				check(Game.state.get("hand") == null, "turn %d: the hand is gone after the check" % turns)
		await get_tree().process_frame
	print("ui_play: %d turns, visits %d, %s, %d items, best mat %d" % [turns, Game.state.visits,
		"run complete" if Game.state.get("runComplete") else "game over" if Game.state.get("finalGameOver") else "?", Game.state.items.size(), Game.state.bestMatScore])
	check(Game.state.get("runComplete") or Game.state.get("finalGameOver"), "the run ended properly")
	check(balloon_done, "crafted something through the suit-spend balloon")
	check(convert_done, "converted through the Convert tray")
	check(Game.state.visits < 12 or expansions > 0, "the mat-expansion reveal showed")
	check(await _until(func(): return app.get_children().any(func(c): return c is EndGame)), "the end screen shows")
	# "Review my collection", then closing the mat: the end screen comes back.
	var shown := func(cls): return app.get_children().any(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	for c in app.get_children():
		if c is EndGame:
			c.queue_free()
	app.open_panel("drawer")
	app.close_panel()
	if Game.state.get("ended"):  # Run Complete: Overtime goes on, no end screen again
		check(await _until(func(): return shown.call(EndGame)), "closing the mat after the run ends brings the end screen back")
	# New Game from there: the capstone choice, and the end screen stays gone.
	for c in app.get_children():
		if c is EndGame:
			c.queue_free()
	Progress.hide_tip("classicTut")  # "✕ Hide" was tapped: no slides this time
	app.new_game()
	check(await _until(func(): return shown.call(CapstoneChoice)) and not shown.call(EndGame) and not shown.call(HowToPlay),
		"New Game: the capstone choice (slides hidden for good), not the end screen")
	for c in app.get_children():
		if c is CapstoneChoice:
			c.queue_free()
	finished.run = true


## The run's last turn (24): leaving the station plays the "Final Score!"
## shutter and opens the mat; Home counts it and the run is complete.
func _final_score(app: App) -> void:
	Game.start_run("Coral Reef")
	await get_tree().process_frame
	Game.state.visits = int(Data.t("RUN_COMPLETE_VISIT"))
	Game.state.rolledHere = true
	Game.state_changed.emit()
	check(app.home_face() == "map", "turn 24: Home says Map")
	app._on_hub("home")
	check(Game.state.get("finalCheckPending") == true, "turn 24: the final check is pending")
	check(await _until(func(): return app.panel == "drawer" and not _busy(app)), "turn 24: the shutter opens the mat")
	check(await _until(func(): return app.get_children().any(func(c): return c is OrderInfo)), "turn 24: the Grand Exhibition shows")
	_dismiss(app)
	check(app.home_face() == "play" and Game.check_hand() != null, "turn 24: the final check is played with a hand")
	app.hand_lock_in()
	check(await _until(func(): return Game.state.get("runComplete") == true), "turn 24: the count completes the run")
	check(await _until(func(): return app.get_children().any(func(c): return c is EndGame and c._completing)), "turn 24: Run Complete shows")
	finished.final_score = true


## Converts 3 of the first element held 3+ into one Fe (or C) through the
## tray: FROM from the picker, TO from the picker, then the arrow.
func _convert(app: App) -> bool:
	var three: Array = Game.state.elements.keys().filter(func(s): return Game.state.elements[s] >= 3)
	if three.is_empty():
		return false
	var from: String = three[0]
	var to := "Fe" if from != "Fe" else "C"
	var before_from := Catalog.count(Game.state, from)
	var before_to := Catalog.count(Game.state, to)
	app.open_panel("convert")
	check(app.home_face() == "close", "Convert open: Home says Close")
	var tray: ConvertTray = app._panel_node
	for side in ["from", "to"]:
		tray._pick(side)
		var p: ElementPicker = app.get_children().filter(func(c): return c is ElementPicker).back()  # the last one's freed only at frame end
		p.queue_free()
		p.on_pick.call(from if side == "from" else to)
	tray.do_convert()
	check(Catalog.count(Game.state, from) == before_from - 3 and Catalog.count(Game.state, to) == before_to + 1, "converted 3 %s into 1 %s" % [from, to])
	check(tray.from == "" and tray.to == "", "the tray resets after converting")
	app.close_panel()
	await get_tree().process_frame
	return true


## The Market's moments, as crafts land: the run's first square ever opens
## the tray; a later one only puts "!" on the Market button; every square
## pays one "?" on Nice, a finished row nothing more. (The crafts are
## stood in for by owning the items: the screens react to the same state.)
func _market(app: App) -> void:
	for c in app.get_children():
		if c is EndGame:
			c.queue_free()
	Game.start_run("Coral Reef")
	await get_tree().process_frame
	var row: Array = Market.lines()[0].map(func(i): return Game.state.bingoCard[i])
	var own := func(n):
		Game.state.items.append(n)
		Market.check_lines(Game.state)
		Game._changed()
	var q: int = Util.get_or(Game.state, "emptyElements", 0)
	own.call(row[0])
	check(await _until(func(): return app.panel == "market"), "the first Market square opens the tray")
	check(await _nice(app) and await _until(func(): return Util.get_or(Game.state, "emptyElements", 0) == q + 1), "its ? is paid on Nice")
	check(await _until(func(): return app.panel == ""), "the tray closes again after the square")
	own.call(row[1])
	check(await _nice(app) and app.panel == "" and Game.state.get("marketUnseen") == true, "a later square: its ? window without the tray, and the Market button marked")
	check(await _until(func(): return Util.get_or(Game.state, "emptyElements", 0) == q + 2 and Game.state.pendingBingoClears.is_empty()), "Nice pays the square's ?")
	app._on_hub("market")
	check(app.panel == "market" and not Game.state.marketUnseen and app.home_face() == "map", "the Market button opens the tray (Home reads Map) and clears its mark")
	app._on_hub("home")
	check(app.panel == "", "Home closes the tray")
	own.call(row[2])
	await _nice(app)
	own.call(row[3])
	await _nice(app)
	check(await _until(func(): return Util.get_or(Game.state, "emptyElements", 0) == q + 4 and Game.state.bingoLinesCompleted.has(0)), "a finished row: its squares paid, the row nothing more")
	# Crafting a square from the open Market: its Crafting Bench, Craft.
	await get_tree().process_frame
	var name := ""
	for i in Market.lines()[1] + Market.lines()[2]:  # (every square has a suit cost: the balloon pays it)
		if not Catalog.owns(Game.state, Game.state.bingoCard[i]):
			name = Game.state.bingoCard[i]
			break
	var e: Dictionary = Catalog.entry(name)
	var needs := Catalog.needs_of(e.reqs)
	for it in needs.items:  # what it takes, handed over
		if not Catalog.owns(Game.state, it.name):
			Game.state.items.append(it.name)
	for sym in needs.els:
		Game.state.elements[sym] = needs.els[sym]
	var cost := Game.suit_cost_need(name)
	for su in cost:  # the suit cost, in the suit's first element
		var el: String = Data.t("SUIT_CORE_ELEMENTS").get(su, Data.t("SUIT_CORE_ELEMENTS").values()[0])[0]
		Game.state.elements[el] = Catalog.count(Game.state, el) + cost[su]
	_squares_reset(app)
	if app.panel != "market":  # the row's own tray may still be open (the button would close it)
		app._on_hub("market")
	var bench := MarketCraft.open(app, name)
	var shop_row: ShopRow = bench.get_node("Bench").get_children().filter(func(c): return c is ShopRow)[0]
	var plays := app.market_plays
	shop_row.on_craft.call(name, Rect2(100, 400, 60, 35))  # its Craft button
	if not Game.suit_cost_need(name).is_empty():
		_pay_balloon(app, Game.suit_cost_need(name))
	check(Catalog.owns(Game.state, name), "crafted %s from its Market square" % name)
	check(await _until(func(): return not is_instance_valid(bench) or bench.is_queued_for_deletion()), "the Crafting Bench closes once it's made")
	check(await _until(func(): return app.market_plays > plays), "the square bounces in the open tray")
	check(await _nice(app), "its ? window")
	check(await _until(func(): return not app._market_playing), "and the tray settles")
	# The tray closed in the middle of its bounces: the sequence still ends
	# (it used to stop on the freed tray, its tap blocker left on screen).
	var kids := app.get_child_count()
	app._market_sequence([0], [])
	app.close_panel()
	check(await _until(func(): return not app._market_playing) and app.get_child_count() <= kids, "a tray closed mid-bounce: the sequence still ends, nothing left blocking taps")
	app.close_panel()
	finished.market = true


## The To-Do List: the hub button opens it (Home reads Close); the hint
## opens the breakdowns down to its suggestion; a pin in a tree pins.
func _todo(app: App) -> void:
	Game.start_run("Coral Reef")
	await get_tree().process_frame
	Progress.prefs.pinnedItems = ["Metropolis"]
	TodoTray.expanded.clear()
	TodoTray.hint_open = false
	app._on_hub("jobs")
	check(app.panel == "todo" and app.home_face() == "close", "the To-Do List opens (Home reads Close)")
	var tray: TodoTray = app._panel_node
	tray.hint_open = true
	tray._open_hint_paths()
	var hint = Game.todo_hint()
	check(hint != null and TodoTray.expanded.has("refroot/Metropolis"), "the hint opens the breakdown it's in (%s)" % [hint.name if hint else null])
	var comp: String = Catalog.needs_of(Catalog.entry("Metropolis").reqs).items[0].name
	RefTree.new(RefTree.PARCHMENT, func(_p): pass).pin_button(comp, Vector2.ZERO).gui_input.emit(_release())  # a tree row's pin
	check(Progress.is_pinned(comp), "a pin in the tree pins " + comp)
	Game.set_tracked(null)
	await get_tree().process_frame
	var find_track := func(): return _find_meta(app._panel_node, "todo:track:Metropolis")
	find_track.call().gui_input.emit(_release())
	check(Game.ctx.tracked == "Metropolis", "the To-Do List's 🔍 tracks its item")
	await get_tree().process_frame
	find_track.call().gui_input.emit(_release())
	check(Game.ctx.tracked == null, "a second tap stops tracking it")
	app._on_hub("jobs")
	check(app.panel == "", "the To-Do List button closes it again")
	TodoTray.hint_open = false
	finished.todo = true


## Card pop-ups: a station's element chip opens Convert on it; an element card; an item's
## card drills into a component (Back returns), pins, and an element part
## swaps to the element card; a tap closes each.
func _cards(app: App) -> void:
	Game.start_run("Coral Reef")
	app.close_panel()
	await get_tree().process_frame
	var open := func(cls): return app.get_children().filter(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	var chip: Control = app._screen.get_node("Scroll/Page/Chips").get_child(0)
	var press := _release()
	press.pressed = true
	chip.gui_input.emit(press)
	chip.gui_input.emit(_release())
	var sym: String = Catalog.sorted_dice(Catalog.station(Game.ctx.current))[0]
	check(app.panel == "convert" and app._panel_node.to == sym, "a station's element chip opens Convert with it picked to convert into")
	app.close_panel()
	# The list view's side card: a suit cost's balloon points at the card's suit badges, not at Craft.
	var with_cost: Array = StationScreen.shop_entries(Game.ctx.current).filter(func(e): return not Data.t("ITEM_SUIT_COST_TABLE").get(e.name, []).is_empty())
	if not with_cost.is_empty():
		StationScreen.list_mode = true
		app._screen.open_card = with_cost[0].name
		app._screen._redraw()
		await get_tree().process_frame
		var cbtn := _find_meta(app._screen, "st:craft:" + with_cost[0].name)
		var r := StationScreen._costs_rect(app._screen._side.get_child(0).get_node("Card/Costs"), cbtn)
		check(cbtn != null and r.end.y < cbtn.get_global_rect().position.y, "the list view's Craft: a suit cost's balloon points at the card's suit badges")
		StationScreen.list_mode = false
		app._screen.open_card = ""
		app._screen._redraw()
	# The Crafting Bench: a missing element in the card's recipe opens Convert on it.
	var shop: Array = StationScreen.shop_entries(Game.ctx.current)
	var want = shop.filter(func(e): return e.reqs.any(func(r): return r.kind == "element" and Catalog.count(Game.state, r.name) == 0))
	if want.is_empty():
		check(false, "a station card needs an element not held (for the bench test)")
	else:
		app.open_card(want[0].name)
		await get_tree().process_frame
		var missing: String = want[0].reqs.filter(func(r): return r.kind == "element" and Catalog.count(Game.state, r.name) == 0)[0].name
		var need := _find_meta(app._screen, "need:" + missing)
		check(need != null, "the bench's recipe marks %s as missing" % missing)
		if need:
			need.gui_input.emit(_press(Vector2.ZERO))
			need.gui_input.emit(_release())
			check(app.panel == "convert" and app._panel_node.to == missing, "a missing element on the Crafting Bench opens Convert with it on the To side")
			check(app.panel == "convert" and app._panel_node.bench_item == want[0].name and is_instance_valid(app._panel_node._bench) and _find_meta(app._panel_node._bench, "craft:" + want[0].name) != null,
				"and the card's Crafting Bench rides on the tray, Craft and all")
		app.close_panel()
		app.open_card("")
	# The bench's picture and its component icons open the full card (step 21).
	var with_part: Array = shop.filter(func(e): return e.reqs.any(func(r): return r.kind != "element"))
	if not with_part.is_empty():
		app.open_card(with_part[0].name)
		await get_tree().process_frame
		var row := _find_meta(app._screen, "row:" + with_part[0].name)
		var opens: Array = row.find_children("*", "Control", true, false).filter(func(c): return c.has_meta("opens")) if row else []
		for o in opens:
			o.gui_input.emit(_press(Vector2.ZERO))
			o.gui_input.emit(_release())
			var pops: Array = app.get_children().filter(func(c): return c is CardPop and not c.is_queued_for_deletion())
			check(not pops.is_empty() and pops[-1].entry.get("name") == o.get_meta("opens"), "the bench's %s opens the full card of %s" % ["picture" if o.name == "IconBox" else "component", o.get_meta("opens")])
			for c in pops:
				c.queue_free()
		check(opens.size() >= 2, "the bench's picture and a component icon open cards")
		app.open_card("")
	# A hand card's pop-out (crafted): no ⚛ marks or ticks on its parts.
	var plain := CardPop.side_card(want[0].name if not want.is_empty() else "Water", 150, true)
	app.add_child(plain)
	var quarks := plain.find_children("*", "TextureRect", true, false).filter(func(t): return t.texture != null and t.texture.resource_path.ends_with("btn_quark.webp"))
	check(quarks.is_empty(), "a hand card's pop-out has no ⚛ convert marks")
	plain.queue_free()
	# The mat's combo chips and 🏆.
	var three: Array = StationScreen.shop_entries(Game.ctx.current).filter(func(e): return Catalog.mat_card(e.name) != null).slice(0, 3).map(func(e): return e.name)
	for n in three:
		if not Game.state.items.has(n):
			Game.state.items.append(n)
	Game.state.mat = three.duplicate()
	app.open_panel("drawer")
	await get_tree().process_frame
	var chipn: Control = app._panel_node._chip_nodes.get("station:" + Game.ctx.current)
	check(chipn != null, "three cards from this station: its combo chip")
	if chipn:
		Tap._down = null
		chipn.gui_input.emit(_release())
		var ci: Array = open.call(ComboInfo)
		check(ci.size() == 1 and ComboInfo.cards_for("station", Game.ctx.current).size() >= 3, "a tap on a combo chip lists the cards making it")
		for c in ci:
			c.queue_free()
	var trophy := _find_meta(app._panel_node, "inv:collections")
	if trophy:
		Tap._down = null
		trophy.gui_input.emit(_release())
		check(open.call(CollectionsWindow).size() == 1, "the Inventory's 🏆 opens Collections")
		for c in open.call(CollectionsWindow):
			c.queue_free()
	else:
		check(false, "the Inventory's 🏆 is there")
	Game.state.mat = []
	app.close_panel()
	# A crafted card leaves the Crafting Bench.
	var craftable = shop.filter(func(e): return Catalog.can_craft(Game.state, e) and Game.suit_cost_payable(e.name) and not Catalog.owns(Game.state, e.name))
	if not craftable.is_empty():
		app.open_card(craftable[0].name)
		Game.craft(craftable[0].name, Game.suggest_suit_picks(craftable[0].name))
		check(app._screen.open_card == "", "a crafted card leaves the Crafting Bench")
	# The shop cards' bottom-left circle: the tracked item's icon on what it
	# still needs (a tap: the To-Do List, lit there), else the pin.
	var top_item = shop.filter(func(e): return not Catalog.owns(Game.state, e.name) and not Catalog.still_needed(Game.state, e.name).is_empty())
	if not top_item.is_empty():
		Game.ctx.tracked = top_item[0].name
		Game._changed()
		await get_tree().process_frame
		var comp = Catalog.still_needed(Game.state, top_item[0].name).filter(func(n): return _find_meta(app._screen, "st:slot:" + n) != null)
		check(_find_meta(app._screen, "st:slot:" + top_item[0].name) != null, "the tracked item's own card has the pin circle")
		if not comp.is_empty():
			var slot := _find_meta(app._screen, "st:slot:" + comp[0])
			slot.gui_input.emit(_press(Vector2.ZERO))
			slot.gui_input.emit(_release())
			check(app.panel == "todo" and TodoTray.focus == comp[0] and TodoTray.expanded.has("refroot/" + top_item[0].name), "a component's tracked-item circle opens the To-Do List, its breakdown open to it")
			app.close_panel()
			check(TodoTray.focus == "", "closing the To-Do List lets go of it")
		Game.ctx.tracked = null
	app.show_element_card(sym)
	check(open.call(ElementCard).size() == 1, "an element card opens")
	open.call(ElementCard)[0].get_node("Card").gui_input.emit(_release())
	await get_tree().process_frame
	check(open.call(ElementCard).is_empty(), "a tap closes the element card")
	# Every card's components in one row at the shared size, bar the two
	# outliers (smaller) and Planet (its 16 elements wrap).
	var odd := []
	for n in Data.t("CORE_ITEM_NAMES"):
		app.show_card(n)
		var cp: CardPop = open.call(CardPop)[0]
		if n != "Planet" and cp.last_scale != CardPop.FIT:
			odd.append(n)
		cp.free()
	check(odd.size() <= 3 and odd.has("Car"), "card views: one row at the shared size, bar the outliers %s" % [odd])
	app.show_card("Bridge")
	var pop: CardPop = open.call(CardPop)[0]
	check(not pop.get_node("Actions/Back").visible, "a fresh card has no Back")
	var item_part = pop.get_node("Card/Parts").get_children().filter(func(c): return c.has_meta("cmp") and not c is Label).front()
	check(item_part != null, "Bridge shows an item among its components")
	if item_part != null:
		item_part.gui_input.emit(_release())
		check(pop.entry.name != "Bridge" and pop.get_node("Actions/Back").visible, "a component opens its card, with Back")
		pop.get_node("Actions/Back").gui_input.emit(_release())
		check(pop.entry.name == "Bridge" and not pop.get_node("Actions/Back").visible, "Back returns to Bridge")
	var was := Progress.is_pinned("Bridge")
	pop.get_node("Actions/Pin").gui_input.emit(_release())
	check(Progress.is_pinned("Bridge") != was, "📌 on the card pins it")
	pop.get_node("Actions/Pin").gui_input.emit(_release())
	pop.get_node("Card").gui_input.emit(_release())
	await get_tree().process_frame
	check(open.call(CardPop).is_empty(), "a tap closes the card")
	app.show_card("Steel")  # elements and an item
	pop = open.call(CardPop)[0]
	var el_part = pop.get_node("Card/Parts").get_children().filter(func(c): return c is Label and c.has_meta("cmp")).front()
	check(el_part != null, "Steel shows an element among its components")
	if el_part != null:
		el_part.gui_input.emit(_release())
		await get_tree().process_frame
		check(open.call(CardPop).is_empty() and open.call(ElementCard).size() == 1, "an element component swaps to its element card")
	for c in open.call(ElementCard) + open.call(CardPop):
		c.queue_free()
	await get_tree().process_frame
	# After a craft (C5): the small card, flying off by itself; a capstone's
	# card with its banner, then (once closed) the items it unlocked.
	for c in app.get_children():  # rolls the run section never collected: the reveal waits for a clear screen
		if c is RollPopup:
			c.free()
	Game.last_tax = {}
	Game.crafted.emit("Glass")  # two kept items (Sand, Limestone), no elements
	var peeks := func(): return app.get_children().filter(func(c): return c.has_meta("peek") and not c.is_queued_for_deletion())
	var fx := func(): return app.get_children().filter(func(c): return c.has_meta("craft_fx") and not c.is_queued_for_deletion())
	check(peeks.call().size() == 1, "a craft pops up its small card")
	var keeps: Array = fx.call().filter(func(c): return c is ItemCard)
	check(keeps.size() == 2 and keeps[0].get_index() < app._hub.get_index(), "a craft's kept items peek up from behind the hub")
	check(await _until(func(): return peeks.call().is_empty()), "the small card flies into the Inventory")
	check(await _until(func(): return fx.call().is_empty()), "the kept items go back down, freed")
	var el_item: Dictionary = Data.t("ENTRIES").filter(func(e): return e.tier != "CAPSTONE" and e.reqs.any(func(r): return r.kind == "element" and not r.catalyst))[0]
	var n_spent: int = el_item.reqs.filter(func(r): return r.kind == "element" and not r.catalyst).size()
	Game.crafted.emit(el_item.name)
	check(fx.call().size() == 1 and fx.call()[0].get_child_count() == n_spent, "a craft's spent elements rise onto its card, one square each (%s: %d)" % [el_item.name, n_spent])
	check(await _until(func(): return fx.call().is_empty() and peeks.call().is_empty()), "they pop and are freed; the card flies off")
	Game.state.items.append("Metropolis")
	Game.crafted.emit("Metropolis")
	var cel: Array = open.call(CardPop)
	check(cel.size() == 1 and cel[0].entry.name == "Metropolis", "a capstone opens its card")
	check(await _until(func(): return fx.call().is_empty()), "a capstone's craft pieces play out over its card and are freed")
	if cel.size() == 1:
		cel[0].queue_free()
	check(await _until(func(): return open.call(UnlockReveal).size() == 1), "then New Items Unlocked")
	for c in open.call(UnlockReveal):
		c.queue_free()
	Game.state.items.erase("Metropolis")
	finished.cards = true


## The Items screen: the hub's Items opens it (Home reads Close); search
## keeps only matches; a row opens its breakdown; 📌 on a row pins; Item
## Info on a card opens the screen at that item; Items again closes it.
func _items(app: App) -> void:
	Game.start_run("Coral Reef")
	app.close_panel()
	await get_tree().process_frame
	app._on_hub("codex")
	check(app.panel == "codex" and app.home_face() == "close", "the hub's Items opens the Items screen (Home reads Close)")
	var scr: ItemsScreen = app._panel_node
	var rows := func(): return scr._rows.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())
	var open_items: Array = Data.t("ENTRIES").map(func(e): return e.name).filter(func(n): return Catalog.item_open(Game.state, n))
	var uniq := {}
	for n in open_items:
		uniq[n] = true
	check(rows.call().size() == uniq.size(), "one row per open item (%d)" % uniq.size())
	scr.get_node("Bar/Search").text_changed.emit("steel")
	var shown: Array = rows.call().filter(func(r): return r.visible)
	check(not shown.is_empty() and shown.all(func(r): return String(r.get_meta("search")).contains("steel")), "searching keeps only the matches")
	scr.get_node("Bar/Search").text_changed.emit("")
	var row: RefRow = rows.call().filter(func(r): return r.item == "Bridge")[0]
	row.gui_input.emit(_press(Vector2(100, 400)))  # a finger that drags the list by this row
	row.gui_input.emit(_release(Vector2(100, 340)))
	await get_tree().process_frame
	check(not TodoTray.expanded.has("refroot/Bridge"), "dragging the list by a row doesn't open it (Tap)")
	var ds: DragScroll = app.get_children().filter(func(c): return c is DragScroll)[0]
	var bar: VScrollBar = scr._scroll.get_v_scroll_bar()
	check(scr._scroll.scroll_deadzone > 100000, "Godot's own list drag is off (DragScroll's instead)")
	row = rows.call().filter(func(r): return r.item == "Bridge")[0]
	await get_tree().process_frame
	var y0 := bar.value
	var lpm := OS.low_processor_usage_mode
	ds._input(_press(Vector2(100, 600)))  # the finger goes down on a row (rows stop input: Godot's drag never saw them)
	row.gui_input.emit(_press(Vector2(100, 600)))
	for i in 8:
		ds._input(_drag(Vector2(100, 600 - 12 * (i + 1))))
	check(absf(bar.value - (y0 + 96 - 12)) < 1.0, "a drag on a row scrolls the list with the finger (past the slop: %.0f -> %.0f)" % [y0, bar.value])
	check(not OS.low_processor_usage_mode, "every frame drawn while a finger is down")
	var held := bar.value
	ds._input(_release(Vector2(100, 504)))
	row.gui_input.emit(_release(Vector2(100, 504)))
	for i in 5:
		await get_tree().process_frame
	check(not TodoTray.expanded.has("refroot/Bridge"), "a drag never taps the row")
	check(bar.value > held, "a quick release flings the list on")
	ds._input(_press(Vector2(100, 400)))
	row.gui_input.emit(_press(Vector2(100, 400)))
	ds._input(_release(Vector2(100, 400)))
	row.gui_input.emit(_release(Vector2(100, 400)))
	var stopped := bar.value
	await get_tree().process_frame
	await get_tree().process_frame
	check(bar.value == stopped and not TodoTray.expanded.has("refroot/Bridge"), "a press on a flinging list stops it and isn't a tap")
	check(OS.low_processor_usage_mode == lpm, "low processor mode back once nothing moves")
	bar.value = y0
	DragScroll.caught = false  # the later checks press rows without _input (which resets it each press)
	row = rows.call().filter(func(r): return r.item == "Bridge")[0]
	row.gui_input.emit(_press(Vector2(100, 400)))
	row.gui_input.emit(_release(Vector2(103, 404)))  # a tap: the finger stayed put
	Tap._down = null  # the other checks send bare releases
	await get_tree().process_frame
	check(TodoTray.expanded.has("refroot/Bridge"), "a tap on a row opens its breakdown")
	row = rows.call().filter(func(r): return r.item == "Bridge")[0]
	check(row.get_node("Tree").get_child_count() > 0, "the breakdown shows under the row")
	var apple: RefRow = rows.call().filter(func(r): return r.item == "Apple")[0]
	var banana: RefRow = rows.call().filter(func(r): return r.item == "Banana")[0]
	Game._changed()
	check(rows.call().has(apple) and rows.call().has(banana) and rows.call().size() == uniq.size(), "a change keeps the rows it doesn't touch (not rebuilt)")
	var was := Progress.is_pinned("Banana")
	banana.get_node("Pin").gui_input.emit(_release())
	await get_tree().process_frame
	check(Progress.is_pinned("Banana") != was and (rows.call().filter(func(r): return r.item == "Banana")[0].get_parent().name == "PinTable") == Progress.is_pinned("Banana"),
		"📌 on a row pins it (into the Pinned table)")
	check(rows.call().has(apple) and (not is_instance_valid(banana) or not rows.call().has(banana)), "pinning makes only that row again")
	if Progress.is_pinned("Banana") != was:
		Progress.toggle_pin("Banana")
	app._on_hub("codex")
	check(app.panel == "", "Items again closes it")
	app.show_card("Steel")
	var pop: CardPop = app.get_children().filter(func(c): return c is CardPop).back()
	pop.get_node("Actions/Info").gui_input.emit(_release())
	await get_tree().process_frame
	check(app.panel == "codex" and TodoTray.expanded.keys() == ["refroot/Steel"], "Item Info opens the Items screen at that item, its breakdown open")
	app.close_panel()
	finished.items = true


## Collections: a collection complete on the mat brings "New collection!"
## (Add: found, a Star); its row has no on/off switch;
## from the title screen a clue costs Stars and opens as a gift; Combo Lab
## swaps in a sandbox run and Exit puts the real one back, unsaved.
func _collections(app: App) -> void:
	for c in app.get_children().slice(app._hub.get_index() + 1):
		if c is Control:
			c.queue_free()
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mat_visit18.json")))
	Progress.prefs.everUnlockedMatCollections = ["bedrock", "fruits"]
	Progress.prefs.collectionClues = {}
	Progress.prefs.stars = 7
	app.close_panel()
	for i in 2:
		await get_tree().process_frame
	var top := func(cls): return app.get_children().filter(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	check(top.call(CollectionFound).size() == 1 and top.call(CollectionFound)[0].collection.id == "alloys", "Alloys complete on the mat: New collection!")
	top.call(CollectionFound)[0].get_node("Window/Content/Add").gui_input.emit(_release())
	check(Progress.prefs.everUnlockedMatCollections.has("alloys") and Progress.prefs.stars == 8, "Add: found for good, and a Star")
	await get_tree().process_frame
	var cw := CollectionsWindow.show_on(app)
	await get_tree().process_frame
	var row = cw.get_node("Window/Content/Scroll/Pad/Rows").get_children().filter(func(r): return not r.is_queued_for_deletion())[0]
	check(row.get_node_or_null("Toggle") == null, "a found collection has no on/off switch (the mat changes only by playing)")
	var rws: Array = cw.get_node("Window/Content/Scroll/Pad/Rows").get_children().filter(func(r): return r is CollectionRow and not r.is_queued_for_deletion())
	var ids: Array = rws.map(func(r): return r.get_meta("collection"))
	var near: Array = ids.filter(func(i): return Progress.prefs.everUnlockedMatCollections.has(i)).map(func(i): return CollectionRow.closeness(Mat.collections().filter(func(c): return c.id == i)[0]))
	var sorted_near := near.duplicate()
	sorted_near.sort()
	sorted_near.reverse()
	check(near == sorted_near and _find_meta(cw, "coll:legend").visible and _find_meta(cw, "coll:more") != null, "in a run: found collections closest-to-done first, a legend, how many are left")
	var on_mat_item: String = Game.state.mat[0] if not Game.state.mat.is_empty() else ""
	var tile := _find_meta(cw, "coll:item:" + on_mat_item) if on_mat_item != "" else null
	check(on_mat_item == "" or tile == null or tile.get_meta("place") == "mat", "a tile says its item is on the mat")
	cw.close()
	cw = CollectionsWindow.show_on(app, true)
	cw.get_node("Window/Content/Shop/One").gui_input.emit(_release())
	check(Progress.prefs.stars == 8 - int(Data.t("CLUE_COST")) and top.call(ClueOpen).size() == 1, "one clue: its Stars spent, a gift to open")
	var gift: ClueOpen = top.call(ClueOpen)[0]
	gift._card()
	check(gift.get_node("Window/Content/CardHolder").get_child_count() == 1 and gift.get_node("Window/Content/Next/Text").text == "Done", "the gift opens to its clue card")
	gift.get_node("Window/Content/Next").gui_input.emit(_release())
	check(top.call(ClueOpen).is_empty(), "Done closes it")
	cw.close()
	var real := Game.state
	app.open_combo_lab()
	check(Game.ctx.get("comboLab") == true and Game.state != real and Game.state.items.size() > real.items.size() and not app._hub.visible, "Combo Lab: a sandbox run, every item, no hub")
	Game.toggle_mat_card(Game.state.items[0])
	app.close_combo_lab()
	check(Game.state == real and app._hub.visible and not Game.ctx.get("comboLab", false), "Exit puts the real run back")
	# The Challenge Test (card playing, tried in the lab): a copy of the run at
	# the picked check, a hand to play; Lock In goes back to the lab.
	var real_mat: Array = real.mat.duplicate()
	app.open_combo_lab()
	var lab := Game.state
	app.get_node("LabBar/Test").gui_input.emit(_release())
	var pick: Array = top.call(ParchDialog).filter(func(d): return d.has_node("Window/Content/Rounds/R12"))
	check(pick.size() == 1, "Challenge Test opens the round picker")
	pick[0].get_node("Window/Content/Rounds/R12").gui_input.emit(_release())
	await get_tree().process_frame
	for c in top.call(OrderInfo):
		c.queue_free()
	var hd: Dictionary = Game.state.get("hand", {})
	check(Game.state != real and Game.state != lab and int(Game.state.visits) == 12 and Game.state.order != null, "the test: a copy of the run at check 12, with its challenge")
	check(hd.get("hand", []).size() == 7 and Game.state.mat.is_empty(), "a hand of 7; the mat cleared for the check")
	var dm := app._panel_node as DisplayMatScreen
	check(not dm._scroll.visible and _find_meta(dm, "hand:discard") != null and _find_meta(dm, "hand:lockin") == null and _find_meta(dm, "hand:draw") != null, "the hand in place of the item list; Discard and Draw under the mat, no Lock In")
	check(_find_meta(dm, "tab:Elements") == null and app._hub.visible and app._hub.hand and app._hub.face == "play" and app._hub.muted, "no page tabs; the hub's middle button is Play, muted with nothing picked")
	check(app._hub.get_node("Jobs/Label").text == "To-Do List" and app._hub.off.get("market") == true, "the hub's other buttons as usual (the To-Do List too), the Market shut")
	var goal := _find_meta(dm, "hand:goal")
	check(goal != null and goal.position.x < _find_meta(dm, "hand:pass").position.x, "🎯 Goal above the hand, left of Pass")
	if goal:
		Tap._down = null
		goal.gui_input.emit(_release())
		check(top.call(OrderInfo).size() == 1, "Goal opens the challenge")
		for c in top.call(OrderInfo):
			c.queue_free()
	check(_find_meta(dm, "hand:deck") != null, "the deck's count in the middle")
	_find_meta(dm, "hand:deck").gui_input.emit(_release())
	check(dm.browsing and dm._scroll.visible and _find_meta(dm, "hand") == null, "the deck tapped: the whole Inventory, no hand")
	check(_find_meta(dm, "mat:add") == null, "browsing: no Add / Remove (the mat changes only by playing)")
	(_find_meta(dm, "hand:back") as Button).pressed.emit()
	check(not dm.browsing and not dm._scroll.visible and _find_meta(dm, "hand:deck") != null, "Back to your hand")
	var page_was: Panel = dm._page
	var first: String = hd.hand[0]
	dm._lift(first)
	check(dm._page == page_was and dm.lifted == first, "picking a card doesn't rebuild the mat; one pick shows its card")
	check(_find_meta(dm._page, "hand:gain") != null and not app._hub.muted, "picked: what it adds shows over the mat; Play in full colour")
	check(_find_meta(dm._page, "hand:landing") != null, "picked: the slot it would take lights up")
	var deck_n: int = hd.deck.size()
	app._on_hub("home")
	check(Game.state.mat == [first] and hd.hand.size() == 7 and hd.deck.size() == deck_n - 1 and Game.state.matPlays == [[first]], "Play: the card on the mat, the hand refilled 1 for 1")
	var flying := func(): return app.get_children().filter(func(c): return c.has_meta("flying") and not c.is_queued_for_deletion()).size()
	dm = app._panel_node as DisplayMatScreen
	check(flying.call() == 1 and dm._mat_nodes[first].modulate.a == 0.0, "the played card flies to its slot (hidden there until it lands)")
	check(HandView._arrive.has(hd.hand[-1]), "the refill rises from below")
	check(await _until(func(): return flying.call() == 0 and dm._mat_nodes[first].modulate.a == 1.0), "the flight ends: its copy freed, the card shows in its slot")
	dm._lift(hd.hand[0])
	var on_mat: Array = dm._mat_nodes.values().map(func(c): return Rect2(c.position, c.size).grow(-2))
	var lit: Array = []
	for n in dm._page.get_children():
		for l in n.get_children():
			if l.get_meta("cmp", "") == "hand:landing":
				lit.append(Rect2(l.position, l.size))
	check(not lit.is_empty() and not lit.any(func(r): return on_mat.any(func(m): return m.intersects(r))), "a pick's landing lights only open slots, never a card already there")
	dm._lift("")
	# The ⭐: a known collection the hand and the mat can finish, one of its cards still in the hand.
	var col: Dictionary = Mat.collections()[0]
	var was_found: Array = Progress.prefs.everUnlockedMatCollections.duplicate()
	Progress.prefs.everUnlockedMatCollections = [col.id]
	var fake := {"hand": [col.items[0]]}
	var mat_was: Array = Game.state.mat
	Game.state.mat = col.items.slice(1)
	check(DisplayMatScreen.starred(fake).has(col.items[0]) and DisplayMatScreen.starred(fake).size() == col.items.size(), "⭐ on each card of a known collection the hand can finish")
	var sc := ItemCard.make(col.items[0], {"star": col.id})
	sc.size = Vector2(100, 140)
	app.add_child(sc)
	var star := _find_meta(sc, "card:star")
	check(star != null and star.get_parent().get_meta("cmp", "").ends_with(":icon"), "the ⭐ rides the item's picture")
	if star:
		Tap._down = null
		star.gui_input.emit(_release())
		var cws: Array = top.call(CollectionsWindow)
		check(cws.size() == 1 and cws[0].focus == col.id and _find_meta(cws[0], "coll:focus") != null, "a tap on the ⭐: Collections, that collection lit")
		for c in cws:
			c.queue_free()
	sc.queue_free()
	fake.hand = []
	Game.state.mat = col.items.duplicate()
	check(DisplayMatScreen.starred(fake).is_empty(), "no ⭐ when all of it is on the mat")
	Progress.prefs.everUnlockedMatCollections = []
	fake.hand = [col.items[0]]
	Game.state.mat = col.items.slice(1)
	check(DisplayMatScreen.starred(fake).is_empty(), "no ⭐ for a collection not found yet")
	# A collection a play finds: its reveal window first, then the cards land.
	var plays_was: Array = Game.state.matPlays.duplicate(true)
	var hand_before: Array = hd.hand.duplicate()
	var items_before: Array = Game.state.items.duplicate()
	Game.state.mat = col.items.slice(1)
	hd.hand[0] = col.items[0]
	for n in col.items:
		if not Game.state.items.has(n):
			Game.state.items.append(n)
	Game._changed()
	dm = app._panel_node as DisplayMatScreen
	dm._lift(col.items[0])
	dm.hand_play()
	await get_tree().process_frame
	var reveal: Array = top.call(CollectionFound)
	check(reveal.size() == 1 and reveal[0].collection.id == col.id and not Game.state.mat.has(col.items[0]), "a play that finds a collection: its window first, the card not played yet")
	if reveal.size() == 1:
		reveal[0].get_node("Window/Content/Add").gui_input.emit(_release())
	check(await _until(func(): return Game.state.mat.has(col.items[0])), "then the card lands")
	check(Progress.prefs.everUnlockedMatCollections.has(col.id) and top.call(CollectionFound).is_empty(), "found once, no second window")
	await _until(func(): return flying.call() == 0)
	Game.state.matPlays = plays_was
	hd.hand.assign(hand_before)
	Game.state.items = items_before
	Progress.prefs.everUnlockedMatCollections = was_found
	Game.state.mat = mat_was
	Game._changed()
	dm = app._panel_node as DisplayMatScreen
	# Combo cards: those in a live group (a gold border).
	var by_st := {}
	for n in Game.state.items:
		var mc = Catalog.mat_card(n)
		if mc != null and not Mat.is_capstone(mc) and not Mat.is_tier1(mc):
			by_st[mc.stations[0]] = by_st.get(mc.stations[0], []) + [mc]
	for st in by_st:
		if by_st[st].size() >= 3:
			var three: Array = by_st[st].slice(0, 3)
			var lone = Catalog.mat_card("Water")
			var cm := DisplayMatScreen.combo_members(three + [lone], Mat.score(three + [lone], {"visits": 12}, {}))
			check(three.all(func(c): return cm.has(c.name)), "three cards of a station: all combo cards")
			break
	# Several picked: Discard throws them all out, for one discard.
	var two: Array = hd.hand.slice(0, 2)
	dm._lift(two[0])
	dm._lift(two[1])
	check(dm.picks == two and dm.lifted == two[1] and _find_meta(dm._hand_view, "hand:lifted") != null, "two hand cards picked: both raised, the last tapped big in the fan")
	dm._lift(two[1])
	check(dm.picks == [two[0]] and dm.lifted == two[0], "a picked card tapped again goes back; one left shows its card")
	dm._lift(two[1])
	var tosses: int = hd.tosses
	var held: Array = hd.hand.duplicate()
	Tap._down = null
	_find_meta(dm, "hand:discard").gui_input.emit(_release())
	check(hd.hand.size() == 7 and hd.discards == two and hd.tosses == tosses - 1, "Discard: both cards out for one discard, the hand refilled")
	check(flying.call() == 2 and hd.hand.filter(func(n): return not held.has(n)).all(func(n): return HandView._arrive.has(n)), "the discards fly off, the refills rise")
	dm = app._panel_node as DisplayMatScreen
	_find_meta(dm, "hand:deck").gui_input.emit(_release())
	var faded := func(n): return _find_meta(dm, "inv:" + n) != null and _find_meta(dm, "inv:" + n).modulate != Color.WHITE
	check(faded.call(two[0]) and faded.call(first) and not faded.call(hd.hand[0]), "browsing: the mat's cards and the discards faded, the rest not")
	(_find_meta(dm, "hand:back") as Button).pressed.emit()
	dm = app._panel_node as DisplayMatScreen
	dm._lift(hd.hand[0])
	dm._blank_tap(_release())
	check(dm.picks.is_empty() and dm.lifted == "", "a tap on a blank space lets go of the picks")
	dm._on_card_input(_press(Vector2.ZERO), first)
	dm._on_card_input(_release(), first)
	var big := _find_meta(app, "mat:big")
	check(Game.state.mat.has(first) and dm.selected == "" and big != null and big.get_meta("card") == first, "a mat card tapped: shown big over its place; nothing comes off the mat")
	check(_find_meta(dm, "convert") == null, "no Convert in the check's corner (it's on the Elements page)")
	if big:
		big.get_node("Close").gui_input.emit(_release())
		await get_tree().process_frame
		check(not is_instance_valid(big) or big.is_queued_for_deletion(), "a tap anywhere puts it back")
	# An owned capstone: always on, its chip beside the mat; a tap shows its card.
	var cap: String = Data.t("CAPSTONES").filter(func(c): return not Catalog.owns(Game.state, c))[0]
	Game.state.items.append(cap)
	dm._redraw()
	var cap_chip = dm._chip_nodes.get("cap:" + cap)
	check(cap_chip != null and not dm._mat_nodes.has(cap), "an owned capstone: a chip beside the mat, no slot")
	if cap_chip != null:
		Tap._down = null
		cap_chip.gui_input.emit(_release())
	check(top.call(CardPop).size() == 1 and top.call(CardPop)[0].entry.name == cap, "a capstone's chip tapped: its card")
	for c in top.call(CardPop):
		c.queue_free()
	Game.state.items.erase(cap)
	dm._redraw()
	# Element draws on the mat's Elements tab; Convert works as ever.
	var esym := ""
	for sym in Data.t("CLASSIC_ELEMENTS"):
		if Hand.suit_card(hd, sym) != "":
			esym = sym
			break
	Game.state.elements = {esym: 2}
	Game.state.emptyElements = 1
	Game._changed()
	dm = app._panel_node as DisplayMatScreen
	check(_find_meta(dm, "convert") == null, "no Convert in the mat's corner during a check")
	dm.view = "elements"
	dm._redraw()
	check(_find_meta(dm, "convert") != null, "Convert on the Elements page")
	dm.view = "mat"
	app.open_panel("convert")
	check(app._panel_node is ConvertTray and (app._panel_node as ConvertTray).to == "" and app._hub.face == "close", "its tray is the usual one")
	check(is_instance_valid(dm) and not dm.is_queued_for_deletion() and dm.visible, "Convert opens over the mat (the mat stays open under it)")
	var over := _find_meta(app._floats, "convert")
	check(over != null, "the Convert button shows over its tray")
	if over:
		Tap._down = null
		over.gui_input.emit(_release())
		check(app.panel == "drawer" and app._panel_node == dm, "a tap on it closes the tray, back to the same mat")
		app.open_panel("convert")
	app._on_hub("home")
	check(app.panel == "drawer" and Game.state.get("hand") == hd, "closing it goes back to the hand")
	dm = app._panel_node as DisplayMatScreen
	Tap._down = null
	_find_meta(dm, "hand:draw").gui_input.emit(_release())
	check(dm.view == "elements" and _find_meta(dm, "el:" + esym) != null, "Draw flips the mat to its Elements page")
	var suit_cards := Hand.suit_cards(hd, esym)
	var want_card: String = suit_cards[-1]  # the player's pick, not just the deck's first
	var n_hand: int = hd.hand.size()
	_find_meta(dm, "el:" + esym).gui_input.emit(_release())
	var picks_el: Array = top.call(CardPick)
	check(picks_el.size() == 1 and hd.hand.size() == n_hand and picks_el[0].get_node("Window/Content/Scroll/Cards").get_child_count() == suit_cards.size(),
		"Elements tab: a tapped element opens a pick of its suit's deck cards")
	if picks_el.size() == 1:
		var pc = _find_meta(picks_el[0], "pick:" + want_card)
		check(pc != null and pc.mouse_filter == Control.MOUSE_FILTER_PASS, "the pick's cards let a drag scroll")
		Tap._down = null
		Tap._scrolled = true  # a drag that scrolled the list
		pc.gui_input.emit(_release())
		check(hd.hand.size() == n_hand, "a drag on a card never takes it")
		Tap._scrolled = false
		pc.gui_input.emit(_release())
	check(hd.hand.size() == n_hand + 1 and hd.hand.has(want_card) and Catalog.count(Game.state, esym) == 1, "Elements tab: a tapped element is spent on the card picked")
	dm = app._panel_node as DisplayMatScreen
	var hand_was: Array = hd.hand.duplicate()
	while hd.hand.size() < Hand.most():
		hd.hand.append(hd.deck.pop_back())
	_find_meta(dm, "el:?").gui_input.emit(_release())
	check(top.call(CardPick).is_empty() and dm.get_children().any(func(c): return c is Label and c.text == "Your hand is full."), "the ? with a full hand: says so, no card pick")
	hd.deck += hd.hand.filter(func(n): return not hand_was.has(n))
	hd.hand = hand_was
	_find_meta(dm, "el:?").gui_input.emit(_release())
	var cps: Array = top.call(CardPick)
	var pick_card: String = hd.deck[-1]
	check(cps.size() == 1, "the ? opens the card pick")
	if cps.size() == 1:
		cps[0]._take(pick_card)
	check(hd.hand.has(pick_card) and int(Game.state.emptyElements) == 0 and app.panel == "drawer", "an Unknown Element picks any card from the deck")
	dm = app._panel_node as DisplayMatScreen
	dm.view = "elements"
	dm._redraw()
	dm._lift(hd.hand[0])
	check(dm.view == "mat" and dm.picks.size() == 1, "picking a card on the Elements page turns back to the mat")
	dm._lift("")
	check(_find_meta(dm, "hand:pass") != null, "Pass in the middle")
	Tap._down = null
	_find_meta(dm, "hand:pass").gui_input.emit(_release())
	var done_ask: Array = top.call(ConfirmDialog)
	check(done_ask.size() == 1 and Game.check_hand() != null, "Done with a card that still fits: asks first")
	if done_ask.size() == 1:
		done_ask[0].on_yes.call()
		done_ask[0].queue_free()
	check(await _until(func(): return not top.call(LockInReward).is_empty()), "Lock In counts, then the reward")
	top.call(LockInReward)[0].on_done.call()
	top.call(LockInReward)[0].queue_free()
	check(Game.state == lab and not Game.state.has("hand") and app.get_node("LabBar/Test").text.contains("Challenge") and not app._hub.visible, "then back to the lab")
	app.close_combo_lab()
	check(Game.state == real and real.mat == real_mat, "the real run is untouched")
	finished.collections = true


## Saved Layouts (the Combo Lab's now: the run's mat is locked in): the
## mat's 💾 opens it; a name and 💾 save the mat; a tap on its row puts it
## back; 🗑 asks, then deletes it.
func _layouts(app: App) -> void:
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mat_visit18.json")))
	Game.ctx.travelPromptFor = null  # between checks
	Progress.prefs.savedMatLayouts = []
	app.close_panel()
	app.open_panel("drawer")
	await get_tree().process_frame
	var locked_mat := app._panel_node as DisplayMatScreen
	check(locked_mat.locked() and _find_meta(locked_mat, "btn:💾") == null and _find_meta(locked_mat, "btn:Clear") == null and _find_meta(locked_mat, "btn:Combo Lab") != null,
		"between checks the mat is locked: no 💾, Clear or Last, a Combo Lab button")
	var run_items: Array = Game.state.items.duplicate()
	_find_meta(locked_mat, "btn:Combo Lab").pressed.emit()
	check(Game.ctx.get("comboLab") and Game.state.items == run_items and Game.state.mat.size() > 0, "the Inventory's Combo Lab: this run's items and mat")
	await get_tree().process_frame
	var mat_before: Array = Game.state.mat.duplicate()
	var save_btn: Button = app._panel_node.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("cmp", "") == "btn:💾")[0]
	save_btn.pressed.emit()
	var top := func(cls): return app.get_children().filter(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	check(top.call(LayoutsWindow).size() == 1, "the mat's 💾 opens Saved Layouts")
	var lw: LayoutsWindow = top.call(LayoutsWindow)[0]
	lw.get_node("Window/Content/SaveRow/Row/Name").text = "Test mat"
	lw.get_node("Window/Content/SaveRow/Row/Save").gui_input.emit(_release())
	check(Progress.prefs.savedMatLayouts.size() == 1 and Progress.prefs.savedMatLayouts[0].items == mat_before, "💾 saves the mat under its name")
	await get_tree().process_frame
	Game.clear_mat()
	var rows := func(): return lw.get_node("Window/Content/Scroll/Pad/Rows").get_children().filter(func(r): return not r.is_queued_for_deletion())
	rows.call()[0].load_pressed.emit()
	check(Game.state.mat == mat_before and top.call(LayoutsWindow).is_empty(), "a row puts its layout back on the mat, and closes")
	LayoutsWindow.show_on(app)
	lw = top.call(LayoutsWindow)[0]
	lw.get_node("Window/Content/Scroll/Pad/Rows").get_children()[0].delete_pressed.emit()  # the new window's row (rows holds the closed one)
	var ask: Array = top.call(ConfirmDialog)
	check(ask.size() == 1, "🗑 asks first")
	ask[0].get_node("Window/Content/Buttons/Yes").gui_input.emit(_release())
	check(Progress.prefs.savedMatLayouts.is_empty(), "then deletes it")
	lw.close()
	app.close_combo_lab()
	finished.layouts = true


## Professor Mouse and the tips: the first walkthrough tip (Roll) shows once,
## ✕ closes it, "✕ Hide" turns the tips off; the first "?" ever held brings
## the Unknown Element tip; How to Play runs its two windows and 7 steps.
func _tips(app: App) -> void:
	# A clean screen: earlier sections jump between states mid-animation and
	# can leave a pop-up or an input block behind (a player can't).
	for c in app.get_children().slice(app._hub.get_index() + 1):
		if c is Control:
			c.queue_free()
	app.mouse._queue.clear()  # and no tip from an earlier section (Settings turns the tips back on)
	app.mouse.hide_tip()
	# The 💡 hints (Hints): one at a time, on the thing itself; a tap and
	# Mouse says it; once a run; "Don't show again" hides just that one.
	Progress.prefs.hints = true
	Progress.prefs.hiddenTips = []
	Game.start_run("Coral Reef")
	app.close_panel()
	var badge := func(): return app.hints._badge if app.hints._on != null and is_instance_valid(app.hints._badge) else null
	check(await _until(func(): return badge.call() != null and app.hints._on.id == "roll"), "a 💡 on Roll")
	check(badge.call() != null and badge.call().get_parent() == app._hub.button("home") and not app.mouse.showing, "on the Roll button itself; Mouse waits for a tap")
	Tap._down = null
	badge.call().gui_input.emit(_release())
	var said: String = app.mouse.get_node("Bubble/Text").text
	check(app.mouse.showing and said.contains("Roll") and app.mouse.get_node("Bubble/Hide/Row/Label").text == app.hints.hide_text, "a tap: Mouse says it, with Don't show again ('%s')" % said)
	check(app.hints.seen("roll") and badge.call() == null, "tapped: seen this run, the 💡 gone")
	app.mouse.get_node("Bubble/Hide").gui_input.emit(_release())
	check(not app.mouse.showing and Progress.tip_hidden("roll") and Hints.enabled(), "Don't show again hides just that hint")
	check(app.mouse.get_node("Bubble/Hide/Row/Label").text != app.hints.hide_text, "and Mouse's Hide is itself again")
	Game.state.hintsSeen = []
	for i in 10:
		await get_tree().process_frame
	check(badge.call() == null or app.hints._on.id != "roll", "a hidden hint stays hidden (next run too)")
	Progress.prefs.hiddenTips = []
	check(await _until(func(): return badge.call() != null and app.hints._on.id == "roll"), "unhidden, it's back")
	Game.state.rolledHere = true
	Game._changed()
	check(await _until(func(): return app.hints.seen("roll")), "its moment passed while it was out: seen this run")
	Progress.prefs.hints = false
	check(await _until(func(): return badge.call() == null and app.hints._on == null), "hints off: no 💡")
	Game.state.emptyElements = 1
	Game._changed()
	for i in 3:
		await get_tree().process_frame
	check(not app.get_children().any(func(c): return c is UnknownTip), "the first \"?\" held: no window (it's a hint)")
	# The map's tracked-item badges say what they mean when tapped.
	Game.ctx.tracked = "Coral Reef"
	app._go_map()
	check(await _until(func(): return app._screen is MapScreen and app._screen.get_node("Area/Badges").get_child_count() > 0), "the map shows the tracked item's badges")
	for b: Control in app._screen.get_node("Area/Badges").get_children():
		Tap._down = null
		b.gui_input.emit(_release())
		var bub = app._screen._bubble
		var txt: String = bub.get_child(0).get_parsed_text() if is_instance_valid(bub) else ""
		check(txt.contains("tracking") or txt.contains("are here"), "a tapped badge says what it means ('%s')" % txt)
	app.show_elements()
	var dialogs := func(): return app.get_children().filter(func(c): return c is ParchDialog and not c.is_queued_for_deletion())
	check(dialogs.call().size() == 1, "The 16 Elements: the periodic table")
	dialogs.call()[0].pressed.emit("Next")
	await get_tree().process_frame
	var els: Array = dialogs.call().filter(func(c): return c is TutElements)
	check(els.size() == 1 and els[0].get_node("Window/Content/Scroll/Grid").get_child_count() == 16, "then the 16 elements")
	els[0].pressed.emit("Next")
	await get_tree().process_frame
	check(dialogs.call().is_empty(), "Next closes it")
	finished.tips = true


## Tracking: a 📌 on an Items row tracks it (the pill shows it); the 🔍
## button opens the pins tray, a chip there stops (and restarts) tracking; the
## pill opens the item's card with its tracking banner.
func _pins(app: App) -> void:
	Game.start_run("Coral Reef")
	app.close_panel()
	await get_tree().process_frame
	check(Game.ctx.tracked == "Coral Reef", "a new run tracks its capstone")
	var floats := func(): return app._floats.get_children().filter(func(c): return not c.is_queued_for_deletion())
	var btn = func(): return floats.call().filter(func(c): return c.get_meta("cmp", "") == "pins").front()
	check(floats.call().size() == 2, "the 🔍 button and the tracked pill")
	app.open_items("")
	var row: RefRow = app._panel_node._rows.filter(func(r): return r.item == "Steel")[0]
	row.get_node("Pin").gui_input.emit(_release())
	await get_tree().process_frame
	check(Game.ctx.tracked == "Steel" and Progress.is_pinned("Steel"), "a 📌 tap pins and tracks")
	app.close_panel()
	await get_tree().process_frame
	btn.call().gui_input.emit(_release())
	check(app.panel == "pins" and app._panel_node is PinsTray, "🔍 opens the pins tray")
	await get_tree().process_frame
	var chips: Array = app._panel_node.get_node("Tray/Body/Col/Chips").get_children().filter(func(c): return c is PinChip and not c.is_queued_for_deletion())
	var steel: PinChip = chips.filter(func(c): return c.get_node("Row/Name").text == "Steel")[0]
	steel.gui_input.emit(_release())
	check(Game.ctx.tracked == null, "the tracked chip stops tracking")
	await get_tree().process_frame
	check(btn.call().get_child_count() == 1, "nothing tracked: \"!\" on the 🔍 button")
	chips = app._panel_node.get_node("Tray/Body/Col/Chips").get_children().filter(func(c): return c is PinChip and not c.is_queued_for_deletion())
	chips.filter(func(c): return c.get_node("Row/Name").text == "Steel")[0].gui_input.emit(_release())
	check(Game.ctx.tracked == "Steel", "a chip tracks it again")
	btn.call().gui_input.emit(_release())
	check(app.panel == "", "🔍 again closes the tray")
	await get_tree().process_frame
	# On the map, a tap on the map itself puts the tray away; the Inventory's
	# fold button minimises the mat to a row of icons, a tap on it brings it back.
	Game.go_map()
	await get_tree().process_frame
	btn.call().gui_input.emit(_release())
	check(app.panel == "pins", "the pins tray on the map")
	Tap._down = null
	app._screen._on_map_tap(_release(Vector2(5, 300)))
	check(app.panel == "", "a tap on the map puts the pins tray away")
	app.open_panel("drawer")
	await get_tree().process_frame
	var fold := _find_meta(app._panel_node, "mat:fold")
	check(fold != null, "the mat's fold button")
	if fold:
		Tap._down = null
		fold.gui_input.emit(_release())
		check(DisplayMatScreen.collapsed and _find_meta(app._panel_node, "mat:mini") != null and _find_meta(app._panel_node, "mat:page") == null, "fold: the mat minimised to its row of icons")
		Tap._down = null
		_find_meta(app._panel_node, "mat:mini").gui_input.emit(_release())
		check(not DisplayMatScreen.collapsed and _find_meta(app._panel_node, "mat:page") != null, "a tap on the row shows the mat again")
	app.close_panel()
	Tap._down = null
	await get_tree().process_frame
	var pill: Control = floats.call().filter(func(c): return c.get_meta("cmp", "") != "pins")[0]
	pill.gui_input.emit(_release())
	var pops: Array = app.get_children().filter(func(c): return c is CardPop)
	check(pops.size() == 1 and pops[0].get_children().any(func(c): return c is TextureRect and c.texture != null and c.texture.resource_path.ends_with("btn_search.webp")), "the pill opens its card with the tracking banner")
	pops[0].queue_free()
	Progress.toggle_pin("Steel")
	finished.pins = true


## The title screen: Settings' Home and the end screen's Main Menu open it
## over the run (which stays as it was); Play opens the Classic window;
## Continue closes both.
func _welcome(app: App) -> void:
	Game.start_run("Coral Reef")
	app.close_panel()
	await get_tree().process_frame
	var top := func(cls): return app.get_children().filter(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	var visits: int = Game.state.visits
	app.open_settings()
	top.call(SettingsWindow)[0].get_node("Window/Content/Buttons/Home").gui_input.emit(_release())
	await get_tree().process_frame
	check(top.call(WelcomeScreen).size() == 1 and top.call(SettingsWindow).is_empty() and Game.state.visits == visits, "Settings' Home: the title screen, the run untouched")
	app.open_settings()  # Settings from the title screen, then Home: still one title screen
	top.call(SettingsWindow)[0].get_node("Window/Content/Buttons/Home").gui_input.emit(_release())
	await get_tree().process_frame
	check(top.call(WelcomeScreen).size() == 1, "Home over the title screen doesn't stack a second one")
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/trophies_history.json"))
	var kept := [Progress.trophies, Progress.history]
	Progress.trophies = fx.trophies
	Progress.history = fx.history
	top.call(WelcomeScreen)[0].get_node("Actions/Row2/Trophies").gui_input.emit(_release())
	check(top.call(TrophiesWindow).size() == 1, "the title screen's Trophies opens them")
	var tw: TrophiesWindow = top.call(TrophiesWindow)[0]
	var tiles: Array = tw.get_node("Window/Content/Scroll/Pad/Grid").get_children()
	check(tiles.size() == Trophies.all().size() and tw.get_node("Window/Content/Count").text.begins_with("5 of %d earned" % tiles.size()), "every trophy, 5 earned")
	tiles[0].gui_input.emit(_release())
	check(top.call(TrophyDetail).size() == 1 and top.call(TrophyDetail)[0].get_node("Window").title == "First Run", "a tile opens its detail")
	top.call(TrophyDetail)[0].get_node("Window/Content/Ok").gui_input.emit(_release())
	tw.close()
	await get_tree().process_frame
	top.call(WelcomeScreen)[0].get_node("Actions/Play").gui_input.emit(_release())
	await get_tree().process_frame
	check(top.call(ClassicMode).size() == 1, "Play opens the Classic window")
	top.call(ClassicMode)[0].get_node("Window/Content/History").pressed.emit()
	check(top.call(HistoryWindow).size() == 1, "its History row opens History")
	var hw: HistoryWindow = top.call(HistoryWindow)[0]
	var rows: Array = hw.get_node("Window/Content/Scroll/Rows").get_children()
	check(rows.size() == 2, "one row per finished run")
	rows[0].get_node("Body/Line/Row").gui_input.emit(_release())
	await get_tree().process_frame
	var first: HistEntry = hw.get_node("Window/Content/Scroll/Rows").get_children().filter(func(c): return not c.is_queued_for_deletion())[0]
	check(first.get_node("Body/Detail").visible and first.get_node("Body/Detail/Pad/Turns").get_child_count() == fx.history[0].visitLog.size(), "a tap opens its turn-by-turn log")
	hw.close()
	Progress.trophies = kept[0]
	Progress.history = kept[1]
	top.call(ClassicMode)[0].get_node("Window/Content/Card/Body/Buttons/Continue").gui_input.emit(_release())
	await get_tree().process_frame
	check(top.call(ClassicMode).is_empty() and top.call(WelcomeScreen).is_empty(), "Continue closes the window and the title screen")
	app._show_end(false)
	top.call(EndGame)[0].get_node("Window/Foot/MainMenu").gui_input.emit(_release())
	await get_tree().process_frame
	check(top.call(WelcomeScreen).size() == 1 and top.call(EndGame).is_empty(), "the end screen's Main Menu: the title screen")
	check(int(Game.state.get("visits", 0)) == 0, "and the run is over: Play starts a new one")
	top.call(WelcomeScreen)[0].queue_free()
	finished.welcome = true


## Settings and the rules: the gear opens Settings; Game Rules' switch is
## saved by Save (turning tips back on restores the hidden ones); Tutorial
## Messages opens each tip window and ✕ goes back to Settings; Reset asks
## first; the mat's "?" opens the rules (Next: Quark Combos, Got it closes).
func _settings(app: App) -> void:
	Game.start_run("Coral Reef")
	app.close_panel()
	await get_tree().process_frame
	var top := func(cls): return app.get_children().filter(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	var gear: Control = app._screen.get_node("Top").get_children().filter(func(c): return c.get_meta("cmp", "") == "settings")[0]
	gear.gui_input.emit(_release())
	check(top.call(SettingsWindow).size() == 1, "the gear opens Settings")
	var sw: SettingsWindow = top.call(SettingsWindow)[0]
	Progress.prefs.hints = false  # tips off, one hidden
	Progress.prefs.hiddenTips = ["classicTut"]
	sw.get_node("Window/Content/Rules").pressed.emit()
	await get_tree().process_frame
	check(top.call(GameRules).size() == 1 and top.call(SettingsWindow).is_empty(), "Game Rules opens in its place")
	var gr: GameRules = top.call(GameRules)[0]
	var tips: SettingRow = gr.get_node("Window/Content/Tips")
	gr.get_node("Window/Content/SaveRow/Save").gui_input.emit(_release())  # unchanged: stays off
	check(Progress.prefs.hints == false and Progress.prefs.hiddenTips == ["classicTut"], "Save keeps a switch as it is")
	await get_tree().process_frame
	app.open_settings("rules")
	gr = top.call(GameRules)[0]
	tips = gr.get_node("Window/Content/Tips")
	# Press feedback (Juice): a pressed row squishes, a release springs it back.
	tips.gui_input.emit(_press(Vector2(200, 400)))
	check(await _until(func(): return tips.offset_transform_scale.x < 0.94), "a pressed row squishes (Juice)")
	get_viewport().push_input(_release(Vector2(-50, -50)))  # off the window: no tap
	check(await _until(func(): return is_equal_approx(tips.offset_transform_scale.x, 1.0)), "and springs back on release")
	Tap._down = null
	tips.gui_input.emit(_release())
	check(tips.on, "a tap flips the switch")
	check(gr.get_node("Window/Content/Vibration").on and not gr.get_node("Window/Content/LowMotion").on, "Vibration starts on, Low motion off")
	gr.get_node("Window/Content/LowMotion").gui_input.emit(_release())
	gr.get_node("Window/Content/SaveRow/Save").gui_input.emit(_release())
	check(Progress.prefs.hints == true and Progress.prefs.hiddenTips.is_empty(), "tips back on: saved, and the hidden tips come back")
	check(Progress.prefs.lowMotion == true and Juice.calm(), "Low motion saved: no press motion")
	var leaving := func(): return app.get_children().any(func(c): return c.has_meta("leaving"))
	check(not leaving.call(), "Low motion: Save closed the window at once (no shrinking out)")
	app.open_settings("rules")
	gr = top.call(GameRules)[0]
	check(gr.get_node("Window").offset_transform_scale == Vector2.ONE and gr.get_node("Window").modulate.a == 1.0, "Low motion: a window opens without popping")
	gr.close()
	Progress.prefs.lowMotion = false
	await get_tree().process_frame
	check(top.call(GameRules).is_empty(), "Save closes Game Rules")
	app.open_settings("rules")
	gr = top.call(GameRules)[0]
	check(gr.get_node("Window").offset_transform_scale.x < 1.0, "a window pops in (grows from Juice.pop_from)")
	gr.close()
	check(top.call(GameRules).is_empty() and leaving.call(), "a closed window is out of the way at once, shrinking out in its holder")
	check(await _until(func(): return not leaving.call()), "and its holder is freed")
	app.open_settings("tuts")
	var wins := {"HowToPlay": HowToPlay, "PinTip": PinTip, "BoardChecks": MatRules, "Challenges": ParchDialog, "Unknown": UnknownTip, "Elements": ParchDialog}
	for row in wins:
		var tm: TutorialMessages = top.call(TutorialMessages)[0]
		tm.get_node("Window/Content/" + row).pressed.emit()
		await get_tree().process_frame
		var shown: Array = top.call(wins[row])
		check(top.call(TutorialMessages).is_empty() and not shown.is_empty(), "Tutorial Messages: %s opens its window" % row)
		for c in shown:
			c.queue_free()
		await get_tree().process_frame
		app.open_settings("tuts")
	var tm2: TutorialMessages = top.call(TutorialMessages)[0]
	tm2.get_node("Window/Back").gui_input.emit(_release())
	await get_tree().process_frame
	check(top.call(SettingsWindow).size() == 1, "✕ on Tutorial Messages goes back to Settings")
	top.call(SettingsWindow)[0].get_node("Window/Content/Buttons/Reset").gui_input.emit(_release())
	check(top.call(ConfirmDialog).size() == 1, "Reset asks first")
	for c in top.call(ConfirmDialog) + top.call(SettingsWindow):
		c.queue_free()
	app.open_panel("drawer")
	await get_tree().process_frame
	var help: Control = app._panel_node.get_node("Body").get_children().filter(func(c): return c.get_meta("cmp", "") == "btn:rules")[0]
	help.gui_input.emit(_release())
	var mr: Array = top.call(MatRules)
	check(mr.size() == 1, "the mat's \"?\" opens the Display Mat rules")
	if not mr.is_empty():
		mr[0].get_node("Window/Content/Page1/NextRow/Next").gui_input.emit(_release())
		check(mr[0].get_node("Window/Content/Page2").visible and mr[0].get_node("Window").title == "Quark Combos", "Next turns to Quark Combos")
		mr[0].get_node("Window/Content/Page2/OkRow/Ok").gui_input.emit(_release())
		await get_tree().process_frame
		check(top.call(MatRules).is_empty(), "Got it closes them")
	# Back (Android) / Escape: the top window, then the panel, never a quit.
	for c in app.get_children():  # rolls earlier sections never collected
		if c is RollPopup:
			c.free()
	app.open_panel("drawer")
	app.open_settings()
	app.back()
	await get_tree().process_frame
	check(top.call(SettingsWindow).is_empty() and app.panel == "drawer", "Back closes the top window first")
	app.back()
	check(app.panel == "", "then the panel")
	app.back()  # nothing open: nothing happens
	check(ProjectSettings.get_setting("application/config/quit_on_go_back") == false, "Back never quits the app")
	app.close_panel()
	finished.settings = true


## Dev mode: five taps on Settings' version show Dev Tools; its switch
## shows the 🛠 button; the panel's Jump sets the turn and marks the run;
## five more taps hide it all again.
func _dev(app: App) -> void:
	Game.start_run("Coral Reef")
	await get_tree().process_frame
	var top := func(cls): return app.get_children().filter(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	app.open_settings()
	var sw: SettingsWindow = top.call(SettingsWindow)[0]
	var ver: Control = sw.get_node("Window/Content/Version")
	for i in 4:
		ver.gui_input.emit(_release())
	check(not sw.get_node("Window/Content/DevTools").visible, "four taps on the version: nothing yet")
	ver.gui_input.emit(_release())
	check(sw.get_node("Window/Content/DevTools").visible and Progress.prefs.devUnlocked, "the fifth shows Dev Tools")
	sw.get_node("Window/Content/DevTools").pressed.emit()
	await get_tree().process_frame
	var dt: DevTools = top.call(DevTools)[0]
	dt.get_node("Window/Content/DevMode").gui_input.emit(_release())
	var fab: Button = app.get_node("Dev/Fab")
	check(Progress.prefs.devMode and fab != null, "Developer mode shows the 🛠 button")
	dt.close()
	fab.pressed.emit()
	var dp: DevPanel = app.get_node("Dev").get_child(1)
	check(dp.visible and not Game.state.get("dev"), "🛠 opens the Dev Panel; the run isn't a dev run yet")
	var turn: SpinBox = dp.get_node("V/Scroll/Body").get_child(0).get_child(1)
	turn.value = 9
	dp.get_node("V/Scroll/Body").get_child(0).get_child(2).pressed.emit()  # Set
	check(int(Game.state.visits) == 9 and Game.state.dev and (dp.get_node("V/Head/Flag") as Label).text == "dev run", "Jump's Set: turn 9, a dev run")
	dp.hide()
	app.open_combo_lab()
	var lab_hides: bool = not (app.get_node("Dev") as CanvasLayer).visible
	app.close_combo_lab()
	check(lab_hides and (app.get_node("Dev") as CanvasLayer).visible, "Combo Lab hides the 🛠 button (its panel could save over the real run); Exit brings it back")
	app.open_settings()
	sw = top.call(SettingsWindow)[0]
	for i in 5:
		sw.get_node("Window/Content/Version").gui_input.emit(_release())
	await get_tree().process_frame
	check(not Progress.prefs.devUnlocked and not Progress.prefs.devMode and app.get_node_or_null("Dev") == null, "five more taps hide Dev Tools and the button")
	sw.close()
	finished.dev = true


## The first-play tutorial (work queue 9), played with real taps through
## the viewport (so its lock is tested too): the first New Game starts it,
## each step's target shows and a tap on it moves on; taps elsewhere are
## swallowed; free steps are played like a player would; it ends after the
## first Lock In. Then Skip, and resuming a step whose bench closed.
func _tutorial(app: App) -> void:
	for c in app.get_children().slice(app._hub.get_index() + 1):
		if c is Control:
			c.queue_free()
	app.close_panel()
	app.mouse.hide_tip()
	Progress.prefs.erase("tutorialSeen")
	Progress.prefs.hints = true  # the 💡 hints stay quiet while it runs
	Progress.prefs.hiddenTips = []
	app.new_game()
	var tut := app.tutorial
	check(await _until(func(): return tut.running()), "the first New Game starts the tutorial")
	check(not app.get_children().any(func(c): return c is HowToPlay), "no how-to-play slides in the tutorial")
	var guard := 0
	var swallowed := false
	while tut.running() and guard < 120:
		guard += 1
		var at := tut.i
		var st: TutorialStep = tut.steps[at]
		await get_tree().process_frame
		check(app.hints._on == null, "step %d: no 💡 hint while the tutorial runs" % at)
		if st.free:
			if st.done_if == "screen:map":
				for e in StationScreen.shop_entries(Game.ctx.current):
					if not Catalog.owns(Game.state, e.name) and Catalog.can_craft(Game.state, e) and Game.suit_cost_payable(e.name):
						Game.craft(e.name, Game.suggest_suit_picks(e.name))
				app._on_hub("home")
			elif st.done_if == "settled":
				await _until(func(): return app.get_children().any(func(c): return c is OrderInfo or c is MatExpand) or Tutorial.met("settled"))
				_dismiss(app)
			else:  # Lock In, the Bonus Dice window, the fade
				app.hand_lock_in()
				check(await _until(func(): return app.get_children().any(func(c): return c is LockInReward)), "tutorial: Lock In counts, then the Bonus Dice window")
				for c in app.get_children():
					if c is LockInReward:
						c._done()
		elif st.until == "next":
			check(await _until(func(): return app.mouse.showing and app.mouse.get_node("Bubble/Tour/Next").is_visible_in_tree()), "step %d: Mouse's Next shows" % at)
			_vtap(app.mouse.get_node("Bubble/Tour/Next").get_global_rect().get_center())
		else:
			for c in app.get_children():  # a window of the game's own ("New collection!"): closed as a player would
				if c is CollectionFound:
					c.queue_free()
			var found := await _until(func(): return tut._target != null and is_instance_valid(tut._target) and not tut._aside)
			check(found, "step %d: its target %s shows" % [at, st.target])
			if not found:
				break
			if not swallowed and st.target == "hub:home":  # a tap elsewhere does nothing
				swallowed = true
				_vtap(app._hub.button("codex").get_global_rect().get_center())
				await get_tree().process_frame
				check(app.panel != "codex" and tut.i == at, "a tap off the target is swallowed")
			await get_tree().create_timer(1.2).timeout  # popups finish moving in, fades end
			var r0: Rect2 = tut._target.get_global_rect()
			if st.target == "hand":  # a card in the fan, not the gaps
				r0 = tut._target.get_children().filter(func(c): return c.has_meta("hand"))[0].get_global_rect()
			_vtap(r0.get_center())
		check(await _until(func(): return tut.i != at or not tut.running()), "step %d (%s) moves on" % [at, st.target if st.target else st.until])
	check(not tut.running() and Game.state.visits == 4 and Game.state.items.has("Soil") and Game.state.items.has("Limestone"), "the tutorial runs to the first Lock In (visit %d)" % Game.state.visits)
	check(int(Progress.prefs.tutorialStep) == -1 and Progress.prefs.tutorialSeen and not app.mouse.showing, "then it's over for good")
	# Skip: asks, then ends it.
	Progress.prefs.erase("tutorialSeen")
	app.new_game()
	check(await _until(func(): return tut.running()), "a fresh first New Game")
	app.mouse.skip.emit()
	var ask := app.get_children().filter(func(c): return c is ConfirmDialog)
	check(ask.size() == 1 and tut.running(), "Skip asks first")
	if ask.size() == 1:
		ask[0].on_yes.call()
		ask[0].queue_free()
	check(not tut.running() and Progress.prefs.tutorialStep == -1, "Yes ends it")
	# Settings' How to Play: asks, then a new game with the tutorial.
	app.replay_tutorial()
	ask = app.get_children().filter(func(c): return c is ConfirmDialog and not c.is_queued_for_deletion())
	check(ask.size() == 1, "How to Play asks first (it starts a new game)")
	if ask.size() == 1:
		ask[0].on_yes.call()
		ask[0].queue_free()
	check(await _until(func(): return tut.running()), "then the tutorial runs again")
	tut.finish()
	for k in 30:  # the logo's moment, then the capstone choice: cleared for the next sections
		await get_tree().process_frame
	for c in app.get_children().slice(app._hub.get_index() + 1):
		if c is Control:
			c.queue_free()
	Progress.prefs.tutorialSeen = true
	for c in app.get_children():
		if c is CapstoneChoice:
			c.queue_free()
	# Resume: saved on the bench's Craft (the bench closed with the app): back to the card.
	Game.start_run("Coral Reef")
	Game.state.rolledHere = true
	Game.state.elements = {"H": 1, "O": 1}
	app.close_panel()
	Progress.prefs.tutorialStep = 9
	tut.resume()
	check(tut.i == 7, "resuming on Craft with the bench closed goes back to the shop (step %d)" % tut.i)
	tut.finish()
	Tap._down = null  # the real taps' last press: later sections tap with releases only
	finished["tutorial"] = true


## A tap through the viewport, as a finger would (Tutorial._input sees it).
func _vtap(at: Vector2) -> void:
	Tap._down = Vector2(-999, -999)  # a stale press elsewhere, as on a phone: the press must be seen
	for ev in [_press(at), _release(at)]:
		ev.position = at
		get_viewport().push_input(ev, true)  # in the viewport's own coordinates


## The first node under n tagged with meta "cmp" == tag (or null).
func _find_meta(n: Node, tag: String) -> Control:
	if n.has_meta("cmp") and n.get_meta("cmp") == tag and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		var f := _find_meta(c, tag)
		if f:
			return f
	return null


func _release(at := Vector2.ZERO) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at  # DragScroll reads the viewport's
	ev.global_position = at
	return ev


func _drag(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	return ev


func _press(at: Vector2) -> InputEventMouseButton:
	var ev := _release(at)
	ev.pressed = true
	return ev


## The handed-over ingredients aren't new Market squares (only the craft is).
## Waits for a Market "?" window and taps its Nice. False if none came.
func _nice(app: App) -> bool:
	if not await _until(func(): return app.get_children().any(func(c): return c is RowReward and not c.is_queued_for_deletion())):
		return false
	var rw: RowReward = app.get_children().filter(func(c): return c is RowReward and not c.is_queued_for_deletion())[0]
	rw.queue_free()
	rw.on_done.call()
	return true


## Lets the Market's moments end, tapping Nice on each "?" window.
func _settle_market(app: App) -> bool:
	return await _until(func():
		for c in app.get_children():
			if c is RowReward and not c.is_queued_for_deletion():
				c.queue_free()
				c.on_done.call()
		return not app._market_playing)


func _squares_reset(app: App) -> void:
	app._squares_card = ""
	app._market_check()


## Is the shutter still playing?
func _busy(app: App) -> bool:
	return app.get_children().any(func(c): return c is Shutter)


## Closes the mat-expansion reveal (going on to the challenge) and the
## challenge window, as taps would.
func _dismiss(app: App) -> void:
	for c in app.get_children():
		if c is MatExpand:
			expansions += 1
			c.queue_free()
			c.on_done.call()
	for c in app.get_children():
		if c is OrderInfo:
			c.queue_free()


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
		_pay_balloon(app, need)
		var after := 0.0
		for v in Game.state.elements.values():
			after += v
		check(Catalog.owns(Game.state, e.name), "balloon crafted " + e.name)
		check(is_equal_approx(before - after, spend), "%s: spent %d elements, recipe + suit cost is %d" % [e.name, before - after, spend])
		return true
	return false


## Taps the open balloon like a player until it crafts: one more from the
## element with the most spare, for each suit still short.
func _pay_balloon(app: App, need: Dictionary) -> void:
	var b: SuitSpend = app.get_children().filter(func(c): return c is SuitSpend).back()
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
