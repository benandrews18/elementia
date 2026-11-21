## A station (renderStation(), station.css): the station's art behind
## everything; the dark header (icon, name, its six elements, the crafted
## items folded into a bar); then the shop as cards with a pin and a Craft
## button under each. The page scrolls under the Quark bar.
class_name StationScreen
extends Control

## The layout is ui/screens/station.tscn: the art and its wash, the header
## (icon, title, labels, the crafted bar), the shop's heading. This fills
## them in from the station and packs the shop with the numbers below.
const SCENE := "res://ui/screens/station.tscn"
const TOP := QuarkTopBar.H

## The shop: columns, the gap between cards, a card's height to its width,
## and the pin / Craft row's height under each card.
@export var columns := 4
@export var gap := 8.0
@export var card_ratio := 1.4
@export var act_h := 35.0

var open_card := ""  # the shop card whose row is on the Crafting Bench (stationCardOpen)
var _press_at := Vector2.ZERO
@onready var _scroll: ScrollContainer = $Scroll
@onready var _page: Control = $Scroll/Page


static func make() -> StationScreen:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
	_redraw()


func _redraw() -> void:
	if is_queued_for_deletion() or not Game.ctx.get("current"):
		return  # leaving the station: the app is swapping this screen out
	var keep := _scroll.scroll_vertical
	for holder in [$Scroll/Page/Chips, $Scroll/Page/Fold, $Scroll/Page/Crafted, $Scroll/Page/View, $Scroll/Page/Bench, $Scroll/Page/Shop, $Top]:
		for c in holder.get_children():
			c.queue_free()
	var name: String = Game.ctx.current
	var st := Catalog.station(name)
	var w := size.x
	# The station's art, full width from the top, fixed behind the page.
	var art: TextureRect = $Art
	art.texture = load("res://assets/" + Data.t("STATION_BG")[name])
	art.size = Vector2(w, w * art.texture.get_height() / art.texture.get_width())
	$Wash.size = art.size
	_scroll.position = Vector2(0, TOP)
	_scroll.size = Vector2(w, size.y - TOP)
	var y := _header(_page, st, w)
	if open_card != "":
		y = _bench(_page, w, y)
	y = _shop(_page, name, w, y)
	_page.custom_minimum_size = Vector2(w, y + HubBar.H + 80)
	_scroll.set_deferred("scroll_vertical", keep)
	if Game.state.get("matChecked"):
		var qt := QuarkTopBar.make()
		qt.size = Vector2(w, TOP)
		$Top.add_child(qt)
	corner_buttons($Top, true)


## The dark header: icon and name, the element chips, the crafted-items bar.
## Returns where the shop starts (page coordinates).
func _header(page: Control, st: Dictionary, w: float) -> float:
	$Scroll/Page/Icon.texture = Data.icon(st.emoji)
	$Scroll/Page/Title.text = st.name
	# Six chips in a row, centred, 4px apart (.gather / .gchip).
	var dice := Catalog.sorted_dice(st)
	var cw := (w - 44 - 4 * (dice.size() - 1)) / dice.size()
	for i in dice.size():
		var chip := element_chip(dice[i], cw)
		chip.position = Vector2(22 + i * (cw + 4), 98.8)
		chip.get_child(0).set_meta("cmp", "st:chip%d" % i)
		var sym: String = dice[i]
		chip.mouse_filter = MOUSE_FILTER_PASS  # a tap opens its card; a drag still scrolls
		chip.gui_input.connect(_on_tap.bind(func(): if App.current: App.current.show_element_card(sym)))
		$Scroll/Page/Chips.add_child(chip)
	# The fold button, the crafted icons in the bar, the list/cards switch.
	var bar: Control = $Scroll/Page/Bar
	var row_y := bar.position.y
	$Scroll/Page/Fold.add_child(_round_btn(Vector2.ZERO, true))
	if Game.state.get("collapseCraftedItems"):
		var x := bar.position.x + 9
		for e in _sorted(shop_entries(st.name)):
			if Catalog.owns(Game.state, e.name) and e.tier != "CAPSTONE":
				var i2 := Tok.icon(e.emoji, 18)
				i2.position = Vector2(x + 3, row_y + 8.3)
				var item: String = e.name
				i2.mouse_filter = MOUSE_FILTER_PASS
				i2.gui_input.connect(_on_tap.bind(func(): if App.current: App.current.show_card(item)))
				$Scroll/Page/Crafted.add_child(i2)
				var t := Tok.tick(Color.WHITE, 14, Tok.OK, Tok.CARD)  # .station-item-icon.owned::after
				t.position = Vector2(x + 24 - 9, row_y + 5 - 5)
				$Scroll/Page/Crafted.add_child(t)
				x += 29
	$Scroll/Page/View.add_child(_round_btn(Vector2.ZERO, false))
	return $Scroll/Page/Head.size.y


## Craft through the app (it asks which elements pay a suit cost); alone
## (tests), the simulator's picks.
func _craft(n: String, at: Rect2) -> void:
	if App.current:
		App.current.craft_tap(n, at)
	else:
		Game.craft(n, Game.suggest_suit_picks(n))


## The Crafting Bench under the header: the tapped card's shop row (craft
## and pin from it) and the close button. Returns where the shop starts.
func _bench(page: Control, w: float, y: float) -> float:
	var e = Catalog.entry(open_card)
	if e == null:
		return y
	var bench := BenchPanel.new()
	var craft := func(n, at: Rect2): _craft(n, at)
	var pin := func(n):
		Progress.toggle_pin(n)
		Game._changed()  # saves, then redraws
	bench.add_child(ShopRow.make(e, w - 36, craft, pin))
	bench.position = Vector2(0, y)
	bench.size = Vector2(w, 30 + ShopRow.H + 18)
	page = $Scroll/Page/Bench
	page.add_child(bench)
	var close := TextureRect.new()
	close.texture = load("res://assets/ui/btn_close.webp")
	close.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close.position = Vector2(w - 20 - 34, y + bench.size.y - 4 - 34)
	close.size = Vector2(34, 34)
	close.mouse_filter = MOUSE_FILTER_PASS
	close.gui_input.connect(_on_tap.bind(func():
		open_card = ""
		_redraw()))
	page.add_child(close)
	return y + bench.size.y


## sortShopItems(): the fundamentals first (FUNDAMENTAL_ITEMS order), then by points.
static func _sorted(entries: Array) -> Array:
	var fund: Array = Data.t("FUNDAMENTAL_ITEMS")
	var rank := func(n): return fund.find(n) if fund.has(n) else 999
	var pts: Dictionary = Data.t("ITEM_POINTS")
	return Util.stable_sort(entries, func(a, b): return rank.call(a.name) - rank.call(b.name) if rank.call(a.name) != rank.call(b.name) else pts.get(a.name, 0) - pts.get(b.name, 0))


## Station shop: open items here (entriesAt()), in data order.
static func shop_entries(station: String) -> Array:
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	return Data.t("ENTRIES").filter(func(e): return e.station == station \
		and (not unlocked.has(e.name) or Catalog.owns(Game.state, unlocked[e.name])))


## shopCardsHTML(): tier 1 (half height) in rows of 4, then the rest, a
## capstone 2 wide (dense: later cards fill the gaps it leaves). Folded
## crafted items leave the grid.
func _shop(page: Control, station: String, w: float, y: float) -> float:
	var s := Game.state
	y += 18
	$Scroll/Page/ShopLabel.position.y = y
	$Scroll/Page/ShopLine.position.y = y + 23.5
	y += 25.5 + 10
	page = $Scroll/Page/Shop
	var fold: bool = s.get("collapseCraftedItems", false)
	var shown := shop_entries(station).filter(func(e): return not (fold and Catalog.owns(s, e.name) and e.tier != "CAPSTONE"))
	var col_w := (w - 12 - (columns - 1) * gap) / columns
	var row_h := col_w * card_ratio
	var groups := [shown.filter(func(e): return e.tier == "MATERIAL"),
		shown.filter(func(e): return e.tier == "COMPONENT") + shown.filter(func(e): return e.tier == "CREATION") + shown.filter(func(e): return e.tier == "CAPSTONE")]
	for gi in 2:
		var items: Array = groups[gi]
		if items.is_empty():
			continue
		var card_h := (row_h - 2) / 2 if gi == 0 else row_h
		var cell_h := card_h + 3 + act_h
		var taken := {}  # "row,col" -> true (dense packing)
		var rows := 0
		for e in items:
			var span := 2 if e.tier == "CAPSTONE" else 1
			var at := _first_free(taken, span, columns)
			for k in span:
				taken["%d,%d" % [at.x, at.y + k]] = true
			rows = maxi(rows, at.x + 1)
			var pos := Vector2(6 + at.y * (col_w + gap), y + at.x * (cell_h + gap))
			_cell(page, e, pos, Vector2(col_w * span + gap * (span - 1), card_h), gi == 0)
		y += rows * cell_h + (rows - 1) * gap + 12
	return y


static func _first_free(taken: Dictionary, span: int, columns := 4) -> Vector2i:
	var r := 0
	while true:
		for c in range(0, columns + 1 - span):
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
	if e.name == open_card:  # .selected: 4px gold outline, 2px out
		var sel := Panel.new()
		sel.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 17 if not t1 else 15, 4, Color("#d9a441")))
		sel.position = pos - Vector2(6, 6)
		sel.size = card_size + Vector2(12, 12)
		sel.mouse_filter = MOUSE_FILTER_IGNORE
		page.add_child(sel)
	var card := ItemCard.make(e.name, {"mini": t1, "wide": e.tier == "CAPSTONE", "tag": "st:" + e.name})
	card.position = pos
	card.size = card_size
	card.gui_input.connect(_on_tap.bind(func():  # the card's row on the Crafting Bench
		open_card = "" if open_card == e.name else e.name
		_redraw()))
	if owned:
		card.modulate = Color(0.7, 0.7, 0.7)
	page.add_child(card)
	if owned:  # .st-owned::after: a green tick, bottom right
		var tick := Tok.tick(Color.WHITE, 20, Tok.OK)
		tick.position = pos + card_size - Vector2(15, 15)
		page.add_child(tick)
	var ay := pos.y + card_size.y + 3
	# Pin and Craft (60px, shrinking to fit) centred under the card (.st-acts).
	var acts_w := minf(card_size.x, act_h + 3 + 60)
	var ax := pos.x + (card_size.x - acts_w) / 2
	var acts := ShopActs.make()
	acts.position = Vector2(ax, ay)
	acts.show_state(acts_w, act_h, Progress.is_pinned(e.name), can, owned)
	var pin: Control = acts.get_node("Pin")
	pin.gui_input.connect(_on_tap.bind(func(): Progress.toggle_pin(e.name); Game._changed()))  # saves, then redraws
	pin.set_meta("cmp", "st:pin:" + e.name)
	var btn: Control = acts.get_node("Craft")
	if can:
		btn.gui_input.connect(_on_tap.bind(func(): _craft(e.name, btn.get_global_rect())))
	btn.set_meta("cmp", "st:craft:" + e.name)
	page.add_child(acts)


## A white element chip with its suit-coloured border, atomic number, the
## suit badge in the corner and the name under it (.gchip, .gname). Its look
## is ui/pieces/element_chip.tscn; the colours and sizes come from the element
## and w. The name stays the last child (callers recaption or hide it).
static func element_chip(sym: String, w: float) -> Control:
	var col: Control = load("res://ui/pieces/element_chip.tscn").instantiate()
	col.size = Vector2(w, w + 13.8)
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
	var chip: Panel = col.get_node("Chip")
	var sb: StyleBoxFlat = chip.get_theme_stylebox("panel").duplicate()
	sb.border_color = color
	chip.add_theme_stylebox_override("panel", sb)
	chip.size = Vector2(w, w)
	var sym_l: Label = col.get_node("Sym")
	sym_l.text = sym
	sym_l.add_theme_font_size_override("font_size", int(round(minf(32, 0.55 * w))))
	sym_l.size = Vector2(w, w)
	var num: Label = col.get_node("Num")
	num.text = str(int(Data.t("ATOMIC_NUMBER").get(sym, 0)))
	num.add_theme_color_override("font_color", color)
	var b: Panel = col.get_node("Badge")
	b.visible = suit != ""
	if suit != "":
		var bsb: StyleBoxFlat = b.get_theme_stylebox("panel").duplicate()
		bsb.bg_color = Tok.suit_color(suit)
		b.add_theme_stylebox_override("panel", bsb)
		b.position = Vector2(w - 14, 1)  # top/right -4px from inside the 5px border
		var g: TextureRect = b.get_node("Glyph")
		g.texture = Data.icon("suit:" + suit)
		g.material = Tok.white()
	var nm: Label = col.get_node("Name")
	nm.text = Data.t("ELEMENT_NAMES").get(sym, sym)
	nm.position = Vector2(-8, w + 3)
	nm.size = Vector2(w + 16, 10)
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
			Game._changed()))  # saves, then redraws
	else:
		var ic := Tok.icon("📋", 15)  # list view: comes later (cards only for now)
		ic.position = Vector2(7.5, 7.5)
		b.add_child(ic)
	return b


## Settings (top right; not on the map, under its card) and Convert (bottom
## right, once any element is held), on screen `on`.
static func corner_buttons(on: Control, settings: bool) -> void:
	var w := on.size.x
	var gear := TextureRect.new()
	gear.texture = load("res://assets/ui/btn_settings.webp")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear.position = Vector2(w - 14 - 46, (TOP if Game.state.get("matChecked") else 0.0) + 10)
	gear.size = Vector2(46, 46)
	gear.set_meta("cmp", "settings")
	if settings:
		on.add_child(gear)
	# Convert: on screen once any element is held (state.convertRevealed in
	# the HTML game's updateHub()), with how many 3:1 conversions are possible.
	var held: Array = Util.get_or(Game.state, "elements", {}).values()
	if Game.state.get("convertRevealed") or held.any(func(v): return v > 0):
		var conv := TextureRect.new()
		conv.texture = load("res://assets/ui/btn_quark.webp")
		conv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		conv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		conv.position = Vector2(w - 16 - 58, on.size.y - HubBar.H - 14 - 58)
		conv.size = Vector2(58, 58)
		conv.set_meta("cmp", "convert")
		conv.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed and App.current:
			if App.current.panel == "convert":
				App.current.close_panel()
			else:
				App.current.open_panel("convert"))
		on.add_child(conv)
		var n := 0
		for v in held:
			n += int(v) / int(Data.t("CONVERT_RATE"))
		if n > 0:
			conv.add_child(HubBar._badge(str(n), Vector2(58 + 7 - 24, -7)))


## A tap (not a scroll) runs fn.
func _on_tap(ev: InputEvent, fn: Callable) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_at = ev.global_position
		elif ev.global_position.distance_to(_press_at) < 10:
			fn.call()
