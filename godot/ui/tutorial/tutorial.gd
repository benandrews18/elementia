## The first-play tutorial (work queue 9; decisions 2026-11-23): a real run
## on known dice, stepped through by Professor Mouse up to the first Lock
## In. Each step points at one thing; only it takes taps (and the bubble,
## with Skip); a tap on it, Next, or the step's done_if moves on. The steps
## are TutorialStep resources on ui/tutorial/tutorial.tscn. The App owns
## one. Saved as prefs.tutorialStep (-1: not running); prefs.tutorialSeen:
## it ran (or was skipped) once, so New Game doesn't start it again.
class_name Tutorial
extends Node

const SCENE := "res://ui/tutorial/tutorial.tscn"
const LOST_MS := 1500  # a target missing this long: nothing is locked (never trap the player)

@export var steps: Array[TutorialStep] = []
@export_multiline var skip_ask := "Skip the tutorial?\nYou can play it again from Settings' How to Play."

var i := -1  # the step showing (-1: not running)
var _target: Control
var _since := 0  # when the target was last seen (ms)
var _paused := false  # the Skip question is open
var _spot_at := Rect2()  # where the spotlight was last put (only moved when the target moves: no redraw a frame)
var _aside := false  # the game's own moment (the Market's, a window the step doesn't point into): unlocked, Mouse hidden


static func make() -> Tutorial:
	return load(SCENE).instantiate()


func running() -> bool:
	return i >= 0


## The first New Game: the tutorial from its first step.
func start() -> void:
	Progress.prefs.tutorialSeen = true
	_go(0)


## After a load: back to where the saved step was, redoing the steps that
## led there but whose state was lost (a bench that closed with the app),
## skipping the ones already done.
func resume() -> void:
	var at := int(Progress.prefs.get("tutorialStep", -1))
	if at < 0 or at >= steps.size() or not Game.state.get("mode"):
		return
	while at > 0 and steps[at - 1].done_if != "" and not met(steps[at - 1].done_if):
		at -= 1
	_go(at)


func finish() -> void:
	i = -1
	Progress.prefs.tutorialStep = -1
	Progress.save_all()
	randomize()  # the steps seeded the dice: everyone's run would go the same way
	_target = null
	if App.current:
		App.current.mouse.end_coach()


func _go(n: int) -> void:
	while n < steps.size() and steps[n].done_if != "" and met(steps[n].done_if):
		n += 1
	if n >= steps.size():
		finish()
		return
	i = n
	Progress.prefs.tutorialStep = n
	Progress.save_all()
	var st := steps[n]
	seed(hash("tutorial%d" % n))  # the deal and the challenge come out the same
	if not st.dice.is_empty() and Game.ctx.get("current"):
		var faces := Catalog.sorted_dice(Catalog.station(Game.ctx.current))
		Rng.feed(Array(st.dice).map(func(sym): return (faces.find(sym) + 0.5) / faces.size()))
	_target = null
	_since = Time.get_ticks_msec()
	_show()


func _show() -> void:
	var st := steps[i]
	App.current.mouse.coach(st.pose, st.say, _target, st.until == "next", st.target == "" and not st.free)


func _process(_d: float) -> void:
	if i < 0 or _paused or App.current == null:
		return
	var st := steps[i]
	var app := App.current
	if st.done_if != "" and met(st.done_if):
		_go(i + 1)
		return
	_aside = app._market_playing or _covered() or Game.ctx.get("comboLab") \
		or app.get_children().any(func(c): return c is WelcomeScreen and not c.is_queued_for_deletion())  # the title screen (every launch)
	if _aside:  # wait it out, unlocked
		app.mouse.visible = false
		_since = Time.get_ticks_msec()
		return
	if not app.mouse.showing or not app.mouse.visible:
		app.mouse.visible = true
		_show()
	if st.target == "":
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree() or _target.is_queued_for_deletion():
		var t := find(st.target)
		if t != _target:
			_target = t
			if t != null:
				# The tap that moves on is one the target itself gets (not one
				# landing while something covers it, like a fade).
				if not t.has_meta("tutorial_hook"):  # once a node (a later step can point at it again)
					t.set_meta("tutorial_hook", true)
					t.gui_input.connect(_on_target_input.bind(t))
				_show()  # docked away from it, spotlit
	if _target != null:
		_since = Time.get_ticks_msec()
		var r := _target.get_global_rect()
		if r != _spot_at:  # it may be moving (a popup sliding in)
			_spot_at = r
			app.mouse._spot(_target)


## Every press outside the target and the bubble is swallowed (unless the
## step is free or the target is missing); a tap on the target moves on.
func _input(ev: InputEvent) -> void:
	if i < 0 or _paused or _aside or steps[i].free or App.current == null:
		return
	if ev.is_action_pressed("ui_cancel"):  # Escape: Back would close what the step needs
		get_viewport().set_input_as_handled()
		return
	if not (ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventScreenDrag):
		return
	var pos: Vector2 = ev.position
	if _in_bubble(pos):
		return
	var on_target := _target != null and is_instance_valid(_target) and _target.get_global_rect().grow(App.current.mouse.pad).has_point(pos)
	if not on_target:
		if steps[i].target == "" or _target != null or Time.get_ticks_msec() - _since < LOST_MS:
			get_viewport().set_input_as_handled()
		return


## A window over the screen that the step's target isn't in (a "New
## collection!" over the map): the player has to deal with it first.
func _covered() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var app := App.current
	var wins := app.get_children().slice(app._hub.get_index() + 1).filter(func(c): return c is Control and c.visible and not c.is_queued_for_deletion())
	return not wins.is_empty() and not wins.back().is_ancestor_of(_target)


func _on_target_input(ev: InputEvent, t: Control) -> void:
	if i < 0 or t != _target or steps[i].until != "tap":
		return
	if ev is InputEventMouseButton and not ev.pressed and Tap.tap(ev):
		_tapped.call_deferred(i)  # after the target has handled it


func _tapped(at: int) -> void:
	if i == at:  # not moved on already (its done_if)
		_go(at + 1)


func _in_bubble(pos: Vector2) -> bool:
	var m := App.current.mouse
	if not m.visible:
		return false
	var b: Control = m.get_node("Bubble")
	return b.get_global_rect().grow(14).has_point(pos) or m.get_node("Bubble/Hide").get_global_rect().has_point(pos)


func _ready() -> void:
	await get_tree().process_frame  # the App's Mouse first
	if App.current == null:
		return
	var m := App.current.mouse
	m.next_step.connect(func(): if i >= 0 and steps[i].until == "next": _go(i + 1))
	m.skip.connect(func():
		_paused = true
		m.visible = false
		var d := ConfirmDialog.ask(App.current, skip_ask, finish)
		d.tree_exited.connect(func(): _paused = false))


## The control a target names: a hub button, or the first visible control
## in the App tagged with it (meta "cmp"; "x*" a prefix).
static func find(tag: String) -> Control:
	var app := App.current
	if tag.begins_with("hub:"):
		return app._hub.button(tag.substr(4))
	var prefix := tag.ends_with("*")
	var want := tag.trim_suffix("*")
	var stack: Array = [app]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Control and (not n.is_visible_in_tree() or n.is_queued_for_deletion()):
			continue
		if n.has_meta("cmp"):
			var t: String = n.get_meta("cmp")
			if t == want or (prefix and t.begins_with(want)):
				return n
		stack.append_array(n.get_children())
	return null


## Does the state test hold? ("a|b": either.)
static func met(test: String) -> bool:
	var app := App.current
	var s := Game.state
	for t in test.split("|"):
		var k := t.get_slice(":", 0)
		var v := t.get_slice(":", 1) if t.contains(":") else ""
		var ok := false
		match k:
			"rolled": ok = bool(s.get("rolledHere"))
			"collected": ok = bool(s.get("rolledHere")) and not app.get_children().any(func(c): return c is RollPopup and not c.is_queued_for_deletion())
			"started": ok = int(s.get("visits", 0)) >= 1
			"owns": ok = Catalog.owns(s, v)
			"has": ok = Catalog.count(s, v) >= 1
			"from": ok = app._panel_node is ConvertTray and app._panel_node.from == v
			"panel": ok = app.panel == v
			"nopanel": ok = app.panel == ""
			"screen": ok = Game.ctx.get("screen") == v
			"at": ok = Game.ctx.get("current") == v
			"selected": ok = Game.ctx.get("selectedMapStation") == v
			"check": ok = app._hand_mat() != null
			"settled": ok = app._hand_mat() != null and not app._window_open()  # the check's windows closed
			"lifted": ok = app._hand_mat() != null and app._hand_mat().lifted != ""
			"played": ok = Game.check_hand() != null and int(Game.check_hand().plays) < int(Data.t("HAND_PLAYS"))
			"visit": ok = int(s.get("visits", 0)) >= int(v)
		if ok:
			return true
	return false
