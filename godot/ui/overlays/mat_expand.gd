## "Display Mat Expansion!" (maybeShowMatExpansion(), #matExpand): on a
## growth turn's check, once per growth, the screen goes dark around the
## mat's new slots (a gold-ringed hole), the title under them. Taps count
## after 2s ("Tap to continue" fades in then); on_done runs on the tap.
## With pages set (DisplayMatScreen.grow()'s before and after), the hole
## first rings the whole mat and follows it as it grows, then closes in on
## the new slots.
class_name MatExpand
extends Control

const GROW := 0.9  # DisplayMatScreen.grow()'s time
var hole: Rect2:
	set(v):
		hole = v
		queue_redraw()
var pages := []
var on_done: Callable
var _ready_at := 0


## The new slots' rect on the open drawer if this check grew the mat and
## hasn't shown it yet (marks it shown), else an empty Rect2.
static func fresh_rect(mat: DisplayMatScreen) -> Rect2:
	var s := Game.state
	var st := Mat.stage(s)
	var grow: Array = Data.t("MAT_GROW_ROUNDS")
	if st == 0 or int(grow[st - 1]) != int(s.visits) or int(Util.get_or(s, "matExpandSeen", 0)) >= st:
		return Rect2()
	s.matExpandSeen = st
	Game._changed()
	var cards := Mat.on_mat(s)
	var now: Array = Mat.layout(cards, st).kinds
	var before: Array = Mat.layout(cards, st - 1).kinds
	var r := Rect2()
	for i in now.size():
		if now[i] != before[i] and mat.slot_rects.has(i):
			r = mat.slot_rects[i] if r.size == Vector2.ZERO else r.merge(mat.slot_rects[i])
	return r


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var slots := hole.grow(6)
	var lead := 0.0  # the growing, before the title
	var tw := create_tween()
	if pages.size() == 2:
		lead = GROW + 0.25 + 0.45
		hole = pages[0].grow(6)
		tw.tween_property(self, "hole", pages[1].grow(6), GROW).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(self, "hole", slots, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		hole = slots
	_ready_at = Time.get_ticks_msec() + int(lead * 1000 / Engine.time_scale)
	draw.connect(_paint)
	var t := Tok.label("Display Mat Expansion!", 30, Color("#ffe08a"), 900)
	t.add_theme_color_override("font_shadow_color", Color.BLACK)
	t.add_theme_constant_override("shadow_offset_y", 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(16, slots.end.y + 24)
	t.size = Vector2(size.x - 32, 36)
	t.pivot_offset = t.size / 2
	add_child(t)
	var tap := Tok.label("Tap to continue", 13, Color(1, 1, 1, 0.65), 700)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.position = Vector2(16, t.position.y + 36 + 22)
	tap.size = Vector2(size.x - 32, 18)
	tap.modulate.a = 0
	add_child(tap)
	t.scale = Vector2(0.82, 0.82)
	t.modulate.a = 0.0 if lead > 0 else 1.0
	tw.tween_property(t, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tap, "modulate:a", 1.0, 0.3).set_delay(2.0 - 0.45)


func _gui_input(ev: InputEvent) -> void:
	if Tap.tap(ev) and Time.get_ticks_msec() - _ready_at >= 2000 / Engine.time_scale:
		queue_free()
		on_done.call()


## The dark all round the hole, then its gold ring and glow.
func _paint() -> void:
	var dark := Color(4 / 255.0, 6 / 255.0, 10 / 255.0, 0.9)
	var r := hole
	draw_rect(Rect2(0, 0, size.x, r.position.y), dark)
	draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), dark)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dark)
	draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), dark)
	for k in range(8, 0, -1):  # the glow, fading out over 16px
		draw_style_box(Tok.box(Color.TRANSPARENT, 14 + k * 2, 2, Color(1, 0.88, 0.54, 0.5 * (1 - k / 9.0))), r.grow(k * 2))
	draw_style_box(Tok.box(Color.TRANSPARENT, 14, 3, Color("#ffe08a")), r)
