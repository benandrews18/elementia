## Convert (convert.js, #convert): a tray over the station, above the hub
## (Home reads Close). Every element held, 8 to a row (a tap on one with 3+
## makes it FROM); the FROM stack, the arrow (3:1) and the TO box (a tap on
## either opens the picker); Unknown Elements held, top right (a tap opens
## the "?" picker: any element of this station). The arrow converts; the
## result flies to the Inventory button.
class_name ConvertTray
extends Control

## The layout is ui/overlays/convert_tray.tscn (the tray, its title, the
## arrow's two looks, "3:1"); this lays out the elements held.
const SCENE := "res://ui/overlays/convert_tray.tscn"
const TOP_PAD := 14.0
const NAVY := Color("#1b3446")

@export var arrow_on: StyleBox  # FROM and TO are set: tap to convert
@export var arrow_off: StyleBox

var from := ""
var to := ""
var _to_box: Control
var _ready_now := false


static func make() -> ConvertTray:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Scrim.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.close_panel())
	$Tray/Arrow.gui_input.connect(func(ev): if Tap.tap(ev) and _ready_now: do_convert())
	Game.state_changed.connect(_redraw)
	_redraw()


func _redraw() -> void:
	var tray: Control = $Tray
	var content: Control = $Tray/Content
	for c in content.get_children():
		c.queue_free()
	for c in $Tray/Arrow.get_children():
		c.queue_free()
	var w := size.x
	var held: Array = Game.state.elements.keys().filter(func(k): return Game.state.elements[k] > 0)
	var an: Dictionary = Data.t("ATOMIC_NUMBER")
	held = Util.stable_sort(held, func(a, b): return an.get(a, 999) - an.get(b, 999))
	var cell := (w - 32 - 7 * 6) / 8
	var rows := ceili(held.size() / 8.0)
	var grid_h := rows * (cell + 16) + maxf(0, rows - 1) * 6
	var big := minf(110.0, (w - 32 - 72 - 40) / 2)
	var grid_y := TOP_PAD + 26 + 30 + 10  # under the title and the "?" counter
	var h := grid_y + grid_h + 26 + big + 30 + 20
	tray.position = Vector2(0, size.y - HubBar.H - h)
	tray.size = Vector2(w, h + HubBar.H)
	content.add_child(_unknown_badge(Vector2(w - 16 - 54, TOP_PAD + 26)))
	# The quick grid: a tap on an element with 3+ sets FROM.
	var y := grid_y
	for i in held.size():
		var sym: String = held[i]
		var ok := Catalog.count(Game.state, sym) >= int(Data.t("CONVERT_RATE"))
		var b := box(sym, cell, "%d" % int(Game.state.elements[sym]), 1.0 if ok else 0.45)
		b.position = Vector2(16 + (i % 8) * (cell + 6), y + (i / 8) * (cell + 16 + 6))
		if ok:
			b.gui_input.connect(func(ev): if Tap.tap(ev):
				from = sym
				_redraw())
		content.add_child(b)
	y += grid_h + 26
	# FROM (with two cards stacked behind it), the arrow, TO.
	var fx := (w - (big * 2 + 72 + 40)) / 2
	var from_box := _big_box(from, big)
	if from != "":
		for k in [2, 1]:
			var ghost := _big_box(from, big)
			ghost.position = Vector2(fx - k * 8, y + k * 8)
			ghost.mouse_filter = MOUSE_FILTER_IGNORE
			content.add_child(ghost)
	from_box.position = Vector2(fx, y)
	from_box.gui_input.connect(func(ev): if Tap.tap(ev): _pick("from"))
	content.add_child(from_box)
	_ready_now = from != "" and to != "" and from != to and Catalog.count(Game.state, from) >= int(Data.t("CONVERT_RATE"))
	var arrow: Panel = $Tray/Arrow
	arrow.add_theme_stylebox_override("panel", arrow_on if _ready_now else arrow_off)
	arrow.position = Vector2(fx + big + 20 + 10, y + big / 2 - 34)
	var ar := _arrow_glyph(Color.WHITE if _ready_now else Color(1, 1, 1, 0.35))
	ar.position = Vector2(14, 14)
	arrow.add_child(ar)
	$Tray/Rate.position = Vector2(arrow.position.x - 10, arrow.position.y + 60)
	var to_box := _big_box(to, big)
	to_box.position = Vector2(fx + big + 72 + 40 - 0, y)
	to_box.gui_input.connect(func(ev): if Tap.tap(ev): _pick("to"))
	content.add_child(to_box)
	_to_box = to_box



## An element box with a caption under it (the count, "×n"); faded = alpha.
static func box(sym: String, w: float, caption: String, alpha := 1.0) -> Control:
	var c := StationScreen.element_chip(sym, w)
	c.mouse_filter = MOUSE_FILTER_STOP
	var nm: Label = c.get_child(c.get_child_count() - 1)
	nm.text = caption
	nm.add_theme_font_size_override("font_size", 11)
	nm.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	nm.add_theme_font_override("font", Tok.font(800))
	c.modulate.a = alpha
	return c


## .convert-box: a big white square with the symbol and name, its border in
## the element's colour; "Pick element" on a dashed outline when empty.
func _big_box(sym: String, sz: float) -> Control:
	var b := Panel.new()
	b.size = Vector2(sz, sz)
	b.mouse_filter = MOUSE_FILTER_STOP
	if sym == "":
		b.add_theme_stylebox_override("panel", Tok.box(Color(1, 1, 1, 0.04), 14))
		b.add_child(DisplayMatScreen._dashed(Rect2(Vector2.ZERO, b.size), 14))
		var l := Tok.label("Pick\nelement", 15, Color(1, 1, 1, 0.45), 800)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = b.size
		b.add_child(l)
		return b
	b.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 14, 8, Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6")), 6, 3, Color(0, 0, 0, 0.35)))
	var s := Tok.label(sym, 28, Color("#221f1a"), 900)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0, sz * 0.22)
	s.size = Vector2(sz, 34)
	b.add_child(s)
	var n := Tok.label(Data.t("ELEMENT_NAMES").get(sym, sym), 14, Color("#221f1a"), 800)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.position = Vector2(0, sz * 0.22 + 36)
	n.size = Vector2(sz, 20)
	b.add_child(n)
	return b


## "→", drawn (not in Nunito): a shaft and a head.
static func _arrow_glyph(color: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(24, 24)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_line(Vector2(3, 12), Vector2(19, 12), color, 3.5, true)
		c.draw_polyline(PackedVector2Array([Vector2(12, 4.5), Vector2(20, 12), Vector2(12, 19.5)]), color, 3.5, true))
	return c


## The "?" counter: the square and how many are held (faded at 0).
func _unknown_badge(at: Vector2) -> Control:
	var n := int(Util.get_or(Game.state, "emptyElements", 0))
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color(0, 0, 0, 0.3), 14, 1.5, Tok.GOLD if n > 0 else Color(1, 1, 1, 0.2)))
	b.size = Vector2(54, 30)
	b.position = at
	b.modulate.a = 1.0 if n > 0 else 0.5
	var sq := LockInReward.unknown_square(20)
	sq.position = Vector2(6, 5)
	sq.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(sq)
	var l := Tok.label(str(n), 14, Tok.GOLD if n > 0 else Color.WHITE, 900)
	l.position = Vector2(32, 4)
	b.add_child(l)
	if n > 0:
		b.gui_input.connect(func(ev): if Tap.tap(ev):
			var app := App.current
			app.close_panel()
			UnknownPick.open(app))
	return b


## The picker window for FROM (what's held, 3+ only) or TO (every element).
func _pick(side: String) -> void:
	var p := ElementPicker.make()
	p.side = side
	p.other = to if side == "from" else from
	p.on_pick = func(sym):
		if side == "from":
			from = sym
		else:
			to = sym
		_redraw()
	p.size = App.current.size
	App.current.add_child(p)


## Converts; the TO box flies into the Inventory button, then both reset.
func do_convert() -> void:
	var to_box := _to_box
	var target := App.current._hub.button_center("inv")
	var fly := _big_box(to, to_box.size.x)
	fly.global_position = to_box.global_position
	fly.pivot_offset = fly.size / 2
	App.current.add_child(fly)
	var d := target - (to_box.global_position + to_box.size / 2)
	var tw := fly.create_tween()
	tw.tween_property(fly, "position", fly.position + d, 0.37).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(fly, "scale", Vector2(0.55, 0.55), 0.37)
	tw.tween_property(fly, "scale", Vector2(0.15, 0.15), 0.15)
	tw.parallel().tween_property(fly, "modulate:a", 0.0, 0.15)
	tw.tween_callback(fly.queue_free)
	var f := from
	var t := to
	from = ""
	to = ""
	Game.convert_elements(f, t)
