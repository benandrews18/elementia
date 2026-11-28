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
## The side card (the user, 2026-11-22: the Inventory's list view, the
## station shop): the card alone, in place, scaled to its column (no dim,
## Close or buttons). What you hold shows: a missing element faded (with the
## convert badge when Convert could cover it; a tap opens Convert on it), a
## suit you hold none of faded too; an item component opens its own card.
var side := false
var plain := false  # a crafted card (the hand's): no fades, ⚛ or ticks on its parts (the user, 2026-11-23)
var pic_px := 0.0  # > 0: the picture this wide in the card's own units (the hand's full card: its fan card's size)


## The side card for name, scaled to width w (its top-left at 0, 0).
static func side_card(name: String, w: float, plain := false, pic := 0.0) -> CardPop:
	var p: CardPop = Tok.make(SCENE)
	p.side = true
	p.plain = plain
	p.size = Vector2(p.portrait.x, p.portrait.y)
	p.pic_px = pic * p.portrait.x / w  # on screen: pic px wide
	p.show_item(name)
	p.scale = Vector2.ONE * w / p.size.x
	Tok.floor_text(p, p.scale.x)
	return p


static func open(on: Control, name: String) -> CardPop:
	var p: CardPop = Tok.make(SCENE)
	p.size = on.size
	on.add_child(p)
	p.show_item(name)
	return p


func _ready() -> void:
	Explain.on_tap($Card/Station, func(): return "Made at " + str(entry.station))  # step 27
	if side:
		for n in [$Dim, $Close, $Actions]:
			n.visible = false
		mouse_filter = MOUSE_FILTER_IGNORE
		return
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for n in [$Dim, $Card, $Close]:
		n.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	$Actions/Pin.gui_input.connect(func(ev): if Tap.tap(ev):
		App.pin(entry.name)
		_show_pin())
	$Actions/Back.mouse_filter = MOUSE_FILTER_STOP
	$Actions/Back.gui_input.connect(func(ev): if Tap.tap(ev) and not _back.is_empty(): show_item(_back.pop_back().name, true))
	$Actions/Info.gui_input.connect(func(ev): if Tap.tap(ev) and App.current:  # its row on the Items screen
		var name: String = entry.name
		queue_free()
		App.current.open_items(name))
	$Actions/Back/Arrow.draw.connect(func():  # ←, drawn (not in Nunito)
		var a: Control = $Actions/Back/Arrow
		var y := a.size.y / 2
		a.draw_line(Vector2(4, y), Vector2(a.size.x - 2, y), Tok.INK, 3.5, true)
		a.draw_polyline(PackedVector2Array([Vector2(12, y - 8), Vector2(4, y), Vector2(12, y + 8)]), Tok.INK, 3.5, true))



## Shows an item's card; keep_back: drilling in or Back (the back stack stays).
## Opened from the tracked pill: the 🔍 button's circle and a green pill
## over the card, "You are tracking this item!" (.cp-celeb.cp-tracking).
func show_tracking() -> void:
	var card: Control = $Card
	var pill: Control = Tok.make("res://ui/pieces/tracked_pill.tscn")
	pill.get_node("Row/Icon").visible = false
	var nl: Label = pill.get_node("Row/Name")
	nl.text = "You are tracking this item!"
	nl.add_theme_font_override("font", Tok.font(900))
	nl.add_theme_font_size_override("font_size", 14)
	(pill.get_node("Row") as Control).offset_left = 24
	(pill.get_node("Row") as Control).offset_right = -16
	var tw := nl.get_theme_font("font").get_string_size(nl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	pill.size = Vector2(24 + tw + 16, 32)
	var glass := TextureRect.new()
	glass.texture = load("res://assets/ui/btn_search.webp")
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.size = Vector2(46, 46)
	var w := 46 - 16 + pill.size.x
	var x := card.position.x + (card.size.x - w) / 2
	var y := card.position.y - 10 - 46
	glass.position = Vector2(x, y)
	pill.position = Vector2(x + 30, y + 7)
	for n: Control in [pill, glass]:
		n.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(n)


## A capstone just crafted (celebrate(), .cp-celeb): a gold banner over the
## card, "Capstone complete!" with the trophy and how many of the eight.
func show_celebration(n: int, of: int) -> void:
	var card: Control = $Card
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color("#2a2018"), 16, 3, Tok.GOLD, 6, 3))
	b.size = Vector2(minf(card.size.x, 300), 62)
	b.position = Vector2(card.position.x + (card.size.x - b.size.x) / 2, card.position.y - 14 - b.size.y)
	b.mouse_filter = MOUSE_FILTER_IGNORE
	var t := Tok.label("Capstone complete!", 20, Color("#ffe08a"), 900)
	var tw := t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var cup := Tok.icon("🏆", 24)
	cup.position = Vector2((b.size.x - tw - 30) / 2, 8)
	b.add_child(cup)
	t.clip_text = true  # before its size (Tok.centre_name)
	t.position = Vector2(cup.position.x + 30, 6)
	t.size = Vector2(tw + 2, 28)
	b.add_child(t)
	var sub := Tok.label("That's all eight -- every capstone in Elementia!" if n == of else "%d of %d capstones" % [n, of], 13, Color(1, 1, 1, 0.8), 700)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.clip_text = true
	sub.position = Vector2(6, 36)
	sub.size = Vector2(b.size.x - 12, 20)
	b.add_child(sub)
	b.pivot_offset = b.size / 2
	b.scale = Vector2(0.7, 0.7)
	add_child(b)
	b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		if side and not plain and not Catalog.owns(Game.state, name) and not Game.suit_held(su):  # never on a card you own (the user, 2026-11-24)
			cb.modulate.a = 0.35  # none of this suit held
		cb.set_meta("cmp", "cp:cost%d" % $Card/Costs.get_child_count())
		$Card/Costs.add_child(cb)
	$Card/Station/Icon.texture = Data.icon(Catalog.station(entry.station).emoji)
	for c in card.get_children():
		if c.has_meta("extra_station"):
			c.free()
	if entry.tier == "MATERIAL":  # sold at several: every station, right to left along the bottom (the user, 2026-11-26)
		var mc = Catalog.mat_card(name)
		var others: Array = (mc.stations if mc else []).filter(func(st): return st != entry.station)
		for i in others.size():
			var b: Control = $Card/Station.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)  # not its tap
			b.set_meta("extra_station", true)
			b.set_meta("cmp", "cp:station:" + others[i])
			b.position.x -= (i + 1) * ($Card/Station.size.x - 6)
			b.get_node("Icon").texture = Data.icon(Catalog.station(others[i]).emoji)
			var stn: String = others[i]
			Explain.on_tap(b, func(): return "Made at " + stn)
			card.add_child(b)
	var old_size := card.get_node_or_null("Size")
	if old_size:
		old_size.free()
	# The middle: art, name, divider, "Components:", the parts, the rule.
	var pad_top := 30.0 if cap else 36.0  # the 16px frame + 14 / 20px padding
	var bottom := card.size.y - (50.0 if cap else 32.0)  # a capstone's content clears the size badge's corner
	var inner_x := 36.0
	var inner_w := card.size.x - 72
	var name_l: Label = $Card/Name
	name_l.text = name
	var nf := name_l.get_theme_font("font")
	var npx := name_l.get_theme_font_size("font_size")
	var name_w := inner_w - (72.0 if cap else 0.0)  # a capstone's clear of its right-hand circles
	npx = Tok.fit_px(name, nf, npx, name_w)  # one line always (the user, 2026-11-23): smaller type for a long name
	name_l.add_theme_font_size_override("font_size", npx)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var name_h := npx * 1.15
	var parts_w := inner_w - (32.0 if cap else 0.0)  # a capstone's clear of the suit-cost column
	var parts_h := _parts(parts_w, cap)
	var sig: Label = $Card/Sig
	sig.visible = Data.t("CAPSTONE_SIGNATURES").has(name)  # Cruise Ship too (a tier 3 card with one)
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
	var k: float = ItemCard.BIG_ART.get(name, 1.0)
	var art_h := 0.0  # a BIG_ART picture's own height
	var icon_h := (bottom - pad_top) / 2  # portrait: the art gets the top half
	if cap:
		# The art takes what's left (at least 56px); the card grows past 7:5
		# when its parts don't fit (CSS aspect-ratio gives way to content).
		icon_px = minf(72, size.x * 0.16)
		var tex := Data.icon(entry.emoji)
		art_h = icon_px * k * tex.get_height() / tex.get_width() if k != 1.0 and tex else 0.0
		var rest := 2 + name_h + 6 + 1 + 6 + 14.8 + 5 + parts_h + (8 + sig_h if sig.visible else 0.0)
		card.size.y = maxf(card.size.y, pad_top + maxf(56, art_h) + rest + 50)
		bottom = card.size.y - 50
		icon_h = bottom - pad_top - rest
	elif Data.t("PDF_ENLARGED_ICONS").has(name):
		icon_px = 150.0
	if not cap and sig.visible:  # a portrait card with a rule (Cruise Ship): the art gives way, the rule clears the corner badges
		var rest_p := 6 + name_h + 10 + 1 + 10 + 14.8 + 9 + parts_h + 8 + sig_h
		icon_h = minf(icon_h, card.size.y - 50 - pad_top - rest_p)
		icon_px = minf(icon_px, icon_h - 6)
	if pic_px > 0 and not cap:
		icon_px = minf(icon_px, pic_px)
	var icon: TextureRect = $Card/Icon
	icon.texture = Data.icon(entry.emoji)
	var isz := Vector2(icon_px * k, art_h if art_h > 0 else icon_px * k)
	if k != 1.0 and art_h == 0 and icon.texture:  # portrait card: as tall as the art, within its half
		isz.y = minf(icon_h, isz.x * icon.texture.get_height() / icon.texture.get_width())
	icon.size = isz
	icon.material = Tok.outline(isz.x / 2)  # a bold dark edge, like the icon sheet's art (the user, 2026-11-28: the telescope's)
	icon.position = Vector2((card.size.x - isz.x) / 2, pad_top + (icon_h - isz.y) / 2 + (0.0 if cap else 3.0))
	var y := pad_top + icon_h + (2.0 if cap else 6.0)
	name_l.size = Vector2(name_w, 0)  # grows to its text: centred on the CSS line boxes
	name_l.position = Vector2(inner_x + (36.0 if cap else 0.0), y + (name_h - name_l.size.y) / 2)
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
	# The size badge: the bottom-left corner circle (the station's is
	# bottom-right, the points top-left).
	var sb := SizeBadge.make(name, 60, 4)
	sb.name = "Size"
	sb.position = Vector2(0, card.size.y - 60)
	card.add_child(sb)
	# Centred in the screen above the hub; the buttons 12px under the card.
	var total := card.size.y + 12 + 34.9
	card.position = Vector2((size.x - card.size.x) / 2, maxf(20, (size.y - HubBar.H - total) / 2))
	if side:
		card.position = Vector2.ZERO
		size = card.size
		return
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
	SuitSpend.on_tap(b, su)  # the suit and its elements (the user, 2026-11-26)
	var g := Tok.icon("suit:" + su, 36)
	g.position = Vector2(12, 12)
	g.material = Tok.white()
	b.add_child(g)
	return b


## The components (elements first, then items by points; "+" between), in
## one row (the user, 2026-11-22): every card at FIT of full size when its
## row fits (most do), else shrunk to fit; Planet's 16 elements wrap,
## smaller, with no "+". Returns their height. Each opens its own card.
const FIT := 0.91  # the shared size; a recipe too long for one row at it takes two (Car, Fruit Cake, Cruise Ship)
const SIDE_FIT := 1.4  # the side card is drawn small: its parts bigger, as many as fit one row
var last_scale := 1.0  # the row's scale on the card shown (tests)


func _parts(w: float, _cap: bool) -> float:
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
	var lots := toks.size() >= 10  # Planet: small chips, no "+"
	var k := FIT if lots or not side else SIDE_FIT
	var wraps := lots or _row(toks, k, false, null, 0.0) > w  # too long: a second row, never smaller (the user, 2026-11-26: Car, Cruise Ship)
	last_scale = k
	return _row(toks, k, lots, holder, w, wraps)


## Lays the parts out at scale k into holder (or only measures: holder
## null); one row, or wrapping at w when lots. Returns the width measured,
## or the height laid out.
func _row(toks: Array, k: float, lots: bool, holder: Control, w: float, wraps := false) -> float:
	var gap := 4.0 if lots else part_gap * k
	var icon_px := 32.0 * k
	var row_h := icon_px
	var x := 0.0
	var y := 0.0
	for i in toks.size():
		var r: Dictionary = toks[i]
		var parts: Array[Control] = []
		if i > 0 and not lots:
			var plus := Tok.label("+", 14 * k, Color("#5a5548"), 700)
			plus.size = Vector2(9.9 * k, row_h)
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			parts.append(plus)
		parts.append(_element(r.name, lots, k) if r.kind == "element" else _item(r.name, icon_px))
		parts.back().set_meta("cmp", "cp:ing%d" % i)
		var group_w := 0.0
		for c in parts:
			group_w += c.size.x + gap
		if wraps and x > 0 and x + group_w - gap > w:  # the next part on a new row; its "+" stays behind
			x = 0
			y += row_h + gap
			if parts.size() > 1:
				parts[0].free()
				parts.remove_at(0)
		for c in parts:
			var cw := c.size.x
			if holder:
				c.position = Vector2(x, y + (row_h - c.size.y) / 2)
				holder.add_child(c)
			else:
				c.free()
			x += cw + gap
	if holder == null:
		return x - gap
	holder.size = Vector2(w, y + row_h)
	return y + row_h


## An element: its symbol on a white chip with a black edge; opens its card.
func _element(sym: String, small: bool, k := 1.0) -> Control:
	var px := 12.0 if small else 14.0 * k
	var l := Tok.label(sym, px, Color("#181614"), 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", Tok.box(Color.WHITE, 8, 2, Color.BLACK))
	var tw := l.get_theme_font("font").get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(px))).x
	l.size = Vector2(tw + (10.0 if small else 18.0 * k) + 4, px + (6.0 if small else 10.0 * k) + 4)
	l.mouse_filter = MOUSE_FILTER_STOP
	if side and plain:
		l.mouse_filter = MOUSE_FILTER_IGNORE  # the hand's card: its parts take no taps (the user, 2026-11-24)
		return l
	if side:
		var need := 0
		for r in entry.reqs:
			if r.kind == "element" and r.name == sym:
				need += 1
		if Catalog.count(Game.state, sym) < need:
			l.modulate.a = 0.4
			if Game.state.elements.values().any(func(v): return int(v) >= int(Data.t("CONVERT_RATE"))):
				var cv := TextureRect.new()  # Convert could cover it
				cv.texture = load("res://assets/ui/btn_quark.webp")
				cv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				cv.size = Vector2(18, 18) * k
				cv.position = Vector2(l.size.x - 10 * k, -10 * k)
				cv.modulate.a = 2.5  # undo the chip's fade
				l.add_child(cv)
		l.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.open_convert(sym, entry.name))
		return l
	l.gui_input.connect(func(ev): if Tap.tap(ev):
		var on := get_parent()
		queue_free()
		ElementCard.open(on, sym))
	return l


## An item: its icon (a tick when owned); opens its card here (Back returns).
func _item(name: String, px: float) -> Control:
	var c := Control.new()
	c.size = Vector2(px, px)
	c.add_child(Tok.icon(Data.t("ITEM_EMOJI").get(name, ""), px))
	if Catalog.owns(Game.state, name) and not plain:  # .tok-check
		var t := Tok.tick(Color.WHITE, 17 * px / 32, Tok.OK, Tok.CARD)
		t.position = Vector2(px - 11 * px / 32, -4 * px / 32)
		c.add_child(t)
	if plain:
		c.mouse_filter = MOUSE_FILTER_IGNORE  # the hand's card: its parts don't open their own cards (the user, 2026-11-24)
	elif Catalog.entry(name) != null and side:
		c.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.show_card(name))
	elif Catalog.entry(name) != null:
		c.gui_input.connect(func(ev): if Tap.tap(ev):
			_back.append(entry)
			show_item(name, true))
	return c
