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

var open_card := ""  # the shop card whose row is on the Crafting Bench (stationCardOpen); the side card's in the list view
const NAME_PX := 18  # the names under the shop's cards (the user, 2026-11-27: 1.5x the Market's)
const NAME_H := 42.0  # room for two lines
const HEAD_H := 295.0  # the header's dark blue: the shop's title, then the crafted-items bar, to its foot
static var list_mode := false  # 📋: the shop as compact rows across the screen (the user, 2026-11-26: no side card; card view on every arrival)
var _bulbs := {}  # shop cards whose 💡 has shown this visit (station -> {name: true}): no fade-in again on a redraw
@onready var _scroll: ScrollContainer = $Scroll
@onready var _page: Control = $Scroll/Page


static func make() -> StationScreen:
	return Tok.make(SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
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
	if open_card != "":  # both views: the tapped item on the Crafting Bench
		y = _bench(_page, w, y)
	y = _shop_list(_page, name, w, y) if list_mode else _shop(_page, name, w, y)
	_page.custom_minimum_size = Vector2(w, y + HubBar.H + 80)
	_scroll.set_deferred("scroll_vertical", keep)
	if Game.state.get("matChecked"):
		var qt := QuarkTopBar.make()
		qt.size = Vector2(w, TOP)
		$Top.add_child(qt)
	var qr = Game.ctx.get("qr")  # Quick Rules: no Settings; Convert once its step comes
	corner_buttons($Top, qr == null, qr == null or qr.get("convert", false))


## Arriving from the map (step 26, the user 2026-11-26): the art fades in,
## the header drops into place, the cards come in from the right a row at a
## time, then the 🔍 marks pop on (App bounces the tracked pill with them).
## Visual only (offset_transform, scale): taps work throughout.
const ARRIVE_MARKS := 0.45  # when the 🔍 marks pop on

func arrive() -> void:
	if not Juice.on():
		return
	for n in [$Art, $Wash]:
		n.modulate.a = 0.0
		n.create_tween().tween_property(n, "modulate:a", 1.0, 0.35)
	for nm in ["Head", "Icon", "Title", "ElementsLabel", "Chips", "CraftedLabel", "Fold", "Bar", "Crafted", "View", "ShopLine", "ShopLabel", "ShopHint"]:  # the shop title falls with the header (the user, 2026-11-26)
		_arrive_slide(_page.get_node(nm), Vector2(0, -60), 0.0)
	_arrive_slide(_page.get_node("Bench"), Vector2(size.x * 0.6, 0), 0.08)
	var shop: Array = $Scroll/Page/Shop.get_children()
	var top := INF
	for c in shop:
		top = minf(top, c.position.y)
	for c in shop:
		if not c is Control:
			continue
		var tag := str(c.get_meta("cmp", ""))
		if tag.begins_with("st:slot:") and Game.feeds_tracked(tag.substr(8)):  # a 🔍: pops on last
			c.pivot_offset = c.size / 2
			c.scale = Vector2.ZERO
			c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.3).set_delay(ARRIVE_MARKS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_arrive_slide(c, Vector2(size.x * 0.6, 0), 0.1 + (c.position.y - top) * 0.0005 + c.position.x * 0.0002)


func _arrive_slide(c: Control, from: Vector2, delay: float) -> void:
	c.offset_transform_enabled = true
	c.offset_transform_position = from
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_transform_position", Vector2.ZERO, 0.3).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)


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
	y += 10  # room for the title pill on its top edge
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
		var cell_h := card_h + 3 + NAME_H  # the name under the card (the user, 2026-11-27: as in the Market); Pin and Craft are on the Crafting Bench
		var taken := {}  # "row,col" -> true (dense packing)
		var rows := 0
		# Tier 1 over several rows: the short row on top, the full ones on the rest (the user, 2026-11-26)
		var short := items.size() % columns if gi == 0 and items.size() > columns else 0
		for i in items.size():
			var e: Dictionary = items[i]
			var span := 2 if e.tier == "CAPSTONE" else 1
			var at := _first_free(taken, span, columns)
			if short > 0:
				at = Vector2i(0, i) if i < short else Vector2i(1 + (i - short) / columns, (i - short) % columns)
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
	var fold: bool = s.get("collapseCraftedItems", false)
	var shown := shop_entries(station).filter(func(e): return not (fold and Catalog.owns(s, e.name) and e.tier != "CAPSTONE"))
	var order := ["MATERIAL", "COMPONENT", "CREATION", "CAPSTONE"]
	var lw := w - 12  # across the screen
	for tier in order:
		for e in shown.filter(func(x): return x.tier == tier):
			var owned := Catalog.owns(s, e.name)
			var can := not owned and Catalog.can_craft(s, e) and Game.suit_cost_payable(e.name)
			var row := wide_row(e.name, lw)
			row.position = Vector2(6, y)
			row.set_meta("cmp", "st:" + e.name)
			if e.name == open_card:
				row.add_theme_stylebox_override("panel", Tok.box(Color("#f3e6c8"), 10, 3, Color("#d9a441"), 2, 1, Color(0, 0, 0, 0.25)))
			if owned:
				row.modulate = Color(0.7, 0.7, 0.7)
				var tick := Tok.tick(Color.WHITE, 16, Tok.OK)
				tick.position = Vector2(lw - 20, (WIDE_ROW_H - 16) / 2)
				row.add_child(tick)
			row.gui_input.connect(_on_tap.bind(func():
				open_card = e.name
				_redraw()))
			page.add_child(row)
			y += row.size.y + 6
	return y + 6


## The list view's row (the user, 2026-11-26): picture, name, suit icons and
## the parts, all in one line at the same sizes for every item (measured:
## the widest, Fruit Cake, needs 324 px of the phone's 378; only Planet's 16
## elements run onto a second line).
const WIDE_ROW_H := 42.0

static func wide_row(name: String, lw: float) -> Panel:
	var row := Panel.new()
	row.add_theme_stylebox_override("panel", Tok.box(Color("#f3e6c8"), 10, 1.5, Color("#c9a571"), 2, 1, Color(0, 0, 0, 0.25)))
	row.mouse_filter = MOUSE_FILTER_PASS
	var ic := Tok.icon(Data.t("ITEM_EMOJI").get(name, ""), 30)
	ic.position = Vector2(6, (WIDE_ROW_H - 30) / 2)
	row.add_child(ic)
	var x := 42.0
	var nm := Tok.label(name, 13, Tok.CARD_INK, 800)
	var nw := Tok.font(800).get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	nm.position = Vector2(x, (WIDE_ROW_H - Tok.font(800).get_height(13)) / 2)
	row.add_child(nm)
	x += nw + 6
	for su in Data.t("ITEM_SUIT_COST_TABLE").get(name, []):
		var g := Tok.icon("suitdisc:" + su, 14)
		g.position = Vector2(x, (WIDE_ROW_H - 14) / 2)
		row.add_child(g)
		x += 15
	x += 8
	var parts := DisplayMatScreen.row_parts(name, Vector2(x, (WIDE_ROW_H - 22) / 2), 0, lw - 26 - x)  # clear of the owned tick
	row.add_child(parts)
	row.size = Vector2(lw, WIDE_ROW_H + parts.size.y - 22)
	return row


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
	# You are at its station: no station badges (a tier 1 item's others: on its full card, the user 2026-11-26).
	var card := ItemCard.make(e.name, {"mini": t1, "wide": e.tier == "CAPSTONE", "tag": "st:" + e.name, "no_stations": not t1, "stations_right": t1, "station_px": 24.0,  # tier 1: where else it's made, along the bottom from the right (the user, 2026-11-27)
		"shop": not t1, "fade_suits": not owned, "no_name": true,
		"icon_px": minf(card_size.y * 0.78, card_size.x * 0.72) if t1 else minf(card_size.y * 0.62, card_size.x * 0.82)})  # the picture fills the room the name left (the user, 2026-11-27)
	var n := Tok.label(e.name, NAME_PX, Color(1, 1, 1, 0.7) if owned else Color.WHITE, 800)  # under the card, as in the Market (MarketTray._cell), 1.5x its size
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.max_lines_visible = 2
	n.add_theme_constant_override("line_spacing", -3)
	n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	n.add_theme_constant_override("outline_size", 4)
	n.size = Vector2(card_size.x + 4, NAME_H)
	var longest: String = Array(e.name.split(" ")).reduce(func(a, b): return a if a.length() >= b.length() else b)
	n.add_theme_font_size_override("font_size", Tok.fit_px(longest, Tok.font(800), NAME_PX, n.size.x - 4))  # never a word broken in two
	n.position = pos + Vector2(-2, card_size.y + (10 if t1 else 3))  # tier 1: under its station badges
	n.mouse_filter = MOUSE_FILTER_IGNORE
	n.set_meta("cmp", "st:name:" + e.name)
	page.add_child(n)
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
	var d := 34.0  # one size on every tier, big enough to see and tap (the user, 2026-11-27)
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
	var col: Control = Tok.make("res://ui/pieces/element_chip.tscn")
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
		b.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		b.position = Vector2(w - 15, 0)  # top/right -4px from inside the 5px border
		b.size = Vector2(15, 15)
		var g: TextureRect = b.get_node("Glyph")
		g.texture = Data.icon("suitdisc:" + suit)  # the suit disc (the user, 2026-11-28)
		g.position = Vector2.ZERO
		g.size = b.size
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
static func corner_buttons(on: Control, settings: bool, convert := true, suits := true) -> void:
	var w := on.size.x
	var gear := gear_button(46)
	gear.position = Vector2(w - 14 - 46, (TOP if Game.state.get("matChecked") else 0.0) + 10)
	if settings:
		on.add_child(gear)
	var conv := convert_button(58) if convert else null
	if conv:
		conv.position = Vector2(w - App.EDGE - 58, on.size.y - HubBar.H - 14 - 58)
		if suits:
			on.add_child(suit_pill(conv.position))
		on.add_child(conv)


## The suit strip (the user, 2026-11-26): left of Convert, each suit's icon
## in a thin gold ring sitting on a narrow pill, how many of its elements
## are held in a bubble on the ring's top right (what suit costs are paid
## from). A tap opens Convert too. Hidden over the Convert tray.
static func suit_pill(conv_at: Vector2) -> Control:
	const D := 28.0  # a ring (four fit right of the screen's middle, clear of the tracked pill)
	const GAP := 4.0
	var suits: Array = Data.t("ELEMENT_SUIT_LABEL").keys()
	var held := {}
	for sym in Util.get_or(Game.state, "elements", {}):
		var su: String = Data.t("ELEMENT_SUIT").get(sym, "")
		held[su] = held.get(su, 0) + int(Catalog.count(Game.state, sym))
	var strip := Control.new()
	var row_w := suits.size() * D + (suits.size() - 1) * GAP
	strip.size = Vector2(4 + row_w + 4 + 29, 58)  # the pill's right end hides under the button's middle
	strip.position = Vector2(conv_at.x + 29 - strip.size.x, conv_at.y)
	strip.set_meta("cmp", "suits")
	var pill: Control = Tok.make("res://ui/pieces/tracked_pill.tscn")
	pill.get_node("Row").visible = false
	pill.size = Vector2(strip.size.x, 18)
	pill.position = Vector2(0, (58 - 18) / 2)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(pill)
	for i in suits.size():
		var su: String = suits[i]
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, D / 2 + 1, 1.5, Tok.GOLD))
		ring.size = Vector2(D, D)
		ring.position = Vector2(4 + i * (D + GAP), (58 - D) / 2)
		ring.set_meta("cmp", "suits:ring:" + su)
		SuitSpend.on_tap(ring, su, true)  # its balloon with how many of each you hold (the user, 2026-11-26); the pill: Convert
		var ic := Tok.icon("suitdisc:" + su, D)  # the suit disc in the gold ring (the user, 2026-11-28)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_child(ic)
		var n := count_bubble(held.get(su, 0), Vector2(D - 11, -9))
		n.set_meta("cmp", "suits:" + su)
		ring.add_child(n)
		strip.add_child(ring)
	strip.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.open_panel("convert"))
	return strip


## A count in a small round bubble (the suit strip's, the "?" counter's):
## white on navy with a gold rim, wider for longer numbers.
static func count_bubble(n: int, at: Vector2) -> Label:
	var l := Tok.label(str(n), 11, Color.WHITE, 900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", Tok.box(Color("#0b1c25"), 9, 1.5, Tok.GOLD))
	var tw := Tok.font(900).get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	l.size = Vector2(maxf(19, tw + 10), 19)
	l.position = at
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
