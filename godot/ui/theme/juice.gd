## UI feedback (PLAN.md work queue 6; decisions 2026-11-23): a light
## squish-and-spring under the finger on every button, card and menu press,
## windows popping in and out, trays rising, a played card's flight, the
## map's dust, and a short buzz on the game's key moments. Every number is
## here, tunable in the Inspector: ui/theme/juice.tscn, which the App loads.
## It hooks every Control as it enters the tree, so new buttons press
## without any wiring. A Control presses when it's a button, has meta
## "button", or has its own gui_input handler (a tap), and isn't a big area
## (the map, a backdrop, the mat's play layer); meta "no_press" opts one
## out. Motion uses Godot 4.7's offset transform where it can: drawn only,
## so layouts and tap areas never move. Each node has one Juice tween at a
## time (_tween: a new motion stops the old one). Low motion (Game Rules)
## turns all of it off; Vibration turns off the buzz.
class_name Juice
extends Node

@export_group("Press")
@export var squish := 0.93  # pressed size
@export var down_time := 0.06
@export var up_time := 0.22  # the spring back (a small overshoot: TRANS_BACK)
@export var max_area := 0.2  # of the screen: bigger tappables don't press
@export var slop := 10.0  # a finger that moved further is scrolling: spring back

@export_group("Windows")
@export var pop_from := 0.9  # a window grows from this size, with a soft bounce
@export var pop_time := 0.28
@export var pop_fade := 0.12
@export var dim_fade := 0.15  # the backdrop
@export var close_to := 0.92  # a closing window shrinks to this size as it fades
@export var close_time := 0.14

@export_group("Trays")
@export var tray_rise := 40.0  # px it rises into place
@export var tray_time := 0.22
@export var tray_fade := 0.14

@export_group("Card play")
@export var fly_time := 0.3  # hand to slot
@export var settle_from := 1.08  # the landed card's bounce
@export var settle_time := 0.25
@export var drop_distance := 90.0  # a replaced card falls this far,
@export var drop_turn := 0.25  # turning (radians),
@export var drop_time := 0.32  # and fading

@export_group("Dust")
@export var dust_count := 9
@export var dust_time := 0.45
@export var dust_reach := Vector2(14, 26)  # px out, at least / at most
@export var dust_rise := 8.0
@export var dust_size := 16.0
@export var dust_color := Color(0.86, 0.76, 0.6, 0.85)

@export_group("Craft")
@export var spend_size := 56.0  # a spent element's square
@export var spend_rise := 0.42  # from below the screen onto the new card,
@export var spend_stagger := 0.08  # one after another,
@export var spend_fan := 7.0  # into a fanned pile (px apart; degrees x0.7)
@export var spend_wait := 0.16  # the pile shows this long,
@export var spend_pop := 0.28  # then pops (grows, shrinks, fades) in a firework
@export var spark_count := 26
@export var spark_reach := Vector2(80, 190)  # px out, at least / at most
@export var spark_time := 0.55
@export var keep_size := 104.0  # a kept item's card (width; the user, 2026-11-23: larger, fanned)
@export var keep_tilt := 7.0  # degrees per card from the fan's middle
@export var keep_overlap := 0.45  # of a card's width under the next one
@export var keep_up := 0.38  # peeks 75% up from behind the hub,
@export var keep_hold := 0.65  # waits (at least; longer while elements pop),
@export var keep_stagger := 0.07  # one after another, then back down

@export_group("Buzz")
@export var buzz_ms := 30  # a key moment; the Lock-In count's end: buzz_big_ms
@export var buzz_big_ms := 45
@export var buzz_strength := 0.6

const SCENE := "res://ui/theme/juice.tscn"

static var cfg: Juice  # the App's: its numbers (null: no motion at all)
static var _held: Control
static var _held_at := Vector2.ZERO
static var _frame := -1
static var _dot_tex: GradientTexture2D
static var _dust_rng := RandomNumberGenerator.new()  # its own (the firework's too): the dice use the global one (Rng)


static func make() -> Juice:
	return load(SCENE).instantiate()


func _ready() -> void:
	cfg = self
	get_tree().node_added.connect(_hook)
	_hook_all(get_tree().root)


func _exit_tree() -> void:
	if cfg == self:
		cfg = null


## Low motion (Game Rules): no feedback motion.
static func calm() -> bool:
	return Progress.prefs.get("lowMotion", false) == true


## Motion plays: the App's Juice is there and Low motion is off.
static func on() -> bool:
	return is_instance_valid(cfg) and not calm()


## A short buzz on a key moment (a card played, a craft, Lock In); phones
## that can (Android, also in the browser), unless Vibration is off.
static func buzz(big := false) -> void:
	if not is_instance_valid(cfg) or Progress.prefs.get("vibration", true) == false:
		return
	if OS.has_feature("android") or OS.has_feature("web_android"):
		Input.vibrate_handheld(cfg.buzz_big_ms if big else cfg.buzz_ms, cfg.buzz_strength)


## A fresh tween for node n's motion, the one before it stopped (two tweens
## on one property fight: a window closed mid-pop, a card pressed mid-settle).
static func _tween(n: Node) -> Tween:
	var old = n.get_meta("juice_tw") if n.has_meta("juice_tw") else null  # get_meta(k, null) errors when k is missing
	if old is Tween and old.is_valid():
		old.kill()
	var tw := n.create_tween()
	n.set_meta("juice_tw", tw)
	return tw


## A window (or a toast) coming on: its backdrop fades in, it grows from
## pop_from with a soft bounce.
static func pop_in(win: Control, dim: Control = null) -> void:
	if not on():
		return
	win.offset_transform_enabled = true
	win.offset_transform_scale = Vector2.ONE * cfg.pop_from
	win.modulate.a = 0.0
	var tw := _tween(win).set_parallel(true)
	tw.tween_property(win, "offset_transform_scale", Vector2.ONE, cfg.pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(win, "modulate:a", 1.0, cfg.pop_fade)
	if dim != null:
		dim.modulate.a = 0.0
		tw.tween_property(dim, "modulate:a", 1.0, cfg.dim_fade)


## A tray coming on: it rises the last few pixels into place and fades in.
static func slide_in(c: Control) -> void:
	if not on():
		return
	c.offset_transform_enabled = true
	c.offset_transform_position = Vector2(0, cfg.tray_rise)
	c.modulate.a = 0.0
	var tw := _tween(c).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_transform_position", Vector2.ZERO, cfg.tray_time)
	tw.tween_property(c, "modulate:a", 1.0, cfg.tray_fade)


## A window going: moved at once into a holder of its own (so nothing
## counts it as open and taps pass through), then shrunk, faded and freed.
## The move takes it out of the tree and back in: listen to a window's
## `closed`, never its tree_exited (that fires twice).
static func leave(d: Control, win: Control) -> void:
	var p := d.get_parent()
	if not on() or p == null:
		d.queue_free()
		return
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("leaving", true)
	p.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.reparent(holder)
	_ignore_mouse(d)
	win.offset_transform_enabled = true
	var tw := _tween(win).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(win, "offset_transform_scale", Vector2.ONE * cfg.close_to, cfg.close_time)
	tw.tween_property(d, "modulate:a", 0.0, cfg.close_time)
	holder.get_tree().create_timer(cfg.close_time + 0.02).timeout.connect(holder.queue_free)  # not on the tween: it stops if the window is freed under it


## A played card's flight: `card` (a copy, not yet in the tree) goes over
## everything from `from` (the lifted card, global) to where `to` sits,
## then `to` shows and settles with a little bounce.
static func fly(card: Control, from: Rect2, to: Control) -> void:
	var app := App.current
	if not on() or app == null or not from.has_area():
		card.free()
		return
	var dest := to.get_global_rect()
	card.size = dest.size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = from.position
	card.scale = Vector2.ONE * (from.size.x / dest.size.x)
	card.set_meta("flying", true)
	app.add_child(card)
	to.modulate.a = 0.0  # the card in its slot shows when the flight lands
	var tw := _tween(card).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position", dest.position, cfg.fly_time)
	tw.tween_property(card, "scale", Vector2.ONE, cfg.fly_time)
	tw.chain().tween_callback(func():
		card.queue_free()
		if is_instance_valid(to):
			to.modulate.a = 1.0
			to.offset_transform_enabled = true
			to.offset_transform_scale = Vector2.ONE * cfg.settle_from
			_tween(to).tween_property(to, "offset_transform_scale", Vector2.ONE, cfg.settle_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## A replaced card (a copy, not yet in the tree) drops away from `at`
## (global), turning and fading.
static func drop(card: Control, at: Rect2) -> void:
	var app := App.current
	if not on() or app == null or not at.has_area():
		card.free()
		return
	card.size = at.size
	card.position = at.position
	card.pivot_offset = at.size / 2
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("flying", true)
	app.add_child(card)
	var tw := _tween(card).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "position:y", at.position.y + cfg.drop_distance, cfg.drop_time)
	tw.tween_property(card, "rotation", cfg.drop_turn, cfg.drop_time)
	tw.tween_property(card, "modulate:a", 0.0, cfg.drop_time)
	tw.chain().tween_callback(card.queue_free)


## A small dust poof at `at` (in `on_node`'s space): specks that burst out,
## drift up, grow and fade. Tweens, not CPUParticles2D: particles draw on
## the global random numbers the dice use too (Rng), so every poof would
## shift later rolls; these use their own.
static func dust(on_node: Control, at: Vector2) -> void:
	if not on():
		return
	var puff := Control.new()
	puff.position = at
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puff.set_meta("dust", true)
	on_node.add_child(puff)
	for i in cfg.dust_count:
		var d := TextureRect.new()
		d.texture = _dot()
		d.size = Vector2.ONE * cfg.dust_size
		d.pivot_offset = d.size / 2
		d.position = -d.size / 2
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.modulate = cfg.dust_color
		d.scale = Vector2.ONE * _dust_rng.randf_range(0.4, 0.7)
		puff.add_child(d)
		var a := TAU * (i + _dust_rng.randf_range(-0.3, 0.3)) / cfg.dust_count
		var to := d.position + Vector2(cos(a), sin(a)) * _dust_rng.randf_range(cfg.dust_reach.x, cfg.dust_reach.y) + Vector2(0, -cfg.dust_rise)
		var tw := d.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "position", to, cfg.dust_time)
		tw.tween_property(d, "scale", d.scale * 1.8, cfg.dust_time)
		tw.tween_property(d, "modulate:a", 0.0, cfg.dust_time).set_ease(Tween.EASE_IN)
	puff.get_tree().create_timer(cfg.dust_time + 0.05).timeout.connect(puff.queue_free)


## When a craft's n spent elements pop (seconds from the craft; 0: nothing
## plays), so the new card can wait for them.
static func spend_pop_at(n: int) -> float:
	if not on() or n == 0:
		return 0.0
	return (n - 1) * cfg.spend_stagger + cfg.spend_rise + cfg.spend_wait


## flyIngredientsAndReveal()'s elements: each element a craft spent rises
## from below the screen onto the new card at `at` (app coordinates), one
## after another; they pile up fanned, then pop in a firework.
static func craft_spend(app: Control, spent: Array, at: Vector2) -> void:
	var pop_at := spend_pop_at(spent.size())
	if pop_at == 0.0:
		return
	var n := spent.size()
	var pile := Control.new()
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.set_meta("craft_fx", true)
	app.add_child(pile)
	for i in n:
		var sq := StationScreen.element_chip(spent[i], cfg.spend_size)
		_ignore_mouse(sq)
		sq.get_node("Name").visible = false  # a gather-window square: no name under it
		sq.pivot_offset = Vector2.ONE * cfg.spend_size / 2
		var off := i - (n - 1) / 2.0
		sq.position = Vector2(at.x + off * 70, app.size.y + 90) - sq.pivot_offset
		sq.modulate.a = 0.0
		sq.scale = Vector2.ONE * 0.9
		pile.add_child(sq)
		var tw := sq.create_tween()
		tw.tween_interval(i * cfg.spend_stagger + 0.001)
		tw.tween_property(sq, "modulate:a", 1.0, cfg.spend_rise * 0.12)
		tw.parallel().tween_property(sq, "scale", Vector2.ONE, cfg.spend_rise * 0.12)
		tw.parallel().tween_property(sq, "position", at + Vector2.ONE * off * cfg.spend_fan - sq.pivot_offset, cfg.spend_rise).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sq, "rotation_degrees", off * cfg.spend_fan * 0.7, cfg.spend_rise)
		tw.tween_interval(pop_at - i * cfg.spend_stagger - cfg.spend_rise + 0.001)
		tw.tween_property(sq, "scale", Vector2.ONE * 1.25, cfg.spend_pop * 0.3)
		tw.tween_property(sq, "scale", Vector2.ONE * 0.2, cfg.spend_pop * 0.7).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(sq, "modulate:a", 0.0, cfg.spend_pop * 0.7).set_ease(Tween.EASE_IN)
	var pt := pile.create_tween()
	pt.tween_interval(pop_at)
	pt.tween_callback(func(): firework(pile, at))
	pt.tween_interval(maxf(cfg.spend_pop, cfg.spark_time * 1.4) + 0.05)
	pt.tween_callback(pile.queue_free)


## fireworkBurst(): coloured sparks flying out from `at` and fading.
static func firework(on_node: Control, at: Vector2) -> void:
	var colors := ["#2e9e5b", "#d9432b", "#b7791f", "#3b7fc4", "#a16a34", "#e2b25a", "#ffffff"]
	for i in cfg.spark_count:
		var p := Panel.new()
		p.add_theme_stylebox_override("panel", Tok.box(Color(colors[_dust_rng.randi() % colors.size()]), 4))
		p.size = Vector2(7, 7)
		p.pivot_offset = p.size / 2
		p.position = at - p.pivot_offset
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		on_node.add_child(p)
		var a := TAU * i / cfg.spark_count + _dust_rng.randf() * 0.35
		var t := cfg.spark_time * _dust_rng.randf_range(1.0, 1.4)
		var tw := p.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "position", p.position + Vector2(cos(a), sin(a)) * _dust_rng.randf_range(cfg.spark_reach.x, cfg.spark_reach.y), t)
		tw.tween_property(p, "scale", Vector2.ONE * 0.25, t)
		tw.tween_property(p, "modulate:a", 0.0, t)


## The kept components (a craft uses them, doesn't spend them): their cards
## peek up from behind the hub (drawn under it), hold at least `hold`, then
## slide back down. Returns when the last is down (0: nothing plays).
static func craft_keep(app: Control, items: Array, hub: Control, hold: float) -> float:
	if not on() or items.is_empty():
		return 0.0
	var n := items.size()
	var top := app.size.y - HubBar.H
	var step := minf(cfg.keep_size * (1.0 - cfg.keep_overlap), (app.size.x - 20 - cfg.keep_size) / maxf(1, n - 1))  # close together: a fan
	var held := maxf(cfg.keep_hold, hold)
	for i in n:
		var card := ItemCard.make(items[i], {"mini": true, "in_grid": false})
		card.size = Vector2(cfg.keep_size, cfg.keep_size * 1.4)
		card.pivot_offset = Vector2(card.size.x / 2, card.size.y)
		card.position = Vector2(app.size.x / 2 + (i - (n - 1) / 2.0) * step - card.size.x / 2, top)
		card.set_meta("craft_fx", true)
		_ignore_mouse(card)
		app.add_child(card)
		app.move_child(card, hub.get_index())  # under the hub: it comes up from behind it
		var tw := card.create_tween()
		tw.tween_interval(i * cfg.keep_stagger + 0.001)
		var d := i - (n - 1) / 2.0
		tw.tween_property(card, "position:y", top - card.size.y * 0.75 + d * d * 3.0, cfg.keep_up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # the outer cards a little lower
		tw.parallel().tween_property(card, "rotation_degrees", d * cfg.keep_tilt, cfg.keep_up)
		tw.tween_interval(held)
		tw.tween_property(card, "position:y", top, cfg.keep_up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(card, "rotation_degrees", 0.0, cfg.keep_up)
		tw.tween_callback(card.queue_free)
	return cfg.keep_up * 2 + held + (n - 1) * cfg.keep_stagger


## A soft round dot (no image file): a radial gradient, white to clear.
static func _dot() -> GradientTexture2D:
	if _dot_tex == null:
		_dot_tex = GradientTexture2D.new()
		_dot_tex.width = 32
		_dot_tex.height = 32
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		_dot_tex.gradient = g
	return _dot_tex


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func _hook_all(n: Node) -> void:
	_hook(n)
	for c in n.get_children():
		_hook_all(c)


func _hook(n: Node) -> void:
	if n is Control and not n.has_meta("juice"):  # once: a reparent (Juice.leave) adds it again
		n.set_meta("juice", true)
		n.gui_input.connect(_on_gui.bind(n))


## The deepest pressable Control under a press takes it (the event goes up
## through its parents in the same frame: one press a frame).
func _on_gui(ev: InputEvent, c: Control) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed):
		return
	if _frame == Engine.get_process_frames() or calm() or not _pressable(c):
		return
	_frame = Engine.get_process_frames()
	_release()
	_held = c
	_held_at = ev.global_position
	_spring(c, squish, down_time, Tween.TRANS_SINE)


func _pressable(c: Control) -> bool:
	if c.has_meta("no_press") or c is ScrollContainer or (c is BaseButton and c.disabled):
		return false
	var screen := c.get_viewport_rect().size
	if c.size.x * c.size.y > max_area * screen.x * screen.y:
		return false
	return c is BaseButton or c.has_meta("button") or c.gui_input.get_connections().size() > 1  # ours + its own


## Every release (and a finger that's scrolling) springs the held one back.
func _input(ev: InputEvent) -> void:
	if _held == null:
		return
	if ev is InputEventMouseButton and not ev.pressed \
			or ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT and ev.global_position.distance_to(_held_at) > slop:
		_release()


func _release() -> void:
	if is_instance_valid(_held):
		_spring(_held, 1.0, up_time, Tween.TRANS_BACK)
	_held = null


func _spring(c: Control, to: float, time: float, trans: Tween.TransitionType) -> void:
	c.offset_transform_enabled = true
	_tween(c).set_trans(trans).set_ease(Tween.EASE_OUT).tween_property(c, "offset_transform_scale", Vector2(to, to), time)
