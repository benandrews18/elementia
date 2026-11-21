## The Display Mat (renderMatTop(), display-mat.css): the score card (Quark
## Meter, combo chips) over the mat itself, a parchment page holding the
## cards in slots as the mat has grown. Redraws from Game.state on
## state_changed.
class_name DisplayMatScreen
extends Control

## The layout is ui/screens/display_mat.tscn (the drawer, the mat page's two
## looks, the fold button); these numbers lay out what's built from the run.
const SCENE := "res://ui/screens/display_mat.tscn"
const HUB_H := HubBar.H  # the drawer ends at the hub bar's top
const GOLD_LINE := Color("#e2b25a")

## Page sides, the top, the gap between mat columns, the mat page's padding,
## the gap between combo chips, a card's height to its width.
@export var side := 6.0  # #drawerTop padding 10px 6px 0
@export var top := 12.0  # the drawer's 2px top edge + #drawerTop's 10px
@export var cols_gap := 5.0
@export var page_pad := 5.0  # .mat-zone-page padding + border (2px) are inside the 14px
@export var chip_gap := 6.0  # .mat-combos gap (rows and columns)
@export var card_ratio := 1.4
@export var line_color := Color("#e2b25a")  # the line between the mat and the list
@export var mat_page: StyleBox
@export var elements_page: StyleBox
@export var fold_style: StyleBox

@onready var _drawer: Panel = $Drawer
@onready var _scroll: ScrollContainer = $Scroll
@onready var _body: Control = $Body  # the mat half, rebuilt on every change (drawn over the list)
var _inv_cards := {}  # item name -> its card in the list, to dim it in place
var _inv_ring: Panel  # the selected card's green ring in the list
var _inv_key := ""  # what the list was built for: item count and width
var _press_at := Vector2.ZERO
var view := "mat"  # which page under the score card: "mat" or "elements" (matDrawerView)
var selected := ""  # the card on the Crafting Bench (matListOpen)
var playing := false  # the Lock-In count is running: no redraws under it
var _qm: QuarkMeter
var _mat_nodes := {}  # card name -> its card on the mat (the count bounces them)
var _chip_nodes := {}  # "kind:name" -> its combo chip
var slot_rects := {}  # slot index -> its rect on screen (the expansion reveal)


static func make() -> DisplayMatScreen:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)  # e.g. Safari's bar collapsing makes the screen wider
	_redraw()


## The mat half is rebuilt on every change (it's small); the item list only
## when the items or the width change, otherwise its cards just re-dim. A
## full rebuild with a late-game inventory took ~70ms on a PC.
func _redraw() -> void:
	if playing:
		return
	_mat_nodes.clear()
	_chip_nodes.clear()
	slot_rects.clear()
	for c in _body.get_children():
		c.queue_free()
	var s := Game.state
	var cards := Mat.on_mat(s)
	var sc := Mat.score(cards, s, Game.ctx)
	_drawer.size = Vector2(size.x, size.y - HUB_H)
	var w := size.x - 2 * side
	var y := top
	# Quark Meter line.
	var qm := QuarkMeter.new()
	qm.position = Vector2(side, y)
	qm.size = Vector2(w, qm.custom_minimum_size.y)
	_body.add_child(qm)
	_qm = qm
	qm.show_score(sc.total, Orders.tiers(Orders.check_round(s)))
	y += qm.size.y + 4
	# Combo chips (min height 40, wrapping rows).
	y += _chips(sc, Vector2(side, y), w) + 6
	# The mat page: as many columns as are open, and one row, a row and a
	# half-height strip, or two, as the mat has grown.
	var st := Mat.stage(s)
	var L := Mat.layout(cards, st)
	var open: int = L.kinds.slice(0, L.cols).filter(func(k): return k != "locked").size()
	var row_h := ((w - 14 - (open - 1) * cols_gap) / open) * card_ratio
	var mat_h: float = row_h if st < 2 else (row_h * 1.5 + 4 if st == 2 else row_h * 2 + cols_gap)
	var page := Panel.new()
	var elements := view == "elements"
	page.add_theme_stylebox_override("panel", elements_page if elements else mat_page)
	page.position = Vector2(side, y)
	page.size = Vector2(w, mat_h + 14)
	page.clip_contents = elements
	page.set_meta("cmp", "mat:page")
	_body.add_child(page)
	if elements:
		_elements(page)
	else:
		_slots(cards, sc, page, row_h, open)
	_page_controls(page)
	y += page.size.y + 22  # .mat-zone-wrap margin-bottom: the tabs hang below
	# The gold line between the mat and the item list, with the fold button.
	var line := ColorRect.new()
	line.color = line_color
	line.position = Vector2(0, y)
	line.size = Vector2(size.x, 2)
	_body.add_child(line)
	var line_y := y
	y += 2
	# The selected card's row on the Crafting Bench, Add / Remove below it.
	if selected != "" and Catalog.owns(s, selected) and Catalog.entry(selected) != null:
		y = _sel_bench(y)
	# The item list: search bar, then the owned cards by tier.
	_scroll.position = Vector2(0, y)
	_scroll.size = Vector2(size.x, size.y - HUB_H - y)
	if selected != "" and _body.has_meta("acts"):
		_body.move_child(_body.get_meta("acts"), -1)
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
	# The selection's green ring, moved onto its card (no list rebuild).
	if is_instance_valid(_inv_ring):
		_inv_ring.visible = _inv_cards.has(selected)
		if _inv_ring.visible:
			var c: Control = _inv_cards[selected]
			_inv_ring.position = c.position - Vector2(6, 6)
			_inv_ring.size = c.size + Vector2(12, 12)
	var fold := Panel.new()
	fold.add_theme_stylebox_override("panel", fold_style)
	fold.size = Vector2(38, 20)
	fold.position = Vector2((size.x - 38) / 2, line_y + 1 - 10)
	fold.add_child(_chevron())
	_body.add_child(fold)


## The Lock-In count (playLockInSequence()): the meter drops to 0 and builds
## back up one scoring beat at a time (score_beats()), bouncing the cards and
## chips each beat is for; then it snaps to the real total, the Quarks
## bounce, and on_done runs. Collections locked in for the first time are
## discovered on the way (one Star each).
## shortcut: a first-time collection bounces the "!" chip instead of
## revealing its own chip, fine until the collections row gets its reveal.
func play_lock_in(on_done: Callable) -> void:
	playing = true
	var s := Game.state
	var cards := Mat.on_mat(s)
	var sc := Mat.score(cards, s, Game.ctx)
	var beats := score_beats(cards, sc)
	var tiers := Orders.tiers(Orders.check_round(s))
	_qm.show_score(0, tiers)
	var pts := 0.0
	var mult := 1.0
	for i in beats.size():
		await get_tree().create_timer(0.22 if i > 0 else 0.0).timeout
		if not is_instance_valid(self):
			return
		var b: Dictionary = beats[i]
		for n in b.cards:
			bounce(_mat_nodes.get(n))
		if b.has("chip"):
			bounce(_chip_nodes.get(b.chip, _chip_nodes.get("new") if b.chip == "collection" else null))
		pts += b.points
		mult += b.mult
		_qm.show_score(pts * mult, tiers)
	await get_tree().create_timer(0.38 + 0.15).timeout
	_qm.show_score(sc.total, tiers)
	bounce(_qm.total_label())
	bounce(_chip_nodes.get("order"))
	await get_tree().create_timer(0.38 + 0.3).timeout
	for col in sc.cols:
		if not Util.get_or(Progress.prefs, "everUnlockedMatCollections", []).has(col.id):
			Progress.discover_collection(col.id)
	on_done.call()


## lockInScoreBeats(): every card's points; every complete recipe again
## (the card and its ingredients); each completed collection's bonus; each
## station / suit / component combo's multiplier; then whatever the
## capstone signatures add, as one points beat and one multiplier beat.
static func score_beats(cards: Array, sc: Dictionary) -> Array:
	var beats := []
	for c in cards:
		beats.append({"cards": [c.name], "points": c.points, "mult": 0})
	for c in cards:
		if Mat.is_complete(c, cards):
			var need := Mat.direct_items(c)
			beats.append({"cards": [c.name] + cards.filter(func(m): return need.has(m.name)).map(func(m): return m.name), "points": c.points, "mult": 0})
	for col in sc.cols:
		beats.append({"cards": cards.filter(func(c): return col.items.has(c.name)).map(func(c): return c.name), "points": col.bonus, "mult": 0, "chip": "collection"})
	for kind in ["station", "suit", "component"]:
		for g in sc.combos[kind]:
			var members: Array = cards.filter(func(c): return (c.stations.has(g.name) if kind == "station"
				else c.pips.has(g.name) if kind == "suit" else c.name == g.name or Mat.direct_items(c).has(g.name)))
			beats.append({"cards": members.map(func(c): return c.name), "points": 0, "mult": g.bonus, "chip": kind + ":" + g.name})
	var sig := func(names: Array) -> Array: return cards.filter(func(c): return names.has(c.name)).map(func(c): return c.name)
	var pts := 0.0
	var mult := 0.0
	for b in beats:
		pts += b.points
		mult += b.mult
	if sc.base + sc.colBonus - pts != 0:
		beats.append({"cards": sig.call(["Robot", "Homestead", "Maglev Train", "Space Station"]), "points": sc.base + sc.colBonus - pts, "mult": 0})
	if sc.mult - 1 - mult != 0:
		beats.append({"cards": sig.call(["Coral Reef", "Ecosystem"]), "points": 0, "mult": sc.mult - 1 - mult})
	return beats


## bouncePulse(): a quick scale punch (1 -> 1.35 -> 1, 380ms).
static func bounce(c) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.35, 1.35), 0.19).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.19).set_trans(Tween.TRANS_SINE)


## Tabs under the page's lower-left corner; Last / Clear / Layouts and the
## rules "?" riding its lower-right edge (renderMatTop()).
func _page_controls(page: Control) -> void:
	var bottom := page.position.y + page.size.y
	var x := page.position.x + 4
	for t in [["Elements", Color("#f2e6cc"), Color("#c3a06a"), view == "elements"], ["Display Mat", Color("#cda874"), Color("#a67c4a"), view == "mat"]]:
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
		tab.mouse_filter = MOUSE_FILTER_STOP
		var to: String = "elements" if t[0] == "Elements" else "mat"
		tab.gui_input.connect(func(ev): if Tap.tap(ev):
			view = to
			_redraw())
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
	help.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: MatRules.show_on(App.current))
	_body.add_child(help)
	var qs: bool = Game.state.get("quickSavedMat") != null
	var x2 := right - 30
	if view != "mat":
		return
	var btns := [["💾", 30.0, func(): if App.current: LayoutsWindow.show_on(App.current)], ["Clear", 0.0, Game.clear_mat], ["↻" if qs else "↺", 30.0, _last]]
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
	var row_h := col_w * card_ratio
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
		for k in 2:
			var ln := ColorRect.new()
			ln.color = Tok.LINE2
			ln.size = Vector2((w - hw) / 2 - 8, 2)
			ln.position = Vector2(pad + k * ((w + hw) / 2 + 8), y + 6 + 9)
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
	_inv_ring = _selected_ring(Vector2.ZERO, Vector2.ZERO)
	_inv_ring.visible = false
	list.add_child(_inv_ring)
	list.move_child(_inv_ring, 0)
	list.custom_minimum_size = Vector2(width, y + 150)  # room to scroll clear of the hub
	return list


## A tap (not a scroll) selects the card: its row goes on the Crafting Bench
## with Add / Remove (tap it again to put it back).
func _on_card_input(ev: InputEvent, name: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_at = ev.global_position
		elif ev.global_position.distance_to(_press_at) < 10:
			selected = "" if selected == name else name
			_redraw()


## Last: back to the last locked-in mat (asks first, quick-saving this one);
## with a quick save, it comes straight back.
func _last() -> void:
	if Game.state.get("quickSavedMat") != null:
		Game.mat_last_tap()
		return
	ConfirmDialog.ask(App.current if App.current else self,
		"Reset the Display Mat to your last locked-in layout? Your current mat is quick-saved -- tap the arrow again to bring it back.",  # ↻ isn't in Nunito
		Game.mat_last_tap)


## The Crafting Bench under the gold line (#matSelPanel) with the selected
## card's row, and Add / Remove dropping down below it (#matListActions).
## Returns where the list starts.
func _sel_bench(y: float) -> float:
	var bench := BenchPanel.new()
	bench.add_child(ShopRow.make(Catalog.entry(selected), size.x - 36, func(_n, _r): pass, func(n):
		Game.toggle_pin(n), true))  # saves, then redraws; plain row (no have/missing marks)
	bench.position = Vector2(0, y)
	bench.size = Vector2(size.x, 30 + ShopRow.H + 18)
	_body.add_child(bench)
	var close := TextureRect.new()
	close.texture = load("res://assets/ui/btn_close.webp")
	close.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close.position = Vector2(size.x - 8 - 34, y + bench.size.y + 2 - 34)
	close.size = Vector2(34, 34)
	close.gui_input.connect(func(ev): if Tap.tap(ev):
		selected = ""
		_redraw())
	_body.add_child(close)
	var end := y + bench.size.y
	var on: bool = Game.state.mat.has(selected)
	var card = Catalog.mat_card(selected)
	var fits: bool = card != null and Mat.fits(Mat.on_mat(Game.state) + [card], Mat.stage(Game.state))
	var acts := Control.new()  # no height of its own: floats over the list
	acts.position = Vector2(0, end + 4)
	acts.mouse_filter = MOUSE_FILTER_IGNORE
	var bx := (size.x - (96 * 2 + 10)) / 2
	for i in 2:
		var add := i == 0
		var enabled := (not on and fits) if add else on
		var b := Label.new()
		b.text = ("+  Add" if add else "–  Remove")
		b.add_theme_font_override("font", Tok.font(900))
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var bs := Tok.box(Tok.OK if add else Tok.BAD, 12, 2.5, Color.BLACK, 5, 4, Color(0, 0, 0, 0.35))
		b.add_theme_stylebox_override("normal", bs)
		b.position = Vector2(bx + i * (96 + 10), 0)
		b.size = Vector2(96, 34)
		if not enabled:
			b.modulate = Color(0.55, 0.55, 0.55, 0.6)
		else:
			b.mouse_filter = MOUSE_FILTER_STOP
			b.gui_input.connect(func(ev): if Tap.tap(ev):
				var msg := Game.toggle_mat_card(selected)
				if msg != "":
					_show_toast(msg))
		b.set_meta("cmp", "mat:add" if add else "mat:remove")
		acts.add_child(b)
	_body.add_child(acts)
	_body.set_meta("acts", acts)
	return end


## The Elements page: every element held, 8 to a row (elementsGridHTML()).
func _elements(page: Control) -> void:
	var held: Array = Game.state.elements.keys().filter(func(k): return Game.state.elements[k] > 0)
	var an: Dictionary = Data.t("ATOMIC_NUMBER")
	held = Util.stable_sort(held, func(a, b): return an.get(a, 999) - an.get(b, 999))
	var inner := page.size.x - 14
	var cw := (inner - 7 * 5) / 8
	for i in held.size():
		var sym: String = held[i]
		var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
		var at := Vector2(7 + (i % 8) * (cw + 5), 7 + (i / 8) * (cw + 3 + 12 + 6))
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 8, 5, color))
		box.position = at
		box.size = Vector2(cw, cw)
		box.mouse_filter = MOUSE_FILTER_IGNORE
		page.add_child(box)
		var l := Tok.label(sym, 13, Color("#221f1a"), 800)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.position = at
		l.size = box.size
		page.add_child(l)
		var q := Tok.label(str(int(Game.state.elements[sym])), 9, Color("#3b2412"), 800)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.position = at + Vector2(0, cw + 3)
		q.size = Vector2(cw, 12)
		page.add_child(q)
	if held.is_empty():
		var none := Tok.label("No loose elements — visit a station and roll.", 14, Color("#8a6a48"), 400)
		none.position = Vector2(12, 12)
		page.add_child(none)


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
	var chips := combo_chips(sc)
	# Wrap into rows (gap 8px between rows, 10px between chips).
	return _place_chips(chips, at, w)


## matComboChipsHTML(): the mat's combo chips, in order: the challenge (live:
## only on the mat itself), the signature cards, station, suit and component
## combos, the collections star, and "!" for an undiscovered collection.
static func combo_chips(sc: Dictionary, live := true) -> Array:
	var chips := []
	var o = Orders.current(Game.state) if live else null
	if o != null:
		chips.append(_order_chip(o, sc))
		chips[-1].set_meta("combo", "order")
		chips[-1].gui_input.connect(func(ev): if Tap.tap(ev) and App.current: OrderInfo.open(App.current))
	for g in sc.sigs:
		chips.append(_chip(_icon_circle(Data.t("ITEM_EMOJI")[g.name], Tok.PARCHMENT, Tok.GOLD, 2), g.label, 13, 0.45 if not g.on else 1.0))
	for g in sc.combos.station:
		chips.append(_counted(_icon_circle(Catalog.station(g.name).emoji, Tok.station_color(g.name), Color.TRANSPARENT, 0, true), g.k))
		chips[-1].set_meta("combo", "station:" + g.name)
	for g in sc.combos.suit:
		chips.append(_counted(_icon_circle("suit:" + g.name, Tok.suit_color(g.name)), g.k))
		chips[-1].set_meta("combo", "suit:" + g.name)
	for g in sc.combos.component:
		var em = Data.t("ITEM_EMOJI").get(g.name)
		chips.append(_counted(_icon_circle(em if em else "", Tok.PARCHMENT, Color.TRANSPARENT, 0, true), g.k))
		chips[-1].set_meta("combo", "component:" + g.name)
	var found: Array = Util.get_or(Progress.prefs, "everUnlockedMatCollections", [])
	var known: Array = sc.cols.filter(func(c): return found.has(c.id))
	if not known.is_empty():
		var star := _icon_circle("", Color("#241c3a"), Color("#8a5ce0"), 1.5)
		var st_ic := Tok.star(Color("#ffd166"), 15)
		st_ic.position = Vector2(6, 5.5)
		star.add_child(st_ic)
		chips.append(_counted(star, known.size(), Color("#8a5ce0"), Color.WHITE))
		chips[-1].set_meta("combo", "collection")
	if sc.cols.any(func(c): return not found.has(c.id)):
		chips.append(_chip(_text_circle("!", 18, Color.WHITE, Tok.BAD, Color.WHITE, 2), "", 0))
		chips[-1].set_meta("combo", "new")
	return chips


## Lays chips out in wrapping rows under at, w wide; returns their height.
func _place_chips(chips: Array, at: Vector2, w: float) -> float:
	var x := 0.0
	var y := 0.0
	var row_h := 0.0
	for i in chips.size():
		var c: Control = chips[i]
		var sz := c.custom_minimum_size
		if x > 0 and x + sz.x > w:
			x = 0
			y += row_h + chip_gap
			row_h = 0
		c.position = at + Vector2(x, y + 0)
		c.size = sz
		c.set_meta("cmp", "chip%d" % i)
		_body.add_child(c)
		if c.has_meta("combo"):
			_chip_nodes[c.get_meta("combo")] = c
		x += sz.x + chip_gap
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
static func _chip(circle: Control, label: String, size_px: float, alpha := 1.0, color := Tok.GOLD) -> Control:
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
static func _counted(circle: Control, n: int, bg := Tok.GOLD, ink := Tok.CARD_INK) -> Control:
	var num := Tok.label(str(n), 10.5, ink, 900)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var w := maxf(17, num.get_minimum_size().x + 6 + 3)
	num.add_theme_stylebox_override("normal", Tok.box(bg, 9, 1.5))
	num.size = Vector2(w, 17)
	num.position = Vector2(27 + 8 - w, -6)
	circle.add_child(num)
	return _chip(circle, "", 0)


static func _order_chip(o: Dictionary, sc: Dictionary) -> Control:
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
			if o.id == "collector":  # ★: drawn (not in Nunito)
				circle = _icon_circle("", Color("#fff3c4"), Tok.GOLD, 2)
				var st := Tok.star(Tok.GOLD, 15)
				st.position = Vector2(6, 5.5)
				circle.add_child(st)
			else:  # an emoji: its Noto image
				circle = _icon_circle(glyph, Color("#fff3c4"), Tok.GOLD, 2)
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
static func _icon_circle(key: String, bg: Color, border := Color.TRANSPARENT, bw := 0.0, outline := false) -> Panel:
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


static func _text_circle(text: String, px: float, ink: Color, bg: Color, border: Color, bw: float) -> Panel:
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
	var inner := page.size.x - 2 * (page_pad + 2)
	var col_w := (inner - (open - 1) * cols_gap) / open  # open columns share the width
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
		var pos := Vector2(page_pad + 2 + c * (col_w + cols_gap), page_pad + 2 + r * (row_h + cols_gap))
		var h := row_h if sl.kind == "full" else (row_h - 2) / 2
		slot_rects[i] = Rect2(page.position + pos, Vector2(col_w * sl.get("w", 1) + cols_gap * (sl.get("w", 1) - 1), row_h if sl.has("card") or sl.has("stack") or sl.kind == "top" else h))
		if sl.has("card"):
			if sl.card.name == selected:
				page.add_child(_selected_ring(pos, Vector2(col_w * sl.w + cols_gap * (sl.w - 1), row_h)))
			var card := ItemCard.make(sl.card.name, card_opts.call(sl.card, false))
			card.gui_input.connect(_on_card_input.bind(sl.card.name))
			card.position = pos
			card.size = Vector2(col_w * sl.w + cols_gap * (sl.w - 1), row_h)
			page.add_child(card)
			_mat_nodes[sl.card.name] = card
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
					_mat_nodes[stack[k].card.name] = mini
				elif k == stack.size():
					page.add_child(_dashed(Rect2(at, Vector2(col_w, mh)), 10))
		else:
			page.add_child(_dashed(Rect2(pos, Vector2(col_w, h)), 12))


## .mm-card.selected: a 4px green outline, 2px out.
static func _selected_ring(pos: Vector2, sz: Vector2) -> Panel:
	var r := Panel.new()
	r.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 17, 4, Tok.OK))
	r.position = pos - Vector2(6, 6)
	r.size = sz + Vector2(12, 12)
	r.mouse_filter = MOUSE_FILTER_IGNORE
	return r


## An empty slot: a 2px dashed outline (.mm-slot.empty, .mm-mini-empty).
static func _dashed(r: Rect2, radius: float) -> Control:
	var d := DashedBox.new()
	d.position = r.position
	d.size = r.size
	d.radius = radius
	return d
