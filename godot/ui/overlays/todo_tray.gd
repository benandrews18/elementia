## The To-Do List (the hub's To-Do List button; job-board.js
## classicPinsAndJobsHTML()): a tray sliding in from the left with the
## pinned items. Each row: icon (suit costs under it), name, points, where
## it's made, "Full breakdown" opening its recipe tree (items expand in
## turn, elements show where they're rolled), and its pin. "Get a Hint"
## suggests what to craft next and lights it up in the trees.
## shortcut: no 🔍 "tracked" badge (Godot has no tracked item yet).
class_name TodoTray
extends Control

const INK := Color("#2a1f14")
const EDGE := Color("#b08a5a")
const ROW := 50.0  # a tree row's height

static var expanded := {}  # "refroot/<item>" and "ref/<root>/.../<item>" paths shown open
static var hint_open := false

## The layout is ui/overlays/todo_tray.tscn (the tray, the "Pinned" heading);
## this builds the pinned items' trees.
const SCENE := "res://ui/overlays/todo_tray.tscn"

@onready var _scroll: ScrollContainer = $Tray/Scroll
@onready var _list: Control = $Tray/Scroll/List/Items  # what's rebuilt (the heading stays)
var _hint_name := ""


static func make() -> TodoTray:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Scrim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed and App.current: App.current.close_panel())
	var w := minf(400, size.x * 0.92)
	$Tray.size = Vector2(w, size.y - HubBar.H)
	_scroll.size = $Tray.size - Vector2(3, 3)
	Game.state_changed.connect(_redraw)
	_redraw()


func _redraw() -> void:
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		c.queue_free()
	var w := _scroll.size.x - 40
	var names: Array = Progress.prefs.pinnedItems.filter(func(n): return Catalog.entry(n) != null)
	var y := 20.0
	$Tray/Scroll/List/Pin.visible = not names.is_empty()
	$Tray/Scroll/List/Pinned.visible = not names.is_empty()
	if not names.is_empty():
		y += 26
		var hint = Game.todo_hint() if hint_open else null
		_hint_name = hint.name if hint != null else ""
		y = _hint_button(y) + 10
		if hint_open:
			y = _hint_card(hint, y, w) + 16
		for n in names:
			y = _row(Catalog.entry(n), Vector2(20, y + 6), w) + 14
	$Tray/Scroll/List.custom_minimum_size = Vector2(_scroll.size.x, y + 20)
	_scroll.set_deferred("scroll_vertical", keep)


func _toggle(path: String) -> void:
	if expanded.has(path):
		expanded.erase(path)
	else:
		expanded[path] = true
	_redraw()


## "Get a Hint" / "Hide Hint"; opening it opens every breakdown down to the
## suggestion (expandTodoHintPaths()).
func _hint_button(y: float) -> float:
	var text := "Hide Hint" if hint_open else "Get a Hint"
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color(1, 1, 1, 0.08), 16))
	var tw := Tok.font(800).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	b.size = Vector2(tw + 26 + 28, 32)
	b.position = Vector2(20, y)
	var ic := Tok.icon(Data.t("ITEM_EMOJI")["Light Bulb"], 15)
	ic.position = Vector2(16, 8.5)
	b.add_child(ic)
	var l := Tok.label(text, 13, Color("#b3becd"), 800)
	l.position = Vector2(36, 6)
	b.add_child(l)
	b.gui_input.connect(func(ev): if ConvertTray._tap(ev):
		hint_open = not hint_open
		if hint_open:
			_open_hint_paths()
		_redraw())
	_list.add_child(b)
	return y + 32


func _open_hint_paths() -> void:
	var hint = Game.todo_hint()
	if hint == null:
		return
	for root in hint.roots:
		if root == hint.name:
			continue
		expanded["refroot/" + root] = true
		for trail in _trails(root, hint.name):
			var path: String = "ref/" + root
			for n in trail.slice(0, -1):
				path += "/" + n
				expanded[path] = true


## hintTrails(): every path from root's breakdown down to target, through
## unowned items (at most 8, 8 deep).
static func _trails(root: String, target: String) -> Array:
	var out := []
	var walk := func(cur: String, trail: Array, self_ref: Callable) -> void:
		if out.size() >= 8 or trail.size() > 8:
			return
		var e = Catalog.entry(cur)
		if e == null:
			return
		for it in Catalog.needs_of(e.reqs).items:
			if trail.has(it.name):
				continue
			if it.name == target:
				out.append(trail + [it.name])
			elif not Catalog.owns(Game.state, it.name):
				self_ref.call(it.name, trail + [it.name], self_ref)
	walk.call(root, [], walk)
	return out


## The hint's card: the item, why, whether it can be made now, where.
func _hint_card(hint, y: float, w: float) -> float:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Tok.box(Color("#241c3a"), 12, 1.5, Color("#4b3d77")))
	card.position = Vector2(20, y)
	_list.add_child(card)
	if hint == null:
		var none := Tok.label("Everything on your list is already crafted!", 13, Color("#b3becd"), 700)
		none.position = Vector2(14, 12)
		card.add_child(none)
		card.size = Vector2(w, 42)
		return y + 42
	var ic := Tok.icon(hint.entry.emoji, 36)
	ic.position = Vector2(14, 0)
	card.add_child(ic)
	var others: Array = hint.roots.filter(func(r): return r != hint.name)
	var why := "It's on your list"
	if not others.is_empty():
		why = "Needed for " + " and ".join(others.slice(0, 2)) + (" and %d more" % (others.size() - 2) if others.size() > 2 else "")
	var status := "You can craft it now!" if hint.can_now else ("Still need: " + ", ".join(hint.missing) if not hint.missing.is_empty() else "You have its elements -- check its suit cost")
	var lines := [["Try crafting " + hint.name, 15, Color.WHITE, 900], [why, 12, Color("#b3becd"), 400],
		[status, 12, Color("#4fe583") if hint.can_now else Color("#b3becd"), 900]]
	var ly := 12.0
	for l in lines:
		var t := Tok.label(l[0], l[1], l[2], l[3])
		t.position = Vector2(62, ly)
		t.size = Vector2(w - 72, 0)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(t)
		ly += l[1] * 1.45
	var x := 62.0
	for h in hint.homes:
		var sic := Tok.icon(Catalog.station(h).emoji, 14)
		sic.position = Vector2(x, ly + 2)
		card.add_child(sic)
		var hl := Tok.label(h, 12, Color("#e8edf4"), 700)
		hl.position = Vector2(x + 18, ly)
		card.add_child(hl)
		x += 18 + Tok.font(700).get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12
	ly += 22
	card.size = Vector2(w, ly + 10)
	ic.position.y = (card.size.y - 36) / 2
	return y + card.size.y


## refStyleRowHTML(): a parchment card with its pushpin; returns its bottom.
func _row(e: Dictionary, at: Vector2, w: float) -> float:
	var owned := Catalog.owns(Game.state, e.name)
	var path: String = "refroot/" + e.name
	var open := expanded.has(path)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Tok.box(Color("#dff2e2") if owned else Color("#f3e6c8"), 14, 2,
		Color("#4fbf7a") if owned else Color("#c9a571"), 4, 2, Color(0, 0, 0, 0.3)))
	card.position = at
	card.mouse_filter = MOUSE_FILTER_PASS
	card.gui_input.connect(func(ev): if ConvertTray._tap(ev) and App.current: App.current.show_card(e.name))  # its card
	_list.add_child(card)
	var tack := Panel.new()  # the red pushpin at the top
	tack.add_theme_stylebox_override("panel", Tok.box(Color("#d9483c"), 6.5, 0, Color.BLACK, 2, 1, Color(0, 0, 0, 0.4)))
	tack.size = Vector2(13, 13)
	tack.position = Vector2(w / 2 - 6.5, -6)
	card.add_child(tack)
	var ic := Tok.icon(e.emoji, 40)
	ic.position = Vector2(16, 18)
	card.add_child(ic)
	var sx := 16.0
	for su in Data.t("ITEM_SUIT_COST_TABLE").get(e.name, []):
		var g := Tok.icon("suit:" + su, 11)
		g.material = Tok.tinted(Tok.suit_color(su))
		g.position = Vector2(sx, 62)
		card.add_child(g)
		sx += 14
	var name_l := Tok.label(e.name, 17, INK, 900)
	name_l.position = Vector2(66, 14)
	card.add_child(name_l)
	var nx := 66 + Tok.font(900).get_string_size(e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 6
	if owned:
		var t := Tok.tick(Color.WHITE, 16, Tok.OK)
		t.position = Vector2(nx, 18)
		card.add_child(t)
	var pts := Panel.new()  # ⭐ points
	pts.add_theme_stylebox_override("panel", Tok.box(Color("#fbe9b5"), 10))
	var ptxt := str(int(e.points))
	pts.size = Vector2(20 + Tok.font(900).get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14, 20)
	pts.position = Vector2(w - 56 - pts.size.x, 16)
	var star := Tok.star(Color("#f5b400"), 12)
	star.position = Vector2(7, 4)
	pts.add_child(star)
	var pl := Tok.label(ptxt, 12, INK, 900)
	pl.position = Vector2(23, 1)
	pts.add_child(pl)
	card.add_child(pts)
	var hx := 66.0
	for h in Data.t("ENTRIES").filter(func(x): return x.name == e.name).map(func(x): return x.station):
		var sic := Tok.icon(Catalog.station(h).emoji, 13)
		sic.position = Vector2(hx, 42)
		card.add_child(sic)
		var hl := Tok.label(h, 12, Color("#5e4026"), 600)
		hl.position = Vector2(hx + 17, 40)
		card.add_child(hl)
		hx += 17 + Tok.font(600).get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
	var tog := Control.new()  # ▸ Full breakdown
	tog.position = Vector2(64, 60)
	tog.size = Vector2(170, 20)
	tog.mouse_filter = MOUSE_FILTER_STOP
	var arrow := _arrow(open, Color("#8a5a1a"))
	arrow.position = Vector2(2, 5)
	tog.add_child(arrow)
	var tl := Tok.label("Hide full breakdown" if open else "Full breakdown", 11.5, Color("#8a5a1a"), 800)
	tl.position = Vector2(16, 1)
	tog.add_child(tl)
	tog.gui_input.connect(func(ev): if ConvertTray._tap(ev): _toggle(path))
	card.add_child(tog)
	card.add_child(_pin_button(e.name, Vector2(w - 48, 14), true))
	var h := 88.0
	if open:
		var seen := {}
		var toks := []
		for r in e.reqs:
			if not seen.has(r.kind + ":" + r.name):
				seen[r.kind + ":" + r.name] = true
				toks.append(r)
		h = _nodes(card, _sorted(toks), "ref/" + e.name, {e.name: true}, Vector2(16, h), w - 32) + 10
	card.size = Vector2(w, h)
	return at.y + h


static func _sorted(toks: Array) -> Array:
	var pts: Dictionary = Data.t("ITEM_POINTS")
	return toks.filter(func(r): return r.kind == "element") + Util.stable_sort(toks.filter(func(r): return r.kind != "element"),
		func(a, b): return pts.get(a.name, 0) - pts.get(b.name, 0))


## jobNodeHTML(): one level of the tree in parent, from at; returns the bottom.
func _nodes(parent: Control, toks: Array, path: String, seen: Dictionary, at: Vector2, w: float) -> float:
	var y := at.y
	for r in toks:
		y = _node(parent, r.name, r.kind, path + "/" + r.name, seen, Vector2(at.x, y), w) + 8
	return y - 8


func _node(parent: Control, name: String, kind: String, path: String, seen: Dictionary, at: Vector2, w: float) -> float:
	var s := Game.state
	var row_w := w - 50
	if kind == "element":  # a leaf: the element, its name, where it's rolled
		var have := Catalog.count(s, name) >= 1
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", Tok.box(Color("#dff2e2") if have else Color("#fdf8ec"), 12, 1.5, Color("#4fbf7a") if have else EDGE))
		box.position = at
		box.size = Vector2(row_w, ROW)
		parent.add_child(box)
		var chip := StationScreen.element_chip(name, 28)
		chip.get_child(chip.get_child_count() - 1).visible = false  # no caption
		chip.position = Vector2(12, 11)
		box.add_child(chip)
		var nl := Tok.label(Data.t("ELEMENT_NAMES").get(name, name), 15, INK, 800)
		nl.position = Vector2(50, 14)
		box.add_child(nl)
		_where(box, name, "element", row_w)
		return at.y + ROW
	var e = Catalog.entry(name)
	if e == null:
		return at.y - 8
	var has := Catalog.owns(s, name)
	var open := expanded.has(path)
	var x0 := at.x + (24.0 if has else 0.0)
	if has:
		var t := Tok.tick(Tok.OK, 22)
		t.position = Vector2(at.x, at.y + 14)
		parent.add_child(t)
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Tok.box(Color("#dff2e2") if has else Color("#fdf8ec"), 12, 1.5, Color("#4fbf7a") if has else EDGE))
	box.position = Vector2(x0, at.y)
	box.size = Vector2(row_w - (x0 - at.x), ROW)
	box.mouse_filter = MOUSE_FILTER_STOP
	box.gui_input.connect(func(ev): if ConvertTray._tap(ev): _toggle(path))
	parent.add_child(box)
	var arrow := _arrow(open, INK)
	arrow.position = Vector2(12, 20)
	box.add_child(arrow)
	var ic := Tok.icon(e.emoji, 22)
	ic.position = Vector2(30, 14)
	box.add_child(ic)
	var nl := Tok.label(name, 16, INK, 800)
	nl.position = Vector2(60, 13)
	box.add_child(nl)
	_where(box, name, "item", box.size.x)
	parent.add_child(_pin_button(name, Vector2(at.x + row_w + 8, at.y + 5), false))
	if name == _hint_name and hint_open:  # the suggestion, outlined in green
		var hl := Panel.new()
		hl.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 14, 3, Color("#4fe583")))
		hl.position = Vector2(x0 - 4, at.y - 4)
		hl.size = Vector2(w - (x0 - at.x) + 8, ROW + 8)
		hl.mouse_filter = MOUSE_FILTER_IGNORE
		parent.add_child(hl)
	var y := at.y + ROW
	if open and not seen.has(name):
		var seen2 := seen.duplicate()
		seen2[name] = true
		var dedup := {}
		var toks := []
		for r in e.reqs:
			if not dedup.has(r.kind + ":" + r.name):
				dedup[r.kind + ":" + r.name] = true
				toks.append(r)
		var top := y + 8
		y = _nodes(parent, _sorted(toks), path, seen2, Vector2(at.x + 20, top), w - 20)
		var rule := ColorRect.new()  # the branch line down the left
		rule.color = Color("#8a6a48")
		rule.position = Vector2(at.x + 6, top)
		rule.size = Vector2(2, y - top)
		parent.add_child(rule)
	return y


## Where it comes from, as station icons at the row's right end.
func _where(box: Control, name: String, kind: String, w: float) -> void:
	var where: Array = Data.t("STATION_BY_NAME").values().filter(func(st): return st.dice.has(name)).map(func(st): return st.name) if kind == "element" \
		else Data.t("ENTRIES").filter(func(x): return x.name == name).map(func(x): return x.station)
	var uniq := []
	for st in where:
		if not uniq.has(st):
			uniq.append(st)
	var x := w - 14 - uniq.size() * 20
	for st in uniq:
		var ic := Tok.icon(Catalog.station(st).emoji, 18)
		ic.position = Vector2(x, 16)
		box.add_child(ic)
		x += 20


## The pin button (refpin): the big dark one on a row, grey squares in trees.
func _pin_button(name: String, at: Vector2, big: bool) -> Control:
	var pinned := Progress.is_pinned(name)
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color("#3a2414") if big else Color("#e9e4da"), 8, 2,
		Tok.GOLD if big and pinned else Color("#b9b0a0"), 3, 2, Color(0, 0, 0, 0.3)))
	b.size = Vector2(34, 34) if big else Vector2(40, 40)
	b.position = at
	var ic := Tok.icon("📌", 18)
	ic.position = (b.size - Vector2(18, 18)) / 2
	if not pinned:
		ic.material = Tok.grey()
	b.add_child(ic)
	b.gui_input.connect(func(ev): if ConvertTray._tap(ev):
		Progress.toggle_pin(name)
		Game._changed())
	return b


## ▸ / ▾, drawn (not in Nunito).
static func _arrow(open: bool, color: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(10, 10)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var pts := PackedVector2Array([Vector2(0, 1), Vector2(10, 1), Vector2(5, 9)]) if open \
			else PackedVector2Array([Vector2(1, 0), Vector2(9, 5), Vector2(1, 10)])
		c.draw_colored_polygon(pts, color))
	return c
