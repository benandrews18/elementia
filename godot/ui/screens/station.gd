## A station (renderStation(), station.css): the station's art behind
## everything; the dark header (icon, name, its six elements, the crafted
## items folded into a bar); then the shop as cards with a pin and a Craft
## button under each. The page scrolls under the Quark bar.
class_name StationScreen
extends Control

const TOP := QuarkTopBar.H
const GAP := 8.0
const ACT_H := 35.0

var _scroll: ScrollContainer
var _press_at := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
	_redraw()


func _redraw() -> void:
	var keep := 0
	if is_instance_valid(_scroll):
		keep = _scroll.scroll_vertical
	for c in get_children():
		c.queue_free()
	var name: String = Game.ctx.current
	var st := Catalog.station(name)
	var w := size.x
	var bg := ColorRect.new()
	bg.color = Tok.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	# The station's art, full width from the top, fixed behind the page.
	var art := TextureRect.new()
	art.texture = load("res://assets/" + Data.t("STATION_BG")[name])
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = Vector2(w, w * art.texture.get_height() / art.texture.get_width())
	art.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(art)
	var wash := ColorRect.new()  # --backdrop-wash over the art
	wash.color = Color(18 / 255.0, 23 / 255.0, 31 / 255.0, 0.42)
	wash.size = art.size
	wash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(wash)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = Vector2(0, TOP)
	_scroll.size = Vector2(w, size.y - TOP)
	add_child(_scroll)
	var page := Control.new()
	page.mouse_filter = MOUSE_FILTER_PASS
	_scroll.add_child(page)
	var y := _header(page, st, w)
	y = _shop(page, name, w, y)
	page.custom_minimum_size = Vector2(w, y + HubBar.H + 80)
	_scroll.set_deferred("scroll_vertical", keep)
	if Game.state.get("matChecked"):
		var qt := QuarkTopBar.new()
		qt.size = Vector2(w, TOP)
		add_child(qt)
	_corner_buttons(w)


## The dark header: icon and name, the element chips, the crafted-items bar.
## Returns where the shop starts (page coordinates).
func _header(page: Control, st: Dictionary, w: float) -> float:
	var head := Panel.new()
	head.add_theme_stylebox_override("panel", _vgrad_box(Color("#193b4c"), Color("#122e3c")))
	head.size = Vector2(w, 243.8)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	head.set_meta("cmp", "st:head")
	page.add_child(head)
	var ic := Tok.icon(st.emoji, 44)
	ic.position = Vector2(16, 16.6)
	page.add_child(ic)
	var title := Tok.label(st.name, 31, Color.WHITE, 800)
	title.position = Vector2(76, 16.4)
	title.set_meta("cmp", "st:title")
	page.add_child(title)
	page.add_child(_caps_label("ELEMENTS FOUND HERE:", Vector2(26, 70.6)))
	# Six chips in a row, centred, 4px apart (.gather / .gchip).
	var dice := Catalog.sorted_dice(st)
	var cw := (w - 44 - 4 * (dice.size() - 1)) / dice.size()
	for i in dice.size():
		var chip := _element_chip(dice[i], cw)
		chip.position = Vector2(22 + i * (cw + 4), 98.8)
		chip.get_child(0).set_meta("cmp", "st:chip%d" % i)
		page.add_child(chip)
	page.add_child(_caps_label("CRAFTED ITEMS:", Vector2(16, 176.9)))
	# The fold button, the crafted icons bar, the list/cards switch.
	var row_y := 197.1
	page.add_child(_round_btn(Vector2(12, row_y + 2.3), true))
	var bar := Panel.new()
	var sb := Tok.box(Color(1, 1, 1, 0.08), 12, 1.5, Color(1, 1, 1, 0.18))
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(48, row_y)
	bar.size = Vector2(w - 48 - 48, 34.7)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	page.add_child(bar)
	if Game.state.get("collapseCraftedItems"):
		var x := 57.0
		for e in _sorted(_shop_entries(st.name)):
			if Catalog.owns(Game.state, e.name) and e.tier != "CAPSTONE":
				var i2 := Tok.icon(e.emoji, 18)
				i2.position = Vector2(x + 3, row_y + 8.3)
				page.add_child(i2)
				var t := Tok.tick(Color.WHITE, 14, Tok.OK, Tok.CARD)  # .station-item-icon.owned::after
				t.position = Vector2(x + 24 - 9, row_y + 5 - 5)
				page.add_child(t)
				x += 29
	var view := _round_btn(Vector2(w - 42, row_y + 2.3), false)
	page.add_child(view)
	return 243.8


## sortShopItems(): the fundamentals first (FUNDAMENTAL_ITEMS order), then by points.
static func _sorted(entries: Array) -> Array:
	var fund: Array = Data.t("FUNDAMENTAL_ITEMS")
	var rank := func(n): return fund.find(n) if fund.has(n) else 999
	var pts: Dictionary = Data.t("ITEM_POINTS")
	return Util.stable_sort(entries, func(a, b): return rank.call(a.name) - rank.call(b.name) if rank.call(a.name) != rank.call(b.name) else pts.get(a.name, 0) - pts.get(b.name, 0))


## Station shop: open items here (entriesAt()), in data order.
static func _shop_entries(station: String) -> Array:
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	return Data.t("ENTRIES").filter(func(e): return e.station == station \
		and (not unlocked.has(e.name) or Catalog.owns(Game.state, unlocked[e.name])))


## shopCardsHTML(): tier 1 (half height) in rows of 4, then the rest, a
## capstone 2 wide (dense: later cards fill the gaps it leaves). Folded
## crafted items leave the grid.
func _shop(page: Control, station: String, w: float, y: float) -> float:
	var s := Game.state
	y += 18
	var label := _caps_label("ITEM SHOP – TAP TO CRAFT", Vector2(6, y), 13, 1.0)
	label.size = Vector2(w - 12, 17)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(label)
	var line := ColorRect.new()
	line.color = Tok.LINE2
	line.position = Vector2(6, y + 23.5)
	line.size = Vector2(w - 12, 2)
	page.add_child(line)
	y += 25.5 + 10
	var fold: bool = s.get("collapseCraftedItems", false)
	var shown := _shop_entries(station).filter(func(e): return not (fold and Catalog.owns(s, e.name) and e.tier != "CAPSTONE"))
	var col_w := (w - 12 - 3 * GAP) / 4
	var row_h := col_w * 1.4
	var groups := [shown.filter(func(e): return e.tier == "MATERIAL"),
		shown.filter(func(e): return e.tier == "COMPONENT") + shown.filter(func(e): return e.tier == "CREATION") + shown.filter(func(e): return e.tier == "CAPSTONE")]
	for gi in 2:
		var items: Array = groups[gi]
		if items.is_empty():
			continue
		var card_h := (row_h - 2) / 2 if gi == 0 else row_h
		var cell_h := card_h + 3 + ACT_H
		var taken := {}  # "row,col" -> true (dense packing)
		var rows := 0
		for e in items:
			var span := 2 if e.tier == "CAPSTONE" else 1
			var at := _first_free(taken, span)
			for k in span:
				taken["%d,%d" % [at.x, at.y + k]] = true
			rows = maxi(rows, at.x + 1)
			var pos := Vector2(6 + at.y * (col_w + GAP), y + at.x * (cell_h + GAP))
			_cell(page, e, pos, Vector2(col_w * span + GAP * (span - 1), card_h), gi == 0)
		y += rows * cell_h + (rows - 1) * GAP + 12
	return y


static func _first_free(taken: Dictionary, span: int) -> Vector2i:
	var r := 0
	while true:
		for c in range(0, 5 - span):
			var ok := true
			for k in span:
				if taken.has("%d,%d" % [r, c + k]):
					ok = false
			if ok:
				return Vector2i(r, c)
		r += 1
	return Vector2i.ZERO


## One shop cell: the card (green ring if craftable now, dimmed with a tick
## if owned), then the pin and the Craft button.
func _cell(page: Control, e: Dictionary, pos: Vector2, card_size: Vector2, t1: bool) -> void:
	var s := Game.state
	var owned := Catalog.owns(s, e.name)
	var can := not owned and Catalog.can_craft(s, e) and Game.suit_cost_payable(e.name)
	if can:  # .st-can: 3px green outline, 1px out
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 15 if not t1 else 13, 3, Tok.OK))
		ring.position = pos - Vector2(4, 4)
		ring.size = card_size + Vector2(8, 8)
		ring.mouse_filter = MOUSE_FILTER_IGNORE
		page.add_child(ring)
	var card := ItemCard.make(e.name, {"mini": t1, "wide": e.tier == "CAPSTONE", "tag": "st:" + e.name})
	card.position = pos
	card.size = card_size
	if owned:
		card.modulate = Color(0.7, 0.7, 0.7)
	page.add_child(card)
	if owned:  # .st-owned::after: a green tick, bottom right
		var tick := Tok.tick(Color.WHITE, 20, Tok.OK)
		tick.position = pos + card_size - Vector2(15, 15)
		page.add_child(tick)
	var ay := pos.y + card_size.y + 3
	# Pin and Craft (60px, shrinking to fit) centred under the card (.st-acts).
	var acts_w := minf(card_size.x, ACT_H + 3 + 60)
	var ax := pos.x + (card_size.x - acts_w) / 2
	var pinned := Progress.is_pinned(e.name)
	var pin := Panel.new()
	pin.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD_SOFT if pinned else Tok.CARD, 10, 2,
		Tok.GOLD if pinned else Color(1, 1, 1, 0.4), 0, 0))
	pin.position = Vector2(ax, ay)
	pin.size = Vector2(ACT_H, ACT_H)
	pin.modulate.a = 1.0 if pinned else 0.5
	var pic := Tok.icon("📌", 17)
	pic.position = Vector2(9, 9)
	pin.add_child(pic)
	pin.mouse_filter = MOUSE_FILTER_PASS  # taps here, drags still scroll the page
	pin.gui_input.connect(_on_tap.bind(func(): Progress.toggle_pin(e.name); Game.state_changed.emit()))
	pin.set_meta("cmp", "st:pin:" + e.name)
	page.add_child(pin)
	var btn := Label.new()
	btn.text = "    Owned" if owned else "Craft"  # the tick is drawn in front (not in Nunito)
	btn.add_theme_font_override("font", Tok.font(800))
	btn.add_theme_font_size_override("font_size", 13)
	btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.position = Vector2(ax + ACT_H + 3, ay)
	btn.size = Vector2(acts_w - ACT_H - 3, 34.9)
	if can:
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_shadow_color", Color(0.47, 0.24, 0, 0.4))
		btn.add_theme_constant_override("shadow_offset_y", 1)
		# Gold-orange (the CSS gradient #ffce6b -> #f0a428, averaged) over a 3px lip.
		var go := Tok.box(Color("#f8ba4b"), 10)
		go.border_width_bottom = 3
		go.border_color = Color("#a05d12")
		go.expand_margin_bottom = 3
		btn.add_theme_stylebox_override("normal", go)
		btn.gui_input.connect(_on_tap.bind(func(): Game.craft(e.name, Game.suggest_suit_picks(e.name))))
	elif owned:
		btn.add_theme_color_override("font_color", Tok.OK)
		btn.add_theme_stylebox_override("normal", Tok.box(Color("#16301f"), 10))
		var tk := Tok.tick(Tok.OK, 13)
		tk.position = Vector2(4, 11)
		btn.add_child(tk)
	else:
		btn.add_theme_color_override("font_color", Tok.MUTE)
		btn.add_theme_stylebox_override("normal", Tok.box(Tok.SUNKEN, 10))
	btn.mouse_filter = MOUSE_FILTER_PASS
	btn.set_meta("cmp", "st:craft:" + e.name)
	page.add_child(btn)


## A white element chip with its suit-coloured border, atomic number, the
## suit badge in the corner and the name under it (.gchip, .gname).
func _element_chip(sym: String, w: float) -> Control:
	var col := Control.new()
	col.size = Vector2(w, w + 13.8)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
	var chip := Panel.new()
	chip.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 9, 5, color))
	chip.size = Vector2(w, w)
	chip.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(chip)
	var px := minf(32, 0.55 * w)
	var sym_l := Tok.label(sym, px, Color("#221f1a"), 800)
	sym_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sym_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sym_l.size = Vector2(w, w)
	col.add_child(sym_l)
	var num := Tok.label(str(int(Data.t("ATOMIC_NUMBER").get(sym, 0))), 9, color, 800)
	num.position = Vector2(9, 5)
	col.add_child(num)
	if suit != "":
		var b := Panel.new()
		b.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(suit), 6.5, 0, Color.BLACK, 2, 1, Color(0, 0, 0, 0.45)))
		b.position = Vector2(w - 14, 1)  # top/right -4px from inside the 5px border
		b.size = Vector2(13, 13)
		var g := Tok.icon("suit:" + suit, 9)
		g.position = Vector2(2, 2)
		g.material = Tok.white()
		b.add_child(g)
		col.add_child(b)
	var nm := Tok.label(Data.t("ELEMENT_NAMES").get(sym, sym), 8.5, Tok.INK2, 700)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(-8, w + 3)
	nm.size = Vector2(w + 16, 10)
	col.add_child(nm)
	return col


## The 30px round header buttons: the fold toggle (chevron) and the
## list/cards switch.
func _round_btn(at: Vector2, fold: bool) -> Control:
	var on: bool = fold and Game.state.get("collapseCraftedItems", false)
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color("#16301f") if on else Color(1, 1, 1, 0.1), 15 if fold else 8, 1.5,
		Color("#2c5c3c") if on else Color(1, 1, 1, 0.25)))
	b.position = at
	b.size = Vector2(30, 30)
	if fold:
		var c := Control.new()
		c.size = b.size
		c.mouse_filter = MOUSE_FILTER_IGNORE
		var col := Tok.OK if on else Color("#e6eef6")
		c.draw.connect(func():
			var pts := PackedVector2Array([Vector2(12, 10), Vector2(17, 15), Vector2(12, 20)]) if on \
				else PackedVector2Array([Vector2(10, 13), Vector2(15, 18), Vector2(20, 13)])
			c.draw_polyline(pts, col, 2, true))
		b.add_child(c)
		b.gui_input.connect(_on_tap.bind(func():
			Game.state.collapseCraftedItems = not Game.state.get("collapseCraftedItems", false)
			Game.state_changed.emit()))
	else:
		var ic := Tok.icon("📋", 15)  # list view: comes later (cards only for now)
		ic.position = Vector2(7.5, 7.5)
		b.add_child(ic)
	return b


func _caps_label(text: String, at: Vector2, px := 12.0, spacing := 1.5) -> Label:
	var l := Tok.label(text, px, Color.WHITE, 800)
	l.add_theme_font_override("font", Tok.font(800, int(round(spacing))))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.position = at
	return l


## Settings (top right) and Convert (bottom right, once revealed).
func _corner_buttons(w: float) -> void:
	var gear := TextureRect.new()
	gear.texture = load("res://assets/ui/btn_settings.webp")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear.position = Vector2(w - 14 - 46, (TOP if Game.state.get("matChecked") else 0.0) + 10)
	gear.size = Vector2(46, 46)
	gear.set_meta("cmp", "settings")
	add_child(gear)
	# Convert: on screen once any element is held (state.convertRevealed in
	# the HTML game's updateHub()), with how many 3:1 conversions are possible.
	var held: Array = Game.state.elements.values()
	if Game.state.get("convertRevealed") or held.any(func(v): return v > 0):
		var conv := TextureRect.new()
		conv.texture = load("res://assets/ui/btn_quark.webp")
		conv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		conv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		conv.position = Vector2(w - 16 - 58, size.y - HubBar.H - 14 - 58)
		conv.size = Vector2(58, 58)
		conv.set_meta("cmp", "convert")
		add_child(conv)
		var n := 0
		for v in held:
			n += int(v) / int(Data.t("CONVERT_RATE"))
		if n > 0:
			conv.add_child(HubBar._badge(str(n), Vector2(58 + 7 - 24, -7)))


static func _vgrad_box(top: Color, bottom: Color, radius := 0.0) -> StyleBoxTexture:
	var g := Gradient.new()
	g.colors = PackedColorArray([top, bottom])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	var sb := StyleBoxTexture.new()
	sb.texture = t
	return sb


## A tap (not a scroll) runs fn.
func _on_tap(ev: InputEvent, fn: Callable) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_at = ev.global_position
		elif ev.global_position.distance_to(_press_at) < 10:
			fn.call()
