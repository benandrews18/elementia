## An item's breakdown (jobNodeHTML(), .mission-tree): one row per component
## (an item: ▸, icon, name, where it's made, 📌; an element: its chip, name,
## where it's rolled), and under an open item its own components, down a
## guide line. Shared by the To-Do List (parchment) and the Items screen
## (dark); which branches are open is shared too (TodoTray.expanded, the
## HTML game's jobExpanded). A tap on an item row opens or closes it.
class_name RefTree
extends RefCounted

const ROW := 50.0  # a row's height (the HTML tree is zoomed 1.2)

## The To-Do List's parchment (#jobSheet .ref-pinned overrides).
const PARCHMENT := {
	"box": Color("#fdf8ec"), "line": Color("#b08a5a"), "have": Color("#dff2e2"), "have_line": Color("#4fbf7a"),
	"ink": Color("#2a1f14"), "leaf_have_ink": Color("#2a1f14"), "leaf_need_ink": Color("#2a1f14"),
	"rule": Color("#8a6a48"), "rule_dashed": false,
	"pin": Color("#e9e4da"), "pin_line": Color("#b9b0a0"), "pin_on": Color("#e9e4da"), "pin_on_line": Color("#b9b0a0"), "pin_off_alpha": 1.0,
}
## The Items screen's dark look (game-mode.css .mission-tree).
const DARK := {
	"box": Color("#163544"), "line": Color("#2a5a72"), "have": Color("#16301f"), "have_line": Color("#2c5c3c"),
	"ink": Color("#e8edf4"), "leaf_have_ink": Color("#3fb46c"), "leaf_need_ink": Color("#7d8899"),
	"rule": Color("#1c4257"), "rule_dashed": true,
	"pin": Color("#163544"), "pin_line": Color("#2a5a72"), "pin_on": Color("#3a2e14"), "pin_on_line": Color("#e2b25a"), "pin_off_alpha": 0.5,
}

var look: Dictionary
var on_toggle: Callable  # path: an item row was tapped
var hint_name := ""  # the To-Do hint's suggestion, outlined in green


func _init(l: Dictionary, toggle: Callable) -> void:
	look = l
	on_toggle = toggle


## Elements first, then items by points (sortIngredientTokens()).
static func sorted(toks: Array) -> Array:
	var pts: Dictionary = Data.t("ITEM_POINTS")
	return toks.filter(func(r): return r.kind == "element") + Util.stable_sort(toks.filter(func(r): return r.kind != "element"),
		func(a, b): return pts.get(a.name, 0) - pts.get(b.name, 0))


## An item's components, each once, sorted.
static func components(e: Dictionary) -> Array:
	var dedup := {}
	var toks := []
	for r in e.reqs:
		if not dedup.has(r.kind + ":" + r.name):
			dedup[r.kind + ":" + r.name] = true
			toks.append(r)
	return sorted(toks)


## One level of the tree in parent, from at; returns the bottom.
func nodes(parent: Control, toks: Array, path: String, seen: Dictionary, at: Vector2, w: float) -> float:
	var y := at.y
	for r in toks:
		y = node(parent, r.name, r.kind, path + "/" + r.name, seen, Vector2(at.x, y), w) + 8
	return y - 8


func node(parent: Control, name: String, kind: String, path: String, seen: Dictionary, at: Vector2, w: float) -> float:
	var s := Game.state
	var row_w := w - 50
	if kind == "element":  # a leaf: the element, its name, where it's rolled
		var have := Catalog.count(s, name) >= 1
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", Tok.box(look.have if have else look.box, 12, 1.5, look.have_line if have else look.line))
		box.position = at
		box.size = Vector2(row_w, ROW)
		parent.add_child(box)
		var chip := StationScreen.element_chip(name, 28)
		chip.get_child(chip.get_child_count() - 1).visible = false  # no caption
		chip.position = Vector2(12, 11)
		box.add_child(chip)
		var nl := Tok.label(Data.t("ELEMENT_NAMES").get(name, name), 15, look.leaf_have_ink if have else look.leaf_need_ink, 800)
		nl.position = Vector2(50, 14)
		box.add_child(nl)
		where(box, name, "element", row_w)
		return at.y + ROW
	var e = Catalog.entry(name)
	if e == null:
		return at.y - 8
	var has := Catalog.owns(s, name)
	var open := TodoTray.expanded.has(path)
	var x0 := at.x + (24.0 if has else 0.0)
	if has:
		var t := Tok.tick(Tok.OK, 22)
		t.position = Vector2(at.x, at.y + 14)
		parent.add_child(t)
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Tok.box(look.have if has else look.box, 12, 1.5, look.have_line if has else look.line))
	box.position = Vector2(x0, at.y)
	box.size = Vector2(row_w - (x0 - at.x), ROW)
	box.mouse_filter = Control.MOUSE_FILTER_PASS  # a drag scrolls the list it's in; a tap toggles it alone
	box.gui_input.connect(func(ev): if Tap.tap(ev):
		box.accept_event()
		on_toggle.call(path))
	parent.add_child(box)
	var arr := arrow(open, look.ink)
	arr.position = Vector2(12, 20)
	box.add_child(arr)
	var ic := Tok.icon(e.emoji, 22)
	ic.position = Vector2(30, 14)
	box.add_child(ic)
	var nl := Tok.label(name, 16, look.ink, 800)
	nl.position = Vector2(60, 13)
	box.add_child(nl)
	where(box, name, "item", box.size.x)
	parent.add_child(pin_button(name, Vector2(at.x + row_w + 8, at.y + 5)))
	if name == hint_name:  # the suggestion, outlined in green
		var hl := Panel.new()
		hl.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 14, 3, Color("#4fe583")))
		hl.position = Vector2(x0 - 4, at.y - 4)
		hl.size = Vector2(w - (x0 - at.x) + 8, ROW + 8)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(hl)
	var y := at.y + ROW
	if open and not seen.has(name):
		var seen2 := seen.duplicate()
		seen2[name] = true
		var top := y + 8
		y = nodes(parent, components(e), path, seen2, Vector2(at.x + 20, top), w - 20)
		parent.add_child(_rule(Vector2(at.x + 6, top), y - top))
	return y


## The guide line down a branch (solid on parchment, dashed on dark).
func _rule(at: Vector2, h: float) -> Control:
	if not look.rule_dashed:
		var rule := ColorRect.new()
		rule.color = look.rule
		rule.position = at
		rule.size = Vector2(2, h)
		return rule
	var c := Control.new()
	c.position = at
	c.size = Vector2(2, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): c.draw_dashed_line(Vector2(1, 0), Vector2(1, h), look.rule, 2, 5))
	return c


## Where it comes from, as station icons at the row's right end.
static func where(box: Control, name: String, kind: String, w: float) -> void:
	var at: Array = Data.t("STATION_BY_NAME").values().filter(func(st): return st.dice.has(name)).map(func(st): return st.name) if kind == "element" \
		else Data.t("ENTRIES").filter(func(x): return x.name == name).map(func(x): return x.station)
	var uniq := []
	for st in at:
		if not uniq.has(st):
			uniq.append(st)
	var x := w - 14 - uniq.size() * 20
	for st in uniq:
		var ic := Tok.icon(Catalog.station(st).emoji, 18)
		ic.position = Vector2(x, 16)
		box.add_child(ic)
		x += 20


## A tree row's pin (a 40px square, .refpin zoomed).
func pin_button(name: String, at: Vector2) -> Control:
	var pinned := Progress.is_pinned(name)
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(look.pin_on if pinned else look.pin, 8, 2,
		look.pin_on_line if pinned else look.pin_line, 3, 2, Color(0, 0, 0, 0.3)))
	b.size = Vector2(40, 40)
	b.position = at
	b.modulate.a = 1.0 if pinned else look.pin_off_alpha
	var ic := Tok.icon("📌", 18)
	ic.position = (b.size - Vector2(18, 18)) / 2
	if not pinned:
		ic.material = Tok.grey()
	b.add_child(ic)
	b.gui_input.connect(func(ev): if Tap.tap(ev):
		Game.toggle_pin(name))
	return b


## ▸ / ▾, drawn (not in Nunito).
static func arrow(open: bool, color: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(10, 10)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var pts := PackedVector2Array([Vector2(0, 1), Vector2(10, 1), Vector2(5, 9)]) if open \
			else PackedVector2Array([Vector2(1, 0), Vector2(9, 5), Vector2(1, 10)])
		c.draw_colored_polygon(pts, color))
	return c
