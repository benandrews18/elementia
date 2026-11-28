## Quick Rules (decisions 2026-11-27): the game built up one part at a time
## on its real screens, a parchment card of words at each step, Next to go
## on. It runs on a throwaway run (Game.ctx.demo: never saved), the real one
## put back at the end, which then runs `then` (into the new game, or back
## to the Play menu). Game.ctx.qr says what the screens show meanwhile:
## stations (the map's), card (the map's station card, cut after its
## elements), face (the hub's middle button: "" its real face), and once
## their steps come: paths, track (the 🔍 Track buttons), floats (the 🔍
## tracker button and the tracked pill), convert (its button), clock.
## The steps are QuickStep resources on ui/tutorial/quick_rules.tscn; what a
## step's `act` and `spot` words do is below (_act, _spots).
class_name QuickRules
extends Control

const SCENE := "res://ui/tutorial/quick_rules.tscn"
const CARD := "res://ui/tutorial/quick_card.tscn"
const SIDES := ["inv", "codex", "jobs", "market"]
const NBSP := " "  # a picture and its name stay on one line

@export var steps: Array[QuickStep] = []
@export_group("The challenge")
## What flies into the empty Inventory.
@export var items: PackedStringArray
## The challenge's hand, and its deck in the order it's drawn.
@export var hand_cards: PackedStringArray
@export var deck_cards: PackedStringArray
## The elements held for the challenge's draw.
@export var elements := {}
## The check's round (its Quark breakpoints) and the mat's size then (0-3:
## the first check's 3 slots are too few to show a whole hand's worth).
@export var check_round := 3
@export var mat_stage := 3
@export_group("")
@export_multiline var leave_ask := "Leave Quick Rules?"
@export var next_text := "Next"
@export var last_text := "Finish"

static var current: QuickRules

var i := -1
var then := Callable()
var _app: App
var _real: Array = []  # the real run, its context, the prefs and the To-Do List's open rows, put back at the end
var _hidden: Array = []  # windows over the App (the title screen, the Play menu): hidden, then shown again
var _card: QuickCard
var _pop: CardPop  # a big card the steps show
var _holes: Array = []  # the spotlit rects last drawn (local)
var _wait := ""  # the step's card waits for this (QuickStep.wait)
var _since := 0.0  # game time since the step started (s: follows a fixed frame rate and the test's speed-up)
var _locked := false  # the challenge's Lock In has started
@onready var _shade: ColorRect = $Shade
@onready var _rings: Control = $Rings


static func running() -> bool:
	return is_instance_valid(current)


## The 🔍 Track buttons wait for their step (the user, 2026-11-27).
static func no_track() -> bool:
	var qr = Game.ctx.get("qr")
	return qr != null and not qr.get("track", false)


## Starts it over everything on app; `done` runs once it's over (Finish or ✕).
static func begin(app: App, done: Callable) -> QuickRules:
	var q: QuickRules = Tok.make(SCENE)
	q._app = app
	q.then = done
	var layer := CanvasLayer.new()
	layer.name = "QuickRules"
	layer.layer = 2  # over every window the steps open (the App's are on layer 0)
	app.add_child(layer)
	layer.add_child(q)
	return q


func _ready() -> void:
	current = self
	position = _app.global_position  # the App sits under a phone's notch
	size = _app.size
	_real = [Game.state, Game.ctx, Progress.prefs.duplicate(true), TodoTray.detail, TodoTray.expanded.duplicate()]
	Progress.prefs.pinnedItems = []  # the steps pin their own
	Progress.prefs.autoTrackOnPin = false
	Progress.prefs.pinAsked = true  # no "Track it?" window: a later step tracks it
	for c in _app.get_children().slice(_app.hub.get_index() + 1):
		if c is Control and c.visible:
			c.visible = false
			_hidden.append(c)
	_app.close_panel(false)
	seed(hash("quickrules"))  # the same Market for everyone: drawn now, before effects take random numbers too
	Game.state = Game.fresh_state()
	Game.state.bingoCenterChosen = true
	Market.ensure_card(Game.state)
	Game.ctx = Game.fresh_ctx()
	Game.ctx.demo = true
	Game.ctx.qr = {"stations": [], "card": "", "face": "travel"}
	_app.hub.visible = false
	_app.mouse.hide_tip()
	Game.state_changed.emit()
	_rings.draw.connect(_draw_rings)
	var floor_strip := ColorRect.new()  # the hub's place, dark until the hub rises into it
	floor_strip.name = "Floor"
	floor_strip.color = Color("#1c120a")
	floor_strip.mouse_filter = MOUSE_FILTER_IGNORE
	floor_strip.position = Vector2(0, size.y - HubBar.H)
	floor_strip.size = Vector2(size.x, HubBar.H)
	add_child(floor_strip)
	move_child(floor_strip, 0)
	_card = Tok.make(CARD)
	_card.size = size
	add_child(_card)
	_card.pressed.connect(func(b):
		if b == "Next":
			_go(i + 1)
		elif b == "Leave":
			ask_leave())
	_go(0)


func ask_leave() -> void:
	if get_children().any(func(c): return c is ConfirmDialog):
		return
	ConfirmDialog.ask(self, leave_ask, finish)


func _go(n: int) -> void:
	if n >= steps.size():
		finish()
		return
	i = n
	var st := steps[n]
	for c in get_children():  # the last step's lifted copies go
		if c.has_meta("lifted"):
			c.queue_free()
	for a in st.act:
		_act(a)
	_wait = st.wait
	_since = 0.0
	_card.visible = _wait == ""
	var anchor := Rect2()  # "above:<spot>" / "below:<spot>": where that spot is
	if st.place.begins_with("above:") or st.place.begins_with("below:"):
		for c in _spots(st.place.substr(6)):
			if c is Control:
				var g: Rect2 = c.get_global_rect()
				anchor = Rect2(g.position - global_position, g.size)
	_card.low = not (Array(st.spot) + Array(st.tap)).any(func(w): return w.begins_with("hub:"))  # nothing on the hub to see: "bottom" may cover it
	_card.show_step(_words(st.say), st.place, _extra(st.extra), last_text if n == steps.size() - 1 else next_text, anchor, st.title, st.title_icon)
	_card.set_corner(_corner(st.corner))
	_holes = [null]  # redrawn whatever this step spots (none: last step's rings go)
	_update.call_deferred()
	_fit_pop.call_deferred()


## {recipe:Salmon} -> its parts from the game data, each a picture and a
## name; {stations} -> the 8 stations' pictures.
func _words(say: String) -> String:
	var row := ""
	for st in Data.t("STATION_TRACKER_ORDER"):
		row += "{%s}" % Catalog.station(st).emoji
	say = say.replace("{stations}", row)
	if say.contains("{common}"):  # the tier 1 items most recipes use (from the game data)
		var uses := {}
		var tier: Dictionary = Data.t("ITEM_TIER")
		for e in Data.t("ENTRIES"):
			for r in e.reqs:
				if r.kind == "item" and tier.get(r.name) == "MATERIAL":
					uses[r.name] = uses.get(r.name, 0) + 1
		var top: Array = uses.keys()
		top.sort_custom(func(a, b): return uses[a] > uses[b] or (uses[a] == uses[b] and a < b))
		say = say.replace("{common}", "".join(top.slice(0, 6).map(func(n): return "{%s}" % Data.t("ITEM_EMOJI")[n])))
	var re := RegEx.create_from_string("[{]recipe:([^}]+)[}]")
	for m in re.search_all(say):
		var e = Catalog.entry(m.get_string(1))
		var parts := []
		for r in RefTree.components(e) if e else []:
			var em: String = Data.t("ITEM_EMOJI").get(r.name, "") if r.kind == "item" else ""
			parts.append(("{%s}" % em + NBSP if em != "" else "") + r.name.replace(" ", NBSP))
		say = say.replace(m.get_string(), "   ".join(parts))
	return say


## A big card clear of the words (under them, or over them at the bottom).
func _fit_pop() -> void:
	if not is_instance_valid(_pop):
		return
	var card: Control = _pop.get_node("Card")
	var words := _card.target
	if _card.place == "bottom":
		card.position.y = minf(card.position.y, words.position.y - 14 - card.size.y)
	else:
		card.position.y = maxf(card.position.y, words.end.y + 14)


## The run put back, the windows shown again, then `then`.
func finish() -> void:
	if not running():
		return
	current = null
	if is_instance_valid(_pop):
		_pop.queue_free()
	for c in _app.get_children():
		if c is LockInReward or c is RollPopup or c is SuitSpend or c.has_meta("peek"):
			c.queue_free()
	var st := _station()
	if st:
		st.open_card = ""
	Game.state = _real[0]
	Game.ctx = _real[1]
	Progress.prefs = _real[2]
	TodoTray.detail = _real[3]
	TodoTray.expanded = _real[4]
	randomize()  # the seed above made every run's dice the same
	_app.close_panel(false)
	var hub := _app.hub
	hub.visible = true
	hub.position = Vector2.ZERO
	for id in SIDES:
		hub.button(id).visible = true
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	Game.state_changed.emit()
	Progress.save_all()
	get_parent().queue_free()
	if then.is_valid():
		then.call()


## A step's `act` words.
func _act(a: String) -> void:
	var arg := a.get_slice(":", 1) if a.contains(":") else ""
	var hub := _app.hub
	match a.get_slice(":", 0):
		"station":  # it bounces onto the bare map
			Game.ctx.qr.stations.append(arg)
			Game.state_changed.emit()
			var map := _map()
			if map:
				map.bounce_in(arg)
		"mapcard":  # the map's station card, down to its elements ("": none)
			Game.ctx.qr.card = arg
			Game.state_changed.emit()
		"hub":  # the hub rises in, only its middle button
			for id in SIDES:
				hub.button(id).visible = false
			hub.visible = true
			var strip := get_node_or_null("Floor")
			if strip:
				strip.queue_free()
			if Juice.on():
				hub.position.y = HubBar.H + 40
				hub.create_tween().tween_property(hub, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"slide":  # a side button rises into place
			var b := hub.button(arg)
			b.visible = true
			if Juice.on():
				var y := b.position.y
				b.position.y = y + HubBar.SIDE_H + 20
				b.create_tween().tween_property(b, "position:y", y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"market":
			_app.open_panel("market")
		"card":  # an item's big card (no pin, Info or ✕ in Quick Rules)
			if not is_instance_valid(_pop):
				_pop = CardPop.open(_app, arg)
				for n in ["Actions", "Close"]:
					_pop.get_node(n).visible = false
			else:
				_pop.show_item(arg)
		"nocard":
			if is_instance_valid(_pop):
				_pop.queue_free()
		"inventory":  # the Inventory (the Display Mat drawer)
			_app.open_panel("drawer")
		"items":  # they fly up into the Inventory, one after another
			Game.state.items = Array(items)
			Game._changed()
			_rise_items.call_deferred()
		"deal":  # a challenge: the hand dealt in
			var s := Game.state
			s.visits = check_round
			s.checkRound = check_round
			s.demoStage = mat_stage
			s.elements = elements.duplicate()
			s.mat = []
			s.matPlays = []
			s.hand = {"deck": Array(deck_cards), "hand": Array(hand_cards), "discards": [], "fresh": [], "tosses": int(Data.t("HAND_DISCARDS"))}
			Game.ctx.challengeTest = check_round
			HandView.deal(0.2)
			_app.open_panel("drawer")
		"pick":  # cards raised in the hand
			var mat := _app.hand_mat()
			if mat:
				mat.picks = Array(arg.split(","))
				mat._redraw()
		"play":  # cards picked and played onto the mat
			var mat := _app.hand_mat()
			if mat:
				mat.picks = Array(arg.split(","))
				mat.hand_play()
		"discard":  # cards picked, then discarded
			var mat := _app.hand_mat()
			if mat:
				mat.picks = Array(arg.split(","))
				mat._redraw()
				await get_tree().create_timer(0.8).timeout
				if is_instance_valid(mat) and running():
					mat.hand_discard()
		"demomat":  # demomat:Wire,Battery: these on the mat for a look at its combos ("": cleared)
			Game.state.mat = Array(arg.split(",", false))
			Game._changed()
		"view":  # the mat's page: "elements" (Draw's) or "mat"
			var mat := _app.hand_mat()
			if mat:
				mat.view = arg
				mat._redraw()
		"draw":  # draw:O:Egg: an element spent on a card of its suit
			var h = Game.check_hand()
			var mat := _app.hand_mat()
			if h != null and mat:
				Hand.suit_draw(h, Game.state, arg, a.get_slice(":", 2))
				mat.view = "mat"
				Game._changed()
		"scroll":  # the Market tray's list to a spot
			var t := _find(arg)
			var tray := _app.panel_node as MarketTray
			if t and tray:
				tray.get_node("Bg/Scroll").ensure_control_visible(t)
		"visit":  # the first station, fresh: nothing held or crafted (its whole shop to try)
			for c in _app.get_children():
				if c is LockInReward:
					c.queue_free()
			_app.close_panel(false)
			var s := Game.state
			s.items = []
			s.elements = {}
			s.mat = []
			s.matPlays = []
			s.erase("hand")
			s.erase("demoStage")
			s.visits = 0
			Game.ctx.erase("challengeTest")
			Game.ctx.qr.face = ""
			_visit(arg)
		"travel":
			_visit(arg)
		"roll":  # roll:Si,O,C: these come up (the steps craft from them)
			var s := Game.state
			var dice := Catalog.sorted_dice(Catalog.station(Game.ctx.current))
			var out := []
			for sym in arg.split(","):
				s.elements[sym] = Catalog.count(s, sym) + 1
				out.append({"face": maxi(1, dice.find(sym) + 1), "sym": sym})
			s.rolledHere = true
			s.lastRoll = out
			var pop := RollPopup.make()
			pop.roll = out
			pop.size = _app.size
			_app.add_child(pop)
			_app.sync_hub()  # Home reads Gather
			pop.tree_exited.connect(func(): if App.current and App.current.is_inside_tree(): App.current.sync_hub())
		"gather":
			for c in _app.get_children():
				if c is RollPopup:
					c.collect()
		"bench":  # a shop card's row on the Crafting Bench
			_app.open_card(arg)
		"craft":
			Game.craft(arg, Game.suggest_suit_picks(arg))
		"pin":
			Game.toggle_pin(arg)
		"todo":
			_app.open_panel("todo")
		"detail":  # the To-Do List's details panel
			TodoTray.detail = arg
			if _app.panel_node is TodoTray:
				_app.panel_node._redraw()
		"close":
			_app.close_panel(false)
		"map":
			_app.close_panel(false)
			Game.go_map()
		"reveal":  # what leaving the station found bounces in, its paths growing out to them
			var qr: Dictionary = Game.ctx.qr
			var fresh: Array = Catalog.found_stations(Game.state).keys().filter(func(st): return not qr.stations.has(st))
			qr.stations.append_array(fresh)
			qr.paths = true
			var map := _map()
			if map:
				for st in fresh:
					map._pending[st] = true
				map._redraw()
				map._reveal(fresh)
		"floats":  # the 🔍 tracker button slides in from the left
			Game.ctx.qr.floats = true
			_app._sync_floats()
			_slide_in(_app._floats.get_children(), Vector2(-120, 0))
		"pins":  # the tracker's tray
			_app.open_panel("pins")
		"track":  # tracked from the tracker's tray: it flies to the pill
			var chip := _find("pins:chip:" + arg)
			var from := chip.get_global_rect() if chip else Rect2()
			Game.ctx.qr.track = true
			Game.track(arg)
			_app.close_panel(false)
			if from.has_area():
				_app.fly_to_tracker(arg, from)
		"select":  # a station tapped on the map: its full card
			Game.ctx.selectedMapStation = arg
			Game.state_changed.emit()
		"convert":  # the Convert button slides in from the right
			Game.ctx.qr.convert = true
			Game.state_changed.emit()
			_slide_in(Tutorial.find_all("convert") + Tutorial.find_all("suits") + [_lift("convert")], Vector2(160, 0))
		"cvopen":  # cvopen:Ca:Limestone: the Convert tray on Ca, the card's bench on top
			_app.open_convert(arg, a.get_slice(":", 2))
		"cvload":  # cvload:C:Ca: what's converted, into what
			var tray := _app.panel_node as ConvertTray
			if tray:
				tray.from = arg
				tray.to = a.get_slice(":", 2)
				tray._redraw()
		"cvgo":
			var tray := _app.panel_node as ConvertTray
			if tray:
				tray.do_convert()
		"clock":  # the turn clock drops into its corner
			Game.ctx.qr.clock = true
			Game.state_changed.emit()
			_slide_in(Tutorial.find_all("clock"), Vector2(0, -160))


## Arrives at a station (Game.go_station, without its first-visit pin).
func _visit(name: String) -> void:
	var s := Game.state
	var ctx := Game.ctx
	ctx.current = name
	ctx.screen = "station"
	ctx.selectedMapStation = null
	s.visits = int(s.visits) + 1
	s.rolledHere = false
	s.lastRoll = null
	s.visitedStations[name] = true
	if not ctx.qr.stations.has(name):
		ctx.qr.stations.append(name)
	Game.state_changed.emit()


## Controls slide in from `by` away (visual only: taps land where they are).
func _slide_in(nodes: Array, by: Vector2) -> void:
	if not Juice.on():
		return
	for c in nodes:
		if c is Control:
			c.offset_transform_enabled = true
			c.offset_transform_position = by
			c.create_tween().tween_property(c, "offset_transform_position", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A copy of a spot's control over the card (the user, 2026-11-27: the
## Convert button comes in on top of the words), ringed; a tap on it is the
## step's tap. Gone at the next step.
func _lift(tag: String) -> Control:
	var src := _find(tag)
	if src == null:
		return null
	var c: Control = src.duplicate(DUPLICATE_SCRIPTS)  # no signals: its taps are the step's
	c.set_meta("lifted", true)
	var g := src.get_global_rect()
	c.position = g.position - global_position
	c.size = g.size
	c.mouse_filter = MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev): if Tap.tap(ev) and _card.visible: _go(i + 1))
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 12, 3, Color("#ffe08a")))
	ring.position = Vector2(-6, -6)
	ring.size = g.size + Vector2(12, 12)
	ring.mouse_filter = MOUSE_FILTER_IGNORE
	c.add_child(ring)
	add_child(c)
	return c


func _station() -> StationScreen:
	return _app._screen as StationScreen if is_instance_valid(_app._screen) else null


## The challenge's Lock In (App.hand_lock_in, once the mat is full): the
## real count, then the Bonus Dice it earned (Next goes on, not its Nice).
func lock_in() -> void:
	if _locked:
		return
	_locked = true
	_app._count_then(func():
		var total: float = Game.mat_score().total
		var reward := Game.reward_of(Orders.reward_for(total, check_round))
		var dlg := LockInReward.make()
		dlg.dice = reward.dice
		dlg.unknown = reward.unknown
		dlg.quarks = total
		dlg.tiers = Orders.tiers(check_round)
		dlg.size = _app.size
		dlg.on_done = func(): pass
		_app.add_child(dlg))


## The Inventory's new cards rise in from below the screen, one by one.
func _rise_items() -> void:
	var mat := _app.panel_node as DisplayMatScreen
	if mat == null or not Juice.on():
		return
	var k := 0
	for n in items:
		var c: Control = mat._inv_cards.get(n)
		if c == null:
			continue
		var y := c.position.y
		c.position.y = y + size.y
		c.create_tween().tween_property(c, "position:y", y, 0.5).set_delay(0.06 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		k += 1


## A step's corner badge (QuickStep.corner), or null.
func _corner(what: String) -> Control:
	if what == "":
		return null
	if what == "clock":
		return OrderInfo._clock(int(Data.t("RUN_COMPLETE_VISIT")))
	if what == "discard":  # the mat's Discard button: its gold-rimmed circle and card picture
		var r := TextureRect.new()
		r.texture = load("res://assets/ui/btn_round.webp")
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(58, 58)
		var ci := DisplayMatScreen._card_icon("cards_scatter")
		ci.position = (r.size - ci.size) / 2
		r.add_child(ci)
		return r
	var b := Panel.new()  # the clock's look: a cream disc in a gold ring
	b.add_theme_stylebox_override("panel", Tok.box(Color("#fff7e0"), 29, 3, Color("#a8730f"), 4, 2, Color(0, 0, 0, 0.3)))
	b.size = Vector2(58, 58)
	var ic := Tok.icon(what, 38)
	ic.position = (b.size - Vector2(38, 38)) / 2
	b.add_child(ic)
	return b


## A step's picture under its words.
func _extra(name: String) -> Control:
	match name:
		"meter":  # a Quark Meter on its way to the second breakpoint
			var m := QuarkMeter.new()
			m.custom_minimum_size.x = _card.content_width()
			m.mouse_filter = MOUSE_FILTER_IGNORE
			var t := Orders.tiers(check_round)
			m.show_score.call_deferred(lerpf(float(t.one), float(t.two), 0.5), t)
			return m
		"pool":  # the station's six elements, named: 2 rows of 3 (six 11px names don't fit one row in the card)
			var w := _card.content_width()
			var dice := Catalog.sorted_dice(Catalog.station(Game.ctx.current))
			var cell := w / 3
			var cw := 40.0
			var box := Control.new()
			box.mouse_filter = MOUSE_FILTER_IGNORE
			box.custom_minimum_size = Vector2(w, 2 * (cw + 18) + 6)
			for k in dice.size():
				var chip := StationScreen.element_chip(dice[k], cw)
				chip.get_node("Num").visible = false
				chip.get_node("Badge").visible = false
				chip.position = Vector2(k % 3 * cell + (cell - cw) / 2, k / 3 * (cw + 24))
				var nm: Label = chip.get_node("Name")
				nm.add_theme_color_override("font_color", Color("#5e4026"))
				nm.position = Vector2(-(cell - cw) / 2, cw + 3)
				nm.size = Vector2(cell, 12)
				box.add_child(chip)
			return box
		"cardtools":  # the challenge's round buttons as the mat shows them: Discard, Goal, Pass, Deck, Draw
			var w := _card.content_width()
			var cell := w / 5
			var d := 44.0
			var box := Control.new()
			box.mouse_filter = MOUSE_FILTER_IGNORE
			box.custom_minimum_size = Vector2(w, d + 18)
			var icons := [DisplayMatScreen._card_icon("cards_scatter"), Tok.icon("🎯", 23), Tok.icon("🏁", 23),
				DisplayMatScreen._card_icon("cards_deck"), DisplayMatScreen._card_icon("card")]
			var names := ["Discard", "Goal", "Pass", "Deck", "Draw"]
			for k in 5:
				var b := TextureRect.new()
				b.texture = load("res://assets/ui/btn_round.webp")
				b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				b.size = Vector2(d, d)
				b.position = Vector2(k * cell + (cell - d) / 2, 0)
				b.mouse_filter = MOUSE_FILTER_IGNORE
				var ic: Control = icons[k]
				if ic.size.x > 30:  # the card pictures: as on the mat, a little smaller here
					ic.size = Vector2(24, 24)
				ic.position = (b.size - ic.size) / 2
				b.add_child(ic)
				if k == 4:  # Draw's gold "+"
					var plus := Tok.label("+", 20, Tok.GOLD, 900)
					plus.add_theme_color_override("font_outline_color", Color("#3b2412"))
					plus.add_theme_constant_override("outline_size", 5)
					plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					plus.size = ic.size
					ic.add_child(plus)
				box.add_child(b)
				var nm := Tok.label(names[k], 11, Color("#5e4026"), 800)
				nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				nm.position = Vector2(k * cell, d + 3)
				nm.size = Vector2(cell, 14)
				box.add_child(nm)
			return box
		"suits":  # the four suits in the suit strip's gold rings, named
			var w := _card.content_width()
			var suits: Array = Data.t("ELEMENT_SUIT_LABEL").keys()
			var cell := w / suits.size()
			var d := 34.0
			var box := Control.new()
			box.mouse_filter = MOUSE_FILTER_IGNORE
			box.custom_minimum_size = Vector2(w, d + 18)
			for k in suits.size():
				var su: String = suits[k]
				var ring := Panel.new()
				ring.add_theme_stylebox_override("panel", Tok.box(Color("#122e3c"), d / 2, 1.5, Tok.GOLD, 3, 1, Color(0, 0, 0, 0.35)))
				ring.size = Vector2(d, d)
				ring.position = Vector2(k * cell + (cell - d) / 2, 0)
				ring.mouse_filter = MOUSE_FILTER_IGNORE
				var ic := Tok.icon("suit:" + su, 21)
				ic.material = Tok.tinted(Tok.suit_color(su))
				ic.position = (ring.size - Vector2(21, 21)) / 2
				ring.add_child(ic)
				box.add_child(ring)
				var nm := Tok.label(Data.t("ELEMENT_SUIT_LABEL")[su], 11, Tok.suit_color(su).darkened(0.25), 800)
				nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				nm.position = Vector2(k * cell, d + 3)
				nm.size = Vector2(cell, 14)
				box.add_child(nm)
			return box
		"elements":  # the 16, by suit then atomic number: 2 rows of 8
			var w := _card.content_width()
			var suits: Array = Data.t("ELEMENT_SUIT_LABEL").keys()
			var num: Dictionary = Data.t("ATOMIC_NUMBER")
			var syms: Array = Data.t("CORE_ELEMENT_SYMS").duplicate()
			var rank := func(s): return suits.find(Data.t("ELEMENT_SUIT")[s]) * 1000 + int(num[s])
			syms.sort_custom(func(a, b): return rank.call(a) < rank.call(b))
			var cw := floorf((w - 7 * 4) / 8)
			var box := Control.new()
			box.mouse_filter = MOUSE_FILTER_IGNORE
			box.custom_minimum_size = Vector2(w, 2 * cw + 8)
			var x0 := (w - (8 * cw + 7 * 4)) / 2
			for k in syms.size():
				var chip := StationScreen.element_chip(syms[k], cw)
				chip.get_node("Name").visible = false
				chip.get_node("Num").visible = false
				chip.get_node("Badge").visible = false  # too small to clear the symbol; the border is the suit's colour
				chip.position = Vector2(x0 + k % 8 * (cw + 4), k / 8 * (cw + 8))
				box.add_child(chip)
			return box
	return null


## Where each spot word is (the App's coordinates: this node's).
func _spots(word: String) -> Array:
	var tray := _app.panel_node as MarketTray
	var t := "Bg/Scroll/Content/Tray/"
	match word:
		"market:stations":
			return tray.get_node(t + "Stations").get_children() if tray else []
		"market:market":
			return [tray.get_node(t + "Market")] if tray else []
		"market:caps":
			return [tray.get_node(t + "CapsHead"), tray.get_node(t + "CapsSub")] + tray.get_node(t + "Caps").get_children() if tray else []
		"cp:costs", "cp:station", "cp:parts", "cp:pts":
			if not is_instance_valid(_pop):
				return []
			return [_pop.get_node("Card/" + {"cp:costs": "Costs", "cp:station": "Station", "cp:parts": "Parts", "cp:pts": "Pts"}[word])]
	if word.begins_with("hub:"):
		return [_app.hub.button(word.substr(4))]
	if word == "st:chips":  # the station's element pool
		var st := _station()
		return st.get_node("Scroll/Page/Chips").get_children() if st else []
	if word == "mat:combos":  # the Display Mat's combo row
		return Tutorial.find_all("chip")
	if word == "map:finds":  # the 🔍 marks on the stations
		return Tutorial.find_all("map:find:")
	var n := _find(word)
	return [n] if n else []


## The first visible control tagged `tag`; a "market:name:X" label stands for its square.
func _find(tag: String) -> Control:
	for n in Tutorial.find_all(tag):
		if n.get_meta("cmp", "") == tag:
			return n.get_parent() if tag.begins_with("market:name:") else n
	return null


func _map() -> MapScreen:
	for c in _app.get_children():
		if c is MapScreen and not c.is_queued_for_deletion():
			return c
	return null


func _process(d: float) -> void:
	_since += d
	if _wait != "" and _waited():
		_wait = ""
		_card.visible = true
	_update()


func _waited() -> bool:
	match _wait:
		"mat":
			var mat := _app.hand_mat()
			return _since > 1.5 and (mat == null or not mat.playing) 				and not _app.get_children().any(func(c): return c.has_meta("flying"))
		"reward":
			return _app.get_children().any(func(c): return c is LockInReward)
		"arrive":
			return _since > 0.9
		"roll":
			return _app.get_children().any(func(c): return c is RollPopup and c._rolled)
		"gathered":
			return _since > 0.3 and not _app.get_children().any(func(c): return c is RollPopup)
		"crafted":
			return _since > 0.8 and not _app.get_children().any(func(c): return c.has_meta("peek") or c.has_meta("flying"))
		"reveal":
			return _since > 2.0
	return true


## The spotlight follows its targets (a tray sliding in, a list scrolling).
func _update() -> void:
	if i < 0 or i >= steps.size():
		return
	var holes := []
	for word in steps[i].spot:
		var r := Rect2()
		for c in _spots(word):
			if c is Control and c.is_visible_in_tree():
				var g: Rect2 = c.get_global_rect()
				if word == "map:finds":  # apart across the map: a hole each
					holes.append(Rect2(g.position - global_position, g.size).grow(6))
					continue
				r = g if r.size == Vector2.ZERO else r.merge(g)
		if r.size != Vector2.ZERO:
			holes.append(Rect2(r.position - global_position, r.size).grow(6))
	if holes == _holes:
		return
	_holes = holes
	_shade.visible = not holes.is_empty()
	var m: ShaderMaterial = _shade.material
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("count", holes.size())
	var packed := PackedVector4Array()
	for k in 8:
		var h: Rect2 = holes[k] if k < holes.size() else Rect2()
		packed.append(Vector4(h.position.x, h.position.y, h.size.x, h.size.y))
	m.set_shader_parameter("holes", packed)
	_rings.queue_redraw()


func _draw_rings() -> void:
	for h in _holes.filter(func(x): return x is Rect2):
		_rings.draw_style_box(Tok.box(Color.TRANSPARENT, 12, 3, Color("#ffe08a")), h)


## Taps go nowhere but the card, the ✕ question and the step's `tap` spots,
## where a tap does what Next does (the next step does the real thing).
func _gui_input(ev: InputEvent) -> void:
	accept_event()
	if not (_card.visible and i >= 0 and i < steps.size() and Tap.tap(ev)):
		return
	for word in steps[i].tap:
		for c in _spots(word):
			if c is Control and c.is_visible_in_tree() and c.get_global_rect().grow(6).has_point(ev.global_position):
				_go(i + 1)
				return
