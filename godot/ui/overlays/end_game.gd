## The end of a run (showEndGame(), #endGame): a parchment window one phone
## screen tall, the title on its banner; the scores in a row, the capstones
## made, the biggest turn and most-visited station, the trophies won; the
## buttons pinned at the bottom. Also the Run Complete moment at turn 24
## (Continue in Overtime). The stats scroll if they must.
class_name EndGame
extends Control

const INK := Color("#3b2412")
const GOLD_SOFT := Color("#f6dd9c")  # --gold-soft on parchment
const GOLD_LINE := Color("#c9a24a")


## The layout is ui/overlays/end_game.tscn (every section, its icon, title
## and style, the buttons); this fills in the run and hides what's empty.
const SCENE := "res://ui/overlays/end_game.tscn"

## The trophy section's title with one trophy, and with none but Stars (⭐).
@export var one_trophy_title := "New Trophy"
@export var stars_title := "Stars Earned"

var _completing := false


static func make() -> EndGame:
	return load(SCENE).instantiate()


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
	var w := minf(420, size.x - 24)
	var inner := w - 2 * 38
	var won: Array = Progress.award_trophies()
	var body: VBoxContainer = $Window/Scroll/Body
	body.custom_minimum_size.x = inner
	var sub: Label = $Window/Scroll/Body/Sub
	sub.text = sub_text()
	sub.visible = sub.text != ""
	sub.custom_minimum_size.x = inner
	_stats()
	var caps: Array = Trophies.run_caps(s)
	var none: Label = $Window/Scroll/Body/Capstones/None
	none.visible = caps.is_empty()
	none.custom_minimum_size.x = inner
	for n in caps:
		$Window/Scroll/Body/Capstones/Pills.add_child(_cap_pill(n))
	var turn := _biggest_turn()
	$Window/Scroll/Body/BiggestTurn.visible = not turn.is_empty()
	if not turn.is_empty():
		_station_line($Window/Scroll/Body/BiggestTurn/Content/Line, turn.station, "+%s pts" % Util.thousands(int(turn.points)))
		for n in turn.items:
			$Window/Scroll/Body/BiggestTurn/Content/Items.add_child(Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), 28))
	var top := _top_station()
	$Window/Scroll/Body/MostVisited.visible = not top.is_empty()
	if not top.is_empty():
		_station_line($Window/Scroll/Body/MostVisited/Line, top.name, "%d×" % top.count)
	_trophy_section(won, int(Util.get_or(s, "starsEarned", 0)) if _completing else 0, inner)
	# Laid out at full height first; sized to its content a frame later
	# (wrapped text only knows its height then), up to the screen's.
	var foot := _foot(inner)
	var box: ParchmentWindow = $Window
	var scroll: ScrollContainer = $Window/Scroll
	var h := size.y - 40
	box.title = title_text()
	box.size = Vector2(w, h)
	box.position = Vector2((size.x - w) / 2, (size.y - h) / 2)
	scroll.size = Vector2(inner, h - scroll.position.y - 10 - foot.size.y - 24)
	foot.position = Vector2(scroll.position.x, h - 24 - foot.size.y)
	await get_tree().process_frame
	h = minf(scroll.position.y + body.size.y + 10 + foot.size.y + 24, size.y - 40)
	box.size.y = h
	box.position.y = (size.y - h) / 2
	scroll.size.y = h - scroll.position.y - 10 - foot.size.y - 24
	foot.position.y = h - 24 - foot.size.y
	box.queue_redraw()


## The scores in a row: small titles over the numbers.
func _stats() -> void:
	var s := Game.state
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var item_score := 0.0
	for n in s.items:
		item_score += pts.get(n, 0)
	var row := "Window/Scroll/Body/Stats/"
	get_node(row + "Quarks/Value").text = Util.thousands(Util.js_round(Util.get_or(s, "bestMatScore", 0)))
	get_node(row + "ItemScore/Value").text = Util.thousands(int(item_score))
	get_node(row + "Items/Value").text = str(s.items.size())
	get_node(row + "Capstones/Value").text = "%d/%d" % [Trophies.run_caps(s).size(), Data.t("CAPSTONES").size()]


## New Trophies (the tiles, 4 to a row), with the run's Stars as a pill at
## the right of the title; just the Stars when no trophy was won.
func _trophy_section(won: Array, stars: int, inner: float) -> void:
	var sec := $Window/Scroll/Body/Trophies
	sec.visible = not won.is_empty() or stars > 0
	var pill: Control = $Window/Scroll/Body/Trophies/Head/Stars
	pill.visible = stars > 0
	pill.get_node("Row/Text").text = "+%d" % stars
	var star := Tok.star(Color("#f5b400"), 13)  # drawn: Nunito has no ★
	star.size_flags_vertical = SIZE_SHRINK_CENTER
	pill.get_node("Row").add_child(star)
	var title: Label = $Window/Scroll/Body/Trophies/Head/Title
	if won.is_empty():
		$Window/Scroll/Body/Trophies/Head/Icon.texture = Data.icon("⭐")
		title.text = stars_title.to_upper()
		$Window/Scroll/Body/Trophies/Grid.visible = false
	elif won.size() == 1:
		title.text = one_trophy_title.to_upper()
	var tw := (inner - 18) / 4
	for t in won:  # trophyTileHTML(), earned
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
		$Window/Scroll/Body/Trophies/Grid.add_child(p)


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


## A station's icon and name, and a number at the right.
func _station_line(line: Control, name: String, right: String) -> void:
	var st = Catalog.station(name)
	line.get_node("Icon").visible = st != null
	if st != null:
		line.get_node("Icon").texture = Data.icon(st.emoji)
	line.get_node("Name").text = name
	line.get_node("Right").text = right


## The buttons, two to a row; Continue in Overtime spans the first row.
func _foot(inner: float) -> Control:
	var foot: Control = $Window/Foot
	var half := (inner - 8) / 2
	var go_on: Control = $Window/Foot/Continue
	var review: Control = $Window/Foot/Review
	go_on.visible = _completing
	review.visible = not _completing
	go_on.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	$Window/Foot/NewGame.gui_input.connect(func(ev): if Tap.tap(ev):
		queue_free()
		App.current.new_game())
	review.gui_input.connect(func(ev): if Tap.tap(ev):
		queue_free()
		App.current.open_panel("drawer"))
	$Window/Foot/MainMenu.gui_input.connect(func(ev): if Tap.tap(ev):  # the run ends: Play starts a new one (the user, 2026-11-26)
		queue_free()
		App.current.end_run()
		App.current.show_welcome())
	var x := 0.0
	var y := 0.0
	for c: Control in foot.get_children().filter(func(c): return c.visible):
		var wide := c == go_on
		c.size = Vector2(inner, 46) if wide else Vector2(half, 46).max(c.get_combined_minimum_size())  # never narrower than its text
		c.position = Vector2(x, y)
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
