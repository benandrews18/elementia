## The game's frame: the current screen (map / station), the panel open over
## it (the drawer with the Display Mat), and the hub bar on top of
## everything. Decides the Home button's face and what tapping it does
## (hub.js hubHomeFace() and its click handler).
class_name App
extends Control

const EDGE := 6.0  # the 🔍 and ⚛️ corner buttons' gap to the screen's side (the user, 2026-11-26: room for the tracked pill)
const PILL_H := 44.0  # the tracked pill's height

var panel := ""  # "", "drawer" (the Display Mat), "convert", "market" or "todo"
var _squares := []  # Market squares owned when last looked (a new one plays the sequence)
var _squares_card := ""  # the card _squares is for (a new run or a load starts afresh)
var _market_playing := false
var market_plays := 0  # how often the Market's moment has played (tests read it)
var _screen: Control
var _screen_name := ""
var _panel_node: Control
var _under: Control  # the Display Mat kept open under the Convert tray (back to it on close)
var _hub: HubBar
var _floats: Control  # the 🔍 button and the tracked pill, under the hub, over the panels
var mouse: MouseTip  # Professor Mouse, on a layer above everything
var tutorial: Tutorial  # the first-play tutorial (its steps: ui/tutorial/tutorial.tscn)
var hints: Hints  # later plays' 💡 hints (ui/tutorial/hints.tscn)
const LAB_BAR := 40.0  # Combo Lab's exit bar
const LAB_TOP := 52.0  # where the lab's mat starts, under it
var _real: Array = []  # Combo Lab: the real run and its context, put back on exit
var _lab: Array = []  # a Challenge Test: the lab's run and context, put back when it ends

static var current: App  # the running app, for screens that need it (crafting)


func _ready() -> void:
	current = self
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(Juice.make())  # UI feedback on everything added from here on (its numbers: ui/theme/juice.tscn)
	add_child(DragScroll.new())  # every list follows the finger; a drag never taps
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
	tutorial = Tutorial.make()
	add_child(tutorial)
	hints = Hints.make()
	add_child(hints)
	tutorial.resume.call_deferred()  # a run saved mid-tutorial
	Game.state_changed.connect(_sync)
	Game.crafted.connect(_on_crafted)
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
	if not screen_covered() and is_instance_valid(_screen) and _screen.stale:
		_screen._redraw()
	sync_hub()
	_sync_floats()
	_market_check()
	_maybe_end()
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
	if s.get("sawMarketSquareTray") and panel != "market":
		s.marketUnseen = true  # with the tray open (crafted from it) it bounces there instead
		if lines.is_empty():
			Game._changed.call_deferred()
		else:  # each square pays a "?" (the user, 2026-11-26): its window, without the tray
			_market_reward.call_deferred(lines.size())
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
	# The tray can close or be rebuilt during the waits: bounce only while
	# it's there, so the sequence always ends (its block and _market_playing
	# would otherwise stay, freezing taps).
	for i in fresh:
		if is_instance_valid(tray):
			DisplayMatScreen.bounce(tray.cells.get(i))
		await get_tree().create_timer(0.32).timeout
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
		if is_instance_valid(tray) and _panel_node == tray:  # the tray this opened (not one the player reopened since)
			close_panel()
	_maybe_end()


## A Market square made away from the tray (after the run's first): the
## "?" it pays, on Nice; the tray stays shut (the Market button has its "!").
func _market_reward(n: int) -> void:
	_market_playing = true
	var rw := RowReward.make(n, func(): pass)
	rw.size = size
	add_child(rw)
	await rw.tree_exited  # until Nice
	_market_playing = false
	Game.collect_market_rewards()
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


## After a craft (autoCardPop(), celebrate()): a capstone gets its card under
## a "Capstone complete!" banner with confetti, then the items it unlocks;
## anything else a small card that pops up and flies into the Inventory.
func _on_crafted(name: String) -> void:
	if Game.ctx.get("comboLab") or not is_inside_tree():
		return
	Juice.buzz()
	# flyIngredientsAndReveal(): the elements spent (the recipe's, not its
	# catalysts, and the suit cost paid) rise onto the new card and pop, the
	# card waiting for them; the kept items peek up from behind the hub.
	var e: Dictionary = Catalog.entry(name)
	var spent := []
	for r in e.reqs:
		if r.kind == "element" and not r.catalyst:
			spent.append(r.name)
	for sym in Game.last_tax:
		for k in int(Game.last_tax[sym]):
			spent.append(sym)
	var pop_at := Juice.spend_pop_at(spent.size())
	if e.tier == "CAPSTONE":
		_celebrate(name)
	else:
		_craft_peek(name, maxf(0.5, pop_at + (Juice.cfg.spend_pop if pop_at > 0 else 0.0)))
	var centre := size / 2 - Vector2(0, HubBar.H / 2)
	Juice.craft_spend(self, spent, centre)
	var kept: Array = Catalog.needs_of(e.reqs).items.map(func(r): return r.name)
	var down := Juice.craft_keep(self, kept, _hub, pop_at)
	if down > 0:
		_hub.create_tween().tween_interval(down).finished.connect(_hub.punch.bind("inv"))


## The small card: pops in at the middle, a moment's look, then flies into
## the Inventory button (which bounces). A tap first opens the full card.
func _craft_peek(name: String, wait := 0.5) -> void:
	var card := ItemCard.make(name)
	card.size = Vector2(110, 110 * 1.4)
	card.pivot_offset = card.size / 2
	card.position = (size - card.size) / 2 - Vector2(0, HubBar.H / 2)
	card.scale = Vector2(0.6, 0.6)
	card.modulate.a = 0.0
	card.mouse_filter = MOUSE_FILTER_STOP
	card.set_meta("peek", true)
	add_child(card)
	var to := _hub.button_center("inv") - card.size / 2
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.12)
	tw.tween_interval(wait)  # the spent elements pop on it first
	tw.tween_callback(func(): card.mouse_filter = MOUSE_FILTER_IGNORE)
	tw.tween_property(card, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "scale", Vector2(0.15, 0.15), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "modulate:a", 0.4, 0.45)
	tw.tween_callback(func():
		card.queue_free()
		_hub.punch("inv"))
	card.gui_input.connect(func(ev): if Tap.tap(ev) and card.mouse_filter == MOUSE_FILTER_STOP:
		tw.kill()
		card.queue_free()
		show_card(name))


## celebrate(): the capstone's card, "Capstone complete!" and how many of the
## eight, confetti; once it's closed, the items it opened up.
func _celebrate(name: String) -> void:
	var tiers: Dictionary = Data.t("ITEM_TIER")
	var caps: Array = tiers.keys().filter(func(n): return tiers[n] == "CAPSTONE")
	var p := CardPop.open(self, name)
	p.show_celebration(caps.filter(func(n): return Catalog.owns(Game.state, n)).size(), caps.size())
	_confetti()
	p.tree_exited.connect(func(): if is_inside_tree(): _unlock_reveal(name))


## queueUnlockReveal(): "New Items Unlocked!" once the screen is clear.
func _unlock_reveal(cap: String) -> void:
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	var names: Array = unlocked.keys().filter(func(n): return unlocked[n] == cap)
	if names.is_empty() or Game.state.get("ended"):
		return
	while _window_open() or _market_playing or (_panel_node is DisplayMatScreen and _panel_node.playing):
		await get_tree().create_timer(0.4).timeout
		if not is_inside_tree():
			return
	UnlockReveal.show_on(self, cap, names)


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
	end_run()
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
		var choose := func():
			var c := CapstoneChoice.make()
			c.size = size
			add_child(c)
		choose.call()
		if not Progress.prefs.get("tutorialSeen"):  # everyone's first New Game since the tutorial came in
			tutorial.start())


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


## maybeShowCollectionFound(): a named collection complete on the mat that
## was never found: "New collection!", once nothing else is on screen (not
## during a Lock-In or the Market's moment); the next one after it's added.
func _collection_found() -> void:
	if not Game.state.get("mode") or Game.ctx.get("lockInCommitted") or _market_playing or Game.ctx.get("comboLab"):
		return
	if _window_open():
		return  # something's open; the next change tries again
	var c = Progress.undiscovered_on_mat()
	if c != null:
		CollectionFound.show_on(self, c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android's Back (quit_on_go_back is off)
		back()


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):  # Escape (input.js)
		back()


## Back / Escape: what tapping out of the top thing does, never a quit. The
## Dev Panel; else the top window's Close, else its backdrop (each window's
## own rules: a step that can't be skipped has neither, or ignores it); else
## the open panel. Nothing open: nothing.
func back() -> void:
	if tutorial.running() and not tutorial.steps[tutorial.i].free:
		return  # the step needs what Back would close
	var dev := get_node_or_null("Dev")
	for p in dev.get_children() if dev else []:
		if p is DevPanel and p.visible:
			p.hide()
			return
	var wins := get_children().slice(_hub.get_index() + 1).filter(func(c): return c is Control and c.visible and not c.is_queued_for_deletion())
	if not wins.is_empty():
		var w: Control = wins.back()
		var t: Control = w if w.name == "LabBar" else w.find_child("Close", true, false)
		if t == null:
			t = w.find_child("Dim", true, false)
		if t:
			_tap(t)
		return
	if panel != "":
		close_panel()


## A tap on n, as a finger would.
static func _tap(n: Control) -> void:
	if n is BaseButton:
		n.pressed.emit()
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.global_position = n.get_global_rect().get_center()
	Tap._down = null
	n.gui_input.emit(ev)


## A window open over the screen (anything added after the hub).
func _window_open() -> bool:
	return get_children().slice(_hub.get_index() + 1).any(func(c): return c is Control and not c.is_queued_for_deletion())


## The Periodic Table and the 16 Elements (Tutorial Messages): two
## windows, Next through them.
func show_elements() -> void:
	var intro := ParchDialog.open(self, "res://ui/overlays/tut_intro.tscn")
	intro.pressed.connect(func(b): if b == "Next":
		intro.close()
		var els := ParchDialog.open(self, TutElements.SCENE)
		els.pressed.connect(func(b2): if b2 == "Next": els.close()))


## How to Play (Settings): the first-play tutorial again, in a new game
## (this run goes into History).
func replay_tutorial() -> void:
	ConfirmDialog.ask(self, "Play the tutorial again?
It starts a new game.", func():
		Progress.prefs.tutorialSeen = false
		new_game())


## Combo Lab (openComboLab(); the title screen): a sandbox mat. The real run
## is put aside and a throwaway one takes its place: every item owned (but
## a capstone's unlocks this player has never seen), visit 20 so the Quark
## Meter has room, never saved. The mat fills the screen under "✕ Exit Combo
## Lab"; the hub, the screen and the floating buttons are hidden.
## From a run (the Inventory's button; the user, 2026-11-23): that run's
## items, its mat and its visit instead, free to try combos on; the run's
## own mat stays locked in between checks.
func open_combo_lab(from_run := false) -> void:
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
	if from_run:
		lab.items = Game.state.items.duplicate()
		lab.mat = Game.state.mat.duplicate()
		lab.visits = Game.state.visits
		lab.checkRound = Game.state.get("checkRound")  # the mat's size on a growth check (Mat.stage)
		lab.matChecked = Game.state.get("matChecked", false)
	Game.state = lab
	Game.ctx = Game.fresh_ctx()
	Game.ctx.comboLab = true
	_hub.visible = false
	_dev_shown(false)  # the Dev Panel would replace the lab's run and save it over the real one
	open_panel("drawer")
	if is_instance_valid(_screen):
		_screen.visible = false
	var bar := load("res://ui/pieces/lab_bar.tscn").instantiate() as Control
	bar.name = "LabBar"
	bar.size = Vector2(size.x, LAB_BAR)
	bar.gui_input.connect(func(ev): if Tap.tap(ev): close_combo_lab())
	add_child(bar)
	var exit_text: Label = bar.get_node("Text")  # to the left: the Challenge Test button on the right
	exit_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	exit_text.offset_left = 16
	var test := Tok.label("Challenge Test", 12, Tok.CARD_INK, 900)
	test.name = "Test"
	test.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	test.add_theme_stylebox_override("normal", Tok.box(Tok.GOLD, 12, 0, Color.BLACK, 3, 2, Color(0, 0, 0, 0.35)))
	test.size = Vector2(124, 28)
	test.position = Vector2(size.x - 130, (LAB_BAR - 28) / 2)
	test.mouse_filter = MOUSE_FILTER_STOP
	test.gui_input.connect(func(ev): if Tap.tap(ev):
		if _lab.is_empty():
			_challenge_pick()
		else:
			end_challenge_test())
	bar.add_child(test)


func close_combo_lab() -> void:
	if _real.is_empty():
		return
	Game.state = _real[0]
	Game.ctx = _real[1]
	_real = []
	_lab = []
	_hub.visible = true
	_dev_shown(true)
	var bar := get_node_or_null("LabBar")
	if bar:
		bar.name = "LabBarGone"  # a lab opened again this frame gets the name (its Test button is found by it)
		bar.queue_free()
	close_panel()
	if is_instance_valid(_screen):
		_screen.visible = true
	Game.state_changed.emit()


## The Challenge Test (the user, 2026-11-22): card playing at a check, tried
## in the Combo Lab before real checks use it. Pick a check round; a copy of
## the real run (its items, the mat as far as it fits) plays that check with
## a hand. Nothing is saved; Lock In shows the reward, then back to the lab.
func _challenge_pick() -> void:
	var d := ParchDialog.open(self, "res://ui/overlays/challenge_test.tscn")
	var grid: Control = d.get_node("Window/Content/Rounds")
	var every := int(Data.t("MAT_CHECK_EVERY"))
	for r in range(every, int(Data.t("RUN_COMPLETE_VISIT")) + 1, every):  # the regular game's checks (40 is freeplay's cap)
		var b: Control = load("res://ui/pieces/pill_button.tscn").instantiate()
		b.get_node("Text").text = str(r)
		b.custom_minimum_size = Vector2(62, 46)
		b.name = "R%d" % r
		b.gui_input.connect(func(ev): if Tap.tap(ev):
			d.close()
			start_challenge_test(r))
		grid.add_child(b)


func start_challenge_test(round: int) -> void:
	if _real.is_empty():
		return
	_lab = [Game.state, Game.ctx]
	var s: Dictionary = _real[0].duplicate(true)
	s.visits = round
	s.matChecked = round > int(Data.t("MAT_CHECK_EVERY"))
	s.checkRound = round
	s.order = null
	s.ended = false
	s.runComplete = false
	s.finalCheckPending = false
	s.quickSavedMat = null
	Game.state = s
	Game.ctx = Game.fresh_ctx()
	Game.ctx.comboLab = true
	Game.place_mat_cards(s.mat.duplicate())  # what fits this round's mat
	Game.state.hand = Hand.deal(s)
	Game.ctx.challengeTest = round
	_test_label("✕ End Test")
	_hub.visible = true  # the hand's buttons
	open_panel("drawer")
	Game.start_check_order()
	OrderInfo.open(self)


func end_challenge_test() -> void:
	if _lab.is_empty():
		return
	Game.state = _lab[0]
	Game.ctx = _lab[1]
	_lab = []
	_test_label("Challenge Test")
	_hub.visible = false
	open_panel("drawer")
	Game.state_changed.emit()


func _test_label(text: String) -> void:
	var t := get_node_or_null("LabBar/Test") as Label
	if t:
		t.text = text


## The test's Lock In: the real count, the reward this round would give,
## then back to the lab.
func challenge_lock_in() -> void:
	var total: float = Game.mat_score().total
	var reward := Game.reward_of(Orders.reward_for(total, int(Game.ctx.challengeTest)))
	_count_then(func():
		var dlg := LockInReward.make()
		dlg.dice = reward.dice
		dlg.unknown = reward.unknown
		dlg.quarks = total
		dlg.tiers = Orders.tiers(int(Game.ctx.challengeTest))
		dlg.size = size
		dlg.on_done = end_challenge_test
		add_child(dlg))


func _dev_shown(on: bool) -> void:
	var dev := get_node_or_null("Dev") as CanvasLayer
	if dev:
		dev.visible = on


## The run over for good (New Game, the end screen's Main Menu): into
## History, then a fresh state is saved, so Play starts a new run.
func end_run() -> void:
	if tutorial.running():  # a tutorial left unfinished ends with its run
		tutorial.finish()
	Progress.record_history()
	Game.state = Game.fresh_state()  # before close_panel(): an ended run would reopen its end screen
	Game.ctx = Game.fresh_ctx()
	Progress.prefs.pinnedItems = []
	close_panel()
	Game._changed()


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


## The Convert tray with to_sym already picked as what to convert into;
## item: the card it's missing from (its bench rides on the tray).
func open_convert(to_sym: String, item := "") -> void:
	open_panel("convert")
	_panel_node.to = to_sym
	_panel_node.bench_item = item  # its Crafting Bench on top of the tray
	_panel_node._redraw()


## Opens a panel over the screen ("drawer": the Display Mat).
func open_panel(name: String) -> void:
	if name == "convert" and panel == "drawer" and is_instance_valid(_panel_node):
		_under = _panel_node  # Convert opens over the mat (the user: not back to the map)
		_panel_node = null
		panel = ""
	else:
		close_panel(false)
	if name == "drawer":
		Game.deal_hand()  # a check's mat: its hand, the first time
	panel = name
	if name in ["drawer", "convert", "market", "todo", "codex", "pins"]:
		_panel_node = {"drawer": DisplayMatScreen, "convert": ConvertTray, "market": MarketTray, "todo": TodoTray, "codex": ItemsScreen, "pins": PinsTray}[name].make()
		add_child(_panel_node)
		move_child(_panel_node, _floats.get_index())  # under the 🔍 button and the hub
		if name in ["convert", "market", "todo", "pins"]:  # the trays slide in from their own sides (the user, 2026-11-23)
			Juice.slide_in(_panel_node, {"todo": Vector2(-size.x * 0.6, 0), "market": Vector2(0, -size.y * 0.4)}.get(name, Vector2.ZERO))
	_sync()


## In a check with cards, closing the Convert tray goes back to the hand
## (unless another panel is opening: back = false).
func close_panel(back := true) -> void:
	var to_hand := back and _check_convert() and not is_instance_valid(_under)
	if is_instance_valid(_panel_node):
		_panel_node.queue_free()
	_panel_node = null
	panel = ""
	if is_instance_valid(_under):
		if back:  # Convert closed: the mat under it again
			_panel_node = _under
			_under = null
			panel = "drawer"
			_sync()
			return
		_under.queue_free()
	_under = null
	if to_hand:
		open_panel("drawer")
		return
	if Game.state.get("ended"):  # e.g. after "Review my collection": the end screen again (New Game)
		Game.ctx.endShown = ""
	_sync()


## hubHomeFace(): what Home does right now.
func home_face() -> String:
	var s := Game.state
	var c := Game.ctx
	var sel = c.get("selectedMapStation")
	if get_children().any(func(n): return n is RollPopup and not n.collecting and not n.is_queued_for_deletion()):
		return "gather"  # the roll's chips wait: Gather collects them
	if _hand_mat():
		return "play"
	if c.get("awaitingStart"):  # the opening: Start, even over a tray (the user, 2026-11-26)
		return "start"
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


## Every 📌 tap: pins or unpins (Game.toggle_pin). A new pin that isn't
## tracked asks "Track it now?" until "Don't ask again" is ticked, which
## sets Game Rules' "Auto-track on pin" to the answer (the user, 2026-11-26).
## Once tracked, the item flies from `from` to the pill.
static func pin(name: String, from := Rect2()) -> void:
	var was := Progress.is_pinned(name)
	Game.toggle_pin(name)
	if was or current == null:
		return
	var app := current
	var fly := func(): if from.has_area() and Game.ctx.get("tracked") == name: app.fly_to_tracker(name, from)
	if Game.ctx.get("tracked") == name or Progress.prefs.get("pinAsked") == true:
		fly.call()
		return
	var dlg := []  # the window, for its tick box once answered
	var answer := func(yes: bool):
		if dlg[0].checked:
			Progress.prefs.pinAsked = true
			Progress.prefs.autoTrackOnPin = yes
		if yes:
			Game.track(name)
			fly.call()
		else:
			Progress.save_all()
	dlg.append(ConfirmDialog.ask(app, "%s is pinned to your To-Do List. Track it now? Its parts get 🔍 marks at the stations and on the map." % name,
		func(): answer.call(true), {"title": "Track it?", "yes_text": "Track it", "no_text": "Not now",
		"check_text": "Don't ask again", "on_no": func(): answer.call(false)}))


## The opening's locked Start: a line above it saying why (the user,
## 2026-11-26: Start only once something is tracked).
func _start_lock(on: bool) -> void:
	var lock := get_node_or_null("StartLock")
	if not on:
		if lock:
			lock.queue_free()
			lock.name = "StartLockGone"
		return
	if lock:
		return
	var p := Panel.new()
	p.name = "StartLock"
	p.add_theme_stylebox_override("panel", Tok.box(Color(0, 0, 0, 0.72), 14))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.set_meta("cmp", "start:lock")
	var l := Tok.label("Track an item to start", 15, Color.WHITE, 800)
	var tw := Tok.font(800).get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	p.size = Vector2(tw + 28, 30)
	l.position = Vector2(14, 4)
	p.add_child(l)
	p.position = Vector2((size.x - p.size.x) / 2, size.y - HubBar.H - 14 - 58 - 12 - p.size.y)  # over the 🔍 / ⚛️ row
	p.pivot_offset = p.size / 2
	add_child(p)


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
	if panel == "convert":  # its button over the tray: a tap closes it again
		StationScreen.corner_buttons(_floats, false)
		return
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
		# Readable first (the user, 2026-11-26): 17 px, out to the screen's
		# middle at most, a long name shrinking to fit (never under 11).
		pill.position = Vector2(EDGE + 40, y + (58 - PILL_H) / 2)
		var room := size.x / 2 - pill.position.x - (26 + 30 + 8 + 20)
		var px := Tok.fit_px(t, nl.get_theme_font("font"), 17, room)
		nl.add_theme_font_size_override("font_size", px)
		var tw := nl.get_theme_font("font").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		pill.size = Vector2(26 + 30 + 8 + tw + 20, PILL_H)
		pill.set_meta("cmp", "tracked")
		var item: String = t
		pill.gui_input.connect(func(ev): if Tap.tap(ev): CardPop.open(self, item).show_tracking())
		_floats.add_child(pill)
	if panel == "pins":  # .floatbtn.active: a green glow ring
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", Tok.box(Color(0, 0, 0, 0), 32, 3, Tok.OK, 14, 0, Tok.OK))
		ring.position = Vector2(EDGE, y)
		ring.size = Vector2(58, 58)
		ring.mouse_filter = MOUSE_FILTER_IGNORE
		_floats.add_child(ring)
	var b := TextureRect.new()
	b.texture = load("res://assets/ui/btn_search.webp")
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.position = Vector2(EDGE, y)
	b.size = Vector2(58, 58)
	b.set_meta("cmp", "pins")
	b.gui_input.connect(func(ev): if Tap.tap(ev):
		if panel == "pins":
			close_panel()
		else:
			open_panel("pins"))
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
	var target := pill.position + Vector2(26 + 15, PILL_H / 2) - c.size / 2
	var dv := target - start
	c.position = start
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0
	add_child(c)
	var end := 34.0 / d
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


func sync_hub() -> void:
	var s := Game.state
	var sel = Game.ctx.get("selectedMapStation")
	var badges := {}
	if not (s.get("marketVisited") and not s.get("marketUnseen")):
		badges.market = "!"
	var here = s.get("lastStation")
	_hub.shop_glyph = Catalog.station(here).emoji if here else ""  # Shop shows where you are (the user)
	var mat := _hand_mat()
	_hub.muted = false
	if mat:  # a check with cards: Play in the middle (muted until picked cards fit), the Challenge on Jobs
		_hub.greyed = mat.playing
		_hub.muted = not mat.can_play()
		_hub.show_state("play", {"inv": true}, {}, false, true, {"market": true, "inv": Game.ctx.get("challengeTest", false)})
		return
	if _check_convert():  # Close goes back to the hand
		_hub.greyed = false
		_hub.show_state("close", {}, {}, false, true, {"jobs": true, "inv": true, "market": true, "codex": true})
		return
	if _hub.hand:  # out of a check with cards: Draw's grey goes with it
		_hub.greyed = false
	_hub.muted = home_face() == "start" and Game.ctx.get("tracked") == null
	_start_lock(_hub.muted)
	_hub.show_state(home_face(), {"inv": panel == "drawer", "market": panel == "market", "jobs": panel == "todo", "codex": panel == "codex"}, badges,
		sel != null and not Catalog.is_map_connected(s.get("lastStation"), sel))


## The Display Mat while a check is played with cards (else null).
func _hand_mat() -> DisplayMatScreen:
	return _panel_node as DisplayMatScreen if panel == "drawer" and Game.check_hand() != null else null


## The Display Mat covers the map or station under it: that screen skips
## its redraws while it's open (every change in a check redrew it unseen)
## and catches up when it closes (_sync()).
func screen_covered() -> bool:
	return panel == "drawer"


## The Convert tray opened from a check with cards.
func _check_convert() -> bool:
	return panel == "convert" and Game.check_hand() != null


## The hub during a check with cards: Play (the picked hand cards), the
## Market shut until the check ends; the To-Do List, Inventory (closes the
## mat: the check waits) and Codex as usual (the challenge: the 🎯 Goal
## above the hand). True if handled.
func _hand_tap(mat: DisplayMatScreen, id: String) -> bool:
	match id:
		"home": mat.hand_play()
		"market": mat._show_toast("The Market opens after the check.")
		"inv":
			return Game.ctx.get("challengeTest", false)  # the lab's test: nothing under the mat to go back to
		_:
			return false
	return true


## Lock In (under the mat, or the mat full after a play): the check's count,
## then on.
func hand_lock_in() -> void:
	var mat := _hand_mat()
	if mat == null or mat.playing:
		return
	if Game.ctx.get("challengeTest"):
		challenge_lock_in()
	elif Game.state.get("finalCheckPending"):
		_final_lock_in()
	else:
		_lock_in()


## The visit's roll, then the dice pop-up over everything (Collect sends
## the elements into the Inventory button).
func _roll() -> void:
	var out := Game.do_roll()
	if out.is_empty():
		return
	var pop := RollPopup.make()
	pop.roll = out
	if Game.state.get("matChecked"):  # the dice past the usual roll are the Quark score's bonus (do_roll() adds them last)
		pop.bonus = maxi(0, out.size() - int(Data.t("TAKE")))
	pop.fly_to = _hub.button_center("inv")
	pop.size = size
	add_child(pop)
	sync_hub()  # Home reads Gather
	pop.tree_exited.connect(func(): if is_inside_tree(): sync_hub())


## Travel: on a board-check turn the shutter, then the mat opens for the
## Lock-In (Home becomes Lock In); tapping Travel again just reopens the mat.
## Otherwise a quiet check sets this trip's dice and off you go.
## The rules and the challenge are hints now (Hints), not windows.
func _travel(dest: String) -> void:
	if Catalog.is_mat_check_visit(Game.state):
		if Game.ctx.get("travelPromptFor") == dest:
			open_panel("drawer")
			return
		Game.ctx.travelPromptFor = dest
		Game.start_check_order()
		Shutter.play(self, "Display Mat Challenge!", OrderInfo.shutter_line(Orders.current(Game.state)), func():
			HandView.hold()  # dealt in once the challenge is closed (the user, 2026-11-23): _challenge()
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
	var tiers := Orders.tiers(Orders.check_round(Game.state))
	_count_then(func():
		var dlg := LockInReward.make()
		dlg.dice = reward.dice
		dlg.unknown = reward.unknown
		dlg.quarks = Game.mat_score().total
		dlg.tiers = tiers
		dlg.size = size
		dlg.on_done = func(): fade_through_black(func():
			close_panel()
			Game.confirm_lock_in())
		add_child(dlg))


## Under the shutter: the mat-expansion reveal on a growth turn, then this
## check's challenge.
func _check_intro() -> void:
	var mat := _panel_node as DisplayMatScreen
	var r := MatExpand.fresh_rect(mat) if mat else Rect2()
	if r.size == Vector2.ZERO:
		_challenge()
		return
	var grows := mat.view == "mat"  # the growing shows on the mat page, not the elements page
	if grows:
		mat.show_stage(Mat.stage(Game.state) - 1)  # under the shutter: the mat as it was
	await get_tree().create_timer(Shutter.HOLD + Shutter.CLOSE).timeout  # once the shutter has parted
	var mx := MatExpand.new()
	if grows and is_instance_valid(mat):
		mx.pages = mat.grow(MatExpand.GROW)
	mx.hole = r
	mx.on_done = _challenge
	mx.size = size
	add_child(mx)


func _challenge() -> void:
	var s := Game.state
	var o = Orders.current(s)
	if o == null or int(o.round) != int(s.visits):
		_deal_hand()
		return
	OrderInfo.open(self).tree_exiting.connect(_deal_hand)


## The held hand flies in (the challenge window closed, or there was none).
func _deal_hand() -> void:
	if HandView.deal_at >= 0:
		return
	HandView.deal(0.05)
	var mat := _hand_mat()
	if mat:
		mat._redraw()


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
	_hub.greyed = true  # the Lock-In button greys: no second tap while it counts
	_hub._build()
	var held := [block]  # emptied once unblocked: a lambda capturing a freed node errors when called again
	var unblock := func():  # also when the mat goes mid-count (its count never finishes then)
		if not held.is_empty() and is_instance_valid(held[0]):
			held[0].queue_free()
			_hub.greyed = false
			_hub._build()
		held.clear()
	mat.tree_exiting.connect(unblock)
	mat.play_lock_in(func():
		unblock.call()
		Juice.buzz(true)  # the count's end: a key moment
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
	var hand_mat := _hand_mat()
	if hand_mat and _hand_tap(hand_mat, id):
		return
	if _check_convert():
		if id == "home":
			close_panel()
		return
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
				"gather":
					for p in get_children():
						if p is RollPopup:
							p.collect()
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
				"start":
					if Game.ctx.get("tracked") == null:  # locked: the line above says why; the To-Do List is where to track
						if panel != "todo":
							open_panel("todo")
						var lock := get_node_or_null("StartLock")
						if lock:  # a little shake
							var tw: Tween = lock.create_tween()
							for dx in [8.0, -8.0, 5.0, 0.0]:
								tw.tween_property(lock, "position:x", (size.x - lock.size.x) / 2 + dx, 0.06)
						return
					close_panel()
					Game.begin()
				"lockin":
					_lock_in()
				"final":
					_final_lock_in()
