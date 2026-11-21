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
var _floats: Control  # the 🔍 button and the tracked pill, under the hub, over the panels
var mouse: MouseTip  # Professor Mouse, on a layer above everything
const LAB_BAR := 40.0  # Combo Lab's exit bar
const LAB_TOP := 52.0  # where the lab's mat starts, under it
var _real: Array = []  # Combo Lab: the real run and its context, put back on exit

static var current: App  # the running app, for screens that need it (crafting)


func _ready() -> void:
	current = self
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_floats = Control.new()
	_floats.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_floats.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_floats)
	_hub = HubBar.make()
	_hub.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_hub)
	_hub.pressed.connect(_on_hub)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	mouse = MouseTip.make()
	layer.add_child(mouse)
	Game.state_changed.connect(_sync)
	resized.connect(_sync_floats)  # they sit on the bottom edge
	_sync()
	sync_dev()


## Developer mode (prefs.devMode): the 🛠 button and its Dev Panel, on a
## layer above everything (they're used over the end screens too).
func sync_dev() -> void:
	var layer := get_node_or_null("Dev")
	if Progress.prefs.get("devMode") != true:
		if layer:
			layer.queue_free()
			layer.name = "DevGone"
		return
	if layer:
		return
	layer = CanvasLayer.new()
	layer.name = "Dev"
	layer.layer = 3
	add_child(layer)
	var panel := DevPanel.make()
	panel.visible = false
	var fab := Button.new()  # .dev-fab
	fab.name = "Fab"
	fab.icon = Data.icon("🛠")
	fab.expand_icon = true
	fab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := Tok.box(Color("#2b1d0e"), 21, 2, Color("#e2b25a"))
	box.set_content_margin_all(9)
	for st in ["normal", "hover", "pressed", "focus"]:
		fab.add_theme_stylebox_override(st, box)
	fab.anchor_top = 0.42  # follows the screen's height (a CanvasLayer's controls anchor to the window)
	fab.anchor_bottom = 0.42
	fab.offset_left = 6
	fab.offset_right = 48
	fab.offset_bottom = 42
	fab.pressed.connect(func():
		panel.visible = not panel.visible
		panel.place(size))
	layer.add_child(fab)
	layer.add_child(panel)


## The screen follows Game.ctx.screen; the hub follows everything.
func _sync() -> void:
	var want: String = Game.ctx.screen if Game.ctx.get("current") or Game.ctx.screen == "map" else "map"
	if want != _screen_name:
		_screen_name = want
		if is_instance_valid(_screen):
			_screen.queue_free()
		_screen = StationScreen.make() if want == "station" else MapScreen.make()
		add_child(_screen)
		move_child(_screen, 0)
	_sync_hub()
	_sync_floats()
	_market_check()
	_maybe_end()
	_walkthrough.call_deferred()  # after this change's own windows have opened
	_unknown_tip.call_deferred()
	_collection_found.call_deferred()


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
		var rw := RowReward.make(lines.size(), func(): pass)
		rw.size = size
		add_child(rw)
		await rw.tree_exited  # until Nice
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
		Game._changed.call_deferred()  # not inside this state_changed handler
	_show_end.call_deferred(party)


func _show_end(party: bool) -> void:
	var e := EndGame.make()
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
			var c := CapstoneChoice.make()
			c.size = size
			add_child(c)))


## A Craft tap: crafts at once, or, for an item with a suit cost, opens the
## balloon to choose which elements pay it (pointing at the button).
func craft_tap(name: String, button: Rect2) -> void:
	if Game.suit_cost_need(name).is_empty():
		Game.craft(name)
		return
	var b := SuitSpend.make()
	b.item = name
	b.anchor = button
	b.size = size
	add_child(b)


## Puts a shop card's row on the station's Crafting Bench (screenshots, tests).
func open_card(name: String) -> void:
	if _screen is StationScreen:
		_screen.open_card = name
		_screen._redraw()


## showTutorialHintOnce(): a Professor Mouse tip once ever (its id goes in
## prefs.tutorialHintsSeen), unless the tips are off (Game Rules). Returns
## whether it showed. queued: behind the tip showing (queueTutorialHintOnce()).
func tip_once(id: String, pose: int, text: String, anchor := "bottom-left", target: Control = null, px := 19, queued := false, bottom := -1.0) -> bool:
	var seen: Array = Util.get_or(Progress.prefs, "tutorialHintsSeen", [])
	if Progress.prefs.get("guidedTutorialEnabled") == false or seen.has(id):
		return false
	Progress.prefs.tutorialHintsSeen = seen + [id]
	Progress.save_all()
	if queued:
		mouse.queue_tip(pose, text, anchor, target, px)
	else:
		mouse.show_tip(pose, text, anchor, target, px, bottom)
	return true


## maybeShowEmptyElTip(): the first time a player ever holds a "?", what it
## is, once whatever handed it over has finished (nothing open, run going).
func _unknown_tip() -> void:
	var s := Game.state
	if Progress.prefs.get("sawEmptyElTip") or int(Util.get_or(s, "emptyElements", 0)) <= 0 or s.get("ended") or _market_playing:
		return
	if get_children().slice(_hub.get_index() + 1).any(func(c): return c is Control and not c.is_queued_for_deletion()):
		return  # a window is open; the next change tries again
	Progress.prefs.sawEmptyElTip = true
	Progress.save_all()
	ParchDialog.open(self, UnknownTip.SCENE)


## maybeShowCollectionFound(): a named collection complete on the mat that
## was never found: "New collection!", once nothing else is on screen (not
## during a Lock-In or the Market's moment); the next one after it's added.
func _collection_found() -> void:
	if not Game.state.get("mode") or Game.ctx.get("lockInCommitted") or _market_playing or Game.ctx.get("comboLab"):
		return
	if get_children().slice(_hub.get_index() + 1).any(func(c): return c is Control and not c.is_queued_for_deletion()):
		return  # something's open; the next change tries again
	var c = Progress.undiscovered_on_mat()
	if c != null:
		CollectionFound.show_on(self, c)


## walkthroughIdle(): nothing over the screen (no window, panel, roll or
## opening), no tip showing or waiting.
func _idle() -> bool:
	return panel == "" and not mouse.showing and mouse._queue.is_empty() 		and not get_children().slice(_hub.get_index() + 1).any(func(c): return c is Control and not c.is_queued_for_deletion())


## maybeShowWalkthroughTip(): the new player's first presses, each once ever,
## on an idle station: Roll, Craft, Convert (then where to tap a missing
## element), the Map; later the tracked item's badge on a shop card.
func _walkthrough() -> void:
	if Progress.prefs.get("guidedTutorialEnabled") == false or not _idle() or Game.ctx.get("comboLab"):
		return
	var s := Game.state
	if Game.ctx.screen == "map":
		if int(s.get("visits", 0)) >= 1 and not s.get("marketVisited"):  # travel.js: back on the map, Market never opened
			tip_once("checkmarket", 1, "Check out the Market!", "bottom-right", _hub.button("market"), 16)
		return
	if Game.ctx.screen != "station" or not Game.ctx.get("current") or not _screen is StationScreen:
		return
	if not s.get("rolledHere"):
		tip_once("firstroll", 3, "Tap [b]Roll[/b] to get elements!", "bottom-left", _hub.button("home"), 14)
		return
	var craftable: Control = _screen.find_tagged("st:craft:", true)
	if craftable != null:
		tip_once("firstcraft", 7, "Tap [b]Craft[/b]!", "top-left", craftable)
		return
	var n := 0
	for v in s.elements.values():
		n += int(v) / int(Data.t("CONVERT_RATE"))
	if n > 0 and tip_once("firstconvert", 5, "Convert Elements! [b]3:1[/b]", "center", _screen.find_tagged("convert")):
		tip_once("converttapmissing", 7, "Tap to craft missing elements", "bottom-left", null, 12, true)
		return
	if tip_once("gomap", 12, "Onto the next station!
Tap the [b]Map[/b].", "bottom-left", _hub.button("home"), 15):
		return
	var badge: Control = _screen.find_tagged("st:needed:", true)
	if badge != null:
		tip_once("pintrackshop", 7, "Your tracked item needs this one!", "bottom-right", badge)


## How to Play (Settings; startNewTutorial()): "The Periodic Table", "The 16
## Elements", then Professor Mouse walks through the hub's buttons and the
## gear, each spotlit (tutCoachSteps()).
func start_coach() -> void:
	var intro := ParchDialog.open(self, "res://ui/overlays/tut_intro.tscn")
	intro.pressed.connect(func(b): if b == "Next":
		intro.close()
		var els := ParchDialog.open(self, TutElements.SCENE)
		els.pressed.connect(func(b2): if b2 == "Next":
			els.close()
			_coach_step(0)))


func _coach_steps() -> Array:
	return [
		["home", 10, "bottom-left", "The home button keeps the game going!
Collect elements,
and travel the map.", 15],
		["jobs", 2, "bottom-left", "To-Do List: the items you're tracking.", 19],
		["inv", 12, "bottom-left", "Inventory: all you've collected.", 19],
		["codex", 1, "bottom-right", "Look up any item's recipe here.", 19],
		["market", 2, "bottom-right", "The Market: craft items and capstones from anywhere.", 19],
		["settings", 2, "top-right", "Settings: adjust rules or go to Main Menu.", 19],
		["", 3, "top-right", "You're ready! {🎯} Go build!", 19]]


var _coach_cb := Callable()  # the walkthrough's Next, bound to its next step


func _coach_step(i: int) -> void:
	var steps := _coach_steps()
	if _coach_cb.is_valid() and mouse.next_step.is_connected(_coach_cb):
		mouse.next_step.disconnect(_coach_cb)
	if i >= steps.size():  # endTutCoach()
		mouse.coaching = false
		mouse.hide_tip()
		return
	var st: Array = steps[i]
	var target: Control = null
	if st[0] == "settings":
		target = (_screen as Control).call("find_tagged", "settings") if _screen.has_method("find_tagged") else null
	elif st[0] != "":
		target = _hub.button(st[0])
	mouse.coaching = true
	mouse.show_tip(st[1], st[3], st[2], target, st[4], -1.0, "%d / %d" % [i + 1, steps.size()], i == steps.size() - 1)
	_coach_cb = _coach_step.bind(i + 1)
	mouse.next_step.connect(_coach_cb)


## Combo Lab (openComboLab(); the title screen): a sandbox mat. The real run
## is put aside and a throwaway one takes its place: every item owned (but
## a capstone's unlocks this player has never seen), visit 20 so the Quark
## Meter has room, never saved. The mat fills the screen under "✕ Exit Combo
## Lab"; the hub, the screen and the floating buttons are hidden.
func open_combo_lab() -> void:
	_real = [Game.state, Game.ctx]
	var seen := {}
	for n in Util.get_or(Progress.prefs, "capstonesEverCrafted", []) + Game.state.get("items", []):
		seen[n] = true
	for h in Progress.history:
		for n in h.get("capstones", []):
			seen[n] = true
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	var lab := Game.fresh_state()
	lab.items = Data.t("CORE_ITEM_NAMES").filter(func(n): return not unlocked.has(n) or seen.has(unlocked[n]))
	lab.bingoCenterChosen = true
	lab.visits = 20
	Game.state = lab
	Game.ctx = {"current": null, "screen": "map", "travelPromptFor": null, "selectedMapStation": null, "lockInCommitted": false, "comboLab": true}
	_hub.visible = false
	open_panel("drawer")
	if is_instance_valid(_screen):
		_screen.visible = false
	var bar := load("res://ui/pieces/lab_bar.tscn").instantiate() as Control
	bar.name = "LabBar"
	bar.size = Vector2(size.x, LAB_BAR)
	bar.gui_input.connect(func(ev): if Tap.tap(ev): close_combo_lab())
	add_child(bar)


func close_combo_lab() -> void:
	if _real.is_empty():
		return
	Game.state = _real[0]
	Game.ctx = _real[1]
	_real = []
	_hub.visible = true
	var bar := get_node_or_null("LabBar")
	if bar:
		bar.queue_free()
	close_panel()
	if is_instance_valid(_screen):
		_screen.visible = true
	Game.state_changed.emit()


## The title screen over everything (launch, Settings' Home, the end
## screen's Main Menu); the run underneath is untouched.
func show_welcome() -> void:
	if not get_children().any(func(c): return c is WelcomeScreen and not c.is_queued_for_deletion()):  # Home from Settings opened over it
		WelcomeScreen.show_on(self)


## An item's card, big (a tap on an item anywhere: CardPop).
func show_card(name: String) -> void:
	if Catalog.entry(name) != null:
		CardPop.open(self, name)


## The Items screen; with a name, that item's breakdown open and in view
## (Item Info on its card).
func open_items(name := "") -> void:
	open_panel("codex")
	if name != "":
		(_panel_node as ItemsScreen).jump_to(name)


## Settings (the gear); page "rules" or "tuts" opens that window instead.
func open_settings(page := "") -> void:
	match page:
		"rules": ParchDialog.open(self, GameRules.SCENE)
		"tuts": ParchDialog.open(self, TutorialMessages.SCENE)
		_: SettingsWindow.show_on(self)


## A rules or tip window by name (mat_rules, mat_rules2, order, unknown).
func show_tip(name: String) -> void:
	match name:
		"mat_rules", "mat_rules2":
			var m := MatRules.show_on(self)
			if name == "mat_rules2":
				m._page2()
		"order": MatRules.order_tip(self)
		"unknown": ParchDialog.open(self, UnknownTip.SCENE)


## An element's card (a tap on an element anywhere: ElementCard).
func show_element_card(sym: String) -> void:
	ElementCard.open(self, sym)


## Opens a panel over the screen ("drawer": the Display Mat).
func open_panel(name: String) -> void:
	close_panel()
	panel = name
	if name in ["drawer", "convert", "market", "todo", "codex", "pins"]:
		_panel_node = {"drawer": DisplayMatScreen, "convert": ConvertTray, "market": MarketTray, "todo": TodoTray, "codex": ItemsScreen, "pins": PinsTray}[name].make()
		add_child(_panel_node)
		move_child(_panel_node, _floats.get_index())  # under the 🔍 button and the hub
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


## The 🔍 button (#pinsBtn: opens the pins tray) once anything is pinned,
## "!" when nothing is tracked; the tracked pill beside it (a tap: its card).
## On the map and the station, with no panel open but the pins tray (the
## HTML hides them under the others).
func _sync_floats() -> void:
	for c in _floats.get_children():
		c.queue_free()
	if Progress.prefs.pinnedItems.is_empty() or not panel in ["", "pins"] or Game.ctx.get("comboLab"):
		return
	var y := size.y - HubBar.H - 14 - 58
	var t = Game.ctx.get("tracked")
	var e = Catalog.entry(t) if t else null
	if e != null:
		var pill: Control = load("res://ui/pieces/tracked_pill.tscn").instantiate()
		pill.get_node("Row/Icon").texture = Data.icon(e.emoji)
		var nl: Label = pill.get_node("Row/Name")
		nl.text = t
		var tw := nl.get_theme_font("font").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, nl.get_theme_font_size("font_size")).x
		pill.size = Vector2(minf(22 + 16 + 6 + tw + 14, size.x - 140), 34)
		pill.position = Vector2(56, y + 58 - 34)
		pill.set_meta("cmp", "tracked")
		var item: String = t
		pill.gui_input.connect(func(ev): if Tap.tap(ev): CardPop.open(self, item).show_tracking())
		_floats.add_child(pill)
	if panel == "pins":  # .floatbtn.active: a green glow ring
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", Tok.box(Color(0, 0, 0, 0), 32, 3, Tok.OK, 14, 0, Tok.OK))
		ring.position = Vector2(16, y)
		ring.size = Vector2(58, 58)
		ring.mouse_filter = MOUSE_FILTER_IGNORE
		_floats.add_child(ring)
	var b := TextureRect.new()
	b.texture = load("res://assets/ui/btn_search.webp")
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.position = Vector2(16, y)
	b.size = Vector2(58, 58)
	b.set_meta("cmp", "pins")
	b.gui_input.connect(func(ev): if Tap.tap(ev):
		if panel == "pins":
			close_panel()
		else:
			open_panel("pins")
			# openPinsTray(): once there's a pin to tap; on the tray's top edge (bottom:45vh)
			tip_once("pinselect", 10, "Tap to start tracking!", "bottom-left", null, 17, false, size.y * 0.45))
	if t == null:
		b.add_child(HubBar._badge("!", Vector2(58 + 7 - 24, -7)))
	_floats.add_child(b)


## flyItemToTracker(): the item's icon, in a gold-ringed circle, hops up from
## `from` and flies into the tracked pill (0.72s), then the pill pulses.
func fly_to_tracker(name: String, from: Rect2) -> void:
	var pills := _floats.get_children().filter(func(c): return c.get_meta("cmp", "") == "tracked" and not c.is_queued_for_deletion())
	var e = Catalog.entry(name)
	if pills.is_empty() or e == null:
		return
	var pill: Control = pills[0]
	var icon: Control = pill.get_node("Row/Icon")
	icon.modulate.a = 0  # shown again as the circle lands
	var d := clampf(from.size.y, 36, 60)
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", Tok.box(Tok.CARD, d / 2, 2.5, Tok.GOLD, 16, 6, Color(0, 0, 0, 0.4)))
	c.size = Vector2(d, d)
	c.pivot_offset = c.size / 2
	c.mouse_filter = MOUSE_FILTER_IGNORE
	var ic := Tok.icon(e.emoji, d * 0.58)
	ic.position = (c.size - ic.size) / 2
	c.add_child(ic)
	var start := from.get_center() - global_position - c.size / 2
	var target := pill.position + Vector2(22 + 8, 17) - c.size / 2
	var dv := target - start
	c.position = start
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0
	add_child(c)
	var end := 22.0 / d
	var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position", start + Vector2(dv.x * 0.1, dv.y * 0.1 - 30), 0.18)
	tw.parallel().tween_property(c, "scale", Vector2(1.1, 1.1), 0.18)
	tw.parallel().tween_property(c, "modulate:a", 1.0, 0.18)
	tw.tween_property(c, "position", target, 0.47)
	tw.parallel().tween_property(c, "scale", Vector2(end, end), 0.47)
	tw.tween_property(c, "scale", Vector2(end, end) * 0.6, 0.07)
	tw.parallel().tween_property(c, "modulate:a", 0.0, 0.07)
	tw.tween_callback(func():
		c.queue_free()
		if is_instance_valid(pill):
			icon.modulate.a = 1
			pill.pivot_offset = pill.size / 2
			var p := pill.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			p.tween_property(pill, "scale", Vector2(1.15, 1.15), 0.17)
			p.tween_property(pill, "scale", Vector2.ONE, 0.17))


func _sync_hub() -> void:
	var s := Game.state
	var sel = Game.ctx.get("selectedMapStation")
	var badges := {}
	if not (s.get("marketVisited") and not s.get("marketUnseen")):
		badges.market = "!"
	_hub.show_state(home_face(), {"inv": panel == "drawer", "market": panel == "market", "jobs": panel == "todo", "codex": panel == "codex"}, badges,
		sel != null and not Catalog.is_map_connected(s.get("lastStation"), sel))


## The visit's roll, then the dice pop-up over everything (Collect sends
## the elements into the Inventory button).
func _roll() -> void:
	var out := Game.do_roll()
	if out.is_empty():
		return
	var pop := RollPopup.make()
	pop.roll = out
	pop.fly_to = _hub.button_center("inv")
	pop.size = size
	add_child(pop)


## Travel: on a board-check turn the shutter, then the mat opens for the
## Lock-In (Home becomes Lock In); tapping Travel again just reopens the mat.
## Otherwise a quiet check sets this trip's dice and off you go.
## The very first check ever opens the Display Mat rules first.
## shortcut: the once-a-run challenge tip comes with M6 step 7 (tips).
func _travel(dest: String) -> void:
	if Catalog.is_mat_check_visit(Game.state):
		if Game.ctx.get("travelPromptFor") == dest:
			open_panel("drawer")
			return
		Game.ctx.travelPromptFor = dest
		Game.start_check_order()
		Shutter.play(self, "Display Mat Challenge!", OrderInfo.shutter_line(Orders.current(Game.state)), func():
			open_panel("drawer")
			if not Progress.prefs.get("sawMatCheckTutorial"):  # the very first check ever: the rules first
				Progress.prefs.sawMatCheckTutorial = true
				Progress.save_all()
				MatRules.show_on(self).closed.connect(_check_intro)
			else:
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
		var dlg := LockInReward.make()
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
	var s := Game.state
	var o = Orders.current(s)
	if o == null or int(o.round) != int(s.visits):
		return
	# maybeShowOrderTip(): the challenges explained, the first check of a run
	# that has one (unless hidden for good with its ✕ Hide), then this one.
	if not s.get("sawOrderTip") and not Progress.tip_hidden("orderTip"):
		s.sawOrderTip = true
		Progress.save_all()
		MatRules.order_tip(self).closed.connect(func(): OrderInfo.open(self))
		return
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
		"codex":
			if panel == "codex":
				close_panel()
			else:
				open_panel("codex")
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
