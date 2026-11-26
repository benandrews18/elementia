## Every list scrolls under the finger (step 18b; the user, 2026-11-26: "it
## should feel very smooth and immediate"). Godot's own ScrollContainer drag
## never starts on a row that stops input (a Panel, a button: most rows) and
## flings on the 60 Hz physics clock with a linear brake. Here a press
## anywhere in a list picks it (_seen, on every Control's gui_input: the GUI's
## own hit test, so a window over a list keeps its presses); past Tap.SLOP the
## list follows the finger 1:1; a release flings with friction (iOS's), moved
## every drawn frame. A press on a flinging list stops it and isn't a tap.
## Low processor mode (a ~7 ms sleep every frame) is off while a finger is
## down or a list moves. Lists are vertical (all of them); the wheel stays
## Godot's. The App adds one (like Juice).
class_name DragScroll
extends Node

const FRICTION := 2.0  # 1/s: speed × e^(−FRICTION·t) (iOS: 0.998 a millisecond)
const MIN_FLING := 80.0  # list px/s: a slower release just stops
const MAX_FLING := 6000.0
const STOP_SPEED := 12.0
const SAMPLE_USEC := 100000  # the release speed: the finger's last 0.1 s

static var caught := false  # the last press stopped a fling (Tap: not a tap)

var _list: ScrollContainer  # under the finger since the press (null: none)
var _press_frame := -1
var _start := Vector2.ZERO  # the finger's start (viewport px); past the slop: where following began
var _from := 0.0  # the list's scroll when following began
var _dragging := false
var _samples: Array = []  # [usec, finger y]
var _fling: ScrollContainer
var _speed := 0.0  # list px/s
var _low_cpu := false  # the low processor mode to put back when nothing moves
var _awake := false


func _ready() -> void:
	get_tree().node_added.connect(_hook)
	_hook_all(get_tree().root)


func _hook_all(n: Node) -> void:
	_hook(n)
	for c in n.get_children():
		_hook_all(c)


func _hook(n: Node) -> void:
	if n is Control and not n.has_meta("drag_scroll"):  # once: a reparent adds it again
		n.set_meta("drag_scroll", true)
		n.gui_input.connect(_seen.bind(n))
		if n is ScrollContainer:
			n.scroll_deadzone = 1 << 30  # Godot's own drag never starts (the wheel still works)


## The deepest Control under a press hears it first: its nearest list that
## can scroll is the finger's.
func _seen(ev: InputEvent, c: Control) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed):
		return
	if _press_frame == Engine.get_process_frames():
		return
	_press_frame = Engine.get_process_frames()
	var n: Node = c
	while n != null:
		if n is ScrollContainer and _can_scroll(n):
			_list = n
			return
		n = n.get_parent()


static func _can_scroll(s: ScrollContainer) -> bool:
	var bar := s.get_v_scroll_bar()
	return s.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and bar.max_value - bar.page > 0.5


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			caught = is_instance_valid(_fling) and _fling.get_global_rect().has_point(ev.position)
			_fling = null
			_list = null
			_dragging = false
			_start = ev.position
			_samples = [[Time.get_ticks_usec(), ev.position.y]]
			_wake(true)
		else:
			_release(ev.position.y)
	elif ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT and is_instance_valid(_list):
		var y: float = ev.position.y
		if not _dragging:
			var d: Vector2 = ev.position - _start
			if absf(d.y) <= Tap.SLOP or absf(d.y) < absf(d.x):
				return
			_dragging = true
			Tap._scrolled = true  # the press under the finger is no tap now
			_start = ev.position
			_from = _list.get_v_scroll_bar().value
		_list.get_v_scroll_bar().value = _from - (y - _start.y) / _scale(_list)
		var now := Time.get_ticks_usec()
		_samples.append([now, y])
		while _samples.size() > 2 and now - _samples[0][0] > SAMPLE_USEC:
			_samples.pop_front()


func _release(y: float) -> void:
	if _dragging and is_instance_valid(_list) and _samples.size() > 1:
		var now := Time.get_ticks_usec()
		var first: Array = _samples[0]
		var dt: float = (now - first[0]) / 1e6
		var last_move: float = (now - _samples[-1][0]) / 1e6
		if dt > 0.0 and dt < 0.3 and last_move < 0.06:  # a finger that stopped before lifting doesn't fling
			var v: float = -(y - first[1]) / dt / _scale(_list)
			if absf(v) > MIN_FLING:
				_fling = _list
				_speed = clampf(v, -MAX_FLING, MAX_FLING)
	_list = null
	_dragging = false
	_wake(_fling != null)


func _process(delta: float) -> void:
	if not is_instance_valid(_fling):
		if _fling != null:
			_fling = null
			_wake(false)
		return
	var bar := _fling.get_v_scroll_bar()
	var to := bar.value + _speed * delta
	bar.value = to
	_speed *= exp(-FRICTION * delta)
	if absf(_speed) < STOP_SPEED or bar.value != to or not _fling.is_visible_in_tree():  # slowed, or at an end
		_fling = null
		_wake(false)


static func _scale(s: Control) -> float:
	return maxf(s.get_global_transform_with_canvas().get_scale().y, 0.01)


## Every frame drawn while a finger is down or a list moves; then back to
## the project's low processor mode.
func _wake(on: bool) -> void:
	if on and not _awake:
		_low_cpu = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = false
	elif not on and _awake:
		OS.low_processor_usage_mode = _low_cpu
	_awake = on
