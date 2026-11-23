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
var saw_rules := false
var saw_order_tip := false  # the challenge tip, once a run
var finished := {}  # section -> true once it ran to its end (a script error stops one quietly)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL " + what)


func _ready() -> void:
	Progress.autosave = false
	Progress.prefs.erase("sawMatCheckTutorial")  # a first board check ever
	Progress.prefs.guidedTutorialEnabled = false  # Professor Mouse off (the tips section turns him on)
	Progress.prefs.sawEmptyElTip = true
	Engine.time_scale = 20.0  # the Lock-In count and fades, fast
	seed(7)
	var app := App.new()
	add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var only: String = load("res://tests/shot.gd")._args().get("only", "")
	var parts: Array = ["run", "final_score", "market", "todo", "cards", "items", "settings", "welcome", "pins", "tips", "layouts", "collections", "dev"] if only == "" else [only]
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
	check(await _until(func(): return app.get_children().any(func(c): return c is HowToPlay)), "the logo, then the how-to-play slides")
	var tut: HowToPlay = app.get_children().filter(func(c): return c is HowToPlay)[0]
	for i in 3:
		tut._next()  # Next, Next, Let's play
	check(await _until(func(): return app.get_children().any(func(c): return c is CapstoneChoice)), "then the capstone choice")
	var pick: CapstoneChoice = app.get_children().filter(func(c): return c is CapstoneChoice)[0]
	check(Game.state.visits == 0 and app._screen is MapScreen, "the opening waits on the bare map")
	pick._confirm("Coral Reef")
	pick._start("Coral Reef", pick._card)
	check(await _until(func(): return app.get_children().any(func(c): return c is PinTip)) and app.panel == "todo", "the To-Do List and the pinning tip")
	app.get_children().filter(func(c): return c is PinTip)[0]._done()
	check(await _until(func(): return app._screen is StationScreen), "the opening lands at a station")
	check(Game.ctx.current == Data.t("CORE_ITEM_STATION")["Coral Reef"] and Progress.is_pinned("Coral Reef"), "at Coral Reef's station, Coral Reef pinned")
	var turns := 0
	while not Game.state.get("ended") and not Game.state.get("runComplete") and turns < 60:
		turns += 1
		check(app._screen is StationScreen, "turn %d: at a station" % turns)
		check(app.home_face() == "roll", "turn %d: Home says Roll" % turns)
		app._on_hub("home")  # roll
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
		if Game.state.get("finalCheckPending"):
			check(app.home_face() == "final", "final check face")
			check(await _until(func(): return app.panel == "drawer" and not _busy(app)), "the Final Score shutter opens the mat")
			_dismiss(app)
			app._on_hub("home")
			check(await _until(func(): return Game.state.get("runComplete")), "the final count ends the run")
			break
		var options: Array = Data.t("MAP_NODE_POS").keys().filter(func(n): return app.can_travel_to(n))
		Game.ctx.selectedMapStation = options[randi() % options.size()]
		Game.state_changed.emit()
		if turns == 1:  # a tap on the map (not a station) puts the card away
			app._screen.gui_input.emit(_press(Vector2(5, 300)))
			app._screen.gui_input.emit(_release(Vector2(5, 300)))
			check(Game.ctx.selectedMapStation == null, "a tap on the map hides the station card")
			Tap._down = null  # the press is remembered: later test taps land elsewhere
			Game.ctx.selectedMapStation = options[0]
			Game.state_changed.emit()
		check(app.home_face() == "travel", "turn %d: Home says Travel" % turns)
		var check_turn := Catalog.is_mat_check_visit(Game.state)
		app._on_hub("home")  # travel
		if check_turn:
			check(await _until(func(): return app.panel == "drawer" and not _busy(app)), "turn %d: the shutter opens the mat" % turns)
			for c in app.get_children():  # the very first board check ever: the Display Mat rules first
				if c is MatRules and not c.is_queued_for_deletion():
					check(not saw_rules, "turn %d: the Display Mat rules open at the first board check only" % turns)
					saw_rules = true
					c.close()
			if Orders.current(Game.state) != null:
				# The run's first check with a challenge: the challenges explained first (maybeShowOrderTip()).
				var is_tip := func(c): return c is ParchDialog and c.tip_id == "orderTip" and not c.is_queued_for_deletion()
				await _until(func(): return app.get_children().any(func(c): return c is OrderInfo or c is MatExpand or is_tip.call(c)))
				for c in app.get_children().filter(is_tip):
					check(not saw_order_tip, "turn %d: the challenge tip shows once a run" % turns)
					saw_order_tip = true
					c.close()
				check(await _until(func(): return app.get_children().any(func(c): return c is OrderInfo or c is MatExpand)), "turn %d: the challenge (or the expansion) shows" % turns)
			_dismiss(app)
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
				check(app._hub.greyed, "turn %d: Lock In greys while it counts" % turns)
				check(await _until(func(): return app.get_children().any(func(c): return c is LockInReward)), "turn %d: the Bonus Dice window opens" % turns)
				var dlg: LockInReward = app.get_children().filter(func(c): return c is LockInReward)[0]
				check(dlg.dice == mini(reward, 3) and dlg.unknown == (reward >= 4), "turn %d: shows the reward" % turns)
				check(not app._hub.greyed, "turn %d: Lock In back to colour after the count" % turns)
				dlg._done()
				check(await _until(func(): return app._screen is StationScreen and app.panel == ""), "turn %d: the fade lands at the station" % turns)
		await get_tree().process_frame
	print("ui_play: %d turns, visits %d, %s, %d items, best mat %d" % [turns, Game.state.visits,
		"run complete" if Game.state.get("runComplete") else "game over" if Game.state.get("finalGameOver") else "?", Game.state.items.size(), Game.state.bestMatScore])
	check(Game.state.get("runComplete") or Game.state.get("finalGameOver"), "the run ended properly")
	check(balloon_done, "crafted something through the suit-spend balloon")
	check(convert_done, "converted through the Convert tray")
	check(saw_rules, "the first board check opened the Display Mat rules")
	check(Game.state.visits < 12 or expansions > 0, "the mat-expansion reveal showed")
	check(await _until(func(): return app.get_children().any(func(c): return c is EndGame)), "the end screen shows")
	# "Review my collection", then closing the mat: the end screen comes back.
	var shown := func(cls): return app.get_children().any(func(c): return is_instance_of(c, cls) and not c.is_queued_for_deletion())
	for c in app.get_children():
		if c is EndGame:
			c.queue_free()
	app.open_panel("drawer")
	app.close_panel()
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
	saw_order_tip = false  # a new run: its first challenge brings the tip again
	Game.start_run("Coral Reef")
	await get_tree().process_frame
	Game.state.visits = int(Data.t("RUN_COMPLETE_VISIT"))
	Game.state.rolledHere = true
	Game.state_changed.emit()
	check(app.home_face() == "map", "turn 24: Home says Map")
	app._on_hub("home")
	check(Game.state.get("finalCheckPending") == true, "turn 24: the final check is pending")
	check(await _until(func(): return app.panel == "drawer" and not _busy(app)), "turn 24: the shutter opens the mat")
	for c in app.get_children().filter(func(c): return c is ParchDialog and c.tip_id == "orderTip" and not c.is_queued_for_deletion()):
		check(not saw_order_tip, "turn 24: the challenge tip, if no check showed it yet")  # the run's first challenge can be the final one
		saw_order_tip = true
		c.close()
	check(await _until(func(): return app.get_children().any(func(c): return c is OrderInfo)), "turn 24: the Grand Exhibition shows")
	_dismiss(app)
	check(app.home_face() == "final", "turn 24: Home says Final Score")
	app._on_hub("home")
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
## the tray; a later one only puts "!" on the Market button; a finished row
## opens it, shows Row complete! and pays one "?" on Nice. (The crafts are
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
	own.call(row[0])
	check(await _until(func(): return app.panel == "market"), "the first Market square opens the tray")
	check(await _until(func(): return app.panel == ""), "the tray closes again after the square")
	own.call(row[1])
	await get_tree().process_frame
	check(app.panel == "" and Game.state.get("marketUnseen") == true, "a later square only marks the Market button")
	app._on_hub("market")
	check(app.panel == "market" and not Game.state.marketUnseen and app.home_face() == "map", "the Market button opens the tray (Home reads Map) and clears its mark")
	app._on_hub("home")
	check(app.panel == "", "Home closes the tray")
	var q: int = Util.get_or(Game.state, "emptyElements", 0)
	own.call(row[2])
	await get_tree().process_frame
	own.call(row[3])
	check(await _until(func(): return app.get_children().any(func(c): return c is RowReward)), "a finished row shows Row complete!")
	var rw: RowReward = app.get_children().filter(func(c): return c is RowReward)[0]
	rw.queue_free()
	rw.on_done.call()
	check(await _until(func(): return Util.get_or(Game.state, "emptyElements", 0) == q + 1 and Game.state.pendingBingoClears.is_empty()), "Nice pays the row's ?")
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
	Game.crafted.emit("Glass")
	var peeks := func(): return app.get_children().filter(func(c): return c.has_meta("peek") and not c.is_queued_for_deletion())
	check(peeks.call().size() == 1, "a craft pops up its small card")
	check(await _until(func(): return peeks.call().is_empty()), "the small card flies into the Inventory")
	Game.state.items.append("Metropolis")
	Game.crafted.emit("Metropolis")
	var cel: Array = open.call(CardPop)
	check(cel.size() == 1 and cel[0].entry.name == "Metropolis", "a capstone opens its card")
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
	check(rows.call().has(apple) and not rows.call().has(banana), "pinning makes only that row again")
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
## (Add: found, a Star); its switch takes it off the mat and puts it back;
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
	row.toggled.emit(false)
	check(not Game.state.mat.has("Steel"), "its switch takes Alloys off the mat")
	row = cw.get_node("Window/Content/Scroll/Pad/Rows").get_children().filter(func(r): return not r.is_queued_for_deletion())[0]
	row.toggled.emit(true)
	check(Game.state.mat.has("Steel") and Game.state.mat.has("Stainless Steel"), "and puts it all back")
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
	var hd: Dictionary = Game.ctx.get("hand", {})
	check(Game.state != real and Game.state != lab and int(Game.state.visits) == 12 and Game.state.order != null, "the test: a copy of the run at check 12, with its challenge")
	check(hd.get("hand", []).size() == 7 and hd.deck.all(func(n): return not Game.state.mat.has(n)), "a hand of 7 from the cards not on the mat")
	var dm := app._panel_node as DisplayMatScreen
	check(not dm._scroll.visible and _find_meta(dm, "hand:counts") != null and app._hub.visible and app._hub.hand and app._hub.face == "draw", "the hand in place of the item list; the hub's middle button is Draw")
	app._on_hub("home")
	check(hd.hand.size() == 9, "Draw adds 2")
	var on_mat: String = Game.state.mat[0]
	dm.lifted = hd.hand[0]
	dm._redraw()
	check(_find_meta(dm, "hand:gain:" + on_mat) != null and app._hub.off.get("inv") != true, "a lifted card: the score change shows on the mat; Discard lights")
	check(app._hub.hand_sides.market[1] == "Rehang" and app._hub.off.get("market") != true, "Rehang is ready before the first play")
	var played: String = hd.hand[0]
	var plays: int = hd.plays
	dm._play(on_mat)
	check(Game.state.mat.has(played) and hd.discards == [on_mat] and hd.hand.size() == 8 and hd.plays == plays - 1, "played over a mat card: it's replaced, a play spent, the hand not refilled")
	dm.lifted = hd.hand[0]
	app._on_hub("inv")
	check(hd.hand.size() == 7 and hd.discards.size() == 2 and app._hub.off.get("market") == true, "Discard (the hub) throws out the lifted card; no Rehang after a play")
	dm = app._panel_node as DisplayMatScreen
	var back: String = Game.state.mat[-1]
	dm._on_card_input(_press(Vector2.ZERO), back)
	dm._on_card_input(_release(), back)
	check(dm.selected == back and app._hub.hand_sides.inv[1] == "Take Back", "a tapped mat card: Discard becomes Take Back")
	app._on_hub("inv")
	check(hd.hand.has(back) and not Game.state.mat.has(back) and hd.tosses == int(Data.t("HAND_DISCARDS")) - 2, "Take Back: the mat card into the hand, for a discard")
	# Element draws, in the Convert tray (the same button as on the station).
	var esym := ""
	for sym in Data.t("CLASSIC_ELEMENTS"):
		if Hand.suit_card(hd, sym) != "":
			esym = sym
			break
	Game.state.elements = {esym: 2}
	Game.state.emptyElements = 1
	Game._changed()
	dm = app._panel_node as DisplayMatScreen
	check(_find_meta(dm, "convert") != null, "the Convert button shows during a check")
	app.open_panel("convert")
	var tray := app._panel_node as ConvertTray
	tray.from = esym
	tray._redraw()
	var want_card := Hand.suit_card(hd, esym)
	var n_hand: int = hd.hand.size()
	check(tray.to == "card" and tray._ready_now and app._hub.face == "close", "in a check the tray converts an element into a card (1:1)")
	tray.do_convert()
	check(hd.hand.size() == n_hand + 1 and hd.hand.has(want_card) and Catalog.count(Game.state, esym) == 1 and app.panel == "drawer", "it draws a card of that suit, then back to the hand")
	app.open_panel("convert")
	var cp := CardPick.show_on(app)
	await get_tree().process_frame
	var pick_card: String = hd.deck[-1]
	cp._take(pick_card)
	check(hd.hand.has(pick_card) and int(Game.state.emptyElements) == 0 and app.panel == "drawer", "an Unknown Element picks any card from the deck")
	app._on_hub("codex")
	check(await _until(func(): return not top.call(LockInReward).is_empty()), "Lock In counts, then the reward")
	top.call(LockInReward)[0].on_done.call()
	top.call(LockInReward)[0].queue_free()
	check(Game.state == lab and not Game.ctx.has("hand") and app.get_node("LabBar/Test").text.contains("Challenge") and not app._hub.visible, "then back to the lab")
	app.close_combo_lab()
	check(Game.state == real and real.mat == real_mat, "the real run is untouched")
	finished.collections = true


## Saved Layouts: the mat's 💾 opens it; a name and 💾 save the mat; a
## tap on its row puts it back; 🗑 asks, then deletes it.
func _layouts(app: App) -> void:
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mat_visit18.json")))
	Progress.prefs.savedMatLayouts = []
	app.close_panel()
	app.open_panel("drawer")
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
	rows.call()[0].delete_pressed.emit()
	var ask: Array = top.call(ConfirmDialog)
	check(ask.size() == 1, "🗑 asks first")
	ask[0].get_node("Window/Content/Buttons/Yes").gui_input.emit(_release())
	check(Progress.prefs.savedMatLayouts.is_empty(), "then deletes it")
	lw.close()
	app.close_panel()
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
	Progress.prefs.guidedTutorialEnabled = true
	Progress.prefs.tutorialHintsSeen = []
	Game.start_run("Coral Reef")
	app.close_panel()
	for i in 3:
		await get_tree().process_frame
	check(app.mouse.showing and app.mouse.get_node("Bubble/Text").text.contains("Roll"), "the first tip: Roll (showing: '%s')" % app.mouse.get_node("Bubble/Text").text)
	app.mouse.get_node("Bubble/Close").gui_input.emit(_release())
	check(not app.mouse.showing and Progress.prefs.tutorialHintsSeen.has("firstroll"), "✕ closes it; it's seen")
	Game._changed()
	for i in 2:
		await get_tree().process_frame
	check(not app.mouse.showing, "a seen tip doesn't come back")
	Progress.prefs.tutorialHintsSeen = []
	Game._changed()
	for i in 2:
		await get_tree().process_frame
	app.mouse.get_node("Bubble/Hide").gui_input.emit(_release())
	check(not app.mouse.showing and Progress.prefs.guidedTutorialEnabled == false, "✕ Hide turns the tips off")
	Progress.prefs.sawEmptyElTip = false
	Game.state.emptyElements = 1
	Game._changed()
	for i in 2:
		await get_tree().process_frame
	var tips: Array = app.get_children().filter(func(c): return c is UnknownTip and not c.is_queued_for_deletion())
	check(tips.size() == 1 and Progress.prefs.sawEmptyElTip, "the first \"?\" held: the Unknown Element tip")
	if not tips.is_empty():
		tips[0].close()
	app.start_coach()
	var dialogs := func(): return app.get_children().filter(func(c): return c is ParchDialog and not c.is_queued_for_deletion())
	check(dialogs.call().size() == 1, "How to Play: the periodic table")
	dialogs.call()[0].pressed.emit("Next")
	await get_tree().process_frame
	var els: Array = dialogs.call().filter(func(c): return c is TutElements)
	check(els.size() == 1 and els[0].get_node("Window/Content/Scroll/Grid").get_child_count() == 16, "then the 16 elements")
	els[0].pressed.emit("Next")
	await get_tree().process_frame
	check(app.mouse.coaching and app.mouse.get_node("Bubble/Tour/Step").text == "1 / 7", "then the walkthrough, step 1 of 7")
	for i in 7:
		app.mouse.get_node("Bubble/Tour/Next").gui_input.emit(_release())
	check(not app.mouse.coaching and not app.mouse.showing, "Next through all 7 ends it")
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
	var chips: Array = app._panel_node.get_node("Tray/Body/Chips").get_children().filter(func(c): return c is PinChip and not c.is_queued_for_deletion())
	var steel: PinChip = chips.filter(func(c): return c.get_node("Row/Name").text == "Steel")[0]
	steel.gui_input.emit(_release())
	check(Game.ctx.tracked == null, "the tracked chip stops tracking")
	await get_tree().process_frame
	check(btn.call().get_child_count() == 1, "nothing tracked: \"!\" on the 🔍 button")
	chips = app._panel_node.get_node("Tray/Body/Chips").get_children().filter(func(c): return c is PinChip and not c.is_queued_for_deletion())
	chips.filter(func(c): return c.get_node("Row/Name").text == "Steel")[0].gui_input.emit(_release())
	check(Game.ctx.tracked == "Steel", "a chip tracks it again")
	btn.call().gui_input.emit(_release())
	check(app.panel == "", "🔍 again closes the tray")
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
	Progress.prefs.guidedTutorialEnabled = false  # tips off, one hidden
	Progress.prefs.hiddenTips = ["classicTut"]
	sw.get_node("Window/Content/Rules").pressed.emit()
	await get_tree().process_frame
	check(top.call(GameRules).size() == 1 and top.call(SettingsWindow).is_empty(), "Game Rules opens in its place")
	var gr: GameRules = top.call(GameRules)[0]
	var tips: SettingRow = gr.get_node("Window/Content/Tips")
	gr.get_node("Window/Content/SaveRow/Save").gui_input.emit(_release())  # unchanged: stays off
	check(Progress.prefs.guidedTutorialEnabled == false and Progress.prefs.hiddenTips == ["classicTut"], "Save keeps a switch as it is")
	await get_tree().process_frame
	app.open_settings("rules")
	gr = top.call(GameRules)[0]
	tips = gr.get_node("Window/Content/Tips")
	tips.gui_input.emit(_release())
	check(tips.on, "a tap flips the switch")
	gr.get_node("Window/Content/SaveRow/Save").gui_input.emit(_release())
	check(Progress.prefs.guidedTutorialEnabled == true and Progress.prefs.hiddenTips.is_empty(), "tips back on: saved, and the hidden tips come back")
	await get_tree().process_frame
	check(top.call(GameRules).is_empty(), "Save closes Game Rules")
	app.open_settings("tuts")
	var wins := {"HowToPlay": HowToPlay, "PinTip": PinTip, "BoardChecks": MatRules, "Challenges": ParchDialog, "Unknown": UnknownTip}
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
	ev.global_position = at
	return ev


func _press(at: Vector2) -> InputEventMouseButton:
	var ev := _release(at)
	ev.pressed = true
	return ev


## The handed-over ingredients aren't new Market squares (only the craft is).
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
