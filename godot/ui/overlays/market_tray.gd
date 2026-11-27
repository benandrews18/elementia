## The Marketplace (Home's Market face; job-board.js marketRowsHTML()): a
## tray dropping from the top, full width. The stations visited (a "?" for
## all 8); the Market on its brass-framed wood: 3 rows of 4 squares, each
## row ending in its "?" reward (a tick once paid); then every capstone.
## A square you don't own opens the Crafting Bench to craft it from here;
## the corner pin pins it. Home reads Map; a tap outside closes it.
## An owned square or a capstone opens its card (CardPop).
class_name MarketTray
extends Control


## The layout is ui/overlays/market_tray.tscn (the tray, the Market's frame
## and its texts, the Capstones heading); this fills in the rows and squares.
const SCENE := "res://ui/overlays/market_tray.tscn"
const NAME_PX := 12  # the names under the squares (step 23 early, the user 2026-11-26)
const NAME_H := 28.0  # room for two lines

var cells := {}  # card index -> its square (the row sequence bounces them)
@onready var _scroll: ScrollContainer = $Bg/Scroll
@onready var _tray: Control = $Bg/Scroll/Content/Tray  # at most 420 wide, centred (it scrolls when tall)


static func make() -> MarketTray:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Scrim.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.close_panel())
	Game.state_changed.connect(_redraw)
	_redraw()


func _redraw() -> void:
	var keep := _scroll.scroll_vertical
	for holder in [$Bg/Scroll/Content/Tray/Stations, $Bg/Scroll/Content/Tray/Market/Rows, $Bg/Scroll/Content/Tray/Caps]:
		for c in holder.get_children():
			c.queue_free()
	cells.clear()
	var s := Game.state
	Market.ensure_card(s)
	var full := size.x
	var w := minf(420, full)  # a tablet's wider screen keeps phone-sized squares
	var bg: Control = $Bg
	var scroll := _scroll
	scroll.set_deferred("scroll_vertical", keep)  # a pin's redraw keeps your place
	var content: Control = $Bg/Scroll/Content
	_tray.position.x = (full - w) / 2
	var y := 14.0 + _stations(Vector2(16, 14), w - 32) + 12
	# The Market: brass-framed wood with its rows.
	var panel: Control = $Bg/Scroll/Content/Tray/Market
	panel.position = Vector2(16, y)
	var pw := w - 32
	panel.size.x = pw
	var hint: Label = $Bg/Scroll/Content/Tray/Market/Hint
	if not hint.has_node("Unknown"):  # the reward: an Unknown Element, its square after the text (the user, 2026-11-26)
		var sq := LockInReward.unknown_square(20)
		sq.name = "Unknown"
		sq.position = Vector2(hint.get_theme_font("font").get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x + 6, 4)
		hint.add_child(sq)
	var rows_at: Control = $Bg/Scroll/Content/Tray/Market/Rows
	var ry := 42.0
	var card: Array = s.bingoCard
	var lines := Market.lines()
	var cell := (pw - 28 - 13 - 6 - 30 - 3 * 8) / 4
	for r in lines.size():
		var done: bool = Util.get_or(s, "bingoLinesCompleted", []).any(func(x): return int(x) == r)
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD_SOFT if done else Color.TRANSPARENT, 14, 2, Tok.GOLD if done else Color.TRANSPARENT))
		row.position = Vector2(14, ry)
		row.size = Vector2(pw - 28, cell + 6 + 4 + NAME_H)
		row.mouse_filter = MOUSE_FILTER_PASS
		rows_at.add_child(row)
		for k in lines[r].size():
			var idx: int = lines[r][k]
			var c := _cell(card[idx], cell, false)
			c.position = Vector2((row.size.x - lines[r].size() * (cell + 8) + 8) / 2 + k * (cell + 8), 3)  # centred in the box (no 🎁 corner now)
			row.add_child(c)
			cells[idx] = c
		if done:  # a row pays nothing now; its squares each paid a "?"
			var rw := Tok.tick(Color("#4fe583"), 22)
			rw.position = Vector2(row.size.x - 3 - 15 - rw.size.x / 2, (row.size.y - rw.size.y) / 2)
			row.add_child(rw)
		ry += row.size.y + 4
	$Bg/Scroll/Content/Tray/Market/Foot.position.y = ry
	panel.size = Vector2(pw, ry + 16 + 10)
	y += panel.size.y + 12
	# Capstones: a reference list, pinnable.
	$Bg/Scroll/Content/Tray/CapsHead.position.y = y
	$Bg/Scroll/Content/Tray/Trophy.position.y = y + 2
	y += 22
	$Bg/Scroll/Content/Tray/CapsSub.position.y = y
	y += 22
	var caps := Market.capstone_choices()
	var cw := (w - 32 - 44 - 3 * 8) / 4
	for i in caps.size():
		var c := _cell(caps[i], cw, true)
		c.position = Vector2(16 + 22 + (i % 4) * (cw + 8), y + (i / 4) * (cw + 10 + NAME_H))
		$Bg/Scroll/Content/Tray/Caps.add_child(c)
	y += ceili(caps.size() / 4.0) * (cw + 10 + NAME_H) + 8
	_tray.size = Vector2(w, y)
	content.custom_minimum_size = Vector2(full, y)
	bg.size = Vector2(full, minf(y, size.y - HubBar.H - 30))
	scroll.size = bg.size - Vector2(0, 3)


## "5/8 Stations Visited", a circle per station (ticked once visited) and
## the "?" for all 8 (a tick once paid). Returns its height.
func _stations(at: Vector2, w: float) -> float:
	var s := Game.state
	var visited: Dictionary = Util.get_or(s, "visitedStations", {})
	var ORDER: Array = Data.t("STATION_TRACKER_ORDER")
	var n := ORDER.filter(func(st): return visited.has(st)).size()
	var l := Tok.label("%d/%d STATIONS VISITED" % [n, ORDER.size()], 11, Color.WHITE, 800)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))  # white, a small shadow (the user, 2026-11-26)
	l.position = at
	$Bg/Scroll/Content/Tray/Stations.add_child(l)
	var d := minf(32, (w - 30 - 8 - 7 * 5) / 8)
	for i in ORDER.size():
		var v: bool = visited.has(ORDER[i])
		var c := Panel.new()
		c.add_theme_stylebox_override("panel", Tok.box(Color("#16301f") if v else Color(1, 1, 1, 0.12), d / 2, 1.5, Tok.OK if v else Color(1, 1, 1, 0.3)))
		c.position = at + Vector2(i * (d + 5), 20)
		c.size = Vector2(d, d)
		var ic := Tok.icon(Catalog.station(ORDER[i]).emoji, d * 0.6)
		ic.position = Vector2(d * 0.2, d * 0.2)
		c.add_child(ic)
		if v:
			var t := Tok.tick(Color.WHITE, 13, Tok.OK, Tok.CARD)
			t.position = Vector2(d - 9, -4)
			c.add_child(t)
		$Bg/Scroll/Content/Tray/Stations.add_child(c)
	var r: Control = Tok.tick(Color("#4fe583"), 22) if s.get("allStationsPaid") else LockInReward.unknown_square(26)
	r.position = at + Vector2(w - r.size.x - 2, 20 + (d - r.size.y) / 2)
	$Bg/Scroll/Content/Tray/Stations.add_child(r)
	return 20 + d


## bingoCellHTML(): a parchment square (green inside rim when owned or
## craftable now; owned turns green), the icon, the name, the corner pin,
## the tier numeral; a capstone (inspect) shows its station too.
func _cell(name: String, sz: float, inspect: bool) -> Control:
	var s := Game.state
	var e = Catalog.entry(name)
	var owned := Catalog.owns(s, name)
	var craftable: bool = not inspect and not owned and e != null and Catalog.can_craft(s, e)
	var c := Panel.new()
	var sb := Tok.box(Color("#16301f") if owned else Color("#f2e6cc"), 16, 3 if owned or craftable else 0, Color("#4fe583"), 6, 4, Color(0, 0, 0, 0.4))
	c.add_theme_stylebox_override("panel", sb)
	c.size = Vector2(sz, sz)
	c.mouse_filter = MOUSE_FILTER_PASS  # taps still land; a drag scrolls the tray
	var ic := Tok.icon(Data.t("ITEM_EMOJI").get(name, ""), sz * 0.6)
	ic.position = Vector2(sz * 0.2, sz * 0.18)
	ic.material = Tok.outline(sz * 0.6 * 1.5)  # a 1px edge
	c.add_child(ic)
	# The name under the square (the user, 2026-11-26): bigger, centred, two
	# lines when long, never touching the next one's.
	var n := Tok.label(name, NAME_PX, Color.WHITE, 800)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.max_lines_visible = 2
	n.add_theme_constant_override("line_spacing", -3)
	n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	n.add_theme_constant_override("outline_size", 4)
	n.size = Vector2(sz + 4, NAME_H)
	n.position = Vector2(-2, sz + 3)
	n.set_meta("cmp", "market:name:" + name)
	c.add_child(n)
	if not inspect and not owned:  # what crafting it pays
		var q := LockInReward.unknown_square(16)
		q.position = Vector2(-4, -4)
		c.add_child(q)
	if inspect:
		var st := Tok.icon(Catalog.station(Data.t("CORE_ITEM_STATION")[name]).emoji, 16)
		st.position = Vector2(3, 3)
		c.add_child(st)
	var tier: String = Data.t("TIER_NUMERAL").get(Data.t("ITEM_TIER").get(name, ""), "")
	if tier != "":
		var t := Tok.label(tier, 8.5, Color("#2a1f08") if tier == "IV" else Color("#f2e6cc"), 800)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.add_theme_stylebox_override("normal", Tok.box(Tok.GOLD if tier == "IV" else Color("#2a2520"), 9.5, 1.5, Color.BLACK))
		t.position = Vector2(-5, sz - 14)
		t.size = Vector2(19, 19)
		c.add_child(t)
	var pinned := Progress.is_pinned(name)
	var pin := Panel.new()
	pin.add_theme_stylebox_override("panel", Tok.box(Tok.CARD, 10, 1.5, Tok.GOLD if pinned else Color.BLACK))
	pin.position = Vector2(sz - 17, -3)
	pin.size = Vector2(20, 20)
	var pic := Tok.icon("📌", 11)
	pic.position = Vector2(4.5, 4.5)
	if not pinned:
		pic.material = Tok.grey()
	pin.add_child(pic)
	pin.gui_input.connect(func(ev): if Tap.tap(ev):
		App.pin(name))
	c.add_child(pin)
	if e != null:  # not yet owned: craft it from here; else its card
		c.gui_input.connect(func(ev): if Tap.tap(ev):
			if not inspect and not owned:
				MarketCraft.open(App.current, name)
			else:
				App.current.show_card(name))
	return c
