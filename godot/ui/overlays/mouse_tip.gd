## Professor Mouse (hints.js #mouseTip): a pose and a speech bubble in one
## corner of the screen (or the centre), the tip's target spotlit. ✕ closes
## it, "✕ Hide" turns the hints off (Game Rules' Tutorial tips), and the next
## tap anywhere also closes it (the tap still goes through). Tips that come
## while a card is open wait their turn. App owns one, on its own layer above
## everything. The look is ui/overlays/mouse_tip.tscn.
class_name MouseTip
extends Control

const SCENE := "res://ui/overlays/mouse_tip.tscn"

@export var edge := 16.0  # from the screen's sides
@export var above_hub := 14.0  # the bottom corners' gap over the hub
@export var top := 14.0
@export var overlap := Vector2(24, 9)  # the pose tucks under the bubble's corner (and hangs below it)
@export var max_width := 0.92  # of the screen, pose and bubble together (at most 600)
@export var pad := 8.0  # the spotlight around its target
@export var skip_text := "Skip tutorial"  # the first-play tutorial's "✕ Hide"

var _queue: Array = []  # tips waiting for a card to close
var showing := false
var coaching := false  # How to Play's walkthrough: Next steps it; stray taps don't close it
var tutorial := false  # the first-play tutorial (Tutorial): "✕ Hide" skips it
var _dim := true  # coaching without a target: all dark
var _hide_text := ""
var _hint_id := ""  # a 💡 hint showing (Hints): "✕ Hide" hides just it

signal next_step
signal skip


static func make() -> MouseTip:
	return Tok.make(SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	for x: Control in [$Bubble/Close, $Bubble/Hide/Row/X]:  # ✕, drawn (not in Nunito)
		var mark := x
		mark.draw.connect(func():
			var k := 5.0 if mark == $Bubble/Close else 4.0
			var c := mark.size / 2
			var col := Color("#7d8899")
			mark.draw_line(c - Vector2(k, k), c + Vector2(k, k), col, 2.0, true)
			mark.draw_line(c + Vector2(-k, k), c + Vector2(k, -k), col, 2.0, true))
	$Bubble/Close.gui_input.connect(func(ev): if Tap.tap(ev): hide_tip())
	$Bubble/Tour/Next.gui_input.connect(func(ev): if Tap.tap(ev): next_step.emit())
	_hide_text = $Bubble/Hide/Row/Label.text
	$Bubble/Hide.gui_input.connect(func(ev): if Tap.tap(ev):  # tips off for good (Game Rules can turn them back on)
		if tutorial:
			skip.emit()
			return
		if _hint_id != "":
			Progress.hide_tip(_hint_id)
		else:
			Progress.prefs.hints = false
			Progress.save_all()
		_queue.clear()
		hide_tip())


## showMouseTip(): pose 1-12, text (BBCode: [b]...[/b]) at px, anchor one of
## bottom-left, bottom-right, top-left, top-right, center; target spotlit
## (or none). bottom: the bottom corners' line, when not over the hub.
func show_tip(pose: int, text: String, anchor := "bottom-left", target: Control = null, px := 19, bottom := -1.0, step := "", last := false) -> void:
	if _blocked() and step == "" and not tutorial:
		_queue.append([pose, text, anchor, target, px, bottom])
		return
	showing = true
	visible = true
	var img: TextureRect = $Pose
	img.texture = load("res://assets/mouse/%d.webp" % pose)
	img.size = Vector2(114, 114.0 * img.texture.get_height() / img.texture.get_width())
	var t: RichTextLabel = $Bubble/Text
	t.text = ParchDialog.emojify(text, px)  # {🎯}: the emoji's image
	t.add_theme_font_size_override("normal_font_size", px)
	t.add_theme_font_size_override("bold_font_size", px)
	var b: Control = $Bubble
	var room := minf(600, size.x * max_width) - img.size.x + overlap.x  # the bubble's widest
	# Measured with the bold face (the wider), so the text never wraps short of its box.
	var font := t.get_theme_font("bold_font")
	var plain := t.get_parsed_text()
	var inner := minf(font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 2, room - 28 - 42 - 6)
	var text_h := font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, inner, px).y
	t.size = Vector2(inner, text_h + 4)
	# The walkthrough's row under the text: the step count and Next (no ✕ or Hide).
	var tour: Control = $Bubble/Tour
	tour.visible = step != ""
	$Bubble/Close.visible = step == ""
	$Bubble/Hide.visible = step == ""
	var next: Control = $Bubble/Tour/Next
	var nl: Label = next.get_node("Text")
	nl.text = "Start Playing" if last else "Next"
	next.size.x = nl.get_theme_font("font").get_string_size(nl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 36
	if step != "":
		inner = maxf(inner, 60 + 14 + next.size.x)
	var bw := inner + 28 + 42 + 6
	var bh := text_h + 19 * 2 + 6 + (14 + 14 + 1.5 + 34 if step != "" else 0.0)
	b.size = Vector2(bw, bh)
	var r := 22
	var box: StyleBoxFlat = (b.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	box.set_corner_radius_all(r)
	var low := size.y - HubBar.H - above_hub if bottom < 0 else size.y - bottom
	match anchor:
		"bottom-right":
			img.position = Vector2(size.x - edge - img.size.x, low + overlap.y - img.size.y)
			b.position = Vector2(img.position.x + overlap.x - bw, low - bh)
			box.corner_radius_bottom_right = 6
		"top-left":
			img.position = Vector2(edge, top)
			b.position = Vector2(edge + img.size.x - overlap.x, top)
			box.corner_radius_top_left = 6
		"top-right":
			img.position = Vector2(size.x - edge - img.size.x, top)
			b.position = Vector2(img.position.x + overlap.x - bw, top)
			box.corner_radius_top_right = 6
		"center":
			var w := img.size.x - overlap.x + bw
			var h := maxf(img.size.y, bh)
			img.position = Vector2((size.x - w) / 2, (size.y - h) / 2 + (h - img.size.y) / 2)
			b.position = Vector2(img.position.x + img.size.x - overlap.x, (size.y - h) / 2 + (h - bh) / 2)
		_:  # bottom-left
			img.position = Vector2(edge, low + overlap.y - img.size.y)
			b.position = Vector2(edge + img.size.x - overlap.x, low - bh)
			box.corner_radius_bottom_left = 6
	b.add_theme_stylebox_override("panel", box)
	t.position = Vector2(3 + 28, 3 + 19)
	$Bubble/Tour/Step.text = step
	tour.position = Vector2(3 + 28, 3 + 19 + text_h + 14)
	tour.size = Vector2(inner, 14 + 1.5 + 34)
	next.position = Vector2(inner - next.size.x, 15.5)
	$Bubble/Close.position = Vector2(bw - 10 - 28, 10)
	$Bubble/Hide.position = Vector2(-12, bh + 12 - $Bubble/Hide.size.y)
	_spot(target)


## The spotlight around target (hidden without one, or once it's gone).
func _spot(target: Control) -> void:
	var s: ColorRect = $Spot
	var has := target != null and is_instance_valid(target) and target.is_visible_in_tree()
	s.visible = has or (coaching and _dim)  # the walkthrough's last step: all dark (.tut-coach-spot.hidden)
	var m := s.material as ShaderMaterial
	if has:
		var r := target.get_global_rect()
		m.set_shader_parameter("hole_pos", r.position - global_position - Vector2(pad, pad))
		m.set_shader_parameter("hole_size", r.size + Vector2(pad, pad) * 2)
	else:
		m.set_shader_parameter("hole_size", Vector2.ZERO)


## The first-play tutorial's step (Tutorial): Mouse stands on the hub (the
## user, 2026-11-27), on the side away from his target; the bubble moves up
## off the target if it would cover it. No ✕, "Skip tutorial" under the
## bubble; Next only when the step waits for it. dim: all dark without a
## target. count: "2/3" when he has several things to say in a row.
func coach(pose: int, text: String, target: Control, next: bool, dim: bool, count := "") -> void:
	coaching = true
	tutorial = true
	_dim = dim
	$Bubble/Hide/Row/Label.text = skip_text
	_place(pose, text, target, count if count != "" else (" " if next else ""))
	$Bubble/Tour/Next.visible = next
	$Bubble/Tour/Step.text = count
	$Bubble/Close.visible = false
	$Bubble/Hide.visible = true
	if $Pose.position.x < $Bubble.position.x:  # Mouse on the bubble's left: Skip on its right, clear of him
		var h: Control = $Bubble/Hide
		h.position.x = $Bubble.size.x - h.size.x + 12


## Standing on the hub, the side clear of target (the far side first); then
## the bubble lifted above the target (or put below it) if they'd overlap.
func _place(pose: int, text: String, target: Control, step: String) -> void:
	var r := target.get_global_rect().grow(pad + 4) if target != null and is_instance_valid(target) else Rect2()
	r.position -= global_position
	var sides := ["bottom-right", "bottom-left"] if r.get_center().x < size.x / 2 else ["bottom-left", "bottom-right"]
	for side in sides:
		show_tip(pose, text, side, target, 17, -1.0, step)
		if r.size == Vector2.ZERO or not $Pose.get_rect().intersects(r):
			break
	if r.size == Vector2.ZERO:
		return
	var b: Control = $Bubble
	if not b.get_rect().grow(6).intersects(r):
		return
	var above := r.position.y - 12 - b.size.y
	var below := r.end.y + 12
	if above >= top:
		b.position.y = above
	elif below + b.size.y <= size.y - HubBar.H:
		b.position.y = below
	var box: StyleBoxFlat = (b.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	box.set_corner_radius_all(22)  # off Mouse: no corner pointing at him
	b.add_theme_stylebox_override("panel", box)


## A 💡 hint (Hints), tapped: on the hub like the tutorial, spotlit;
## "✕ Hide" reads hide_text and hides just this hint for good.
func hint(id: String, pose: int, text: String, target: Control, hide_text: String) -> void:
	_hint_id = id
	$Bubble/Hide/Row/Label.text = hide_text
	_place(pose, text, target, "")


## The tutorial over: back to plain tips.
func end_coach() -> void:
	coaching = false
	tutorial = false
	_dim = true
	$Bubble/Hide/Row/Label.text = _hide_text
	hide_tip()


func hide_tip() -> void:
	showing = false
	visible = false
	if _hint_id != "":
		_hint_id = ""
		$Bubble/Hide/Row/Label.text = _hide_text
	flush()


## The next waiting tip, once nothing blocks it (a card closed, or this tip did).
func flush() -> void:
	if showing or _queue.is_empty() or _blocked():
		return
	var q: Array = _queue.pop_front()
	show_tip(q[0], q[1], q[2], q[3] if is_instance_valid(q[3]) else null, q[4], q[5])


## Queues a tip behind the one showing (queueTutorialHintOnce()).
func queue_tip(pose: int, text: String, anchor := "bottom-left", target: Control = null, px := 19) -> void:
	_queue.append([pose, text, anchor, target, px, -1.0])


## blockingEventOpen(): a card pop-up is open.
func _blocked() -> bool:
	return App.current != null and App.current.get_children().any(func(c): return c is CardPop and not c.is_queued_for_deletion())


## The next tap anywhere (outside the bubble) closes it, without stopping the tap.
func _input(ev: InputEvent) -> void:
	if showing and not coaching and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed \
			and not $Bubble.get_global_rect().grow(14).has_point(ev.position):
		hide_tip.call_deferred()
