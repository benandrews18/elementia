## Convert's element picker (renderConvertPicker(), #convertPicker): a
## parchment window, 4 to a row. FROM: what's held (under 3 faded, not
## tappable); TO: every element. Grouped by suit; never the other side's.
## The layout is ui/overlays/element_picker.tscn (its labels show the FROM
## texts; the TO texts are below); this fills in the grid and sizes it.
class_name ElementPicker
extends Control

const SCENE := "res://ui/overlays/element_picker.tscn"

@export var to_kicker := "CHOOSE AN ELEMENT"
@export var to_sub := "Pick what you'd like to convert into."
@export var to_none := "No other elements to pick."
## Gaps between the element boxes.
@export var gap := Vector2(14, 6)

var side := "from"
var other := ""
var on_pick: Callable


static func make() -> ElementPicker:
	return Tok.make(SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Dim.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	Tok.grow_hit($Window/Close, 12)
	$Window/Close.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	var is_from := side == "from"
	if not is_from:
		$Window/Kicker.text = to_kicker
		$Window/Sub.text = to_sub
		$Window/None.text = to_none
	var order: Array = Data.t("ELEMENT_SUIT").keys()
	var syms: Array = (Game.state.elements.keys().filter(func(s): return Game.state.elements[s] > 0) if is_from
		else Data.t("CLASSIC_ELEMENTS").duplicate()).filter(func(s): return s != other)
	syms = Util.stable_sort(syms, func(a, b): return order.find(a) - order.find(b))
	var grid: Control = $Window/Grid
	var w := minf(360, size.x - 60)
	var inner := w - 2 * grid.position.x
	var cell := (inner - 3 * gap.x) / 4
	var rows := ceili(syms.size() / 4.0)
	var h := grid.position.y + rows * (cell + 22) + maxf(0, rows - 1) * gap.y + 30
	var win: Control = $Window
	win.size = Vector2(w, h)
	win.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	for i in syms.size():
		var sym: String = syms[i]
		var ok := not is_from or Catalog.count(Game.state, sym) >= int(Data.t("CONVERT_RATE"))
		var b := ConvertTray.box(sym, cell, "×%d" % int(Catalog.count(Game.state, sym)), 1.0 if ok else 0.45)
		var cap: Label = b.get_child(b.get_child_count() - 1)
		cap.add_theme_color_override("font_color", Color("#3b2412"))
		b.position = Vector2((i % 4) * (cell + gap.x), (i / 4) * (cell + 22 + gap.y))
		if ok:
			b.gui_input.connect(func(ev): if Tap.tap(ev):
				queue_free()
				on_pick.call(sym))
		grid.add_child(b)
	$Window/None.visible = syms.is_empty()
