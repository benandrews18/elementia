## The end of a run (showEndGame(), #endGame): a parchment window one phone
## screen tall, the title on its banner; the scores in a row, the capstones
## made, the biggest turn and most-visited station, the trophies won; the
## buttons pinned at the bottom. Also the Run Complete moment at turn 24
## (Continue in Overtime). The stats scroll if they must.
## shortcut: no Main Menu button until the welcome screen exists (M6).
class_name EndGame
extends Control

const INK := Color("#3b2412")
const INK2 := Color("#5e4026")
const MUTE := Color("#8a6a48")
const LINE := Color("#c9a571")
const GOLD_SOFT := Color("#f6dd9c")  # --gold-soft on parchment
const GOLD_LINE := Color("#c9a24a")

var _completing := false


static func title_text() -> String:
	var s := Game.state
	if s.get("runComplete") and not s.ended:
		return "Run Complete!"
	if s.get("craftedEverything"):
		return "Every Item Crafted!"
	if s.get("reachedHardLimit"):
		return "You Reached the End!"
	return "Overtime Over" if s.get("runComplete") else "Game Over"


static func sub_text() -> String:
	var s := Game.state
	if s.get("runComplete") and not s.ended:
		return ""
	if s.get("craftedEverything"):
		return "You crafted every item in Elementia in %d visits -- here's your run:" % s.visits
	if s.get("reachedHardLimit"):
		return "You kept clearing the Quark breakpoint all the way to visit %d -- here's your run:" % s.visits
	if s.get("runComplete"):
		return "Your board missed the first Quark breakpoint on an Overtime Lock-In at visit %d. Your run still counts as complete. Here's what you built:" % s.visits
	return "Game over -- missed the first Quark breakpoint on a Lock-In from visit %d on. Here's what you built:" % Data.t("BREAKPOINT_GATE_VISIT")


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var s := Game.state
	_completing = s.get("runComplete") == true and not s.ended
	var dim := ColorRect.new()
	dim.color = Color(10 / 255.0, 14 / 255.0, 20 / 255.0, 0.72)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	var w := minf(420, size.x - 24)
	var inner := w - 2 * 38
	var won: Array = Progress.award_trophies()
	# The body, top to bottom, in a VBox (it scrolls inside the window).
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.custom_minimum_size.x = inner
	var sub := sub_text()
	if sub != "":
		var l := Tok.label(sub, 13, INK2, 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = inner
		body.add_child(l)
	body.add_child(_stats(inner))
	var caps: Array = Trophies.run_caps(s)
	if caps.is_empty():
		var none := Tok.label("None this time -- plan a route through several stations next run!", 13, INK2, 600)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = inner
		body.add_child(_section("🏆", "Capstones Completed", none))
	else:
		body.add_child(_section("🏆", "Capstones Completed", _flow(caps.map(_cap_pill), inner)))
	var turn := _biggest_turn()
	if not turn.is_empty():
		var v := VBoxContainer.new()
		v.add_child(_station_line(turn.station, "+%s pts" % Util.thousands(int(turn.points)), inner))
		v.add_child(_flow(turn.items.map(func(n): return Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), 28)), inner))
		body.add_child(_section("💥", "Biggest Turn", v))
	var top := _top_station()
	if not top.is_empty():
		body.add_child(_section("🧭", "Station Most Visited", _station_line(top.name, "%d×" % top.count, inner)))
	var stars: int = int(Util.get_or(s, "starsEarned", 0)) if _completing else 0
	if not won.is_empty():
		body.add_child(_section("🎖️", "New Trophy" if won.size() == 1 else "New Trophies", _trophies(won, inner), stars))
	elif stars > 0:
		body.add_child(_section("⭐", "Stars Earned", null, stars))
	# Laid out at full height first; sized to its content a frame later
	# (wrapped text only knows its height then), up to the screen's.
	var foot := _foot(inner)
	var h := size.y - 40
	var box := ConfirmDialog.window(Vector2(w, h), title_text())
	box.position = Vector2((size.x - w) / 2, (size.y - h) / 2)
	add_child(box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(38, 59)
	scroll.size = Vector2(inner, h - 59 - 10 - foot.size.y - 24)
	scroll.add_child(body)
	box.add_child(scroll)
	foot.position = Vector2(38, h - 24 - foot.size.y)
	box.add_child(foot)
	await get_tree().process_frame
	h = minf(59 + body.size.y + 10 + foot.size.y + 24, size.y - 40)
	box.size.y = h
	box.position.y = (size.y - h) / 2
	scroll.size.y = h - 59 - 10 - foot.size.y - 24
	foot.position.y = h - 24 - foot.size.y
	box.queue_redraw()


## The scores in a row: small titles over the numbers.
func _stats(inner: float) -> Control:
	var s := Game.state
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var item_score := 0.0
	for n in s.items:
		item_score += pts.get(n, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var caps := "%d/%d" % [Trophies.run_caps(s).size(), Data.t("CAPSTONES").size()]
	for st in [["⚛️", "Quarks", Util.thousands(Util.js_round(Util.get_or(s, "bestMatScore", 0)))], ["💯", "Item Score", Util.thousands(int(item_score))],
			["🛠️", "Items", str(s.items.size())], ["🏆", "Capstones", caps]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_theme_constant_override("separation", 3)
		head.add_child(Tok.icon(st[0], 12))
		head.add_child(Tok.label(st[1], 10, MUTE, 800))
		col.add_child(head)
		var n := Tok.label(st[2], 21, INK, 900)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		row.add_child(col)
	row.custom_minimum_size.x = inner
	return row


## .end-sec: an icon and an upper-case title over a line, then the content;
## the run's Stars as a pill at the right of the title.
func _section(icon: String, title: String, content, stars := 0) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(Tok.icon(icon, 15))
	var t := Tok.label(title.to_upper(), 12, INK2, 900)
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(t)
	if stars > 0:
		var pill := PanelContainer.new()  # "+n ★" (the star drawn: not in Nunito)
		pill.add_theme_stylebox_override("panel", Shutter._pad(Tok.box(GOLD_SOFT, 999, 1.5, Tok.GOLD), 9, 2))
		var ph := HBoxContainer.new()
		ph.add_theme_constant_override("separation", 3)
		ph.add_child(Tok.label("+%d" % stars, 12, INK, 900))
		var star := Tok.star(Color("#f5b400"), 13)
		star.size_flags_vertical = SIZE_SHRINK_CENTER
		ph.add_child(star)
		pill.add_child(ph)
		head.add_child(pill)
	v.add_child(head)
	var rule := ColorRect.new()
	rule.color = Color(LINE, 0.6)
	rule.custom_minimum_size = Vector2(0, 1.5)
	v.add_child(rule)
	if content != null:
		v.add_child(content)
	return v


func _cap_pill(n: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Shutter._pad(Tok.box(GOLD_SOFT, 999, 1.5, GOLD_LINE), 6, 3))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.add_child(Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), 26))
	var l := Tok.label(n, 12.5, INK, 800)
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(l)
	p.add_child(h)
	return p


func _station_line(name: String, right: String, inner: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	var st = Catalog.station(name)
	if st != null:
		h.add_child(Tok.icon(st.emoji, 28))
	var n := Tok.label(name, 15, INK, 800)
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	n.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(n)
	var r := Tok.label(right, 15, Color("#b7791f"), 900)
	r.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(r)
	h.custom_minimum_size.x = inner
	return h


func _flow(items: Array, inner: float) -> Control:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	f.custom_minimum_size.x = inner
	for c in items:
		f.add_child(c)
	return f


## The trophy tiles, 4 to a row (trophyTileHTML(), earned).
func _trophies(won: Array, inner: float) -> Control:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var tw := (inner - 18) / 4
	for t in won:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Shutter._pad(Tok.box(GOLD_SOFT, 12, 1.5, Tok.GOLD), 4, 6))
		p.custom_minimum_size.x = tw
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var ic := Tok.icon(t.icon, 26)
		ic.size_flags_horizontal = SIZE_SHRINK_CENTER
		v.add_child(ic)
		var n := Tok.label(t.name + (" ×%d" % t.again if t.has("again") else ""), 10.5, INK, 800)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size.x = tw - 8
		v.add_child(n)
		p.add_child(v)
		g.add_child(p)
	return g


## The buttons, two to a row; Continue in Overtime spans the first row.
func _foot(inner: float) -> Control:
	var foot := Control.new()
	var half := (inner - 8) / 2
	var btns := []
	if _completing:
		btns.append(["Continue in Overtime", true, func(): queue_free()])
	btns.append(["New Game", false, func():
		queue_free()
		App.current.new_game()])
	if not _completing:
		btns.append(["Review my collection", false, func():
			queue_free()
			App.current.open_panel("drawer")])
	var x := 0.0
	var y := 0.0
	for i in btns.size():
		var b: Array = btns[i]
		var wide: bool = b[1]
		var bw := inner if wide else half
		var c: Control
		if wide:
			c = RollPopup._pill_button(b[0], Vector2(bw, 46))
		else:
			var l := Tok.label(b[0], 13.5, INK, 800)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_stylebox_override("normal", Tok.box(Color("#e6cf9f"), 11, 1.5, LINE))
			l.mouse_filter = MOUSE_FILTER_STOP
			l.size = Vector2(bw, 46)
			c = l
		c.position = Vector2(x, y)
		var act: Callable = b[2]
		c.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: act.call())
		foot.add_child(c)
		if wide or x > 0:
			x = 0
			y += 46 + 8
		else:
			x = half + 8
	foot.size = Vector2(inner, y + (46 if x > 0 else -8))
	return foot


## biggestTurn(): the visit whose crafts scored most.
func _biggest_turn() -> Dictionary:
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var best := {}
	for t in Util.get_or(Game.state, "visitLog", []):
		var p := 0.0
		for i in t.get("items", []):
			p += pts.get(i, 0)
		if p > 0 and (best.is_empty() or p > best.points):
			best = {"station": t.station, "items": t.items, "points": p}
	return best


## topVisitedStation(): the first station with the most visits.
func _top_station() -> Dictionary:
	var counts := {}
	for t in Util.get_or(Game.state, "visitLog", []):
		counts[t.station] = counts.get(t.station, 0) + 1
	var top = null
	for s in counts:
		if top == null or counts[s] > counts[top]:
			top = s
	return {} if top == null else {"name": top, "count": counts[top]}
