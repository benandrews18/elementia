## The Display Mat (renderMatTop(), display-mat.css): the score card (Quark
## Meter, combo chips) over the mat itself, a parchment page holding the
## cards in slots as the mat has grown. Redraws from Game.state on
## state_changed.
class_name DisplayMatScreen
extends Control

const SIDE := 6.0  # #drawerTop padding 10px 6px 0
const TOP := 12.0  # the drawer's 2px top edge + #drawerTop's 10px
const COLS_GAP := 5.0
const PAGE_PAD := 5.0  # .mat-zone-page padding + border (2px) are inside the 14px
const CHIP_GAP := 6.0  # .mat-combos gap (rows and columns)

var _body: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Tok.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_body)
	Game.state_changed.connect(_redraw)
	_redraw()


func _redraw() -> void:
	for c in _body.get_children():
		c.queue_free()
	var s := Game.state
	var cards := Mat.on_mat(s)
	var sc := Mat.score(cards, s, Game.ctx)
	var w := size.x - 2 * SIDE
	var y := TOP
	# Quark Meter line.
	var qm := QuarkMeter.new()
	qm.position = Vector2(SIDE, y)
	qm.size = Vector2(w, qm.custom_minimum_size.y)
	_body.add_child(qm)
	qm.show_score(sc.total, Orders.tiers(Orders.check_round(s)))
	y += qm.size.y + 4
	# Combo chips (min height 40, wrapping rows).
	y += _chips(sc, Vector2(SIDE, y), w) + 6
	# The mat page and its slots.
	var row_h := ((w - 14 - 3 * COLS_GAP) / 4) * 1.4
	var page := Panel.new()
	var sb := Tok.box(Color("#cda874"), 14, 2, Color("#a67c4a"))
	sb.corner_radius_bottom_left = 4
	page.add_theme_stylebox_override("panel", sb)
	page.position = Vector2(SIDE, y)
	page.size = Vector2(w, row_h * 2 + COLS_GAP + 14)
	page.set_meta("cmp", "mat:page")
	_body.add_child(page)
	_slots(cards, sc, page, row_h)


## The combo row: the challenge in force, capstone effects, station / suit /
## component groups, then the collections star. Returns its height.
func _chips(sc: Dictionary, at: Vector2, w: float) -> float:
	var chips := []
	var o = Orders.current(Game.state)
	if o != null:
		chips.append(_order_chip(o, sc))
	for g in sc.sigs:
		chips.append(_chip(_icon_circle(Data.t("ITEM_EMOJI")[g.name], Tok.PARCHMENT, Tok.GOLD, 2), g.label, 13, 0.45 if not g.on else 1.0))
	for g in sc.combos.station:
		chips.append(_counted(_icon_circle(Catalog.station(g.name).emoji, Tok.station_color(g.name), Color.TRANSPARENT, 0, true), g.k))
	for g in sc.combos.suit:
		chips.append(_counted(_icon_circle("suit:" + g.name, Tok.suit_color(g.name)), g.k))
	for g in sc.combos.component:
		var em = Data.t("ITEM_EMOJI").get(g.name)
		chips.append(_counted(_icon_circle(em if em else "", Tok.PARCHMENT, Color.TRANSPARENT, 0, true), g.k))
	var found: Array = Util.get_or(Progress.prefs, "everUnlockedMatCollections", [])
	var known: Array = sc.cols.filter(func(c): return found.has(c.id))
	if not known.is_empty():
		var star := _text_circle("★", 17, Color("#ffd166"), Color("#241c3a"), Color("#8a5ce0"), 1.5)
		chips.append(_counted(star, known.size(), Color("#8a5ce0"), Color.WHITE))
	if sc.cols.any(func(c): return not found.has(c.id)):
		chips.append(_chip(_text_circle("!", 18, Color.WHITE, Tok.BAD, Color.WHITE, 2), "", 0))
	# Wrap into rows (gap 8px between rows, 10px between chips).
	var x := 0.0
	var y := 0.0
	var row_h := 0.0
	for i in chips.size():
		var c: Control = chips[i]
		var sz := c.custom_minimum_size
		if x > 0 and x + sz.x > w:
			x = 0
			y += row_h + CHIP_GAP
			row_h = 0
		c.position = at + Vector2(x, y + 0)
		c.size = sz
		c.set_meta("cmp", "chip%d" % i)
		_body.add_child(c)
		x += sz.x + CHIP_GAP
		row_h = maxf(row_h, sz.y)
	# Chips in a row stretch to its tallest (flex align-items:stretch).
	var tallest := {}
	for c in chips:
		tallest[c.position.y] = maxf(tallest.get(c.position.y, 0.0), c.size.y)
	for c in chips:
		c.size.y = tallest[c.position.y]
	var h := y + row_h
	# align-items:center within the 40px minimum.
	if h < 40:
		for c in chips:
			c.position.y += (40 - h) / 2
	return maxf(40, h)


## .mm-combo: icon circle on top, an optional bold label under it, padding
## 6px 7px 2px 3px.
func _chip(circle: Control, label: String, size_px: float, alpha := 1.0, color := Tok.GOLD) -> Control:
	var c := Control.new()
	c.mouse_filter = MOUSE_FILTER_PASS
	circle.position = Vector2(3, 6)
	c.add_child(circle)
	var h := 6.0 + 27.0 + 2.0
	if label != "":
		var b := Tok.label(label, size_px, color, 900)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bh := size_px  # line-height 1
		b.position = Vector2(0, 6 + 27 + 1 + (bh - b.get_minimum_size().y) / 2)
		c.add_child(b)
		h += 1 + bh
		var bw := Tok.font(900).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size_px)).x
		c.custom_minimum_size = Vector2(maxf(37, bw + 10), h)
		b.size = Vector2(c.custom_minimum_size.x - 10, b.get_minimum_size().y)
		b.position.x = 3
		circle.position.x = 3 + (c.custom_minimum_size.x - 10 - 27) / 2
	else:
		c.custom_minimum_size = Vector2(37, h)
	c.modulate.a = alpha
	return c


## A chip whose icon carries a count badge on its top-right corner (.mm-ccount).
func _counted(circle: Control, n: int, bg := Tok.GOLD, ink := Tok.CARD_INK) -> Control:
	var num := Tok.label(str(n), 10.5, ink, 900)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var w := maxf(17, num.get_minimum_size().x + 6 + 3)
	num.add_theme_stylebox_override("normal", Tok.box(bg, 9, 1.5))
	num.size = Vector2(w, 17)
	num.position = Vector2(27 + 8 - w, -6)
	circle.add_child(num)
	return _chip(circle, "", 0)


func _order_chip(o: Dictionary, sc: Dictionary) -> Control:
	var grand: bool = o.id == "grand"
	var kind = null if grand else Orders.KINDS[o.id][0]
	var ok := Orders.met(o, Mat.on_mat(Game.state), sc.total, Game.state)
	var circle: Control
	match o.id:
		"stationWeek", "closedStation", "trendShift":
			circle = _icon_circle(Catalog.station(o.p).emoji, Color("#fff3c4"), Tok.GOLD, 2)
		"suitSet", "drought":
			circle = _icon_circle("suit:" + o.p, Color("#fff3c4"), Tok.GOLD, 2)
		"doubleDrought":
			circle = _icon_circle("suit:" + o.p.split("|")[0], Color("#fff3c4"), Tok.GOLD, 2)
		_:
			var glyph: String = {"grand": "🏛️", "collector": "★", "fullRecipe": "🧩", "commonThread": "🧵", "freshFaces": "🆕",
				"shortTable": "🪑", "thinStock": "📦", "spreadOut": "↔️"}.get(o.id, "?")
			circle = _text_circle(glyph, 16.5, Tok.CARD_INK, Color("#fff3c4"), Tok.GOLD, 2)
	var label := Util.thousands(int(Data.t("GRAND_EXHIBITION_TARGET"))) if grand \
		else "×%s" % _num(Data.t("ORDER_REQUEST_MULT") if kind == "request" else Data.t("ORDER_RESTRICT_MULT"))
	var bad: bool = kind == "restriction" and not ok
	if bad:
		circle.get_meta("box").border_color = Tok.BAD
		circle.get_meta("box").bg_color = Color("#371913")
	var chip := _chip(circle, label, 13, 1.0 if bad or (kind == "request" and ok) else 0.55, Tok.BAD if bad else Tok.GOLD)
	return chip


static func _num(x: float) -> String:
	return str(int(x)) if x == int(x) else str(x)


## A 27px circle holding an icon (.mm-cico). outline: the dark icon edge
## used on station and item icons.
func _icon_circle(key: String, bg: Color, border := Color.TRANSPARENT, bw := 0.0, outline := false) -> Panel:
	var p := Panel.new()
	var sb := Tok.box(bg, 13.5, bw, border)
	p.add_theme_stylebox_override("panel", sb)
	p.set_meta("box", sb)
	p.size = Vector2(27, 27)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	if key != "":
		var ic := Tok.icon(key, 18)
		ic.position = Vector2(4.5, 4.5)
		if outline:
			ic.material = Tok.outline(18)
		p.add_child(ic)
	return p


func _text_circle(text: String, px: float, ink: Color, bg: Color, border: Color, bw: float) -> Panel:
	var p := _icon_circle("", bg, border, bw)
	var l := Tok.label(text, px, ink, 900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	p.add_child(l)
	return p


## renderMatGridCells(): only open slots are drawn; a stack of tier 1 cards
## shows a dashed square where another fits.
func _slots(cards: Array, sc: Dictionary, page: Control, row_h: float) -> void:
	var st := Mat.stage(Game.state)
	var pack := Mat.pack(cards, st)
	var L: Dictionary = pack.L
	var cols: int = L.cols
	var inner := page.size.x - 2 * (PAGE_PAD + 2)
	var col_w := (inner - (cols - 1) * COLS_GAP) / cols
	var lit_suits: Array = sc.combos.suit.map(func(g): return g.name)
	var lit_st: Array = sc.combos.station.map(func(g): return g.name)
	var card_opts := func(c: Dictionary, mini: bool) -> Dictionary:
		return {"mini": mini, "in_grid": false, "complete": sc.completeNames.has(c.name), "lit_suits": lit_suits, "lit_stations": lit_st}
	for i in pack.slot.size():
		var sl: Dictionary = pack.slot[i]
		if sl.has("cover") or sl.kind == "locked":
			continue
		var r: int = i / cols
		var c: int = i % cols
		var pos := Vector2(PAGE_PAD + 2 + c * (col_w + COLS_GAP), PAGE_PAD + 2 + r * (row_h + COLS_GAP))
		var h := row_h if sl.kind == "full" else (row_h - 2) / 2
		if sl.has("card"):
			var card := ItemCard.make(sl.card.name, card_opts.call(sl.card, false))
			card.position = pos
			card.size = Vector2(col_w * sl.w + COLS_GAP * (sl.w - 1), row_h)
			page.add_child(card)
		elif sl.has("stack") or sl.kind == "top":
			var stack: Array = sl.get("stack", [])
			var per: int = 1 if sl.kind == "top" else L.perSlot
			var mh := (row_h - (per - 1) * 2) / per
			for k in per:
				var at := pos + Vector2(0, k * (mh + 2))
				if k < stack.size():
					var mini := ItemCard.make(stack[k].card.name, card_opts.call(stack[k].card, true))
					mini.position = at
					mini.size = Vector2(col_w, mh)
					page.add_child(mini)
				elif k == stack.size():
					page.add_child(_dashed(Rect2(at, Vector2(col_w, mh)), 10))
		else:
			page.add_child(_dashed(Rect2(pos, Vector2(col_w, h)), 12))


## An empty slot: a 2px dashed outline (.mm-slot.empty, .mm-mini-empty).
static func _dashed(r: Rect2, radius: float) -> Control:
	var d := DashedBox.new()
	d.position = r.position
	d.size = r.size
	d.radius = radius
	return d
