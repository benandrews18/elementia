## The opening's pinning tip (#pinTip), over the To-Do List: a parchment
## window, Got it, and "✕ Hide" (never again).
## shortcut: the HTML tip also says "Track down a single item with 🔍" and
## hints at tracking; Godot has no tracked item yet, so it says pinning.
class_name PinTip
extends Control

var on_done: Callable


static func open(on: Control, done: Callable) -> PinTip:
	var t := PinTip.new()
	t.on_done = done
	t.size = on.size
	on.add_child(t)
	return t


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ConfirmDialog.dim(self).color.a = 0.3
	var w := minf(420, size.x - 40)
	var inner := w - 76
	var h := 59 + 26 + 10 + 2 * 15 * 1.5 + 18 + 46 + 30
	var box := ConfirmDialog.window(Vector2(w, h), "Pinned Items & To-Do List")
	box.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	add_child(box)
	var l1 := Tok.label("Pin items you want to find", 15, Color("#5e4026"), 400)
	var tw := Tok.font(400).get_string_size(l1.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	l1.position = Vector2((w - tw - 24) / 2, 59)
	box.add_child(l1)
	var pin := Tok.icon("📌", 18)
	pin.position = Vector2(l1.position.x + tw + 6, 61)
	box.add_child(pin)
	var hint := RichTextLabel.new()
	hint.bbcode_enabled = true
	hint.fit_content = true
	hint.scroll_active = false
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("normal_font", Tok.font(400))
	hint.add_theme_font_override("bold_font", Tok.font(800))
	hint.add_theme_font_size_override("normal_font_size", 15)
	hint.add_theme_font_size_override("bold_font_size", 15)
	hint.add_theme_color_override("default_color", Color("#5e4026"))
	hint.text = "[center][b]HINT:[/b] Try pinning smaller components of larger items[/center]"
	hint.position = Vector2(38, 59 + 26 + 10)
	hint.size = Vector2(inner, 0)
	box.add_child(hint)
	var ok := RollPopup._pill_button("Got it", Vector2(Tok.font(800).get_string_size("Got it", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44, 46))
	ok.position = Vector2((w - ok.size.x) / 2, h - 30 - 46)
	ok.gui_input.connect(func(ev): if ConvertTray._tap(ev): _done())
	box.add_child(ok)
	var hide := Tok.parch_button("✕  Hide", Vector2(66, 28), 12)
	hide.position = Vector2(10, h - 30)
	hide.gui_input.connect(func(ev): if ConvertTray._tap(ev):
		Progress.hide_tip("pinTip")
		_done())
	box.add_child(hide)


func _done() -> void:
	queue_free()
	on_done.call()
