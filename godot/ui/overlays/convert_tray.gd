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
## Opened from a card's missing element (the user, 2026-11-23): that card's
## Crafting Bench rides on top of the tray, Craft and all, until it's made.
var bench_item := ""
var _bench: Control
var _to_box: Control
var _ready_now := false


static func make() -> ConvertTray:
	return Tok.make(SCENE)


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
	var grid_y := TOP_PAD + 26 + 12  # under the title (the "?" counter sits on the corner)
	var h := grid_y + grid_h + 26 + big + 30 + 20
	tray.position = Vector2(0, size.y - HubBar.H - h)
	tray.size = Vector2(w, h + HubBar.H)
	_put_bench(tray.position.y, w)
	content.add_child(_unknown_badge(Vector2(w - 58, 0)))
	# The quick grid: a tap on an element with 3+ sets FROM.
	var y := grid_y
	for i in held.size():
		var sym: String = held[i]
		var ok := Catalog.count(Game.state, sym) >= int(Data.t("CONVERT_RATE"))
		var b := box(sym, cell, "%d" % int(Game.state.elements[sym]), 1.0 if ok else 0.45)
		b.position = Vector2(16 + (i % 8) * (cell + 6), y + (i / 8) * (cell + 16 + 6))
		if ok:
			b.set_meta("cmp", "cv:" + sym)
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
	arrow.set_meta("cmp", "cv:go")
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
	c.get_node("Num").visible = false  # no atomic numbers when converting (the user, 2026-11-21)
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
	var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
	b.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 14, 8, color, 6, 3, Color(0, 0, 0, 0.35)))
	var s := Tok.label(sym, 28, Color("#221f1a"), 900)
	Tok.centre_name(s, sz, sz * 0.22, 34)
	b.add_child(s)
	var n := Tok.label(Data.t("ELEMENT_NAMES").get(sym, sym), 14, Color("#221f1a"), 800)
	Tok.centre_name(n, sz, sz * 0.22 + 36, 20)
	b.add_child(n)
	# Its atomic number (top-left) and suit badge (top-right), as on the
	# station's squares (the user: the chosen ones show them).
	var num := Tok.label(str(int(Data.t("ATOMIC_NUMBER").get(sym, 0))), 14, color, 800)
	num.position = Vector2(14, 10)
	b.add_child(num)
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	if suit != "":
		var badge := Panel.new()
		badge.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(suit), 12, 0, Color.BLACK, 2, 1, Color(0, 0, 0, 0.45)))
		badge.size = Vector2(24, 24)
		badge.position = Vector2(sz - 24 - 10, 10)
		var g := Tok.icon("suit:" + suit, 16)
		g.position = Vector2(4, 4)
		g.material = Tok.white()
		badge.add_child(g)
		SuitSpend.on_tap(badge, suit)
		b.add_child(badge)
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


## The "?" counter (the user, 2026-11-26): the square in a gold ring on the
## tray's top-right corner, how many are held in a bubble on the ring's top
## right (faded at 0).
func _unknown_badge(at: Vector2) -> Control:
	var n := int(Util.get_or(Game.state, "emptyElements", 0))
	var b := Panel.new()
	# Tucked into the tray's top-right corner, its edge on the tray's curve (the user, 2026-11-26)
	var sb := Tok.box(Color("#122e3c"), 0, 0, Tok.GOLD)
	sb.border_width_left = 2
	sb.border_width_bottom = 2
	sb.border_width_top = 3
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 16
	b.add_theme_stylebox_override("panel", sb)
	b.size = Vector2(58, 50)
	b.position = at
	b.set_meta("cmp", "cv:unknown")
	var sq := LockInReward.unknown_square(26)
	sq.position = Vector2(12, 13)
	sq.mouse_filter = MOUSE_FILTER_IGNORE
	sq.modulate.a = 1.0 if n > 0 else 0.6
	b.add_child(sq)
	b.add_child(StationScreen.count_bubble(n, Vector2(58 - 24, 4)))
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
	var target := App.current.hub.button_global_center("inv")
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
	tw.tween_callback(App.current.hub.punch.bind("inv"))
	var f := from
	var t := to
	from = ""
	to = ""
	Game.convert_elements(f, t)


## The card's Crafting Bench just above the tray (as at the shop: Craft,
## the pin); gone once the card is crafted.
func _put_bench(tray_y: float, w: float) -> void:
	if is_instance_valid(_bench):
		_bench.queue_free()
	var e = Catalog.entry(bench_item) if bench_item != "" else null
	if e == null or Catalog.owns(Game.state, bench_item):
		return
	var bench := BenchPanel.new()
	var bw := minf(w - 16, 420.0)
	bench.add_child(ShopRow.make(e, bw - 36, func(n, at: Rect2): if App.current: App.current.craft_tap(n, at), func(n): App.pin(n)))
	bench.size = Vector2(bw, 30 + ShopRow.H + 18)
	bench.position = Vector2((w - bw) / 2, tray_y - bench.size.y + 2)  # sitting on the tray (the "?" is inside its corner now)
	add_child(bench)
	_bench = bench
