## An item's card, big (showCardPop(), #cardPop): white face in a heavy
## black frame, the points top-left, its suit costs down the top-right, its
## station bottom-right, the art, the name, and its components (an item's
## icon, an element's symbol; a tick on what you own). A capstone is the same
## card in landscape, with its Display Mat rule. A tap on a component opens
## that card (Back returns); Item Info shows it on the Items screen; 📌 pins
## it; a tap anywhere else closes it.
## The layout is ui/overlays/card_pop.tscn; this fills it in and stacks the
## parts (the CSS gaps are below).
class_name CardPop
extends Control

const SCENE := "res://ui/overlays/card_pop.tscn"

@export var pin_on: StyleBox
@export var pin_off: StyleBox
## The card: portrait (an item) and landscape (a capstone), at most this wide.
@export var portrait := Vector2(300, 420)
@export var landscape_max := 560.0
@export var part_gap := 6.0

var entry: Dictionary
var _back: Array = []  # the cards drilled in from (Back pops one)


static func open(on: Control, name: String) -> CardPop:
	var p: CardPop = load(SCENE).instantiate()
	p.size = on.size
	on.add_child(p)
	p.show_item(name)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for n in [$Dim, $Card, $Close]:
		n.gui_input.connect(func(ev): if _tap(ev): queue_free())
	$Actions/Pin.gui_input.connect(func(ev): if _tap(ev):
		Progress.toggle_pin(entry.name)
		Game._changed()
		_show_pin())
	$Actions/Back.mouse_filter = MOUSE_FILTER_STOP
	$Actions/Back.gui_input.connect(func(ev): if _tap(ev) and not _back.is_empty(): show_item(_back.pop_back().name, true))
	$Actions/Info.gui_input.connect(func(ev): if _tap(ev) and App.current:  # its row on the Items screen
		var name: String = entry.name
		queue_free()
		App.current.open_items(name))
	$Actions/Back/Arrow.draw.connect(func():  # ←, drawn (not in Nunito)
		var a: Control = $Actions/Back/Arrow
		var y := a.size.y / 2
		a.draw_line(Vector2(4, y), Vector2(a.size.x - 2, y), Tok.INK, 3.5, true)
		a.draw_polyline(PackedVector2Array([Vector2(12, y - 8), Vector2(4, y), Vector2(12, y + 8)]), Tok.INK, 3.5, true))


static func _tap(ev: InputEvent) -> bool:
	return ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed


## Shows an item's card; keep_back: drilling in or Back (the back stack stays).
func show_item(name: String, keep_back := false) -> void:
	if not keep_back:
		_back.clear()
	entry = Catalog.entry(name)
	var cap: bool = Data.t("ITEM_TIER").get(name, "") == "CAPSTONE"
	var card: Panel = $Card
	var w := minf(landscape_max, size.x - 40) if cap else portrait.x
	card.size = Vector2(w, w * 5 / 7) if cap else portrait
	# The corners: points, suit costs, the station it's made at.
	$Card/Pts/Num.text = str(int(entry.points))
	for c in $Card/Costs.get_children():
		c.queue_free()
	for su in Data.t("ITEM_SUIT_COST_TABLE").get(name, []):
		var cb := _cost_badge(su)
		cb.set_meta("cmp", "cp:cost%d" % $Card/Costs.get_child_count())
		$Card/Costs.add_child(cb)
	$Card/Station/Icon.texture = Data.icon(Catalog.station(entry.station).emoji)
	# The middle: art, name, divider, "Components:", the parts, the rule.
	var pad_top := 30.0 if cap else 36.0  # the 16px frame + 14 / 20px padding
	var bottom := card.size.y - (28.0 if cap else 32.0)
	var inner_x := 36.0
	var inner_w := card.size.x - 72
	var name_l: Label = $Card/Name
	name_l.text = name
	var nf := name_l.get_theme_font("font")
	var npx := name_l.get_theme_font_size("font_size")
	var name_w := inner_w - 2 * 72  # .pc-title padding: clear of the corner circles
	var name_h := roundf(nf.get_multiline_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, name_w, npx).y / nf.get_height(npx)) * npx * 1.15
	var parts_w := inner_w - (32.0 if cap else 0.0)  # a capstone's clear of the suit-cost column
	var parts_h := _parts(parts_w, cap)
	var sig: Label = $Card/Sig
	sig.visible = cap and Data.t("CAPSTONE_SIGNATURES").has(name)
	var sig_h := 0.0
	if sig.visible:
		sig.text = Data.t("CAPSTONE_SIGNATURES")[name]
		sig.size.x = parts_w
		var sf := sig.get_theme_font("font")
		var spx := sig.get_theme_font_size("font_size")
		var line := spx * 1.3  # CSS line-height 1.3 (Godot's own line is the font's height)
		sig.add_theme_constant_override("line_spacing", int(round(line - sf.get_height(spx))))
		sig_h = roundf(sf.get_multiline_string_size(sig.text, HORIZONTAL_ALIGNMENT_LEFT, parts_w - 16, spx).y / sf.get_height(spx)) * line + 12 + 3
	var icon_px := 100.0
	var icon_h := (bottom - pad_top) / 2  # portrait: the art gets the top half
	if cap:
		# The art takes what's left (at least 56px); the card grows past 7:5
		# when its parts don't fit (CSS aspect-ratio gives way to content).
		icon_px = minf(72, size.x * 0.16)
		var rest := 2 + name_h + 6 + 1 + 6 + 14.8 + 5 + parts_h + (8 + sig_h if sig.visible else 0.0)
		card.size.y = maxf(card.size.y, pad_top + 56 + rest + 28)
		bottom = card.size.y - 28
		icon_h = bottom - pad_top - rest
	elif Data.t("PDF_ENLARGED_ICONS").has(name):
		icon_px = 150.0
	var icon: TextureRect = $Card/Icon
	icon.texture = Data.icon(entry.emoji)
	icon.size = Vector2(icon_px, icon_px)
	icon.position = Vector2((card.size.x - icon_px) / 2, pad_top + (icon_h - icon_px) / 2 + (0.0 if cap else 3.0))
	var y := pad_top + icon_h + (2.0 if cap else 6.0)
	name_l.size = Vector2(name_w, 0)  # grows to its text: centred on the CSS line boxes
	name_l.position = Vector2(inner_x + 72, y + (name_h - name_l.size.y) / 2)
	y += name_h + (6.0 if cap else 10.0)
	$Card/Divider.position = Vector2(inner_x, y)
	$Card/Divider.size.x = inner_w
	y += 1 + (6.0 if cap else 10.0)
	var lab: Label = $Card/Components
	lab.position = Vector2(inner_x, y)
	lab.size.x = inner_w
	y += 14.8 + (5.0 if cap else 9.0)
	$Card/Parts.position = Vector2(inner_x, y)
	y += parts_h
	if sig.visible:
		sig.position = Vector2(inner_x, y + 8)
		sig.size = Vector2(parts_w, sig_h)
	# Centred in the screen above the hub; the buttons 12px under the card.
	var total := card.size.y + 12 + 34.9
	card.position = Vector2((size.x - card.size.x) / 2, maxf(20, (size.y - HubBar.H - total) / 2))
	var acts: Control = $Actions
	acts.position = Vector2(0, card.position.y + card.size.y + 12)
	acts.size.x = size.x
	_show_pin()
	$Actions/Back.visible = not _back.is_empty()
	if not _back.is_empty():
		var prev: Panel = $Actions/Back/Prev
		for c in prev.get_children():
			c.queue_free()
		prev.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 17, 2, Color.BLACK))
		var pi := Tok.icon(_back.back().emoji, 21)
		pi.position = Vector2(6.5, 6.5)
		prev.add_child(pi)


func _show_pin() -> void:
	var pinned := Progress.is_pinned(entry.name)
	var pin: Panel = $Actions/Pin
	pin.add_theme_stylebox_override("panel", pin_on if pinned else pin_off)
	pin.modulate.a = 1.0 if pinned else 0.5
	$Actions/Pin/Icon.material = null if pinned else Tok.grey()


## .pc-suitcost-badge: a 60px circle in the suit's colour, its glyph in white.
static func _cost_badge(su: String) -> Panel:
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(su), 30, 4, Color.BLACK, 3, 2, Color(0, 0, 0, 0.3)))
	b.custom_minimum_size = Vector2(60, 60)
	b.mouse_filter = MOUSE_FILTER_IGNORE
	var g := Tok.icon("suit:" + su, 36)
	g.position = Vector2(12, 12)
	g.material = Tok.white()
	b.add_child(g)
	return b


## The components in a wrapping row (elements first, then items by points;
## "+" between); returns their height. Each opens its own card.
func _parts(w: float, cap: bool) -> float:
	var holder: Control = $Card/Parts
	for c in holder.get_children():
		c.queue_free()
	var seen := {}
	var toks := []
	for r in entry.reqs:
		if not seen.has(r.kind + ":" + r.name):
			seen[r.kind + ":" + r.name] = true
			toks.append(r)
	var pts: Dictionary = Data.t("ITEM_POINTS")
	toks = toks.filter(func(r): return r.kind == "element") + Util.stable_sort(toks.filter(func(r): return r.kind != "element"),
		func(a, b): return pts.get(a.name, 0) - pts.get(b.name, 0))
	var many := toks.size() >= 6
	var lots := toks.size() >= 10  # Planet's 16 elements: smaller, no "+"
	var gap := 4.0 if lots or (cap and many) else part_gap
	var icon_px := 28.0 if cap and many else 32.0
	var row_h := icon_px
	var x := 0.0
	var y := 0.0
	for i in toks.size():
		var r: Dictionary = toks[i]
		var parts: Array[Control] = []
		if i > 0 and not lots:
			var plus := Tok.label("+", 14, Color("#5a5548"), 700)
			plus.size = Vector2(9.9, row_h)
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			parts.append(plus)
		parts.append(_element(r.name, lots) if r.kind == "element" else _item(r.name, icon_px))
		parts.back().set_meta("cmp", "cp:ing%d" % i)
		for c in parts:  # each wraps on its own (CSS flex-wrap): a "+" can end a row
			if x > 0 and x + c.size.x > w:
				x = 0
				y += row_h + gap
			c.position = Vector2(x, y + (row_h - c.size.y) / 2)
			holder.add_child(c)
			x += c.size.x + gap
	holder.size = Vector2(w, y + row_h)
	return y + row_h


## An element: its symbol on a white chip with a black edge; opens its card.
func _element(sym: String, small: bool) -> Control:
	var px := 12 if small else 14
	var l := Tok.label(sym, px, Color("#181614"), 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", Tok.box(Color.WHITE, 8, 2, Color.BLACK))
	var tw := l.get_theme_font("font").get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	l.size = Vector2(tw + (10.0 if small else 18.0) + 4, px + (6.0 if small else 10.0) + 4)
	l.mouse_filter = MOUSE_FILTER_STOP
	l.gui_input.connect(func(ev): if _tap(ev):
		var on := get_parent()
		queue_free()
		ElementCard.open(on, sym))
	return l


## An item: its icon (a tick when owned); opens its card here (Back returns).
func _item(name: String, px: float) -> Control:
	var c := Control.new()
	c.size = Vector2(px, px)
	c.add_child(Tok.icon(Data.t("ITEM_EMOJI").get(name, ""), px))
	if Catalog.owns(Game.state, name):  # .tok-check
		var t := Tok.tick(Color.WHITE, 17, Tok.OK, Tok.CARD)
		t.position = Vector2(px - 11, -4)
		c.add_child(t)
	if Catalog.entry(name) != null:
		c.gui_input.connect(func(ev): if _tap(ev):
			_back.append(entry)
			show_item(name, true))
	return c
