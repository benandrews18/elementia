## UI feedback (PLAN.md work queue 6; decisions 2026-11-23): a light
## squish-and-spring under the finger on every button, card and menu press,
## the windows' pop, and a short buzz on the game's key moments. One of
## these sits in the App; it hooks every Control as it enters the tree, so
## new buttons press without any wiring. A Control presses when it's a
## button, has meta "button", or has its own gui_input handler (a tap), and
## isn't a big area (the map, a backdrop, the mat's play layer); meta
## "no_press" opts one out. The squish is Godot 4.7's offset transform:
## drawn only, so layouts and tap areas never move. Low motion (Game Rules)
## turns all of it off; Vibration turns off the buzz.
class_name Juice
extends Node

@export var squish := 0.93  # pressed size
@export var down_time := 0.06
@export var up_time := 0.22  # the spring back (a small overshoot)
@export var max_area := 0.2  # of the screen: bigger tappables don't press
@export var slop := 10.0  # a finger that moved further is scrolling: spring back

static var _held: Control
static var _held_at := Vector2.ZERO
static var _frame := -1


func _ready() -> void:
	get_tree().node_added.connect(_hook)
	_hook_all(get_tree().root)


## Low motion (Game Rules): no feedback motion.
static func calm() -> bool:
	return Progress.prefs.get("lowMotion", false) == true


## A short buzz on a key moment (a card played, a craft, Lock In); phones
## that can (Android, also in the browser), unless Vibration is off.
static func buzz(ms := 30) -> void:
	if Progress.prefs.get("vibration", true) != false and (OS.has_feature("android") or OS.has_feature("web_android")):
		Input.vibrate_handheld(ms, 0.6)


func _hook_all(n: Node) -> void:
	_hook(n)
	for c in n.get_children():
		_hook_all(c)


func _hook(n: Node) -> void:
	if n is Control and not n.gui_input.is_connected(_on_gui):
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
	if c.has_meta("juice_tw"):
		var old: Tween = c.get_meta("juice_tw")
		if old.is_valid():
			old.kill()
	c.offset_transform_enabled = true
	var tw := c.create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_transform_scale", Vector2(to, to), time)
	c.set_meta("juice_tw", tw)
