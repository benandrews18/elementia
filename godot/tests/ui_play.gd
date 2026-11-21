## Plays a whole run through the screens (App and its hub), the way a player
## taps: roll, craft what's craftable, go to the map, pick a reachable
## station, travel (locking in on check turns), until the run is over.
## Checks the screens follow and nothing errors. Then the Final Score, the
## Market and the To-Do List, each from a fresh run.
##   G --headless --path godot --quit-after 20000 res://tests/ui_play.tscn [-- --only run|final_score|market|todo|cards|items]
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
	Engine.time_scale = 20.0  # the Lock-In count and fades, fast
	seed(7)
	var app := App.new()
	add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var only: String = load("res://tests/shot.gd")._args().get("only", "")
	var parts: Array = ["run", "final_score", "market", "todo", "cards", "items"] if only == "" else [only]
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
		check(app.home_face() == "travel", "turn %d: Home says Travel" % turns)
		var check_turn := Catalog.is_mat_check_visit(Game.state)
		app._on_hub("home")  # travel
		if check_turn:
			check(await _until(func(): return app.panel == "drawer" and not _busy(app)), "turn %d: the shutter opens the mat" % turns)
			if Orders.current(Game.state) != null:
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
	check(app.get_children().any(func(c): return c is OrderInfo), "turn 24: the Grand Exhibition shows")
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
	app._on_hub("jobs")
	check(app.panel == "", "the To-Do List button closes it again")
	TodoTray.hint_open = false
	finished.todo = true


## Card pop-ups: a station's element chip opens the element card; an item's
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
	check(open.call(ElementCard).size() == 1, "a station's element chip opens its element card")
	open.call(ElementCard)[0].get_node("Card").gui_input.emit(_release())
	await get_tree().process_frame
	check(open.call(ElementCard).is_empty(), "a tap closes the element card")
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
	row.gui_input.emit(_release())
	await get_tree().process_frame
	check(TodoTray.expanded.has("refroot/Bridge"), "a tap on a row opens its breakdown")
	row = rows.call().filter(func(r): return r.item == "Bridge")[0]
	check(row.get_node("Tree").get_child_count() > 0, "the breakdown shows under the row")
	var was := Progress.is_pinned("Banana")
	rows.call().filter(func(r): return r.item == "Banana")[0].get_node("Pin").gui_input.emit(_release())
	await get_tree().process_frame
	check(Progress.is_pinned("Banana") != was and (rows.call().filter(func(r): return r.item == "Banana")[0].get_parent().name == "PinTable") == Progress.is_pinned("Banana"),
		"📌 on a row pins it (into the Pinned table)")
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


func _release() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
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
