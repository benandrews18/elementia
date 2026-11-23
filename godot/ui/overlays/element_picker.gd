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
var card_option := false  # a check with cards: "A card" first on the TO side (ConvertTray)


static func make() -> ElementPicker:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Dim.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
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
	if card_option:
		syms.insert(0, "card")
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
		var b: Control
		if sym == "card":
			b = _card_box(cell)
		else:
			b = ConvertTray.box(sym, cell, "×%d" % int(Catalog.count(Game.state, sym)), 1.0 if ok else 0.45)
			var cap: Label = b.get_child(b.get_child_count() - 1)
			cap.add_theme_color_override("font_color", Color("#3b2412"))
		b.position = Vector2((i % 4) * (cell + gap.x), (i / 4) * (cell + 22 + gap.y))
		if ok:
			b.gui_input.connect(func(ev): if Tap.tap(ev):
				queue_free()
				on_pick.call(sym))
		grid.add_child(b)
	$Window/None.visible = syms.is_empty()


## "A card": a gold-edged square with 🃏, captioned like the elements.
static func _card_box(cell: float) -> Control:
	var b := Panel.new()
	b.size = Vector2(cell, cell + 18)
	b.mouse_filter = MOUSE_FILTER_STOP
	var sq := Panel.new()
	sq.size = Vector2(cell, cell)
	sq.mouse_filter = MOUSE_FILTER_IGNORE
	sq.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 10, 3, Tok.GOLD))
	b.add_child(sq)
	var ic := Tok.icon("🃏", cell * 0.6)
	ic.position = Vector2(cell * 0.2, cell * 0.2)
	b.add_child(ic)
	var cap := Tok.label("A card", 11, Color("#3b2412"), 800)
	Tok.centre_name(cap, cell, cell + 2, 16)
	b.add_child(cap)
	b.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	return b
