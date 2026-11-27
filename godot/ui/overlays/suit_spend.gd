## The suit-spend balloon (suit-spend.js, #suitSpendBalloon): a speech bubble
## on the Craft button of an item with a suit cost. One row per suit it
## costs, holding that suit's elements (white chips, × how many are spare
## beyond the recipe). Tapping one pays one more from it (cycling back to
## none); once every suit is covered it crafts. A tap outside closes it.
class_name SuitSpend
extends Control

## The layout is ui/overlays/suit_spend.tscn: the bubble's look (its tail
## takes the bubble's colour) and these sizes; the rows come from the item.
const SCENE := "res://ui/overlays/suit_spend.tscn"

@export var bubble: StyleBox
## An element square's size, the bubble's padding, the gaps between squares (x) and rows (y).
@export var pick := 56.0
@export var pad := 12.0
@export var gap := Vector2(8, 10)
@export var tail := 9.0

var item: String
var anchor: Rect2  # the button it points at, in screen coordinates
## The three balloons (the user, 2026-11-26): paying a suit cost (item: rows
## per suit, spare counts, taps pay); a tapped suit icon (view_suit: its name
## over its elements, no counts, no taps); the suit counter's ring
## (view_counts too: the same with how many of each you hold).
var view_suit := ""
var view_counts := false
const TITLE_H := 30.0


## A tapped suit icon: the balloon pointing at it, the suit's name (its icon
## and REACTIVE, ...) over its elements. A tap anywhere closes it.
static func show_suit(su: String, target: Control, counts := false) -> void:
	if App.current == null:
		return
	var b := make()
	b.view_suit = su
	b.view_counts = counts
	b.anchor = target.get_global_rect()
	b.size = App.current.size
	b.set_meta("cmp", "suitview:" + su)
	App.current.add_child(b)


## Makes a suit icon open show_suit() when tapped.
static func on_tap(c: Control, su: String, counts := false) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev): if Tap.tap(ev): show_suit(su, c, counts))
var _picks := {}
var _above := true
var _tail_x := 0.0
@onready var _balloon: Control = $Balloon


static func make() -> SuitSpend:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	gui_input.connect(func(ev): if Tap.tap(ev): queue_free())  # tap outside
	_balloon.draw.connect(func():  # the bubble and its diamond tail
		var ty := _balloon.size.y if _above else 0.0
		var col: Color = bubble.bg_color if bubble is StyleBoxFlat else Tok.CARD
		_balloon.draw_colored_polygon(PackedVector2Array([Vector2(_tail_x - tail, ty), Vector2(_tail_x, ty + (tail if _above else -tail)), Vector2(_tail_x + tail, ty)]), col)
		_balloon.draw_style_box(bubble, Rect2(Vector2.ZERO, _balloon.size)))
	_build()


func _need() -> Dictionary:
	return Game.suit_cost_need(item)


func _reserved() -> Dictionary:
	return Catalog.needs_of(Catalog.entry(item).reqs).els


func _picked_for(suit: String) -> int:
	var n := 0
	for sym in _picks:
		if Data.t("ELEMENT_SUIT").get(sym) == suit:
			n += _picks[sym]
	return n


func _build() -> void:
	for c in _balloon.get_children():
		c.queue_free()
	var view := view_suit != ""
	var need := {} if view else _need()
	var suits: Array = [view_suit] if view else Data.t("ELEMENT_SUIT_LABEL").keys().filter(func(s): return need.has(s))
	var rows: Array = suits.map(func(su): return Data.t("SUIT_CORE_ELEMENTS")[su])
	var cols := 0
	for r in rows:
		cols = maxi(cols, r.size())
	var row_h := pick if view and not view_counts else pick + 5 + 18  # no counts: just looking
	var top := TITLE_H  # view: the suit's name; paying: "Choose 1 (icon), 2 (icon)" (what's still to pick)
	var w := pad * 2 + cols * pick + (cols - 1) * gap.x
	var h := pad * 2 + top + rows.size() * row_h + (rows.size() - 1) * gap.y
	_balloon.size = Vector2(w, h)
	_above = anchor.position.y - h - 12 >= 4
	var x := clampf(anchor.get_center().x - w / 2, 8, size.x - w - 8)
	_balloon.position = Vector2(x, anchor.position.y - h - 12 if _above else anchor.end.y + 12)
	_tail_x = clampf(anchor.get_center().x - x, 14, w - 14)
	_balloon.queue_redraw()
	if view:  # the title: the suit's icon and its name
		var g := Tok.icon("suit:" + view_suit, 20)
		g.material = Tok.tinted(Tok.suit_color(view_suit))
		var t := Tok.label(str(Data.t("ELEMENT_SUIT_LABEL")[view_suit]), 15, Tok.INK, 900)
		t.add_theme_font_override("font", Tok.font(900, 1))
		var tw := 20 + 6 + Tok.font(900, 1).get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		g.position = Vector2((w - tw) / 2, pad + 2)
		t.position = Vector2(g.position.x + 26, pad + 2 + (20 - Tok.font(900, 1).get_height(15)) / 2)
		t.set_meta("cmp", "suitview:title")
		_balloon.add_child(g)
		_balloon.add_child(t)
	if not view:
		_choose_title(need, w)
	var reserved := {} if view else _reserved()
	for ri in rows.size():
		var row: Array = rows[ri]
		for ci in row.size():
			var sym: String = row[ci]
			var avail := -1.0 if view and not view_counts else float(Catalog.count(Game.state, sym)) if view else maxf(0, Catalog.count(Game.state, sym) - reserved.get(sym, 0))
			var p := _pick(sym, int(avail), _picks.get(sym, 0), suits[ri], view)
			p.position = Vector2(pad + ci * (pick + gap.x), pad + top + ri * (row_h + gap.y))
			_balloon.add_child(p)


func _pick(sym: String, avail: int, have: int, suit: String, view := false) -> Control:
	var c := Control.new()  # avail -1: no count shown
	c.size = Vector2(pick, pick if avail < 0 else pick + 5 + 18)
	c.mouse_filter = MOUSE_FILTER_IGNORE if view else MOUSE_FILTER_STOP
	var inert := avail == 0 and have == 0  # none held (or spare): faded
	if inert:
		c.modulate.a = 0.4
	var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 9, 7, color))
	box.size = Vector2(pick, pick)
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
		b.position = Vector2(pick - 14, 3)
		b.size = Vector2(13, 13)
		b.mouse_filter = MOUSE_FILTER_IGNORE
		var g := Tok.icon("suit:" + es, 9)
		g.position = Vector2(2, 2)
		g.material = Tok.white()
		b.add_child(g)
		c.add_child(b)
	if avail >= 0:
		var q := Tok.label("×%d" % avail, 13, Tok.INK, 800)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.position = Vector2(0, pick + 3)
		q.size = Vector2(pick, 18)
		c.add_child(q)
	if have > 0:  # how many picked, top-left
		var pk := Tok.label(str(have), 11, Color("#0f2733"), 800)
		pk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pk.add_theme_stylebox_override("normal", Tok.box(Color("#4fe583"), 11, 2, Tok.CARD))
		pk.position = Vector2(-6, -6)
		pk.size = Vector2(22, 22)
		c.add_child(pk)
	if not inert and not view:
		c.gui_input.connect(func(ev): if Tap.tap(ev): _tap(sym, suit, avail))
	return c


## Paying (the user, 2026-11-26): "Choose" and, for each suit still short,
## how many more and its icon ("Choose 1 (fire), 2 (leaf)"), centred.
func _choose_title(need: Dictionary, w: float) -> void:
	var f := Tok.font(900)
	var parts: Array = [Tok.label("Choose", 15, Tok.INK, 900)]
	var first := true
	for su in Data.t("ELEMENT_SUIT_LABEL").keys():
		var left: int = int(need.get(su, 0)) - _picked_for(su)
		if left <= 0:
			continue
		var n := Tok.label(("" if first else ", ") + str(left), 15, Tok.INK, 900)
		n.set_meta("cmp", "suitspend:need:" + su)
		parts.append(n)
		var g := Tok.icon("suit:" + su, 18)
		g.material = Tok.tinted(Tok.suit_color(su))
		parts.append(g)
		first = false
	var total := 0.0
	for p in parts:
		total += (f.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 4) if p is Label else 20.0
	var x := (w - total) / 2
	var mid := pad + 2 + 10.0
	for p in parts:
		if p is Label:
			p.text = p.text + " " if p.text == "Choose" else p.text
			p.position = Vector2(x, mid - f.get_height(15) / 2)
			x += f.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 2
		else:
			p.position = Vector2(x, mid - 9)
			x += 20.0
		_balloon.add_child(p)


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
