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

const HUB_H := 67.0  # the hub bar below the drawer (M4)
const GOLD_LINE := Color("#e2b25a")

var _drawer: Panel
var _scroll: ScrollContainer
var _body: Control  # the mat half, rebuilt on every change (drawn over the list)
var _inv_cards := {}  # item name -> its card in the list, to dim it in place
var _inv_key := ""  # what the list was built for: item count and width
var _press_at := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Tok.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	# The drawer: card blue, gold top edge, rounded top, above the hub.
	_drawer = Panel.new()
	var dsb := Tok.box(Tok.CARD, 16, 0)
	dsb.border_width_top = 3
	dsb.border_color = GOLD_LINE
	dsb.corner_radius_bottom_left = 0
	dsb.corner_radius_bottom_right = 0
	_drawer.add_theme_stylebox_override("panel", dsb)
	_drawer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_drawer)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_body)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)  # e.g. Safari's bar collapsing makes the screen wider
	_redraw()


## The mat half is rebuilt on every change (it's small); the item list only
## when the items or the width change, otherwise its cards just re-dim. A
## full rebuild with a late-game inventory took ~70ms on a PC.
func _redraw() -> void:
	for c in _body.get_children():
		c.queue_free()
	var s := Game.state
	var cards := Mat.on_mat(s)
	var sc := Mat.score(cards, s, Game.ctx)
	_drawer.size = Vector2(size.x, size.y - HUB_H)
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
	# The mat page: as many columns as are open, and one row, a row and a
	# half-height strip, or two, as the mat has grown.
	var st := Mat.stage(s)
	var L := Mat.layout(cards, st)
	var open: int = L.kinds.slice(0, L.cols).filter(func(k): return k != "locked").size()
	var row_h := ((w - 14 - (open - 1) * COLS_GAP) / open) * 1.4
	var mat_h: float = row_h if st < 2 else (row_h * 1.5 + 4 if st == 2 else row_h * 2 + COLS_GAP)
	var page := Panel.new()
	var sb := Tok.box(Color("#cda874"), 14, 2, Color("#a67c4a"))
	sb.corner_radius_bottom_left = 4
	page.add_theme_stylebox_override("panel", sb)
	page.position = Vector2(SIDE, y)
	page.size = Vector2(w, mat_h + 14)
	page.set_meta("cmp", "mat:page")
	_body.add_child(page)
	_slots(cards, sc, page, row_h, open)
	_page_controls(page)
	y += page.size.y + 22  # .mat-zone-wrap margin-bottom: the tabs hang below
	# The gold line between the mat and the item list, with the fold button.
	var line := ColorRect.new()
	line.color = GOLD_LINE
	line.position = Vector2(0, y)
	line.size = Vector2(size.x, 2)
	_body.add_child(line)
	# The item list: search bar, then the owned cards by tier.
	_scroll.position = Vector2(0, y + 2)
	_scroll.size = Vector2(size.x, size.y - HUB_H - y - 2)
	var key := "%d|%d" % [s.items.size(), int(size.x)]
	if key != _inv_key:
		_inv_key = key
		for c in _scroll.get_children():
			c.queue_free()
		_inv_cards.clear()
		_scroll.add_child(_inventory(size.x))
	else:
		for n in _inv_cards:
			_inv_cards[n].modulate = Color(0.6, 0.6, 0.6) if s.mat.has(n) else Color.WHITE
	var fold := Panel.new()
	fold.add_theme_stylebox_override("panel", Tok.box(Tok.CARD, 10, 2, GOLD_LINE, 3, 2))
	fold.size = Vector2(38, 20)
	fold.position = Vector2((size.x - 38) / 2, y + 1 - 10)
	fold.add_child(_chevron())
	_body.add_child(fold)


## Tabs under the page's lower-left corner; Last / Clear / Layouts and the
## rules "?" riding its lower-right edge (renderMatTop()).
## shortcut: the Elements tab doesn't switch pages yet, Layouts and "?" open
## nothing, and Last swaps without asking; all come with M4's drawer.
func _page_controls(page: Control) -> void:
	var bottom := page.position.y + page.size.y
	var x := page.position.x + 4
	for t in [["Elements", Color("#f2e6cc"), Color("#c3a06a"), false], ["Display Mat", Color("#cda874"), Color("#a67c4a"), true]]:
		var tab := Label.new()
		tab.text = t[0]
		tab.add_theme_font_override("font", Tok.font(800))
		tab.add_theme_font_size_override("font_size", 10)
		tab.add_theme_color_override("font_color", Color("#3a2f1e"))
		var tsb := Tok.box(t[1], 10, 2, t[2], 3 if t[3] else 0, 3, Color(0, 0, 0, 0.35))
		tsb.border_width_top = 0
		tsb.corner_radius_top_left = 0
		tsb.corner_radius_top_right = 0
		tsb.content_margin_left = 9
		tsb.content_margin_right = 9
		tsb.content_margin_top = 5
		tsb.content_margin_bottom = 8
		tab.add_theme_stylebox_override("normal", tsb)
		tab.position = Vector2(x, bottom - (0.0 if t[3] else 4.0))
		tab.size = tab.get_minimum_size()
		if not t[3]:
			tab.modulate = Color(0.72, 0.72, 0.72)  # the inactive tab, recessed
		tab.set_meta("cmp", "tab:" + t[0])
		_body.add_child(tab)
		x += tab.size.x + 2
	var right := page.position.x + page.size.x
	var help := TextureRect.new()
	help.texture = load("res://assets/ui/btn_help.webp")
	help.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	help.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	help.size = Vector2(34, 34)
	help.position = Vector2(right + 8 - 34, bottom + 24 - 34)
	help.set_meta("cmp", "btn:rules")
	_body.add_child(help)
	var qs: bool = Game.state.get("quickSavedMat") != null
	var x2 := right - 30
	var btns := [["💾", 30.0, func(): pass], ["Clear", 0.0, Game.clear_mat], ["↻" if qs else "↺", 30.0, Game.mat_last_tap]]
	for b in btns:
		var text: String = b[0]
		var is_text: bool = b[1] == 0.0
		var bw: float = b[1] if not is_text else Tok.font(800).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 24
		var bh := 34.0 if is_text else 30.0
		var px := 12 if is_text else (13 if text == "💾" else 18)
		var bg := Color("#3f8fd0") if qs and text == "↻" else Tok.GOLD
		var btn := _round_button(text if is_text else "", Vector2(bw, bh), px, bg)
		if not is_text:  # 💾 as its Noto image; ↺ / ↻ drawn (not in Nunito)
			var ic: Control = Tok.icon(text, 15) if text == "💾" else Tok.loop_arrow(Color.WHITE if qs else Tok.CARD_INK, 20, qs)
			ic.position = (Vector2(bw, bh) - ic.size) / 2
			btn.add_child(ic)
		x2 -= bw
		btn.position = Vector2(x2, bottom + 24 - bh)
		btn.pressed.connect(b[2])
		btn.set_meta("cmp", "btn:" + text)
		_body.add_child(btn)
		x2 -= 4


func _round_button(text: String, sz: Vector2, font_px: int, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", Tok.font(900 if font_px >= 18 else 800))
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_color_override("font_color", Tok.CARD_INK)
	b.add_theme_color_override("font_pressed_color", Tok.CARD_INK)
	b.add_theme_color_override("font_hover_color", Tok.CARD_INK)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Tok.box(bg.darkened(0.08) if k == "pressed" else bg, sz.y / 2, 2, Color("#5c4a20"), 4, 3))
	b.size = sz
	return b


## The fold button's chevron (.mcb-chev: a 9px corner, pointing up).
func _chevron() -> Control:
	var c := Control.new()
	c.size = Vector2(38, 20)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_polyline(PackedVector2Array([Vector2(13, 13), Vector2(19, 7), Vector2(25, 13)]), GOLD_LINE, 2.5, true))
	return c


## The scrolling item list (.dbody padding 16px 18px; renderMatResultsGrid()):
## search bar, then owned cards by tier, highest first; tapping one puts it
## on the mat or takes it off.
func _inventory(width: float) -> Control:
	var list := Control.new()
	list.mouse_filter = MOUSE_FILTER_PASS  # wheel and touch drags reach the ScrollContainer
	var pad := 18.0
	var w := width - 2 * pad
	var y := 16.0 + 14.0
	var search := Label.new()
	search.text = "Search items or components…"
	search.add_theme_font_override("font", Tok.font(400))
	search.add_theme_font_size_override("font_size", 13)
	search.add_theme_color_override("font_color", Tok.MUTE)
	var ssb := Tok.box(Tok.SUNKEN, 8, 1.5, Tok.LINE)
	ssb.content_margin_left = 10
	search.add_theme_stylebox_override("normal", ssb)
	search.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search.position = Vector2(pad, y)
	search.size = Vector2(w - 2 * (38 + 8), 38)
	search.set_meta("cmp", "inv:search")
	list.add_child(search)
	for i in 2:
		var b := Panel.new()
		b.add_theme_stylebox_override("panel", Tok.box(Color("#241c3a"), 8, 1.5, Color("#4a3a75")))
		var ic := Tok.icon(["📋", "🏆"][i], 20)
		ic.position = Vector2(9, 9)
		b.add_child(ic)
		b.position = Vector2(pad + w - 38 - (1 - i) * (38 + 8), y)
		b.size = Vector2(38, 38)
		list.add_child(b)
	y += 38 + 10
	var inv: Array = Game.state.items.map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
	inv = Util.stable_sort(inv, func(a, b): return b.points - a.points if b.points != a.points else a.name.nocasecmp_to(b.name))
	var col_w := (w - 3 * 8) / 4
	var row_h := col_w * 1.4
	for band in Data.t("MAT_TIER_BANDS"):
		var items := inv.filter(func(c): return c.tier == band.tier)
		if items.is_empty():
			continue
		# Heading: a label between two lines (.mat-tier-heading, 6px padding, 10px below).
		var head := Tok.label(band.label, 13, Tok.INK2, 800)
		var hw := Tok.font(800).get_string_size(band.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		head.position = Vector2(pad + (w - hw) / 2, y + 6)
		head.set_meta("cmp", "inv:head:" + band.key)
		list.add_child(head)
		for side in 2:
			var ln := ColorRect.new()
			ln.color = Tok.LINE2
			ln.size = Vector2((w - hw) / 2 - 8, 2)
			ln.position = Vector2(pad + side * ((w + hw) / 2 + 8), y + 6 + 9)
			list.add_child(ln)
		y += 6 + 18 + 6 + 10
		var t1: bool = band.tier == "MATERIAL"
		var h := (row_h - 2) / 2 if t1 else row_h
		var x := 0
		for c in items:
			var span := 2 if c.tier == "CAPSTONE" else 1
			if x + span > 4:
				x = 0
				y += h + 8
			var card := ItemCard.make(c.name, {"mini": t1, "wide": span == 2, "on": Game.state.mat.has(c.name), "tag": "inv:" + c.name})
			card.position = Vector2(pad + x * (col_w + 8), y)
			card.size = Vector2(col_w * span + 8 * (span - 1), h)
			card.set_meta("cmp", "inv:" + c.name)
			_inv_cards[c.name] = card
			card.gui_input.connect(_on_card_input.bind(c.name))
			list.add_child(card)
			x += span
		y += h + 14
	list.custom_minimum_size = Vector2(width, y + 150)  # room to scroll clear of the hub
	return list


## A tap (not a scroll) toggles the card on the mat.
func _on_card_input(ev: InputEvent, name: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_at = ev.global_position
		elif ev.global_position.distance_to(_press_at) < 10:
			var msg := Game.toggle_mat_card(name)
			if msg != "":
				_show_toast(msg)


## The mat's red message pill (.mat-toast), for 2 seconds.
func _show_toast(msg: String) -> void:
	var t := Tok.label(msg, 12.5, Color.WHITE, 800)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := Tok.box(Tok.BAD, 16, 0, Color.BLACK, 6, 4, Color(0, 0, 0, 0.4))
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	t.add_theme_stylebox_override("normal", sb)
	t.size = t.get_minimum_size()
	t.position = Vector2((size.x - t.size.x) / 2, size.y - HUB_H - 16 - t.size.y)
	add_child(t)
	get_tree().create_timer(2.0).timeout.connect(t.queue_free)


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
		var star := _icon_circle("", Color("#241c3a"), Color("#8a5ce0"), 1.5)
		var st_ic := Tok.star(Color("#ffd166"), 15)
		st_ic.position = Vector2(6, 5.5)
		star.add_child(st_ic)
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
		"doubleDrought":  # both banned suits, side by side
			circle = _icon_circle("", Color("#fff3c4"), Tok.GOLD, 2)
			var two: PackedStringArray = o.p.split("|")
			for i in 2:
				var ic := Tok.icon("suit:" + two[i], 11)
				ic.position = Vector2(2.5 + i * 11, 8)
				circle.add_child(ic)
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
func _slots(cards: Array, sc: Dictionary, page: Control, row_h: float, open: int) -> void:
	var st := Mat.stage(Game.state)
	var pack := Mat.pack(cards, st)
	var L: Dictionary = pack.L
	var cols: int = L.cols
	var inner := page.size.x - 2 * (PAGE_PAD + 2)
	var col_w := (inner - (open - 1) * COLS_GAP) / open  # open columns share the width
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
			card.gui_input.connect(_on_card_input.bind(sl.card.name))
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
					mini.gui_input.connect(_on_card_input.bind(stack[k].card.name))
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
