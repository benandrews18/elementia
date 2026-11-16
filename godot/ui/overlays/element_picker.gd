## Convert's element picker (renderConvertPicker(), #convertPicker): a
## parchment window, 4 to a row. FROM: what's held (under 3 faded, not
## tappable); TO: every element. Grouped by suit; never the other side's.
class_name ElementPicker
extends Control

var side := "from"
var other := ""
var on_pick: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(10 / 255.0, 14 / 255.0, 20 / 255.0, 0.72)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ConvertTray._tap(ev): queue_free())
	add_child(dim)
	var is_from := side == "from"
	var order: Array = Data.t("ELEMENT_SUIT").keys()
	var syms: Array = (Game.state.elements.keys().filter(func(s): return Game.state.elements[s] > 0) if is_from
		else Data.t("CLASSIC_ELEMENTS").duplicate()).filter(func(s): return s != other)
	syms = Util.stable_sort(syms, func(a, b): return order.find(a) - order.find(b))
	var w := minf(360, size.x - 60)
	var inner := w - 2 * 28
	var cell := (inner - 3 * 14) / 4
	var rows := ceili(syms.size() / 4.0)
	var gy := 30 + 18 + 22 + 14
	var h := gy + rows * (cell + 22) + maxf(0, rows - 1) * 6 + 30
	var box := ConfirmDialog.window(Vector2(w, h), "")
	box.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	add_child(box)
	var kick := Tok.label("INVENTORY" if is_from else "CHOOSE AN ELEMENT", 12, Color("#5e4026"), 900)
	kick.position = Vector2(28, 30)
	box.add_child(kick)
	var sub := Tok.label("Elements with 3 or more can be converted." if is_from else "Pick what you'd like to convert into.", 14, Color("#5e4026"), 400)
	sub.position = Vector2(28, 30 + 18)
	box.add_child(sub)
	for i in syms.size():
		var sym: String = syms[i]
		var ok := not is_from or Catalog.count(Game.state, sym) >= int(Data.t("CONVERT_RATE"))
		var b := ConvertTray.box(sym, cell, "×%d" % int(Catalog.count(Game.state, sym)), 1.0 if ok else 0.45)
		var cap: Label = b.get_child(b.get_child_count() - 1)
		cap.add_theme_color_override("font_color", Color("#3b2412"))
		b.position = Vector2(28 + (i % 4) * (cell + 14), gy + (i / 4) * (cell + 22 + 6))
		if ok:
			b.gui_input.connect(func(ev): if ConvertTray._tap(ev):
				queue_free()
				on_pick.call(sym))
		box.add_child(b)
	if syms.is_empty():
		var none := Tok.label("You don't have any elements yet." if is_from else "No other elements to pick.", 14, Color("#5e4026"), 600)
		none.position = Vector2(28, gy)
		box.add_child(none)
	var close := TextureRect.new()
	close.texture = load("res://assets/ui/btn_close.webp")
	close.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close.size = Vector2(38, 38)
	close.position = Vector2(w - 26, -12)
	close.gui_input.connect(func(ev): if ConvertTray._tap(ev): queue_free())
	box.add_child(close)
