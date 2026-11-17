## The suit-spend balloon (suit-spend.js, #suitSpendBalloon): a speech bubble
## on the Craft button of an item with a suit cost. One row per suit it
## costs, holding that suit's elements (white chips, × how many are spare
## beyond the recipe). Tapping one pays one more from it (cycling back to
## none); once every suit is covered it crafts. A tap outside closes it.
class_name SuitSpend
extends Control

const PICK := 56.0

var item: String
var anchor: Rect2  # the button it points at, in screen coordinates
var _picks := {}
var _balloon: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: queue_free())  # tap outside
	_build()


func _need() -> Dictionary:
	return Game.suit_cost_need(item)


func _reserved() -> Dictionary:
	return Catalog.needs_of(Catalog.entry(item).reqs).els


func _picked_for(suit: String) -> int:
	var n := 0
	for sym in _picks:
		if suit == "any" or Data.t("ELEMENT_SUIT").get(sym) == suit:
			n += _picks[sym]
	return n


func _build() -> void:
	if is_instance_valid(_balloon):
		_balloon.queue_free()
	var need := _need()
	var order: Array = Data.t("ELEMENT_SUIT_LABEL").keys() + ["any"]
	var suits := order.filter(func(s): return need.has(s))
	var rows: Array = suits.map(func(su): return Data.t("SUIT_CORE_ELEMENTS")[su])
	var cols := 0
	for r in rows:
		cols = maxi(cols, r.size())
	var row_h := PICK + 5 + 18
	var w := 12 * 2 + cols * PICK + (cols - 1) * 8
	var h := 12 * 2 + rows.size() * row_h + (rows.size() - 1) * 10
	_balloon = Control.new()
	_balloon.size = Vector2(w, h)
	var above := anchor.position.y - h - 12 >= 4
	var x := clampf(anchor.get_center().x - w / 2, 8, size.x - w - 8)
	_balloon.position = Vector2(x, anchor.position.y - h - 12 if above else anchor.end.y + 12)
	var tail_x := clampf(anchor.get_center().x - x, 14, w - 14)
	var bal := _balloon  # this balloon, not whichever _balloon is newest when it draws
	bal.draw.connect(func():  # the bubble and its diamond tail
		var ty := h if above else 0.0
		bal.draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 9, ty), Vector2(tail_x, ty + (9 if above else -9)), Vector2(tail_x + 9, ty)]), Tok.CARD)
		bal.draw_style_box(Tok.box(Tok.CARD, 16, 2, Tok.LINE, 14, 10, Color(0, 0, 0, 0.4)), Rect2(Vector2.ZERO, bal.size)))
	add_child(_balloon)
	var reserved := _reserved()
	for ri in rows.size():
		var row: Array = rows[ri]
		for ci in row.size():
			var sym: String = row[ci]
			var avail := maxf(0, Catalog.count(Game.state, sym) - reserved.get(sym, 0))
			var p := _pick(sym, int(avail), _picks.get(sym, 0), suits[ri])
			p.position = Vector2(12 + ci * (PICK + 8), 12 + ri * (row_h + 10))
			_balloon.add_child(p)


func _pick(sym: String, avail: int, have: int, suit: String) -> Control:
	var c := Control.new()
	c.size = Vector2(PICK, PICK + 5 + 18)
	var inert := avail <= 0 and have == 0
	if inert:
		c.modulate.a = 0.4
	var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 9, 7, color))
	box.size = Vector2(PICK, PICK)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	c.add_child(box)
	var l := Tok.label(sym, 23, Color("#221f1a"), 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = box.size
	c.add_child(l)
	var es: String = Data.t("ELEMENT_SUIT").get(sym, "")
	if es != "":
		var b := Panel.new()
		b.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(es), 6.5, 0, Color.BLACK, 2, 1, Color(0, 0, 0, 0.45)))
		b.position = Vector2(PICK - 14, 3)
		b.size = Vector2(13, 13)
		b.mouse_filter = MOUSE_FILTER_IGNORE
		var g := Tok.icon("suit:" + es, 9)
		g.position = Vector2(2, 2)
		g.material = Tok.white()
		b.add_child(g)
		c.add_child(b)
	var q := Tok.label("×%d" % avail, 13, Tok.INK, 800)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.position = Vector2(0, PICK + 3)
	q.size = Vector2(PICK, 18)
	c.add_child(q)
	if have > 0:  # how many picked, top-left
		var pk := Tok.label(str(have), 11, Color("#0f2733"), 800)
		pk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pk.add_theme_stylebox_override("normal", Tok.box(Color("#4fe583"), 11, 2, Tok.CARD))
		pk.position = Vector2(-6, -6)
		pk.size = Vector2(22, 22)
		c.add_child(pk)
	if not inert:
		c.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed: _tap(sym, suit, avail))
	return c


## One more from sym (back to none once it covers all its suit still needs);
## crafts when every suit is covered.
func _tap(sym: String, suit: String, avail: int) -> void:
	var need := _need()
	var have: int = _picks.get(sym, 0)
	var others := _picked_for(suit) - have
	var most := mini(avail, need[suit] - others)
	if most <= 0:
		return
	var next := 0 if have >= most else have + 1
	if next == 0:
		_picks.erase(sym)
	else:
		_picks[sym] = next
	if need.keys().all(func(su): return _picked_for(su) == need[su]):
		Game.craft(item, _picks)
		queue_free()
	else:
		_build()
