## Quick Rules (decisions 2026-11-27): the game built up one part at a time
## on its real screens, a parchment card of words at each step, Next to go
## on. It runs on a throwaway run (Game.ctx.demo: never saved), the real one
## put back at the end, which then runs `then` (into the new game, or back
## to the Play menu). Game.ctx.qr says what the screens show meanwhile:
## stations (the map's), card (the map's station card, cut after its
## elements), face (the hub's middle button).
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
var _real: Array = []  # the real run, its context and the prefs, put back at the end
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
	_real = [Game.state, Game.ctx, Progress.prefs.duplicate(true)]
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
	for a in st.act:
		_act(a)
	_wait = st.wait
	_since = 0.0
	_card.visible = _wait == ""
	_card.show_step(_words(st.say), st.place, _extra(st.extra), last_text if n == steps.size() - 1 else next_text)
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
		if c is LockInReward:
			c.queue_free()
	Game.state = _real[0]
	Game.ctx = _real[1]
	Progress.prefs = _real[2]
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


## Taps go nowhere but the card and the ✕ question (shortcut: Next only; the
## real taps at key moments come with the challenge and station parts).
func _gui_input(ev: InputEvent) -> void:
	accept_event()
