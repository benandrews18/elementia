## "Are you sure?" (askConfirm(), #confirmBox): the screen dims; a parchment
## window (panel_parchment 9-slice) with the title on a wooden banner, the
## message, and "Yes, do it" / Cancel. on_yes runs on Yes; Cancel or a tap
## outside just closes it.
class_name ConfirmDialog
extends Control

var message: String
var on_yes: Callable
var title := "Are you sure?"


## Shows the dialog over `on` (the app).
static func ask(on: Control, msg: String, yes: Callable) -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d.message = msg
	d.on_yes = yes
	d.size = on.size
	on.add_child(d)
	return d


## .sheetbox.parch: the parchment window (56px corners drawn 30px wide) with
## its title on a wooden banner over the top edge. Content starts at y 59.
static func window(sz: Vector2, title_text: String) -> Control:
	var box := Control.new()
	box.size = sz
	var parch: Texture2D = load("res://assets/ui/panel_parchment.webp")
	box.draw.connect(func():
		var sb := StyleBoxTexture.new()
		sb.texture = parch
		sb.set_texture_margin_all(56)
		var k := 30.0 / 56.0
		box.draw_set_transform(Vector2.ZERO, 0, Vector2(k, k))
		box.draw_style_box(sb, Rect2(Vector2.ZERO, box.size / k))
		box.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE))
	if title_text == "":  # no banner
		return box
	var tw := Tok.font(800).get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	var banner := Control.new()
	banner.size = Vector2(tw + 60, 13 + 6 + 28 + 7)
	banner.position = Vector2((sz.x - banner.size.x) / 2, 30 + 10 - 22 - 13)
	var wood: Texture2D = load("res://assets/ui/banner_wood.webp")
	banner.draw.connect(func():  # slices 64 / 96, drawn 13 / 24
		var sb := StyleBoxTexture.new()
		sb.texture = wood
		sb.texture_margin_top = 64
		sb.texture_margin_bottom = 64
		sb.texture_margin_left = 96
		sb.texture_margin_right = 96
		var k := 13.0 / 64.0
		banner.draw_set_transform(Vector2.ZERO, 0, Vector2(k, k))
		banner.draw_style_box(sb, Rect2(Vector2.ZERO, banner.size / k))
		banner.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE))
	var t := Tok.label(title_text, 21, Color("#fff7e0"), 800)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	t.add_theme_constant_override("shadow_offset_y", 2)
	t.size = banner.size
	banner.add_child(t)
	box.add_child(banner)
	return box


## The dark backdrop behind a window, filling `on`; a tap on it calls
## on_tap (none: it only blocks taps).
static func dim(on: Control, on_tap := Callable()) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(10 / 255.0, 14 / 255.0, 20 / 255.0, 0.72)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if on_tap.is_valid():
		d.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed: on_tap.call())
	on.add_child(d)
	return d


## A window's ✕, on its top-right corner.
static func close_x(box: Control, on_close: Callable) -> TextureRect:
	var x := TextureRect.new()
	x.texture = load("res://assets/ui/btn_close.webp")
	x.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	x.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	x.size = Vector2(38, 38)
	x.position = Vector2(box.size.x - 26, -12)
	x.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed: on_close.call())
	box.add_child(x)
	return x


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ConfirmDialog.dim(self, queue_free)
	var w := minf(420, size.x - 40)
	var inner := w - 2 * (30 + 8)
	var msg := Tok.label(message, 15, Color("#5e4026"), 400)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_constant_override("line_spacing", int(round(15 * 1.5 - Tok.font(400).get_height(15))))
	msg.size = Vector2(inner, 0)
	msg.custom_minimum_size = Vector2(inner, 0)
	# Wrapped height, from the font (a label only knows it once laid out); 1.5 line height.
	var lines := Tok.font(400).get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, inner, 15).y / Tok.font(400).get_height(15)
	var msg_h := roundf(lines) * 15 * 1.5
	msg.size = Vector2(inner, msg_h)
	var h := 30 + 10 + 33 + 12 + msg_h + 14 + 18 + 46 + 6 + 30
	var box := window(Vector2(w, h), title)
	box.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	add_child(box)
	msg.position = Vector2(38, 30 + 10 + 33 + 12 - 13)
	box.add_child(msg)
	# Yes (the green pill) and Cancel (parchment-sunken), 10px apart.
	var by := msg.position.y + msg_h + 14 + 18
	var yes := RollPopup._pill_button("Yes, do it", Vector2(Tok.font(800).get_string_size("Yes, do it", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44, 46))
	yes.position = Vector2(38, by)
	yes.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed:
		queue_free()
		on_yes.call())
	box.add_child(yes)
	var no := Tok.parch_button("Cancel", Vector2(Tok.font(800).get_string_size("Cancel", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44, 46))
	no.position = Vector2(yes.position.x + yes.size.x + 10, by)
	no.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: queue_free())
	box.add_child(no)
