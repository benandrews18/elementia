## The Marketplace (Home's Market face; job-board.js marketRowsHTML()): a
## tray dropping from the top, full width. The stations visited (a "?" for
## all 8); the Market on its brass-framed wood: 3 rows of 4 squares, each
## row ending in its "?" reward (a tick once paid); then every capstone.
## A square you don't own opens the Crafting Bench to craft it from here;
## the corner pin pins it. Home reads Map; a tap outside closes it.
## shortcut: tapping an owned square or a capstone opens nothing yet (the
## item card comes with M6's Items screen).
class_name MarketTray
extends Control


var cells := {}  # card index -> its square (the row sequence bounces them)
var _body: Control
var _scroll: ScrollContainer
var _tray: Control  # the content, at most 420 wide, centred (it scrolls when tall)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ConfirmDialog.scrim(self)
	_body = Control.new()
	add_child(_body)
	Game.state_changed.connect(_redraw)
	_redraw()


func _redraw() -> void:
	var keep := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	for c in _body.get_children():
		c.queue_free()
	cells.clear()
	var s := Game.state
	Market.ensure_card(s)
	var full := size.x
	var w := minf(420, full)  # a tablet's wider screen keeps phone-sized squares
	var bg := Panel.new()
	var sb := Tok.box(Tok.CARD, 14, 0)
	sb.border_width_bottom = 3
	sb.border_color = Tok.GOLD
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = MOUSE_FILTER_STOP
	_body.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	_scroll = scroll
	scroll.set_deferred("scroll_vertical", keep)  # a pin's redraw keeps your place
	var content := Control.new()
	content.mouse_filter = MOUSE_FILTER_PASS
	scroll.add_child(content)
	_tray = Control.new()
	_tray.mouse_filter = MOUSE_FILTER_PASS
	_tray.position.x = (full - w) / 2
	content.add_child(_tray)
	var y := 14.0 + _stations(Vector2(16, 14), w - 32) + 12
	# The Market: brass-framed wood with its rows.
	var panel := Frame9.new()
	panel.position = Vector2(16, y)
	_tray.add_child(panel)
	var pw := w - 32
	var head := Tok.label("Market", 16, Color.WHITE, 900)
	head.position = Vector2(14 + 22, 12)
	panel.add_child(head)
	var cart := Tok.icon("🛒", 18)
	cart.position = Vector2(14, 14)
	panel.add_child(cart)
	var hint := Tok.label("Complete a market row to earn a reward!", 11, Color("#b3becd"), 700)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(14 + 22 + 68, 10)
	hint.size = Vector2(pw - 14 - 22 - 68 - 46, 28)
	panel.add_child(hint)
	var gift := Tok.icon("🎁", 20)
	gift.position = Vector2(pw - 14 - 25, 12)
	panel.add_child(gift)
	var ry := 42.0
	var card: Array = s.bingoCard
	var lines := Market.lines()
	var cell := (pw - 28 - 13 - 6 - 30 - 3 * 8) / 4
	for r in lines.size():
		var done: bool = Util.get_or(s, "bingoLinesCompleted", []).any(func(x): return int(x) == r)
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD_SOFT if done else Color.TRANSPARENT, 14, 2, Tok.GOLD if done else Color.TRANSPARENT))
		row.position = Vector2(14, ry)
		row.size = Vector2(pw - 28, cell + 6 + 4)
		row.mouse_filter = MOUSE_FILTER_PASS
		panel.add_child(row)
		for k in lines[r].size():
			var idx: int = lines[r][k]
			var c := _cell(card[idx], cell, false)
			c.position = Vector2(10 + k * (cell + 8), 3)
			row.add_child(c)
			cells[idx] = c
		var rw: Control
		if done:
			rw = Tok.tick(Color("#4fe583"), 22)
		else:
			rw = LockInReward.unknown_square(26)
		rw.position = Vector2(row.size.x - 3 - 15 - rw.size.x / 2, (row.size.y - rw.size.y) / 2)
		row.add_child(rw)
		ry += row.size.y + 4
	var foot := Tok.label("Tap on an item to craft it directly from the market!", 11.5, Color("#ffe08a"), 800)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(0, ry)
	foot.size = Vector2(pw, 16)
	panel.add_child(foot)
	panel.size = Vector2(pw, ry + 16 + 10)
	y += panel.size.y + 12
	# Capstones: a reference list, pinnable.
	var ch := Tok.label("Capstones", 16, Color("#7d8899"), 900)
	ch.position = Vector2(16 + 24, y)
	_tray.add_child(ch)
	var trophy := Tok.icon("🏆", 18)
	trophy.position = Vector2(16, y + 2)
	_tray.add_child(trophy)
	y += 22
	var sub := Tok.label("Capstones must be crafted at their own station", 11.5, Color("#b3becd"), 400)
	sub.position = Vector2(16, y)
	_tray.add_child(sub)
	y += 22
	var caps := Market.capstone_choices()
	var cw := (w - 32 - 44 - 3 * 8) / 4
	for i in caps.size():
		var c := _cell(caps[i], cw, true)
		c.position = Vector2(16 + 22 + (i % 4) * (cw + 8), y + (i / 4) * (cw + 10))
		_tray.add_child(c)
	y += ceili(caps.size() / 4.0) * (cw + 10) + 8
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
	var l := Tok.label("%d/%d STATIONS VISITED" % [n, ORDER.size()], 11, Color(1, 1, 1, 0.75), 800)
	l.position = at
	_tray.add_child(l)
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
		_tray.add_child(c)
	var r: Control = Tok.tick(Color("#4fe583"), 22) if s.get("allStationsPaid") else LockInReward.unknown_square(26)
	r.position = at + Vector2(w - r.size.x - 2, 20 + (d - r.size.y) / 2)
	_tray.add_child(r)
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
	ic.position = Vector2(sz * 0.2, sz * 0.12)
	ic.material = Tok.outline(sz * 0.6 * 1.5)  # a 1px edge
	c.add_child(ic)
	var n := Tok.label(name, 8, Color.WHITE if owned else Color("#181614"), 700)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.position = Vector2(2, sz - 14)
	n.size = Vector2(sz - 4, 11)
	n.clip_text = true
	c.add_child(n)
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
	pin.gui_input.connect(func(ev): if ConvertTray._tap(ev):
		Progress.toggle_pin(name)
		Game._changed())
	c.add_child(pin)
	if not inspect and not owned and e != null:
		c.gui_input.connect(func(ev): if ConvertTray._tap(ev): MarketCraft.open(App.current, name))
	return c
