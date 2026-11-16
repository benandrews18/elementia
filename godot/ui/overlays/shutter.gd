## The board check's scene change (playShutter(), #shutter): two dark blue
## panels slide in from the top and bottom, meet at the middle along gold
## edges with "Round N / 24", the title and the challenge line, then part.
## at_closed runs while the screen is covered (open the mat there). Blocks
## taps while it plays.
class_name Shutter
extends Control

const CLOSE := 0.48
const HOLD := 1.1

var line2 := ""
var line3 := ""
var at_closed: Callable


static func play(on: Control, title: String, sub: String, closed: Callable) -> Shutter:
	var s := Shutter.new()
	s.line2 = title
	s.line3 = sub
	s.at_closed = closed
	s.size = on.size
	on.add_child(s)
	return s


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var h := size.y * 0.505
	var top := _panel(h, false)
	var bot := _panel(h, true)
	top.position.y = -h * 1.02
	bot.position.y = size.y + h * 0.02
	var label := _label()
	label.modulate.a = 0
	label.pivot_offset = label.size / 2
	label.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(top, "position:y", 0.0, CLOSE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(bot, "position:y", size.y - h, CLOSE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(label, "modulate:a", 1.0, 0.2).set_delay(0.38)
	tw.parallel().tween_property(label, "scale", Vector2.ONE, 0.3).set_delay(0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		at_closed.call()
		get_parent().move_child(self, -1))  # stay over what at_closed opened
	tw.tween_interval(HOLD - 0.38)
	tw.tween_property(label, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(top, "position:y", -h * 1.02, CLOSE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(bot, "position:y", size.y + h * 0.02, CLOSE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(queue_free)


## One panel: the blue gradient, the gold 5px edge facing the middle.
func _panel(h: float, bottom: bool) -> Control:
	var p := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#12303f"), Color("#1d4a61")] if not bottom else [Color("#1d4a61"), Color("#12303f")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	p.texture = gt
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_SCALE
	p.size = Vector2(size.x, h)
	var edge := ColorRect.new()
	edge.color = Tok.GOLD
	edge.size = Vector2(size.x, 5)
	edge.position = Vector2(0, 0 if bottom else h - 5)
	p.add_child(edge)
	add_child(p)
	return p


## .sh-label: the round pill, the title, and the challenge line, stacked
## round the middle 6px apart.
func _label() -> Control:
	var box := Control.new()
	var parts: Array[Label] = []
	var l1 := Tok.label("ROUND %d / %d" % [Game.state.visits, Data.t("RUN_COMPLETE_VISIT")], 18, Color.WHITE, 900)
	l1.add_theme_constant_override("outline_size", 0)
	l1.add_theme_stylebox_override("normal", _pad(Tok.box(Color(0, 0, 0, 0.35), 999), 14, 4))
	parts.append(l1)
	var l2 := _wrapped(Tok.label(line2, 32, Color.WHITE, 900), size.x - 32, 0)
	l2.add_theme_color_override("font_shadow_color", Color.BLACK)
	l2.add_theme_constant_override("shadow_offset_y", 3)
	l2.add_theme_constant_override("shadow_offset_x", 0)
	parts.append(l2)
	if line3 != "":
		var l3 := Tok.label(line3, 17, Color.WHITE, 900)
		l3.add_theme_stylebox_override("normal", _pad(Tok.box(Color(0, 0, 0, 0.45), 12, 2, Tok.GOLD), 14, 6))
		l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parts.append(_wrapped(l3, minf(340, size.x - 32), 28))
		l3.custom_minimum_size.y += 16 if l3.autowrap_mode else 0  # padding + border
	var y := 0.0
	for l in parts:
		var sz := l.get_combined_minimum_size()
		l.size = sz
		l.position = Vector2((size.x - sz.x) / 2, y + (4.0 if l == parts[-1] and line3 != "" else 0.0))
		y = l.position.y + sz.y + 6
		box.add_child(l)
	box.size = Vector2(size.x, y - 6)
	box.position = Vector2(0, (size.y - box.size.y) / 2)
	add_child(box)
	return box


## Wraps l (centred) when its text is wider than room (pad: its own side padding).
static func _wrapped(l: Label, room: float, pad: float) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var px := l.get_theme_font_size("font_size")
	var f := Tok.font(900)
	if f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + pad <= room:
		return l
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := roundf(f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, room - pad, px).y / f.get_height(px))
	l.custom_minimum_size = Vector2(room, lines * f.get_height(px))
	return l


static func _pad(sb: StyleBoxFlat, x: float, y: float) -> StyleBoxFlat:
	sb.content_margin_left = x
	sb.content_margin_right = x
	sb.content_margin_top = y
	sb.content_margin_bottom = y
	return sb
