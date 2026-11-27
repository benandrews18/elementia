## A station (renderStation(), station.css): the station's art behind
## everything; the dark header (icon, name, its six elements, the crafted
## items folded into a bar); then the shop as cards with a pin and a Craft
## button under each. The page scrolls under the Quark bar.
class_name StationScreen
extends Control

## A tier 1 shop card: two of them, one above the other with the gap
## between, stand as tall as a tier 2/3 card (the user, 2026-11-24); the
## Inventory's and the mat's tier 1 cards are this size too.

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

var open_card := ""  # the shop card whose row is on the Crafting Bench (stationCardOpen); the side card's in the list view
const HEAD_H := 295.0  # the header's dark blue: the shop's title, then the crafted-items bar, to its foot
static var list_mode := false  # 📋: the shop as a list, the selected item's side card on the right (the user, 2026-11-22)
var _list_top := 0.0  # the list's first row (page y): the side card starts level with it
var _side: Control  # the side card and its Pin / Craft, kept on screen as the page scrolls
var _bulbs := {}  # shop cards whose 💡 has shown this visit (station -> {name: true}): no fade-in again on a redraw
@onready var _scroll: ScrollContainer = $Scroll
@onready var _page: Control = $Scroll/Page


static func make() -> StationScreen:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _place_side())
	_redraw()


var stale := false  # a redraw skipped while covered (App.screen_covered())


func _redraw() -> void:
	if is_queued_for_deletion() or not Game.ctx.get("current"):
		return  # leaving the station: the app is swapping this screen out
	if App.current and App.current.screen_covered():  # under the Display Mat: redrawn when it closes
		stale = true
		return
	stale = false
	if open_card != "" and Catalog.owns(Game.state, open_card):
		open_card = ""  # crafted: off the Crafting Bench
	var keep := _scroll.scroll_vertical
	for holder in [$Scroll/Page/Chips, $Scroll/Page/Fold, $Scroll/Page/Crafted, $Scroll/Page/View, $Scroll/Page/Bench, $Scroll/Page/Shop, $Top]:
		for c in holder.get_children():
			c.queue_free()
	var name: String = Game.ctx.current
	var st := Catalog.station(name)
	var w := size.x
	# The station's art, full width from the top, fixed behind the page; on
	# a screen taller than it, it grows to the bottom (its sides cropped).
	var art: TextureRect = $Art
	art.texture = load("res://assets/" + Data.t("STATION_BG")[name])
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = Vector2(w, maxf(size.y, w * art.texture.get_height() / art.texture.get_width()))
	$Wash.size = art.size
	var top := TOP if Game.state.get("matChecked") else 0.0  # no Quark bar yet: the header reaches the top
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(w, size.y - top)
	var y := _shop_title(_header(_page, st, w))
	if open_card != "" and not list_mode:
		y = _bench(_page, w, y)
	y = _shop_list(_page, name, w, y) if list_mode else _shop(_page, name, w, y)
	_page.custom_minimum_size = Vector2(w, y + HubBar.H + 80)
	_scroll.set_deferred("scroll_vertical", keep)
	if Game.state.get("matChecked"):
		var qt := QuarkTopBar.make()
		qt.size = Vector2(w, TOP)
		$Top.add_child(qt)
	corner_buttons($Top, true)
	if list_mode:
		_side_card(w)


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
		chip.mouse_filter = MOUSE_FILTER_PASS  # a tap opens the Convert tray on it; a drag still scrolls
		chip.gui_input.connect(_on_tap.bind(func(): if App.current: App.current.open_convert(sym)))  # the user: convert into it
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
	return HEAD_H


## A white line, "ITEM SHOP", the crafted-items bar, then "TAP ON ITEMS TO
## START CRAFTING" under it on the header's dark blue (the user, 2026-11-26;
## all placed in the scene). Returns the blue's foot.
func _shop_title(y: float) -> float:
	$Scroll/Page/Head.offset_bottom = y  # anchored across: size.y would warn
	return y


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
		App.pin(n)  # saves, then redraws
	bench.add_child(ShopRow.make(e, w - 36, craft, pin))
	bench.position = Vector2(0, y)
	bench.size = Vector2(w, 30 + ShopRow.H + 18)
	page = $Scroll/Page/Bench
	page.add_child(bench)
	var close := TextureRect.new()
	close.texture = load("res://assets/ui/btn_close.webp")
	close.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close.position = Vector2(w - 34 + 4, y - 6)  # the top-right corner (the user, 2026-11-23)
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
	y += 14
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
		var card_h := (row_h - gap) / 2 if gi == 0 else row_h
		var cell_h := card_h + 3  # no Pin / Craft under the cards: tap one for the Crafting Bench (the user, 2026-11-22)
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


## The list view's shop (the user's trial of a list + side card in place of
## the card grid and its Crafting Bench): the same items in the grid's
## order as compact rows on the left (no craftable mark: the user wants the
## shop explored through the bench, 2026-11-23; a tick,
## dimmed: crafted; gold edge: the one on the side card).
func _shop_list(page: Control, station: String, w: float, y: float) -> float:
	var s := Game.state
	y += 14
	page = $Scroll/Page/Shop
	_list_top = y
	var fold: bool = s.get("collapseCraftedItems", false)
	var shown := shop_entries(station).filter(func(e): return not (fold and Catalog.owns(s, e.name) and e.tier != "CAPSTONE"))
	var order := ["MATERIAL", "COMPONENT", "CREATION", "CAPSTONE"]
	var lw := floorf((w - 12) * 0.5 - 4)
	for tier in order:
		for e in shown.filter(func(x): return x.tier == tier):
			var owned := Catalog.owns(s, e.name)
			var can := not owned and Catalog.can_craft(s, e) and Game.suit_cost_payable(e.name)
			var row := DisplayMatScreen.list_row(e.name, lw)
			row.position = Vector2(6, y)
			row.set_meta("cmp", "st:" + e.name)
			if e.name == open_card:
				row.add_theme_stylebox_override("panel", Tok.box(Color("#f3e6c8"), 10, 3, Color("#d9a441"), 2, 1, Color(0, 0, 0, 0.25)))
			if owned:
				row.modulate = Color(0.7, 0.7, 0.7)
				var tick := Tok.tick(Color.WHITE, 16, Tok.OK)
				tick.position = Vector2(lw - 20, 4)
				row.add_child(tick)
			row.gui_input.connect(_on_tap.bind(func():
				open_card = e.name
				_redraw()))
			page.add_child(row)
			y += DisplayMatScreen.ROW_H + 6
	return y + 6


## Where the suit-cost balloon points from the side card's Craft (the user,
## 2026-11-26: at the card's suit badges, as from the Crafting Bench; it
## pointed at Craft): the cost badges on screen (the card is scaled), or
## the button when there are none.
static func _costs_rect(costs: Control, btn: Control) -> Rect2:
	var r := Rect2()
	for c in costs.get_children():
		var g: Rect2 = c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
		r = g if r.size == Vector2.ZERO else r.merge(g)
	return r if r.size != Vector2.ZERO else btn.get_global_rect()


## The side card for open_card with Pin and Craft under it (in place of the
## Crafting Bench), right of the list; _place_side() keeps it on screen.
func _side_card(w: float) -> void:
	var lw := floorf((w - 12) * 0.5 - 4)
	var rx := 6 + lw + 8
	var rw := w - 6 - rx
	_side = Control.new()
	_side.mouse_filter = MOUSE_FILTER_IGNORE
	_side.position.x = rx
	$Top.add_child(_side)
	$Top.move_child(_side, 0)  # under the Quark bar and the corner buttons
	var e = Catalog.entry(open_card)
	if e == null:
		var hint := Tok.label("Tap an item to see its card", 13, Color("#e6eef6"), 700)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.position = Vector2(0, 30)
		hint.size = Vector2(rw, 40)
		_side.add_child(hint)
		_side.size = Vector2(rw, 80)
		_place_side()
		return
	var card := CardPop.side_card(e.name, rw)
	_side.add_child(card)
	var ch := card.size.y * card.scale.y
	var s := Game.state
	var owned := Catalog.owns(s, e.name)
	var can := not owned and Catalog.can_craft(s, e) and Game.suit_cost_payable(e.name)
	var acts := ShopActs.make()
	acts.position = Vector2(0, ch + 8)
	acts.show_state(rw, act_h + 6, Progress.is_pinned(e.name), can, owned)
	var pin: Control = acts.get_node("Pin")
	pin.gui_input.connect(_on_tap.bind(_pin_tap.bind(e.name, _side, Vector2.ZERO, Vector2(rw, ch))))
	pin.set_meta("cmp", "st:pin:" + e.name)
	var btn: Control = acts.get_node("Craft")
	if can:
		var costs: Control = card.get_node("Card/Costs")
		btn.gui_input.connect(_on_tap.bind(func(): _craft(e.name, _costs_rect(costs, btn))))
		btn.set_meta("tip", "st:craft:" + e.name)
	btn.set_meta("cmp", "st:craft:" + e.name)
	_side.add_child(acts)
	_side.size = Vector2(rw, ch + 8 + act_h + 6)
	_place_side()


## Level with the list's first row; once that scrolls up, held under the
## top bar (the side card stays in view down the list).
func _place_side() -> void:
	if not is_instance_valid(_side):
		return
	var top := _scroll.position.y + 8
	_side.position.y = maxf(top, _scroll.position.y + _list_top - _scroll.scroll_vertical)


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


## One shop cell: the card (no craftable mark, the user, 2026-11-23; dimmed with a tick
## if owned). Pin and Craft are on the Crafting Bench a tap opens.
func _cell(page: Control, e: Dictionary, pos: Vector2, card_size: Vector2, t1: bool) -> void:
	var s := Game.state
	var owned := Catalog.owns(s, e.name)
	var can := not owned and Catalog.can_craft(s, e) and Game.suit_cost_payable(e.name)
	if e.name == open_card:  # .selected: 4px gold outline, 2px out
		var sel := Panel.new()
		sel.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 17 if not t1 else 15, 4, Color("#d9a441")))
		sel.position = pos - Vector2(6, 6)
		sel.size = card_size + Vector2(12, 12)
		sel.mouse_filter = MOUSE_FILTER_IGNORE
		page.add_child(sel)
	# You are at its station: no badges, but a tier 1 item sold at several
	# shows them all from the bottom right (the user, 2026-11-26).
	var many: bool = t1 and Catalog.mat_card(e.name).stations.size() > 1
	var card := ItemCard.make(e.name, {"mini": t1, "wide": e.tier == "CAPSTONE", "tag": "st:" + e.name, "no_stations": not many, "stations_right": many,
		"shop": not t1, "fade_suits": not owned})  # tier 1: the Inventory's small card
	card.position = pos
	card.size = card_size
	card.gui_input.connect(_on_tap.bind(func():  # the card's row on the Crafting Bench
		open_card = "" if open_card == e.name else e.name
		_redraw()))
	if owned:
		card.modulate = Color(0.7, 0.7, 0.7)
	if can:  # the walkthrough's "Tap a green card" points here
		card.set_meta("tip", "st:craft:" + e.name)
		# A soft 💡 on every card you can craft (the user, 2026-11-24), faded
		# in once a visit, not again each time a tap redraws the shop.
		var here: String = str(Game.ctx.get("current", ""))
		if not _bulbs.has(here):
			_bulbs = {here: {}}
		var bulb := HintBadge.new()
		bulb.tappable = false
		bulb.fade_in = not _bulbs[here].has(e.name)
		_bulbs[here][e.name] = true
		bulb.set_meta("cmp", "st:bulb:" + e.name)
		card.add_child(bulb)
	page.add_child(card)
	if owned:  # .st-owned::after: a green tick, bottom right
		var tick := Tok.tick(Color.WHITE, 20, Tok.OK)
		tick.position = pos + card_size - Vector2(15, 15)
		page.add_child(tick)
	else:
		page.add_child(_pin_slot(e.name, page, pos, card_size, t1))


## The card's bottom-left circle (the user, 2026-11-23): a 🔍
## when the tracked item still needs this one (a tap: the To-Do List,
## this one lit in its breakdown); else the 📌 (a tap pins and tracks it, or
## unpins it), the tracked item's own card included.
func _pin_slot(item: String, page: Control, pos: Vector2, card_size: Vector2, t1: bool) -> Control:
	var d := 20.0 if t1 else ItemCard.SHOP_CIRCLE  # the points badge's size (a tier 1 card's small one)
	var feeds := Game.feeds_tracked(item)
	var pinned := Progress.is_pinned(item)
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color("#163544") if feeds else Color("#3a2e14"), d / 2, 2, Tok.GOLD if feeds or pinned else Color("#b9b0a0")))
	b.size = Vector2(d, d)
	b.position = pos + Vector2(-5, card_size.y - d + 5)  # straddling the corner, like the points badge
	b.set_meta("cmp", "st:slot:" + item)
	var ic := Tok.icon("🔍" if feeds else "📌", d * 0.6)  # 🔍: the tracking mark, not the tracked item (the user, 2026-11-26)
	ic.position = (b.size - ic.size) / 2
	ic.mouse_filter = MOUSE_FILTER_IGNORE
	if not feeds and not pinned:
		b.modulate.a = 0.6
		ic.material = Tok.grey()
	b.add_child(ic)
	b.gui_input.connect(_on_tap.bind(func():
		if feeds and App.current:
			TodoTray.focus = item
			App.current.open_panel("todo")
		elif not feeds:
			_pin_tap(item, page, pos, card_size)))
	return b


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
	else:  # 📋: the list view and back
		var ic := Tok.icon("📋", 15)
		ic.position = Vector2(7.5, 7.5)
		b.add_child(ic)
		if list_mode:
			b.add_theme_stylebox_override("panel", Tok.box(Color(1, 1, 1, 0.1), 8, 2.5, Tok.GOLD))
		b.set_meta("cmp", "st:listview")
		b.gui_input.connect(_on_tap.bind(func():
			list_mode = not list_mode
			_redraw()))
	return b


## The gear: a tap opens Settings.
static func gear_button(px: float) -> TextureRect:
	var gear := TextureRect.new()
	gear.texture = load("res://assets/ui/btn_settings.webp")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear.size = Vector2(px, px)
	gear.set_meta("cmp", "settings")
	gear.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.open_settings())
	return gear


## Settings (top right; on the map, under its card) and Convert (bottom
## right, once any element is held), on screen `on`.
static func corner_buttons(on: Control, settings: bool, convert := true) -> void:
	var w := on.size.x
	var gear := gear_button(46)
	gear.position = Vector2(w - 14 - 46, (TOP if Game.state.get("matChecked") else 0.0) + 10)
	if settings:
		on.add_child(gear)
	var conv := convert_button(58) if convert else null
	if conv:
		conv.position = Vector2(w - App.EDGE - 58, on.size.y - HubBar.H - 14 - 58)
		on.add_child(suit_pill(conv.position))
		on.add_child(conv)


## The suit pill (the user, 2026-11-26): out of Convert's left side like the
## tracked pill, each suit's icon over how many of its elements are held
## (what suit costs are paid from). A tap opens Convert too.
static func suit_pill(conv_at: Vector2) -> Control:
	const COL := 22.0
	const GAP := 8.0
	var suits: Array = Data.t("ELEMENT_SUIT_LABEL").keys()
	var held := {}
	for sym in Util.get_or(Game.state, "elements", {}):
		var su: String = Data.t("ELEMENT_SUIT").get(sym, "")
		held[su] = held.get(su, 0) + int(Catalog.count(Game.state, sym))
	var pill: Control = load("res://ui/pieces/tracked_pill.tscn").instantiate()
	pill.get_node("Row").visible = false
	var inner := suits.size() * COL + (suits.size() - 1) * GAP
	pill.size = Vector2(16 + inner + 29 + 8, App.PILL_H)  # its right end hides under the button's middle
	pill.position = Vector2(conv_at.x + 29 - pill.size.x, conv_at.y + (58 - App.PILL_H) / 2)
	pill.set_meta("cmp", "suits")
	for i in suits.size():
		var su: String = suits[i]
		var x := 16 + i * (COL + GAP)
		var ic := Tok.icon("suit:" + su, 16)
		ic.material = Tok.tinted(Tok.suit_color(su))
		ic.position = Vector2(x + (COL - 16) / 2, 5)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(ic)
		var n := Tok.label(str(held.get(su, 0)), 12, Color.WHITE, 800)
		n.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		n.add_theme_constant_override("shadow_offset_y", 1)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.position = Vector2(x - 4, 21)
		n.size = Vector2(COL + 8, 16)
		n.set_meta("cmp", "suits:" + su)
		pill.add_child(n)
	pill.gui_input.connect(func(ev): if Tap.tap(ev) and App.current:
		if App.current.panel == "convert":
			App.current.close_panel()
		else:
			App.current.open_panel("convert"))
	return pill


## Convert: on screen once any element is held (state.convertRevealed in
## the HTML game's updateHub()), with how many 3:1 conversions are
## possible; null before that. The caller places it.
static func convert_button(px: float) -> TextureRect:
	var held: Array = Util.get_or(Game.state, "elements", {}).values()
	if not (Game.state.get("convertRevealed") or held.any(func(v): return v > 0)):
		return null
	var conv := TextureRect.new()
	conv.texture = load("res://assets/ui/btn_quark.webp")
	conv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	conv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	conv.size = Vector2(px, px)
	conv.set_meta("cmp", "convert")
	conv.gui_input.connect(func(ev): if Tap.tap(ev) and App.current:
		if App.current.panel == "convert":
			App.current.close_panel()
		else:
			App.current.open_panel("convert"))
	var n := 0
	for v in held:
		n += int(v) / int(Data.t("CONVERT_RATE"))
	if n > 0:
		conv.add_child(HubBar._badge(str(n), Vector2(px + 7 - 24, -7)))
	return conv


## The first control here (in tree order) whose "tip" or "cmp" tag starts
## with prefix: a tip's target (a craftable Craft button, a needed badge,
## the Convert button).
func find_tagged(prefix: String, tip_only := false) -> Control:
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Control and not n.is_queued_for_deletion() and n.is_visible_in_tree():
			var tag: String = n.get_meta("tip", "") if tip_only else n.get_meta("tip", n.get_meta("cmp", ""))
			if tag.begins_with(prefix):
				return n
		stack.append_array(n.get_children())
	return null


## A card's 📌: pins it (saves, then redraws); once it's tracked, its icon
## flies from the card to the pill (flyItemToTracker()).
func _pin_tap(item: String, page: Control, pos: Vector2, card_size: Vector2) -> void:
	App.pin(item, Rect2(page.global_position + pos, Vector2(card_size.x, minf(card_size.x, 60))))


## A tap (not a scroll) runs fn.
func _on_tap(ev: InputEvent, fn: Callable) -> void:
	if Tap.tap(ev):
		fn.call()
