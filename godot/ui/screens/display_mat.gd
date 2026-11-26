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
static var collapsed := false  # the fold button: the mat minimised to a row of its icons (setMatCollapsed())
static var list_mode := false  # the 📋 view: a compact list on the left, the selected card on the right
var playing := false  # the Lock-In count is running: no redraws under it
var _qm: QuarkMeter
var _hub_h := HUB_H
var _empties: Array = []  # the mat's empty slots (Rect2 on the page), for a lifted card's preview
var _mat_nodes := {}  # card name -> its card on the mat (the count bounces them)
var _chip_nodes := {}  # "kind:name" -> its combo chip
var slot_rects := {}  # slot index -> its rect on screen (the expansion reveal)
var stage_override := -1  # the growth reveal draws the mat as it was first (grow())
var _page: Panel
var lifted := ""  # with one hand card picked: it, shown as its full card over the hand
var picks: Array = []  # the hand cards picked (up to 5), for Play (the hub's middle button) or Discard
var _hand_view: HandView
var _preview: Control  # with cards picked: what playing them adds, over the mat
var _fits := false  # the picked cards fit on the mat (_show_preview works it out once per change)
var _ending := false  # the mat is full: its Lock In is on its way
var browsing := false  # a check: the deck count tapped, the whole Inventory shown (the user, 2026-11-23)


static func make() -> DisplayMatScreen:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_drawer.gui_input.connect(_blank_tap)  # a blank space: let go of what's picked (the user, 2026-11-23)
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
	_empties.clear()
	_chip_nodes.clear()
	slot_rects.clear()
	for c in _body.get_children():
		c.queue_free()
	var s := Game.state
	var cards := Mat.on_mat(s)
	var sc := Mat.score(cards, s, Game.ctx)
	var lab: bool = Game.ctx.get("comboLab", false)  # Combo Lab: the whole screen, under its exit bar
	_hub_h = 0.0 if lab and Game.check_hand() == null else HUB_H  # a lab check with cards keeps the hub
	_drawer.size = Vector2(size.x, size.y - _hub_h)
	var w := size.x - 2 * side
	var y := maxf(top, App.LAB_TOP) if lab else top  # [data-combo-lab] #drawerTop: padding-top 52px
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
	var st := _stage()
	var L := Mat.layout(cards, st)
	var open: int = L.kinds.slice(0, L.cols).filter(func(k): return k != "locked").size()
	var row_h := ((w - 14 - (open - 1) * cols_gap) / open) * card_ratio
	var mat_h: float = row_h if st < 2 else (row_h * 1.5 + 4 if st == 2 else row_h * 2 + cols_gap)
	if collapsed and Game.check_hand() == null:  # minimised: the mat's icons in a row, how full it is
		y = _mini_row(cards, L, Vector2(side, y), w) + 8
	else:
		var page := Panel.new()
		var elements := view == "elements"
		page.add_theme_stylebox_override("panel", elements_page if elements else mat_page)
		page.position = Vector2(side, y)
		page.size = Vector2(w, mat_h + 14)
		page.clip_contents = elements
		page.set_meta("cmp", "mat:page")
		_body.add_child(page)
		_page = page
		page.gui_input.connect(_blank_tap)
		if elements:
			_elements(page)
		else:
			_slots(cards, sc, page, row_h, open)
		_page_controls(page)
		y += page.size.y + 22  # .mat-zone-wrap margin-bottom: the tabs hang below (a check: its buttons)
	var h = Game.check_hand()
	_scroll.visible = h == null or browsing
	if h != null and not browsing:  # a check with cards: the hand in place of the item list
		_hand_area(h, _page)
		return
	lifted = ""
	picks = []
	# The gold line between the mat and the item list, with the fold button.
	var line := ColorRect.new()
	line.color = line_color
	line.position = Vector2(0, y)
	line.size = Vector2(size.x, 2)
	_body.add_child(line)
	var line_y := y
	y += 2
	# The selected card's row on the Crafting Bench, Add / Remove below it.
	var sel_ok: bool = selected != "" and Catalog.owns(s, selected) and Catalog.entry(selected) != null
	if sel_ok and not list_mode and not locked():
		_sel_acts(0, y + 6, size.x)
		y += 46
	# The item list: search bar, then the owned cards by tier.
	_scroll.position = Vector2(0, y)
	_scroll.size = Vector2(size.x, size.y - _hub_h - y)
	if list_mode:  # the side card stays put while the list scrolls; Add / Remove under it
		var lw := _list_w(size.x)
		var rx := LIST_PAD + lw + 8
		var rw := size.x - LIST_PAD - rx
		var cy := y + LIST_TOP
		if sel_ok:
			var card := CardPop.side_card(selected, rw)
			card.position = Vector2(rx, cy)
			_body.add_child(card)
			_sel_acts(rx, cy + card.size.y * card.scale.y + 8, rw)
		else:
			var hint := Tok.label("Tap an item to see its card", 13, Tok.MUTE, 700)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.position = Vector2(rx, cy + 40)
			hint.size = Vector2(rw, 40)
			_body.add_child(hint)
	var key := "%d|%d|%s" % [s.items.size(), int(size.x), list_mode]
	if key != _inv_key:
		_inv_key = key
		for c in _scroll.get_children():
			c.queue_free()
		_inv_cards.clear()
		_scroll.add_child(_inventory(size.x))
	else:
		for n in _inv_cards:
			_inv_cards[n].modulate = Color(0.6, 0.6, 0.6) if _spent(n) else Color.WHITE
	# The selection's green ring, moved onto its card (no list rebuild).
	if is_instance_valid(_inv_ring):
		_inv_ring.visible = _inv_cards.has(selected)
		if _inv_ring.visible:
			var c: Control = _inv_cards[selected]
			_inv_ring.position = c.position - Vector2(6, 6)
			_inv_ring.size = c.size + Vector2(12, 12)
	if browsing and h != null:  # in place of the fold: back to the hand
		var back := _round_button("Back to your hand", Vector2(180, 32), 13, Tok.GOLD)
		back.position = Vector2((size.x - 180) / 2, line_y + 1 - 16)
		back.set_meta("cmp", "hand:back")
		back.pressed.connect(func():
			browsing = false
			_redraw())
		_body.add_child(back)
		return
	var fold := Panel.new()
	fold.add_theme_stylebox_override("panel", fold_style)
	fold.size = Vector2(38, 20)
	fold.position = Vector2((size.x - 38) / 2, line_y + 1 - 10)
	fold.add_child(_chevron())
	fold.set_meta("cmp", "mat:fold")
	fold.gui_input.connect(func(ev): if Tap.tap(ev):
		collapsed = not collapsed
		_redraw())
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
			bounce(_mat_nodes.get(n, _chip_nodes.get("cap:" + n)))
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
	# Made inside one play: counted again (Mat.together).
	var tg: Dictionary = sc.get("together", {"combos": [], "complete": [], "cols": []})
	for g in tg.combos:
		var members: Array = cards.filter(func(c): return (c.stations.has(g.name) if g.kind == "station"
			else c.pips.has(g.name) if g.kind == "suit" else c.name == g.name or Mat.direct_items(c).has(g.name)))
		beats.append({"cards": members.map(func(c): return c.name), "points": 0, "mult": g.bonus, "chip": g.kind + ":" + g.name})
	for c in cards:
		if tg.complete.has(c.name) and Mat.is_complete(c, cards):
			beats.append({"cards": [c.name] + Mat.direct_items(c).filter(func(n): return Mat.has(cards, n)), "points": c.points, "mult": 0})
	for col in tg.cols:
		beats.append({"cards": cards.filter(func(c): return col.items.has(c.name)).map(func(c): return c.name), "points": col.bonus, "mult": 0, "chip": "collection"})
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
	if Game.check_hand() != null:  # a check: Discard, Lock In and Draw under the page (_hand_area)
		return
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
	if locked():  # between checks: the Combo Lab is where combos are tried (with this run's items)
		var bw := Tok.font(800).get_string_size("Combo Lab", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 24
		var lab_btn := _round_button("Combo Lab", Vector2(bw, 34), 12, Tok.GOLD)
		lab_btn.position = Vector2(x2 - bw, bottom + 24 - 34)
		lab_btn.pressed.connect(func(): if App.current: App.current.open_combo_lab(true))
		lab_btn.set_meta("cmp", "btn:Combo Lab")
		_body.add_child(lab_btn)
		return
	if view != "mat" or Game.check_hand() != null:  # with a hand, cards only change by playing
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


## The run's mat between checks (card playing, the user 2026-11-23): locked
## in, changed only by playing cards at a check; tried freely in the lab.
func locked() -> bool:
	return browsing or (not Game.ctx.get("comboLab", false) and Game.check_hand() == null)


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


## The minimised mat (matMiniRowHTML()): the mat's cards as icons, 8 a
## row, then how full it is in tier 1 units (a tier 1 card 1, a normal card
## a slot's worth, a capstone two); a tap shows the mat again. Returns the
## y under it.
func _mini_row(cards: Array, L: Dictionary, at: Vector2, w: float) -> float:
	var per: int = L.perSlot
	var used := 0
	for c in cards:
		used += 0 if Mat.is_capstone(c) else 1 if Mat.is_tier1(c) else per  # capstones: beside the mat
	var cap := 0
	for k in L.kinds:
		if k != "locked":
			cap += 1 if k == "top" else per
	var row := Panel.new()
	row.add_theme_stylebox_override("panel", Tok.box(Color("#cda874"), 12, 2, Color("#a67c4a")))
	row.set_meta("cmp", "mat:mini")
	var room := Tok.label("%d/%d" % [used, cap], 14, Color("#181614"), 900)
	var rw := room.get_minimum_size().x
	var cell := (w - 16 - rw - 8 - 7 * 3) / 8
	var lines := maxi(1, ceili(cards.size() / 8.0))
	var h := 12 + lines * 28 + (lines - 1) * 3
	row.position = at
	row.size = Vector2(w, h)
	if cards.is_empty():
		var none := Tok.label("Nothing on the mat yet", 12, Color(0.094, 0.086, 0.078, 0.7), 700)
		none.position = Vector2(8, (h - none.get_minimum_size().y) / 2)
		row.add_child(none)
	for i in cards.size():
		var ic := Tok.icon(cards[i].emoji, 24)
		ic.position = Vector2(8 + (i % 8) * (cell + 3) + (cell - 24) / 2, 6 + (i / 8) * 31 + 2)
		ic.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(ic)
	room.position = Vector2(w - 8 - rw, (h - room.get_minimum_size().y) / 2)
	row.add_child(room)
	row.gui_input.connect(func(ev): if Tap.tap(ev):
		collapsed = false
		_redraw())
	_body.add_child(row)
	return at.y + h


## The fold button's chevron (.mcb-chev: a 9px corner, pointing up).
func _chevron() -> Control:
	var c := Control.new()
	c.size = Vector2(38, 20)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var pts := PackedVector2Array([Vector2(13, 7), Vector2(19, 13), Vector2(25, 7)]) if collapsed \
			else PackedVector2Array([Vector2(13, 13), Vector2(19, 7), Vector2(25, 13)])  # down when minimised
		c.draw_polyline(pts, GOLD_LINE, 2.5, true))
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
		if i == 0:  # 📋: the list view and back
			if list_mode:
				b.add_theme_stylebox_override("panel", Tok.box(Color("#241c3a"), 8, 2.5, Tok.GOLD))
			b.set_meta("cmp", "inv:listview")
			b.gui_input.connect(func(ev): if Tap.tap(ev):
				list_mode = not list_mode
				_redraw())
		else:  # 🏆: the Collections window (#matCollectionsBtn; it did nothing before)
			b.set_meta("cmp", "inv:collections")
			b.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: CollectionsWindow.show_on(App.current))
	y += 38 + 10
	var inv: Array = Game.state.items.map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
	inv = Util.stable_sort(inv, func(a, b): return b.points - a.points if b.points != a.points else a.name.nocasecmp_to(b.name))
	if list_mode:
		return _inv_list(list, inv, pad, w, y, width)
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
			var card := ItemCard.make(c.name, {"mini": t1, "wide": span == 2, "on": _spent(c.name), "tag": "inv:" + c.name})
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


## The 📋 view (the user, 2026-11-22; to cut the repeated Craft and pin
## buttons at stations): a compact list on the left (each row: the icon, the
## name with its suits, the components in one row under it), the selected
## item's side card on the right (placed by _redraw(), outside the scroll so
## it stays put).
const LIST_PAD := 18.0
const LIST_TOP := 16.0 + 14.0 + 38.0 + 10.0  # the search bar's row
const ROW_H := 58.0
const ROW_FIT := 0.99  # the components' shared size: every row fits at it but Car, Fruit Cake (0.82) and Planet, which shrink


static func _list_w(width: float) -> float:
	return floorf((width - 2 * LIST_PAD) * 0.5 - 4)


func _inv_list(list: Control, inv: Array, pad: float, _w: float, y: float, width: float) -> Control:
	var lw := _list_w(width)
	for c in inv:
		var row := list_row(c.name, lw)
		row.position = Vector2(pad, y)
		_inv_cards[c.name] = row
		row.gui_input.connect(_on_card_input.bind(c.name))
		list.add_child(row)
		y += ROW_H + 6
	_inv_ring = _selected_ring(Vector2.ZERO, Vector2.ZERO)
	_inv_ring.visible = false
	list.add_child(_inv_ring)
	list.move_child(_inv_ring, 0)
	list.custom_minimum_size = Vector2(width, y + 150)
	return list


## A list row (the Inventory's 📋 view, the station shop's): the icon, the
## name with its suits, its components in one row under it. Its parent
## places it and wires its tap.
static func list_row(name: String, lw: float) -> Panel:
	var row := Panel.new()
	row.add_theme_stylebox_override("panel", Tok.box(Color("#f3e6c8"), 10, 1.5, Color("#c9a571"), 2, 1, Color(0, 0, 0, 0.25)))
	row.size = Vector2(lw, ROW_H)
	row.mouse_filter = MOUSE_FILTER_PASS
	row.set_meta("cmp", "inv:" + name)
	var ic := Tok.icon(Data.t("ITEM_EMOJI").get(name, ""), 30)
	ic.position = Vector2(6, (ROW_H - 30) / 2)
	row.add_child(ic)
	var x0 := 42.0
	var nm := Tok.label(name, 12, Tok.CARD_INK, 800)
	var nw := minf(Tok.font(800).get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, lw - x0 - 8)
	nm.clip_text = true
	nm.position = Vector2(x0, 5)
	nm.size = Vector2(nw + 2, 16)
	row.add_child(nm)
	var sx := x0 + nw + 5
	for su in Data.t("ITEM_SUIT_COST_TABLE").get(name, []):  # its suits, after the name
		if sx + 11 > lw - 4:
			break
		var g := Tok.icon("suit:" + su, 11)
		g.material = Tok.tinted(Tok.suit_color(su))
		g.position = Vector2(sx, 8)
		row.add_child(g)
		sx += 13
	row.add_child(row_parts(name, Vector2(x0, 27), lw - x0 - 6))
	return row


## A row's components in one line (elements first, then items by points; no
## "+"), at ROW_FIT, shrunk to fit room when wider. Planet's 16 elements
## shrink too.
static func row_parts(name: String, at: Vector2, room: float) -> Control:
	var e = Catalog.entry(name)
	var holder := Control.new()
	holder.position = at
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	if e == null:
		return holder
	var seen := {}
	var toks := []
	for r in e.reqs:
		if not seen.has(r.kind + ":" + r.name):
			seen[r.kind + ":" + r.name] = true
			toks.append(r)
	var pts: Dictionary = Data.t("ITEM_POINTS")
	toks = toks.filter(func(r): return r.kind == "element") + Util.stable_sort(toks.filter(func(r): return r.kind != "element"),
		func(a, b): return pts.get(a.name, 0) - pts.get(b.name, 0))
	var x := 0.0
	for r in toks:
		var part: Control
		if r.kind == "element":
			var l := Tok.label(r.name, 11, Color("#181614"), 800)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_stylebox_override("normal", Tok.box(Color.WHITE, 6, 1.5, Color.BLACK))
			l.clip_text = true
			l.size = Vector2(Tok.font(800).get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10, 22)
			part = l
		else:
			part = Tok.icon(Data.t("ITEM_EMOJI").get(r.name, ""), 22)
			part.size = Vector2(22, 22)
		part.position = Vector2(x, 0)
		part.mouse_filter = MOUSE_FILTER_IGNORE
		holder.add_child(part)
		x += part.size.x + 4
	var natural := maxf(1, x - 4)
	var k := minf(ROW_FIT, room / natural)
	holder.scale = Vector2(k, k)
	holder.set_meta("fit", k)
	holder.size = Vector2(natural, 22)
	return holder


## A tap (not a scroll) selects the card: its row goes on the Crafting Bench
## with Add / Remove (tap it again to put it back).
func _on_card_input(ev: InputEvent, name: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_at = ev.global_position
		elif ev.global_position.distance_to(_press_at) < 10:
			if Game.check_hand() != null:  # a check: a card laid is a card played; a tap shows it
				if App.current:
					App.current.show_card(name)
				return
			selected = "" if selected == name else name
			_redraw()


## Card playing (PLAN.md steps 14-15): under the mat Discard (left) and
## Draw (right: the Elements page, element draws); no Lock In: the check
## ends itself once nothing in the hand or deck fits; the hand
## fanned in two rows below. Picked hand cards play together from the hub's
## middle button (App._hand_tap), packed onto the mat automatically; what
## they'd add shows over the mat.
func _hand_area(h: Dictionary, page: Panel) -> void:
	picks = picks.filter(func(n): return h.hand.has(n))
	lifted = picks[0] if picks.size() == 1 else ""
	selected = ""
	var bottom := size.y - _hub_h - 18  # clear of the hub's raised buttons
	var row_y := page.position.y + page.size.y + 8
	var fl := Hand.fresh_left(h)
	_hand_button("discard", "🗑️", "Discard", str(h.tosses), Vector2(side, row_y), h.tosses <= 0 or picks.is_empty(), hand_discard)
	var draws := Hand.draws_left(h, Game.state)
	_hand_button("draw", "🃏", "Draw", str(draws), Vector2(size.x - side - BTN, row_y), draws <= 0, _flip_view, view == "elements")
	# The deck's count in the middle; a tap: the whole Inventory, to plan (the user, 2026-11-23).
	# Done beside it: stop playing and lock in (the user, 2026-11-24: a hand with nothing that fits).
	var dw := 124.0
	var dx := (size.x - dw - 8 - BTN) / 2
	_hand_button("pass", "🏁", "Done", "", Vector2(dx + dw + 8, row_y), false, hand_pass)
	var deck := _round_button("", Vector2(dw, 46), 13, Color("#1c2b3d"))
	deck.position = Vector2(dx, row_y + (BTN - 46) / 2)
	deck.set_meta("cmp", "hand:deck")
	var dn := Tok.label("%d in deck" % h.deck.size(), 14, Color.WHITE, 900)
	dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dn.position = Vector2(0, 5)
	dn.size = Vector2(dw, 20)
	dn.mouse_filter = MOUSE_FILTER_IGNORE
	deck.add_child(dn)
	var sub := Tok.label("%d new · see all" % fl if fl else "Tap: see them all", 10, Color("#ffe08a"), 800)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 25)
	sub.size = Vector2(dw, 14)
	sub.mouse_filter = MOUSE_FILTER_IGNORE
	deck.add_child(sub)
	deck.pressed.connect(func():
		browsing = true
		picks = []
		_redraw())
	_body.add_child(deck)
	if not _ending and HandView.deal_at >= 0 and Hand.mat_full(h, Game.state) and App.current:  # nothing more fits: the check ends itself
		_ending = true
		var app := App.current
		get_tree().create_timer(0.9).timeout.connect(func(): if is_instance_valid(app) and is_same(Game.check_hand(), h): app.hand_lock_in())
	var top_y := row_y + BTN + 4
	_hand_view = HandView.new()
	_hand_view.position = Vector2(0, top_y)
	_hand_view.size = Vector2(size.x, bottom - top_y)
	_body.add_child(_hand_view)
	_hand_view.show_hand(h.hand, lifted, picks)
	_hand_view.lift.connect(_lift)
	_show_preview()
	StationScreen.corner_buttons(_body, false)  # Convert, as on the station
	if App.current:
		App.current.sync_hub()


## Done: no more plays this check, lock in. Asks first while a hand card
## still fits (a slip of the finger shouldn't end the check).
func hand_pass() -> void:
	if Game.check_hand() == null or playing or App.current == null:
		return
	var app := App.current
	if Game.check_hand().hand.any(func(n): return Hand.fits(Game.state, [n])):
		ConfirmDialog.ask(app, "Finish this check now?\nSome cards in your hand still fit on the mat.", app.hand_lock_in)
	else:
		app.hand_lock_in()


## Faded in the Inventory: on the mat, or (browsing mid-check) discarded:
## what's left shows what can still be drawn (the user, 2026-11-24).
func _spent(n: String) -> bool:
	var h = Game.check_hand()
	return Game.state.mat.has(n) or (browsing and h != null and h.discards.has(n))


## Draw: the mat's Elements page (spend an element on a card), or back.
func _flip_view() -> void:
	view = "mat" if view == "elements" else "elements"
	_redraw()


const BTN := 54.0  # Discard and Draw: round, the Convert button's look


## Discard / Draw: a round gold button with its icon, its name under it and
## a count badge; dimmed when it can't be used (its tap still says why).
func _hand_button(id: String, icon: String, label: String, badge: String, at: Vector2, dim: bool, fn: Callable, lit := false) -> void:
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color("#fff3d6") if lit else Tok.GOLD, BTN / 2, 3, Color("#ffe08a") if lit else Color("#5c4a20"), 4, 3, Color(0, 0, 0, 0.35)))
	b.position = at
	b.size = Vector2(BTN, BTN)
	b.set_meta("cmp", "hand:" + id)
	var ic := Tok.icon(icon, 28)
	ic.position = Vector2((BTN - 28) / 2, 7)
	ic.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var l := Tok.label(label, 10, Tok.CARD_INK, 900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, BTN - 18)
	l.size = Vector2(BTN, 12)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(l)
	if badge != "":
		b.add_child(HubBar._badge(badge, Vector2(BTN - 16, -6)))
	if dim:
		b.modulate = Color(0.6, 0.6, 0.6, 0.75)
	b.gui_input.connect(func(ev): if Tap.tap(ev): fn.call())
	_body.add_child(b)


## A hand card tapped: picked, or put back if it was ("": a blank tap in
## the hand, let go of them all); any number. Changes only the hand
## and the preview, not the whole drawer (a full redraw took ~100ms on a PC
## with a turn-18 mat).
func _lift(n: String) -> void:
	if n == "":
		picks = []
	elif picks.has(n):
		picks.erase(n)
	else:
		picks.append(n)
	lifted = picks[0] if picks.size() == 1 else ""
	if view == "elements" and not picks.is_empty():  # picking to play: the mat again
		view = "mat"
		_redraw()
		return
	_hand_view.show_hand(Game.state.hand.hand, lifted, picks)
	var dis := _find_cmp(_body, "hand:discard")
	if dis:
		dis.modulate = Color(0.6, 0.6, 0.6, 0.75) if picks.is_empty() or Game.state.hand.tosses <= 0 else Color.WHITE
	_show_preview()
	if App.current:
		App.current.sync_hub()


## A tap on a blank space: nothing picked any more.
func _blank_tap(ev: InputEvent) -> void:
	if Tap.tap(ev) and (not picks.is_empty() or selected != ""):
		picks = []
		lifted = ""
		selected = ""
		_redraw()


## With cards picked: what playing them would add to the score, in a pill
## over the mat's top edge (or that they don't fit).
func _show_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	var after = Hand.score_after(Game.state, Game.ctx, picks) if not picks.is_empty() else null
	_fits = after != null
	if picks.is_empty() or not is_instance_valid(_page) or view != "mat":
		return
	var before := Game.mat_score()
	var g = after.total - before.total if after != null else null
	var d := roundi(g) if g != null else 0
	var pill := Tok.label("No room on the mat" if g == null else "+%d" % d if d > 0 else "%d" % d if d < 0 else "±0", 13, Color.WHITE, 900)
	pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := Tok.box(Tok.MUTE if g == null or d == 0 else Tok.OK if d > 0 else Tok.BAD, 10, 2, Color.WHITE, 3, 2, Color(0, 0, 0, 0.4))
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	pill.add_theme_stylebox_override("normal", sb)
	pill.size = pill.get_minimum_size()
	pill.position = Vector2((_page.size.x - pill.size.x) / 2, 6)
	pill.mouse_filter = MOUSE_FILTER_IGNORE
	pill.set_meta("cmp", "hand:gain")
	# Before Play: the combos the picks would make or grow, and the score
	# they'd bring the mat to (the user, 2026-11-24: playing blind was too
	# much of a gamble against the breakpoint).
	var shown: Control = pill
	if after != null:
		var chips := _preview_chips(before, after)
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", Tok.box(Color(1, 0.953, 0.839, 0.96), 12, 2, Tok.GOLD, 0, 3, Color(0, 0, 0, 0.35)))
		box.mouse_filter = MOUSE_FILTER_IGNORE
		var x := 8.0
		var ch := 0.0
		for c in chips:
			c.position = Vector2(x, 4)  # its count badge rides 6px up
			c.size = c.custom_minimum_size
			Juice._ignore_mouse(c)
			box.add_child(c)
			x += c.size.x + 2
			ch = maxf(ch, c.size.y)
		var tot := Tok.label("= %d" % roundi(after.total), 13, Tok.CARD_INK, 900)
		var bh := maxf(ch + 6, 32)
		pill.position = Vector2(x + 4, (bh - pill.size.y) / 2)
		box.add_child(pill)
		tot.position = Vector2(pill.position.x + pill.size.x + 11, (bh - tot.get_minimum_size().y) / 2)
		tot.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(tot)
		box.size = Vector2(tot.position.x + tot.get_minimum_size().x + 10, bh)
		box.position = Vector2((_page.size.x - box.size.x) / 2, 4)
		box.set_meta("cmp", "hand:preview")
		shown = box
	var layer := Control.new()  # the lit slots, then the pill over them: one queue_free clears it all
	layer.size = _page.size
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(layer)
	_preview = layer
	if g != null:
		for r in _landings(picks):  # where each picked card would go, lit (the user, 2026-11-23)
			var lit := Panel.new()
			lit.add_theme_stylebox_override("panel", Tok.box(Color(Tok.OK, 0.28), 10, 3, Tok.OK))
			lit.position = r.position
			lit.size = r.size
			lit.mouse_filter = MOUSE_FILTER_IGNORE
			lit.set_meta("cmp", "hand:landing")
			layer.add_child(lit)
	layer.add_child(shown)


## Each combo's count as its chip shows it (combo_chips()).
static func _combo_counts(sc: Dictionary) -> Dictionary:
	var n := {}
	for kind in ["station", "suit", "component"]:
		for g in sc.combos[kind]:
			n[kind + ":" + g.name] = int(g.k)
	for t in sc.together.combos:
		n[t.kind + ":" + t.name] = n.get(t.kind + ":" + t.name, 0) + int(t.k)
	var found: Array = Util.get_or(Progress.prefs, "everUnlockedMatCollections", [])
	n.collection = sc.cols.filter(func(c): return found.has(c.id)).size()
	n.new = sc.cols.size() - n.collection
	return n


## The chips a play would add or grow (before -> after), and a chip for
## each item it would complete (with its recipe: x2, x3 made in one play).
static func _preview_chips(before: Dictionary, after: Dictionary) -> Array:
	var was := _combo_counts(before)
	var now := _combo_counts(after)
	var out := []
	for c in combo_chips(after, false):
		var k: String = c.get_meta("combo", "")
		if k != "" and now.get(k, 0) != was.get(k, 0):
			out.append(c)
		else:
			c.free()
	var homestead: bool = after.sigs.any(func(g): return g.name == "Homestead")
	for nm in after.completeNames:
		if not before.completeNames.has(nm):
			var x: int = (3 if homestead else 2) + (1 if after.together.complete.has(nm) else 0)
			out.append(_chip(_icon_circle(Data.t("ITEM_EMOJI").get(nm, ""), Tok.PARCHMENT, Tok.GOLD, 2), "×%d" % x, 12))
	return out


## Where the picked cards would sit on the page (the mat packed with them:
## a capstone over two slots, tier 1 cards in their share of a stack).
func _landings(names: Array) -> Array:
	var cards: Array = names.map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
	var pack := Mat.pack(Mat.on_mat(Game.state) + cards, _stage())
	var out := []
	for i in pack.slot.size():
		var sl: Dictionary = pack.slot[i]
		if not slot_rects.has(i):
			continue
		var r: Rect2 = slot_rects[i]
		r.position -= _page.position
		if sl.has("card") and names.has(sl.card.name):
			if sl.w > 1 and slot_rects.has(i + 1):
				r = r.merge(Rect2(slot_rects[i + 1].position - _page.position, slot_rects[i + 1].size))
			out.append(r)
		var stack: Array = sl.get("stack", [])
		for k in stack.size():
			if names.has(stack[k].card.name):
				var per: int = 1 if sl.kind == "top" else pack.L.perSlot
				var mh := (r.size.y - (per - 1) * 2) / per
				out.append(Rect2(r.position + Vector2(0, k * (mh + 2)), Vector2(r.size.x, mh)))
	return out


## Can the picked cards be played (the hub's Play in full colour)?
func can_play() -> bool:
	return not picks.is_empty() and not playing and _fits


## The hub's Discard: the picked hand cards (any number), for
## one discard; the hand refills 1 for 1.
func hand_discard() -> void:
	var h = Game.check_hand()
	if h == null or playing:
		return
	if picks.is_empty():
		_show_toast("Tap cards in your hand first.")
		return
	var msg := Hand.discard(h, picks)
	if msg != "":
		_show_toast(msg)
		return
	picks = []
	lifted = ""
	Game._changed()


## Play (the hub's middle button): the picked cards onto the mat, packed
## automatically; each flies from the hand into its place. A mat with no
## room left for anything ends the check (App.hand_lock_in).
func hand_play() -> void:
	var h = Game.check_hand()
	if h == null or playing:
		return
	if picks.is_empty():
		_show_toast("Tap cards in your hand to play them.")
		return
	var played := picks.duplicate()
	var gain = Hand.gain(Game.state, Game.ctx, played)
	if gain == null:
		_show_toast(Hand.play(h, Game.state, played))  # why not (changes nothing)
		return
	var tg := Mat.together(Mat.on_mat({"mat": played}), {"matPlays": [played]})
	if not (tg.combos.is_empty() and tg.complete.is_empty() and tg.cols.is_empty()):
		playing = true  # the reveal: no redraws, no second Play
		var banner := _together_banner(tg, gain)
		if is_instance_valid(_hand_view):
			for c in _hand_view.get_children():
				if c.has_meta("hand") and played.has(c.get_meta("hand")):
					bounce(c)
		await get_tree().create_timer(0.9 if Juice.calm() else 1.5).timeout
		if not is_instance_valid(self):
			return
		banner.queue_free()
		playing = false
		if not is_same(Game.check_hand(), h):
			return
	var from := {}
	if is_instance_valid(_hand_view):
		for c in _hand_view.get_children():
			if c.has_meta("hand") and picks.has(c.get_meta("hand")) and (not from.has(c.get_meta("hand")) or c.get_meta("cmp", "") == "hand:lifted"):
				from[c.get_meta("hand")] = c.get_global_rect()
	var msg := Hand.play(h, Game.state, played)
	if msg != "":
		_show_toast(msg)
		return
	view = "mat"
	picks = []
	lifted = ""
	Game._changed()
	Juice.buzz()
	for n in played:
		var to := _mat_nodes.get(n) as ItemCard
		if to and from.has(n):  # its look there: a small card stays small
			Juice.fly(ItemCard.make(n, to.opts.duplicate()), from[n], to)


## "Played together!": the combos, whole recipes and collections a play
## makes by itself (each counts once more), and what the play adds, over
## the top of the hand.
func _together_banner(tg: Dictionary, gain: float) -> Control:
	var chips := []
	for t in tg.combos:
		var icon: String = Catalog.station(t.name).emoji if t.kind == "station" else "suit:" + t.name if t.kind == "suit" else Data.t("ITEM_EMOJI").get(t.name, "")
		var bg: Color = Tok.station_color(t.name) if t.kind == "station" else Tok.suit_color(t.name) if t.kind == "suit" else Tok.PARCHMENT
		chips.append(_counted(_icon_circle(icon, bg, Color.TRANSPARENT, 0, t.kind != "suit"), t.k))
	for n in tg.complete:
		chips.append(_chip(_icon_circle(Data.t("ITEM_EMOJI").get(n, ""), Tok.PARCHMENT, Tok.GOLD, 2), "×3", 13))
	for col in tg.cols:
		var star := _icon_circle("", Color("#241c3a"), Color("#8a5ce0"), 1.5)
		var st_ic := Tok.star(Color("#ffd166"), 15)
		st_ic.position = Vector2(6, 5.5)
		star.add_child(st_ic)
		chips.append(_chip(star, "+%d" % int(col.bonus), 13))
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Tok.box(Color("#fff3d6"), 16, 3, Tok.GOLD, 8, 4, Color(0, 0, 0, 0.45)))
	box.mouse_filter = MOUSE_FILTER_STOP  # nothing under it while it shows
	box.set_meta("cmp", "hand:together")
	var title := Tok.label("Played together!", 16, Tok.CARD_INK, 900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var x := 14.0
	var ch := 0.0
	for c in chips:
		c.position = Vector2(x, 34)
		c.size = c.custom_minimum_size
		box.add_child(c)
		x += c.size.x + 6
		ch = maxf(ch, c.size.y)
	var plus := Tok.label("+%d" % roundi(gain), 22, Tok.OK, 900)
	plus.position = Vector2(x + 4, 34 + (ch - plus.get_minimum_size().y) / 2)
	box.add_child(plus)
	box.size = Vector2(maxf(200, x + 8 + plus.get_minimum_size().x + 14), 34 + ch + 12)
	title.size = Vector2(box.size.x, 30)
	title.position.y = 6
	box.position = Vector2((size.x - box.size.x) / 2, (_hand_view.position.y if is_instance_valid(_hand_view) else size.y / 2) - 8)
	_body.add_child(box)
	Juice.pop_in(box)
	return box


static func _find_cmp(n: Node, tag: String) -> Control:
	for c in n.get_children():
		if c.get_meta("cmp", "") == tag and not c.is_queued_for_deletion():
			return c
	return null


## Last: back to the last locked-in mat (asks first, quick-saving this one);
## with a quick save, it comes straight back.
func _last() -> void:
	if Game.state.get("quickSavedMat") != null:
		Game.mat_last_tap()
		return
	ConfirmDialog.ask(App.current if App.current else self,
		"Reset the Display Mat to your last locked-in layout? Your current mat is quick-saved -- tap the arrow again to bring it back.",  # ↻ isn't in Nunito
		Game.mat_last_tap)


## Add / Remove for the selected card (#matListActions), centred in a
## column w wide from x at y. The Crafting Bench that held its row is gone
## from the Inventory (the user, 2026-11-22: the card shows it all).
func _sel_acts(x: float, y: float, w: float) -> void:
	if locked():  # between checks the mat is locked in
		return
	var on: bool = Game.state.mat.has(selected)
	var card = Catalog.mat_card(selected)
	var fits: bool = card != null and Mat.fits(Mat.on_mat(Game.state) + [card], Mat.stage(Game.state))
	var acts := Control.new()
	acts.position = Vector2(x, y)
	acts.mouse_filter = MOUSE_FILTER_IGNORE
	var bw := minf(96, (w - 8) / 2)
	var bx := (w - (bw * 2 + 8)) / 2
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
		b.position = Vector2(bx + i * (bw + 8), 0)
		b.size = Vector2(bw, 34)
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


## The Elements page: every element held, 8 to a row (elementsGridHTML()).
func _elements(page: Control) -> void:
	var hand = Game.check_hand()
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
		if hand != null:  # a check with cards: 1 of it draws a card of its suit
			box.mouse_filter = MOUSE_FILTER_STOP
			box.set_meta("cmp", "el:" + sym)
			box.gui_input.connect(func(ev): if Tap.tap(ev): _element_draw(hand, sym))
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
	var unknown := int(Util.get_or(Game.state, "emptyElements", 0))
	if hand != null and unknown > 0:  # a check with cards: an Unknown Element picks any deck card
		var at := Vector2(7 + (held.size() % 8) * (cw + 5), 7 + (held.size() / 8) * (cw + 3 + 12 + 6))
		var sq := LockInReward.unknown_square(cw)
		sq.position = at
		sq.mouse_filter = MOUSE_FILTER_STOP
		sq.set_meta("cmp", "el:?")
		sq.gui_input.connect(func(ev): if Tap.tap(ev):
			if hand.hand.size() >= Hand.most() or hand.deck.is_empty():
				_show_toast("Your hand is full." if not hand.deck.is_empty() else "The deck is empty.")
			elif App.current:
				CardPick.show_on(App.current))
		page.add_child(sq)
		var q := Tok.label(str(unknown), 9, Color("#3b2412"), 800)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.position = at + Vector2(0, cw + 3)
		q.size = Vector2(cw, 12)
		page.add_child(q)
	if hand != null and not (held.is_empty() and unknown == 0):
		var tip := Tok.label("Tap an element to spend 1 and draw a card of its suit.", 12, Color("#8a6a48"), 800)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.position = Vector2(7, page.size.y - 24)
		tip.size = Vector2(page.size.x - 14, 18)
		tip.clip_text = true
		page.add_child(tip)
	if held.is_empty():
		var none := Tok.label("No loose elements — visit a station and roll.", 14, Color("#8a6a48"), 400)
		none.position = Vector2(12, 12)
		page.add_child(none)


## An element's draw, asked first (the user: elements are precious).
func _element_draw(hand: Dictionary, sym: String) -> void:
	if Hand.suit_card(hand, sym) == "" or hand.hand.size() >= Hand.most():
		_show_toast(Hand.suit_draw(hand, Game.state, sym))  # why not (spends nothing)
		return
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	ConfirmDialog.ask(App.current if App.current else self,
		"Spend 1 %s to draw a %s card?" % [Data.t("ELEMENT_NAMES").get(sym, sym), Data.t("ELEMENT_SUIT_LABEL").get(suit, suit)],
		func():
			if Hand.suit_draw(hand, Game.state, sym) == "":
				Game._changed())


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
	t.position = Vector2((size.x - t.size.x) / 2, size.y - _hub_h - 16 - t.size.y)
	add_child(t)
	Juice.pop_in(t)
	get_tree().create_timer(2.0).timeout.connect(t.queue_free)


## The combo row: the challenge in force, capstone effects, station / suit /
## component groups, then the collections star. Returns its height.
func _chips(sc: Dictionary, at: Vector2, w: float) -> float:
	var chips := combo_chips(sc)
	if chips.is_empty():  # .mm-combo-none, centred in the row's 40px
		var hint := Tok.label("Three cards alike start a combo", 11.5, Tok.MUTE)
		hint.position = at + Vector2(0, (40 - hint.get_minimum_size().y) / 2)
		_body.add_child(hint)
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
		chips[-1].set_meta("tip", "order")  # the challenge hint's 💡
		chips[-1].gui_input.connect(func(ev): if Tap.tap(ev) and App.current: OrderInfo.open(App.current))
	for g in sc.sigs:  # every owned capstone, always on beside the mat: a tap shows its card (the user, 2026-11-26)
		var cap := _chip(_icon_circle(Data.t("ITEM_EMOJI")[g.name], Tok.PARCHMENT, Tok.GOLD, 2), g.label, 13, 0.45 if not g.on else 1.0)
		cap.set_meta("cap", g.name)
		Juice._ignore_mouse(cap)
		cap.mouse_filter = MOUSE_FILTER_STOP
		var nm: String = g.name
		cap.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.show_card(nm))
		chips.append(cap)
	var twice := {}  # a combo made inside a play counts again: its count too (3 played together: 6)
	for t in sc.get("together", {}).get("combos", []):
		twice[t.kind + ":" + t.name] = twice.get(t.kind + ":" + t.name, 0) + int(t.k)
	for g in sc.combos.station:
		chips.append(_counted(_icon_circle(Catalog.station(g.name).emoji, Tok.station_color(g.name), Color.TRANSPARENT, 0, true), g.k + twice.get("station:" + g.name, 0)))
		chips[-1].set_meta("combo", "station:" + g.name)
	for g in sc.combos.suit:
		chips.append(_counted(_icon_circle("suit:" + g.name, Tok.suit_color(g.name)), g.k + twice.get("suit:" + g.name, 0)))
		chips[-1].set_meta("combo", "suit:" + g.name)
	for g in sc.combos.component:
		var em = Data.t("ITEM_EMOJI").get(g.name)
		chips.append(_counted(_icon_circle(em if em else "", Tok.PARCHMENT, Color.TRANSPARENT, 0, true), g.k + twice.get("component:" + g.name, 0)))
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
		if c.has_meta("cap"):
			_chip_nodes["cap:" + c.get_meta("cap")] = c
		if c.has_meta("combo"):
			_chip_nodes[c.get_meta("combo")] = c
			var combo: String = c.get_meta("combo")
			if combo != "order":  # the challenge opens its own window; the rest: who makes the combo (the user, 2026-11-23)
				Juice._ignore_mouse(c)  # its circle and count take no taps: the chip does
				c.mouse_filter = MOUSE_FILTER_STOP
				c.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: ComboInfo.open_for(App.current, combo))
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
				"rainbow": Data.t("ITEM_EMOJI")["Rainbow"], "grandTour": "🗺️",
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
	var st := _stage()
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
		slot_rects[i] = Rect2(page.position + pos, Vector2(col_w * sl.get("w", 1) + cols_gap * (sl.get("w", 1) - 1), row_h if sl.has("card") or sl.has("stack") and sl.kind != "top" else h))
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
			var mh := h if sl.kind == "top" else (row_h - (per - 1) * 2) / per  # the half-height strip holds one
			for k in per:
				var at := pos + Vector2(0, k * (mh + 2))
				if k < stack.size():
					if stack[k].card.name == selected:
						page.add_child(_selected_ring(at, Vector2(col_w, mh)))
					var mini := ItemCard.make(stack[k].card.name, card_opts.call(stack[k].card, true))
					mini.gui_input.connect(_on_card_input.bind(stack[k].card.name))
					mini.position = at
					mini.size = Vector2(col_w, mh)
					page.add_child(mini)
					_mat_nodes[stack[k].card.name] = mini
				elif k == stack.size():
					page.add_child(_dashed(Rect2(at, Vector2(col_w, mh)), 10))
					_empties.append(Rect2(at, Vector2(col_w, mh)))
		else:
			page.add_child(_dashed(Rect2(pos, Vector2(col_w, h)), 12))
			_empties.append(Rect2(pos, Vector2(col_w, h)))


func _stage() -> int:
	return stage_override if stage_override >= 0 else Mat.stage(Game.state)


## The mat as it was before this check grew it (under the shutter, before
## grow()); held so nothing redraws it until grow() runs.
func show_stage(st: int) -> void:
	stage_override = st
	_redraw()
	playing = true


## The mat growing (the user, 2026-11-22): from the old stage show_stage()
## drew to the real one. The page eases to its new size; each card slides and
## resizes from its old slot to its new one; everything new (empty slots,
## cards that didn't fit before, the tabs) fades in after. Returns the
## page's rect before and after, for the reveal's hole to follow.
func grow(secs := 0.9) -> Array:
	var was := {}
	for n in _mat_nodes:
		was[n] = Rect2(_mat_nodes[n].position, _mat_nodes[n].size)
	var from := Rect2(_page.position, _page.size)
	stage_override = -1
	playing = false
	_redraw()
	var to := Rect2(_page.position, _page.size)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_page.size = from.size
	tw.tween_property(_page, "size", to.size, secs)
	var moved := []
	for n in _mat_nodes:
		if was.has(n):
			var c: Control = _mat_nodes[n]
			moved.append(c)
			var at := Rect2(c.position, c.size)
			c.position = was[n].position  # now, not when the tween starts: no frame at the end first
			c.size = was[n].size
			tw.tween_property(c, "position", at.position, secs)
			tw.tween_property(c, "size", at.size, secs)
	for c in _page.get_children():
		if not moved.has(c):
			c.modulate.a = 0.0
			tw.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(secs)
	return [from, to]


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
	d.mouse_filter = MOUSE_FILTER_IGNORE  # a tap on an empty slot is a blank tap (the page's)
	return d
