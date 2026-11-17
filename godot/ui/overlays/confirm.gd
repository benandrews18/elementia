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


## .sheetbox.parch: the parchment window with its title on a wooden banner
## (ui/pieces/parchment_window.tscn). Content starts at y 59.
static func window(sz: Vector2, title_text: String) -> Control:
	var box: ParchmentWindow = load("res://ui/pieces/parchment_window.tscn").instantiate()
	box.size = sz
	box.title = title_text
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


## A tray's backdrop: a lighter dim; a tap on it closes the open panel.
static func scrim(on: Control) -> ColorRect:
	var d := dim(on, func(): if App.current: App.current.close_panel())
	d.color = Color(0, 0, 0, 0.35)
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
