## The game's frame: the current screen (map / station), the panel open over
## it (the drawer with the Display Mat), and the hub bar on top of
## everything. Decides the Home button's face and what tapping it does
## (hub.js hubHomeFace() and its click handler).
class_name App
extends Control

var panel := ""  # "", "drawer" (the Display Mat), "convert", "market" or "todo"
var _squares := []  # Market squares owned when last looked (a new one plays the sequence)
var _squares_card := ""  # the card _squares is for (a new run or a load starts afresh)
var _market_playing := false
var market_plays := 0  # how often the Market's moment has played (tests read it)
var _screen: Control
var _screen_name := ""
var _panel_node: Control
var _hub: HubBar

static var current: App  # the running app, for screens that need it (crafting)


func _ready() -> void:
	current = self
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hub = HubBar.new()
	_hub.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_hub)
	_hub.pressed.connect(_on_hub)
	Game.state_changed.connect(_sync)
	_sync()


## The screen follows Game.ctx.screen; the hub follows everything.
func _sync() -> void:
	var want: String = Game.ctx.screen if Game.ctx.get("current") or Game.ctx.screen == "map" else "map"
	if want != _screen_name:
		_screen_name = want
		if is_instance_valid(_screen):
			_screen.queue_free()
		_screen = StationScreen.new() if want == "station" else MapScreen.make()
		add_child(_screen)
		move_child(_screen, 0)
	_sync_hub()
	_market_check()
	_maybe_end()


## runBingoSequence(): a craft that owns a new Market square or finishes a
## row. A finished row opens the Market, bounces the row, and pays its "?"
## (Row complete!); a square alone does that the first time ever, bounces in
## the tray when it's open (crafted from it), and otherwise puts "!" on the
## Market button.
## shortcut: no toast for a square (the HTML game's "Marketplace item done").
func _market_check() -> void:
	var s := Game.state
	if _market_playing or s.get("bingoCard") == null:
		return
	var card: Array = s.bingoCard
	var owned := range(card.size()).filter(func(i): return Catalog.owns(s, card[i]))
	var lines: Array = Util.get_or(s, "pendingBingoClears", []).duplicate()  # a load can bring some
	if str(card) != _squares_card:  # a new run or a loaded one: what's owned is the starting point
		_squares_card = str(card)
		_squares = owned
	var fresh := owned.filter(func(i): return not _squares.has(i))
	_squares = owned
	if lines.is_empty() and fresh.is_empty():
		return
	if lines.is_empty() and s.get("sawMarketSquareTray") and panel != "market":
		s.marketUnseen = true  # with the tray open (crafted from it) it bounces there instead
		Game._changed.call_deferred()
		return
	s.sawMarketSquareTray = true
	_market_sequence.call_deferred(fresh, lines)


func _market_sequence(fresh: Array, lines: Array) -> void:
	_market_playing = true
	market_plays += 1
	var opened := panel != "market"
	if opened:
		open_panel("market")
	var block := Control.new()
	block.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(block)
	var tray := _panel_node as MarketTray
	await get_tree().create_timer(0.45 if opened else 0.15).timeout  # the tray's slide-in first
	for i in fresh:
		DisplayMatScreen.bounce(tray.cells.get(i))
		await get_tree().create_timer(0.32).timeout
	for r in lines:
		await get_tree().create_timer(0.3).timeout
		for i in Market.lines()[r]:
			DisplayMatScreen.bounce(tray.cells.get(i))
		await get_tree().create_timer(0.56 + 0.65).timeout
	block.queue_free()
	if not lines.is_empty():
		var rw := RowReward.new()
		rw.rows = lines.size()
		rw.size = size
		var done := false
		rw.on_done = func(): done = true
		add_child(rw)
		while not done and is_instance_valid(rw):
			await get_tree().process_frame
		_market_playing = false
		Game.collect_market_rewards()
	else:
		_market_playing = false
	if opened:
		await get_tree().create_timer(1.6).timeout
		if _panel_node == tray:  # the tray this opened (not one the player reopened since)
			close_panel()
	_maybe_end()


## The end screen, once per ending (game over, Run Complete, then an
## Overtime ending); crafting everything ends the run here.
func _maybe_end() -> void:
	var s := Game.state
	if _market_playing:  # the end waits for the Market's own moment
		return
	var key := "ended" if s.get("ended") or s.get("craftedEverything") else ("complete" if s.get("runComplete") else "")
	if key == "" or key == Game.ctx.get("endShown", ""):
		return
	Game.ctx.endShown = key
	var party: bool = key == "complete" or (s.get("craftedEverything") and not s.get("ended"))
	if s.get("craftedEverything") and not s.get("ended"):
		s.ended = true
		Game._changed()
	_show_end.call_deferred(party)


func _show_end(party: bool) -> void:
	var e := EndGame.new()
	e.size = size
	add_child(e)
	if party:
		_confetti()


## fireConfetti(): 70 bits of coloured paper falling and spinning.
func _confetti() -> void:
	var colors := ["#2e9e5b", "#d9432b", "#b7791f", "#3b7fc4", "#a16a34", "#e2b25a"]
	for i in 70:
		var p := Panel.new()
		var round_bit := randf() < 0.35
		p.add_theme_stylebox_override("panel", Tok.box(Color(colors[randi() % colors.size()]), 5 if round_bit else 0))
		p.size = Vector2(9, 9) if round_bit else Vector2(8, 14)
		p.pivot_offset = p.size / 2
		p.position = Vector2(randf() * size.x, -size.y * (0.12 + randf() * 0.2))
		p.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(p)
		var t := 1.9 + randf() * 1.6
		var tw := p.create_tween()
		tw.tween_interval(randf() * 0.5)
		tw.tween_property(p, "position:y", size.y * 1.05, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "rotation_degrees", randf_range(-540, 540), t)
		tw.tween_callback(p.queue_free)


## New Game (restartRun() / startNewRun()): the finished run goes into
## History; a fresh run waits on the bare map: the Elementia logo, the
## how-to-play slides, then the capstone is chosen (playClassicIntro()).
func new_game() -> void:
	Progress.record_history()
	Game.state = Game.fresh_state()  # before close_panel(): an ended run would reopen its end screen
	Game.ctx = {"current": null, "screen": "map", "travelPromptFor": null, "selectedMapStation": null, "lockInCommitted": false}
	Progress.prefs.pinnedItems = []
	close_panel()
	Game._changed()
	var logo := TextureRect.new()  # #introLogo: bounces in, a second on screen
	logo.texture = load("res://assets/banners/elementia-logo.webp")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(size.x * 0.9, size.x * 0.9 * 0.55)
	logo.position = (size - logo.size) / 2 - Vector2(0, HubBar.H / 2)
	logo.pivot_offset = logo.size / 2
	logo.scale = Vector2(0.6, 0.6)
	logo.modulate.a = 0
	logo.mouse_filter = MOUSE_FILTER_STOP
	add_child(logo)
	var tw := logo.create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(logo, "scale", Vector2(1.05, 1.05), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(0.5)
	tw.tween_property(logo, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		logo.queue_free()
		HowToPlay.play(self, func():
			var c := CapstoneChoice.new()
			c.size = size
			add_child(c)))


## A Craft tap: crafts at once, or, for an item with a suit cost, opens the
## balloon to choose which elements pay it (pointing at the button).
func craft_tap(name: String, button: Rect2) -> void:
	if Game.suit_cost_need(name).is_empty():
		Game.craft(name)
		return
	var b := SuitSpend.new()
	b.item = name
	b.anchor = button
	b.size = size
	add_child(b)


## Puts a shop card's row on the station's Crafting Bench (screenshots, tests).
func open_card(name: String) -> void:
	if _screen is StationScreen:
		_screen.open_card = name
		_screen._redraw()


## Opens a panel over the screen ("drawer": the Display Mat).
func open_panel(name: String) -> void:
	close_panel()
	panel = name
	if name in ["drawer", "convert", "market", "todo"]:
		_panel_node = {"drawer": DisplayMatScreen, "convert": ConvertTray, "market": MarketTray, "todo": TodoTray}[name].new()
		add_child(_panel_node)
		move_child(_panel_node, _hub.get_index())  # under the hub
	_sync()


func close_panel() -> void:
	if is_instance_valid(_panel_node):
		_panel_node.queue_free()
	_panel_node = null
	panel = ""
	if Game.state.get("ended"):  # e.g. after "Review my collection": the end screen again (New Game)
		Game.ctx.endShown = ""
	_sync()


## hubHomeFace(): what Home does right now.
func home_face() -> String:
	var s := Game.state
	var c := Game.ctx
	var sel = c.get("selectedMapStation")
	if s.get("finalCheckPending") and (panel == "" or panel == "drawer"):
		return "final"
	if panel == "drawer" and c.screen == "map" and sel and can_travel_to(sel) and c.get("travelPromptFor") == sel:
		return "lockin"
	if panel == "market":  # the tray reads Map (tapping it closes the tray)
		return "map"
	if panel != "":
		return "close"
	if c.current and not s.get("rolledHere"):
		return "roll"
	if c.screen == "map" and sel and sel == s.get("lastStation"):
		return "shop"
	if c.screen == "map" and sel and can_travel_to(sel):
		return "travel"
	if c.screen == "map" and not sel and s.get("lastStation"):
		return "shop"
	return "map"


## canTravelTo(): not where you are, reachable (a path, or a Helicopter), run not over.
func can_travel_to(name) -> bool:
	var s := Game.state
	return name != null and name != s.get("lastStation") and not s.get("ended") \
		and (Catalog.owns(s, "Helicopter") or Catalog.is_map_connected(s.get("lastStation"), name))


func _sync_hub() -> void:
	var s := Game.state
	var sel = Game.ctx.get("selectedMapStation")
	var badges := {}
	if not (s.get("marketVisited") and not s.get("marketUnseen")):
		badges.market = "!"
	_hub.show_state(home_face(), {"inv": panel == "drawer", "market": panel == "market", "jobs": panel == "todo"}, badges,
		sel != null and not Catalog.is_map_connected(s.get("lastStation"), sel))


## The visit's roll, then the dice pop-up over everything (Collect sends
## the elements into the Inventory button).
func _roll() -> void:
	var out := Game.do_roll()
	if out.is_empty():
		return
	var pop := RollPopup.new()
	pop.roll = out
	pop.fly_to = _hub.button_center("inv")
	pop.size = size
	add_child(pop)


## Travel: on a board-check turn the shutter, then the mat opens for the
## Lock-In (Home becomes Lock In); tapping Travel again just reopens the mat.
## Otherwise a quiet check sets this trip's dice and off you go.
## shortcut: the first check's rules pages and the one-time challenge tip
## aren't shown (they come with M6's rules pages).
func _travel(dest: String) -> void:
	if Catalog.is_mat_check_visit(Game.state):
		if Game.ctx.get("travelPromptFor") == dest:
			open_panel("drawer")
			return
		Game.ctx.travelPromptFor = dest
		Game.start_check_order()
		Shutter.play(self, "Display Mat Challenge!", OrderInfo.shutter_line(Orders.current(Game.state)), func():
			open_panel("drawer")
			_check_intro())
	else:
		Game.quiet_check()
		Game.go_station(dest)


## Lock In (confirmLockIn()): the count, the Bonus Dice window, then a fade
## through black to the station. A mat that misses the breakpoint on a turn
## that can end the run asks first, and ends it.
func _lock_in() -> void:
	if Game.lock_in_ends_run():
		ConfirmDialog.ask(self, "Your mat doesn't have enough points to continue!
If you lock-in now your run ends here.
Are you sure?", func():
			close_panel()
			Game.confirm_lock_in())
		return
	var reward := Game.reward_of(Orders.reward_for(Game.mat_score().total, Orders.check_round(Game.state)))
	_count_then(func():
		var dlg := LockInReward.new()
		dlg.dice = reward.dice
		dlg.unknown = reward.unknown
		dlg.quarks = Game.mat_score().total
		dlg.size = size
		dlg.on_done = func(): fade_through_black(func():
			close_panel()
			Game.confirm_lock_in())
		add_child(dlg))


## Under the shutter: the mat-expansion reveal on a growth turn, then this
## check's challenge.
func _check_intro() -> void:
	var r := MatExpand.fresh_rect(_panel_node) if _panel_node is DisplayMatScreen else Rect2()
	if r.size == Vector2.ZERO:
		_challenge()
		return
	await get_tree().create_timer(Shutter.HOLD + Shutter.CLOSE).timeout  # once the shutter has parted
	var mx := MatExpand.new()
	mx.hole = r
	mx.on_done = _challenge
	mx.size = size
	add_child(mx)


func _challenge() -> void:
	var o = Orders.current(Game.state)
	if o != null and int(o.round) == int(Game.state.visits):
		OrderInfo.open(self)


## Back on the map after turn 24's shopping: the "Final Score!" shutter and
## the mat (startFinalCheck()).
func _go_map() -> void:
	Game.go_map()
	if Game.state.get("finalCheckPending"):
		Shutter.play(self, "Final Score!", OrderInfo.shutter_line(Orders.current(Game.state)), func():
			open_panel("drawer")
			_challenge())


## The final score: opens the mat if it's closed; then the count and Run
## Complete.
func _final_lock_in() -> void:
	if panel != "drawer":
		open_panel("drawer")
		return
	_count_then(func():
		Game.confirm_final_lock_in()
		close_panel())


## Plays the drawer's Lock-In count with input blocked (and Home can't
## score twice), then runs then_do.
func _count_then(then_do: Callable) -> void:
	var mat := _panel_node as DisplayMatScreen
	if mat == null or mat.playing:
		return
	var block := Control.new()
	block.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(block)
	mat.play_lock_in(func():
		block.queue_free()
		then_do.call())


## fadeThroughBlack(): black over everything (.5s), midpoint() under it,
## then back.
func fade_through_black(midpoint: Callable) -> void:
	var c := ColorRect.new()
	c.color = Color.BLACK
	c.modulate.a = 0
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(c)
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func(): midpoint.call(); move_child(c, -1))
	tw.tween_interval(0.04)
	tw.tween_property(c, "modulate:a", 0.0, 0.5)
	tw.tween_callback(c.queue_free)


## shortcut: To-Do List, Market and Items come later in M4.
func _on_hub(id: String) -> void:
	match id:
		"inv":
			if panel == "drawer":
				close_panel()
			else:
				open_panel("drawer")
		"jobs":
			if panel == "todo":
				close_panel()
			else:
				open_panel("todo")
		"market":  # visiting the Market clears its "!"
			if panel == "market":
				close_panel()
			else:
				Game.state.marketVisited = true
				Game.state.marketUnseen = false
				open_panel("market")
				Game._changed()
		"home":
			match home_face():
				"close":
					close_panel()
				"roll":
					_roll()
				"map":
					if panel == "market":
						close_panel()
					else:
						_go_map()
				"shop":  # back into the station you're at, free (no visit spent)
					Game.ctx.screen = "station"
					Game.ctx.current = Game.state.lastStation
					Game.ctx.selectedMapStation = null
					Game.state_changed.emit()
				"travel":
					_travel(Game.ctx.selectedMapStation)
				"lockin":
					_lock_in()
				"final":
					_final_lock_in()
