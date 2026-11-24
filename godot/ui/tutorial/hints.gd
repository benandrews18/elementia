## Later plays' hints (work queue 9 part 3; decisions 2026-11-23): very
## subtle, not like the tutorial. A tiny 💡 (HintBadge) on the thing a hint
## is about, one at a time; a tap on it and Professor Mouse says it, with
## "Don't show again" (Progress.hide_tip). Each once a run (state.hintsSeen:
## tapped, or its moment passed while it was out). Off with Game Rules'
## Tutorial tips (prefs.hints) and while the tutorial runs. The hints are
## Hint resources on ui/tutorial/hints.tscn, first listed first. The App
## owns one.
class_name Hints
extends Node

const SCENE := "res://ui/tutorial/hints.tscn"

@export var hints: Array[Hint] = []
@export var every := 0.25  # seconds between looks (not every frame)
@export var hide_text := "Don't show again"

var _on: Hint  # the hint whose 💡 is out
var _badge: HintBadge
var _wait := 0.0
var _last_on := ""  # the hint and target tag last badged: put back after a redraw, it doesn't fade in again


static func make() -> Hints:
	return load(SCENE).instantiate()


static func enabled() -> bool:
	return Progress.prefs.get("hints", true) != false


func seen(id: String) -> bool:
	return Util.get_or(Game.state, "hintsSeen", []).has(id)


func _process(d: float) -> void:
	_wait -= d
	if _wait > 0:
		return
	_wait = every
	var app := App.current
	if app == null:
		return
	if not _quiet():
		_drop(false)
		return
	if _on != null:
		if not Tutorial.met(_on.when):
			_drop(true)  # its moment passed: shown this run
		elif not is_instance_valid(_badge) or _badge.is_queued_for_deletion():
			_on = null  # its target went (a redraw): put it back below
		else:
			return
	for h in hints:
		if seen(h.id) or Progress.tip_hidden(h.id) or not Tutorial.met(h.when):
			continue
		var t := Tutorial.find(h.target)
		if t == null or t is Container or _covered(t):  # a Container would lay the 💡 out as a child
			continue
		_on = h
		_badge = HintBadge.new()
		var key: String = h.id + "|" + str(t.get_meta("tip", t.get_meta("cmp", "")))
		_badge.fade_in = key != _last_on
		_last_on = key
		_badge.tapped.connect(_open)
		t.add_child(_badge)
		return


## Nothing else going on: hints on, a run going, no tutorial, no Market
## moment, no Combo Lab, Mouse quiet.
func _quiet() -> bool:
	var app := App.current
	return enabled() and Game.state.get("mode") and not Game.state.get("ended") and not app.tutorial.running() \
		and not app._market_playing and not Game.ctx.get("comboLab") and not app.mouse.showing


## A window over the screen that t isn't in.
static func _covered(t: Control) -> bool:
	var app := App.current
	var wins := app.get_children().slice(app._hub.get_index() + 1).filter(func(c): return c is Control and c.visible and not c.is_queued_for_deletion())
	return not wins.is_empty() and not wins.back().is_ancestor_of(t)


func _drop(shown: bool) -> void:
	if _on != null and shown:
		_mark(_on.id)
	_on = null
	if is_instance_valid(_badge):
		_badge.queue_free()
	_badge = null


func _mark(id: String) -> void:
	if not seen(id):
		Game.state.hintsSeen = Util.get_or(Game.state, "hintsSeen", []) + [id]


## The 💡 tapped: Mouse says it, docked away from its target.
func _open() -> void:
	var h := _on
	var t: Control = _badge.get_parent() if is_instance_valid(_badge) else null
	_drop(true)
	Progress.save_all()
	App.current.mouse.hint(h.id, h.pose, h.say, t, hide_text)
