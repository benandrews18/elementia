## An item's breakdown (jobNodeHTML(), .mission-tree): one row per component
## (an item: ▸, icon, name, where it's made, 📌; an element: its chip, name,
## where it's rolled), and under an open item its own components, down a
## guide line. Shared by the To-Do List (parchment) and the Items screen
## (dark); which branches are open is shared too (TodoTray.expanded, the
## HTML game's jobExpanded). A tap on an item row opens or closes it. On the
## To-Do List (look.track) an unowned item row has 🔍 Track instead of 📌,
## its parts count and a green dot when it can be crafted now: facts, never
## advice (the user, 2026-11-26).
class_name RefTree
extends RefCounted

const ROW := 50.0  # a row's height (the HTML tree is zoomed 1.2)

## The To-Do List's parchment (#jobSheet .ref-pinned overrides).
const PARCHMENT := {
	"box": Color("#fdf8ec"), "line": Color("#b08a5a"), "have": Color("#dff2e2"), "have_line": Color("#4fbf7a"),
	"ink": Color("#2a1f14"), "leaf_have_ink": Color("#2a1f14"), "leaf_need_ink": Color("#2a1f14"),
	"rule": Color("#8a6a48"), "rule_dashed": false,
	"pin": Color("#e9e4da"), "pin_line": Color("#b9b0a0"), "pin_on": Color("#e9e4da"), "pin_on_line": Color("#b9b0a0"), "pin_off_alpha": 1.0,
	"track": true,
}
## The To-Do List's details panel (the user, 2026-11-26: no borders inside
## borders): plain rows of icons and text on the panel's navy.
const FLAT := {"flat": true, "track": true, "ink": Color("#e8edf4"), "dim": Color("#8fa3b5"),
	"have_ink": Color("#5fd38a"), "rule": Color(1, 1, 1, 0.16)}
const FLAT_ROW := 38.0

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


## Its direct parts owned (items owned, elements held in the numbers needed)
## of all of them.
static func parts(e: Dictionary) -> Vector2i:
	var n := Catalog.needs_of(e.reqs)
	var done: int = n.items.filter(func(it): return Catalog.owns(Game.state, it.name)).size()
	done += n.els.keys().filter(func(sym): return Catalog.count(Game.state, sym) >= n.els[sym]).size()
	return Vector2i(done, n.items.size() + n.els.size())


## Craftable right now: every part held and its suit cost payable.
static func ready(name: String) -> bool:
	var e = Catalog.entry(name)
	return e != null and not Catalog.owns(Game.state, name) and Catalog.can_craft(Game.state, e) and Game.suit_cost_payable(name)


## An item's suit cost (its "element tax"), as a row of suit icons centred
## on `at` (x: the middle; y: the top). Empty if it has none. ringed: each in
## the suit strip's gold ring, px wide (station.gd suit_pill).
static func suit_row(name: String, at: Vector2, px: float, ringed := false) -> Control:
	var suits: Array = Data.t("ITEM_SUIT_COST_TABLE").get(name, [])
	var r := Control.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta("cmp", "suitcost:" + name)
	var step := px + 3
	r.size = Vector2(maxf(0, suits.size() * step - 3), px)
	r.position = Vector2(at.x - r.size.x / 2, at.y)
	for i in suits.size():
		var ipx := px * 17.0 / 28.0 if ringed else px
		var g := Tok.icon("suit:" + suits[i], ipx)
		g.material = Tok.tinted(Tok.suit_color(suits[i]))
		var slot: Control = g
		if ringed:  # the user, 2026-11-27
			slot = Panel.new()
			slot.add_theme_stylebox_override("panel", Tok.box(Color("#122e3c"), px / 2, 1.5, Tok.GOLD, 3, 1, Color(0, 0, 0, 0.35)))
			slot.size = Vector2(px, px)
			g.position = (slot.size - Vector2(ipx, ipx)) / 2
			slot.add_child(g)
		slot.position = Vector2(i * step, 0)
		var su: String = suits[i]
		SuitSpend.on_tap(slot, su)  # the suit and its elements (step 27; the user, 2026-11-26)
		r.add_child(slot)
	return r


const GREEN := Color("#5fd38a")  # a parts count you can craft now (the user, 2026-11-26: not a dot)


## The green "can craft now" dot, on an icon's top-right corner.
static func ready_dot(at: Vector2) -> Control:
	var d := Panel.new()
	d.add_theme_stylebox_override("panel", Tok.box(Color("#3fcf6c"), 6, 2, Color.WHITE))
	d.size = Vector2(12, 12)
	d.position = at
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_meta("cmp", "todo:ready")
	return d


## One level of the tree in parent, from at; returns the bottom.
func nodes(parent: Control, toks: Array, path: String, seen: Dictionary, at: Vector2, w: float) -> float:
	var gap := 0.0 if look.get("flat", false) else 8.0
	var y := at.y
	for r in toks:
		y = node(parent, r.name, r.kind, path + "/" + r.name, seen, Vector2(at.x, y), w) + gap
	return y - gap


func node(parent: Control, name: String, kind: String, path: String, seen: Dictionary, at: Vector2, w: float) -> float:
	if look.get("flat", false):
		return _flat(parent, name, kind, path, seen, at, w)
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
	var right := where(box, name, "item", box.size.x)
	if look.get("track", false):
		if not has:
			var pc := parts(e)
			var cl := Tok.label("%d/%d" % [pc.x, pc.y], 12, Color("#8a6a48"), 800)
			var cw := Tok.font(800).get_string_size(cl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			right -= cw + 6
			cl.position = Vector2(right, 16)
			box.add_child(cl)
			if ready(name):
				box.add_child(ready_dot(Vector2(46, 8)))
			parent.add_child(track_button(name, Vector2(at.x + row_w + 8, at.y + 5)))
		var px := Tok.fit_px(name, Tok.font(800), 16, right - 6 - 60)
		nl.add_theme_font_size_override("font_size", px)
		nl.position.y = 13 + (16 - px) * 0.6
	else:
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


## A flat row: ▸, icon, name (green once owned), its parts count, where it's
## made, 🔍 Track; an element: its chip, name, where it's rolled. A tap opens
## or closes an item's parts under it.
func _flat(parent: Control, name: String, kind: String, path: String, seen: Dictionary, at: Vector2, w: float) -> float:
	var s := Game.state
	var row := Control.new()
	row.position = at
	row.size = Vector2(w, FLAT_ROW)
	row.mouse_filter = Control.MOUSE_FILTER_PASS  # a drag scrolls the panel
	parent.add_child(row)
	if name == hint_name:  # the hint's suggestion (or the shop's 🔍 tap): a soft green wash
		var hl := Panel.new()
		hl.add_theme_stylebox_override("panel", Tok.box(Color(0.31, 0.9, 0.51, 0.16), 8))
		hl.size = row.size
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hl)
	if kind == "element":
		var have := Catalog.count(s, name) >= 1
		var chip := StationScreen.element_chip(name, 22)
		chip.get_child(chip.get_child_count() - 1).visible = false  # no caption
		# just the symbol in its coloured border, a thinner one (the user, 2026-11-26)
		chip.get_node("Badge").visible = false
		chip.get_node("Num").visible = false
		var sb: StyleBoxFlat = chip.get_node("Chip").get_theme_stylebox("panel")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		chip.position = Vector2(14, 8)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
		var el := Tok.label(Data.t("ELEMENT_NAMES").get(name, name), 14, look.have_ink if have else look.dim, 700)
		el.position = Vector2(44, 9)
		row.add_child(el)
		where(row, name, "element", w + 4, 10)
		return at.y + FLAT_ROW
	var e = Catalog.entry(name)
	if e == null:
		return at.y
	var has := Catalog.owns(s, name)
	var open := TodoTray.expanded.has(path)
	row.set_meta("cmp", "todo:row:" + name)
	row.gui_input.connect(func(ev): if Tap.tap(ev):
		row.accept_event()
		on_toggle.call(path))
	var arr := arrow(open, look.dim)
	arr.position = Vector2(0, 14)
	row.add_child(arr)
	var ic := Tok.icon(e.emoji, 22)
	ic.position = Vector2(14, 8)
	row.add_child(ic)
	var right := w - 36  # the 🔍 column, kept clear even when owned (no 🔍: nothing moves into it)
	if not has:
		row.add_child(track_button(name, Vector2(w - 30, 4), 30))
	right = where(row, name, "item", right + 10, 10)
	if not has:
		var pc := parts(e)
		var cl := Tok.label("%d/%d" % [pc.x, pc.y], 12, GREEN if ready(name) else look.dim, 800)
		var cw := Tok.font(800).get_string_size(cl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		right -= cw + 4
		cl.position = Vector2(right, 11)
		row.add_child(cl)
	var x := 44.0
	if has:
		var t := Tok.tick(look.have_ink, 14)
		t.position = Vector2(x, 12)
		row.add_child(t)
		x += 18
	var px := Tok.fit_px(name, Tok.font(800), 15, right - 6 - x)
	var nl := Tok.label(name, px, look.have_ink if has else look.ink, 800)
	nl.position = Vector2(x, 8 + (15 - px) * 0.6)
	row.add_child(nl)
	var y := at.y + FLAT_ROW
	if open and not seen.has(name):
		var seen2 := seen.duplicate()
		seen2[name] = true
		var top := y
		if not Data.t("ITEM_SUIT_COST_TABLE").get(name, []).is_empty():  # its suit cost first (the user, 2026-11-26)
			var sw: float = Data.t("ITEM_SUIT_COST_TABLE")[name].size() * 25 - 3
			parent.add_child(suit_row(name, Vector2(at.x + 16 + sw / 2, y + 4), 22, true))  # from the parts' left edge
			y += 30
		y = nodes(parent, components(e), path, seen2, Vector2(at.x + 16, y), w - 16)
		var rule := ColorRect.new()
		rule.color = look.rule
		rule.position = Vector2(at.x + 4, top)
		rule.size = Vector2(2, y - top)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rule)
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


## Where it comes from, as station icons at the row's right end; returns
## their left edge.
static func where(box: Control, name: String, kind: String, w: float, y := 16.0) -> float:
	var at: Array = Data.t("STATION_BY_NAME").values().filter(func(st): return st.dice.has(name)).map(func(st): return st.name) if kind == "element" \
		else Data.t("ENTRIES").filter(func(x): return x.name == name).map(func(x): return x.station)
	var uniq := []
	for st in at:
		if not uniq.has(st):
			uniq.append(st)
	var x := w - 14 - uniq.size() * 20
	var left := x
	for st in uniq:
		var ic := Tok.icon(Catalog.station(st).emoji, 18)
		ic.position = Vector2(x, y)
		box.add_child(ic)
		x += 20
	return left


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
		App.pin(name))
	return b


## A To-Do tree row's 🔍 Track (gold while it's the tracked item): tracks
## it (and pins it), or stops tracking it. px < 40: the flat look's round one.
static func track_button(name: String, at: Vector2, px := 40.0) -> Control:
	var on: bool = Game.ctx.get("tracked") == name
	var b := Panel.new()
	if px < 40:
		b.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD if on else Color(1, 1, 1, 0.08), px / 2))
	else:
		b.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD if on else Color("#e9e4da"), 8, 2,
			Color.BLACK if on else Color("#b9b0a0"), 3, 2, Color(0, 0, 0, 0.3)))
	b.size = Vector2(px, px)
	b.position = at
	b.set_meta("cmp", "todo:track:" + name)
	var ipx := px / 2
	var ic := Tok.icon("🔍", ipx)
	ic.position = (b.size - Vector2(ipx, ipx)) / 2
	b.add_child(ic)
	if Game.ctx.get("awaitingStart") and Game.ctx.get("tracked") == null:  # the opening: track something to Start (the user, 2026-11-27)
		# A gold ring with a halo outside it only, the inside left clear (a fill read as "already on"),
		# breathing 5 times, then still (an endless loop redraws every frame: battery).
		var m := 8.0
		var r0 := px / 2 if px < 40 else 8.0
		var glow := Control.new()
		glow.position = Vector2(-m, -m)
		glow.size = b.size + Vector2(m, m) * 2
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.draw.connect(func():
			var core := Rect2(Vector2(m, m), b.size)
			for k in range(4, 0, -1):
				var a := Color(Tok.GOLD, 0.45 * (1 - k / 5.0))
				if px < 40:  # true circles: a round style box seams at these sizes
					glow.draw_arc(core.get_center(), px / 2 + k * 1.5, 0, TAU, 64, a, 2, true)
				else:
					glow.draw_style_box(Tok.box(Color.TRANSPARENT, r0 + k * 2, 2, a), core.grow(k * 2))
			if px < 40:
				glow.draw_arc(core.get_center(), px / 2 - 1, 0, TAU, 64, Tok.GOLD, 2, true)
			else:
				glow.draw_style_box(Tok.box(Color.TRANSPARENT, r0, 2, Tok.GOLD), core))
		glow.set_meta("cmp", "todo:trackglow")
		b.add_child(glow)
		b.move_child(glow, 0)
		if Juice.on():
			glow.pivot_offset = glow.size / 2
			var tw := glow.create_tween().set_loops(5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(glow, "modulate:a", 0.35, 0.8)
			tw.parallel().tween_property(glow, "scale", Vector2(1.08, 1.08), 0.8)
			tw.tween_property(glow, "modulate:a", 1.0, 0.8)
			tw.parallel().tween_property(glow, "scale", Vector2.ONE, 0.8)
	b.gui_input.connect(func(ev): if Tap.tap(ev):
		b.accept_event()
		if on:
			Game.set_tracked(null)
		else:
			Game.track(name))
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
