## The To-Do List (the hub's To-Do List button): a tray sliding in from the
## left, a quest log (the user, 2026-11-26: questline games keep one
## objective in view, chapters with counts, progress from what's owned).
## One background, no boxes (the user, 2026-11-26): each pinned item a row
## (icon, name, points, its parts owned, its 📌 to drop it); a tap opens the
## details panel over the list's right side, the icons and names still
## showing at the left (the list still scrolls; another tap switches it; ✕
## closes it): the item's card details, a parts bar, and its parts as a tree
## (RefTree.FLAT, one level per tap) with 🔍 Track. The quest holding the
## tracked item leads and opens in the panel, down to it. Facts only, no
## advice; "Get a Hint" stays, asked for.
class_name TodoTray
extends Control

const INK := Color("#2a1f14")

static var expanded := {}  # "refroot/<item>" and "ref/<root>/.../<item>" paths shown open
static var hint_open := false
static var focus := ""  # a shop card's tracked-item badge was tapped: this one lit in the tracked item's breakdown
static var detail := ""  # the item in the details panel ("" closed)
const LEFT_W := 138.0  # the list's icons and names, still showing beside the details panel
const ROW_H := 58.0

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
	$Scrim.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.close_panel())
	var t = Game.ctx.get("tracked")
	if t:  # the leading quest in the details panel, open down to the tracked item (or to the shop's 🔍 tap)
		detail = lead()
		_open_to(detail, focus if focus != "" else t)
	tree_exiting.connect(func(): focus = "")
	var w := minf(560, size.x)  # the whole width: the details panel needs it
	$Tray.size = Vector2(w, size.y - HubBar.H)
	_scroll.size = $Tray.size - Vector2(3, 3)
	Game.state_changed.connect(_redraw)
	_redraw()


## The quest holding the tracked item: the pinned item worth the most
## points that still needs it, else the tracked item itself ("" untracked).
static func lead() -> String:
	var t = Game.ctx.get("tracked")
	if t == null:
		return ""
	var best: String = t
	var pts: Dictionary = Data.t("ITEM_POINTS")
	for n in Progress.prefs.pinnedItems:
		if n != t and Catalog.entry(n) != null and Catalog.still_needed(Game.state, n).has(t) and (best == t or pts.get(n, 0) > pts.get(best, 0)):
			best = n
	return best


## Opens root's quest and its first path down to target (one branch, not
## the whole tree).
static func _open_to(root: String, target: String) -> void:
	expanded["refroot/" + root] = true
	var trails := _trails(root, target)
	if trails.is_empty():
		return
	trails.sort_custom(func(x, y): return x.size() < y.size())  # the shortest way down
	var path: String = "ref/" + root
	for n in trails[0].slice(0, -1):
		path += "/" + n
		expanded[path] = true


func _redraw() -> void:
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		c.queue_free()
	if detail != "" and not Progress.is_pinned(detail):
		detail = ""
	var names: Array = Progress.prefs.pinnedItems.filter(func(n): return Catalog.entry(n) != null)
	# Only as wide as its rows, the pins just clear of the longest name (the
	# user, 2026-11-26): the screen behind shows beside it.
	$Tray.size.x = minf(size.x, _list_width(names))
	_scroll.size.x = $Tray.size.x - 3
	var w := _scroll.size.x - 40
	# Closest first (the user, 2026-11-26: "almost done" goals keep long chains
	# winnable): craftable now, then the most parts owned, then points; the
	# tracked item always on top, the quest holding it next.
	names = Util.stable_sort(names, func(a, b): return _closeness(b) - _closeness(a))
	for top in [lead(), Game.ctx.get("tracked")]:
		if top != null and names.has(top):
			names.erase(top)
			names.push_front(top)
	var y := 20.0
	$Tray/Scroll/List/Pin.visible = not names.is_empty()
	$Tray/Scroll/List/Pinned.visible = not names.is_empty()
	$Tray/Scroll/List/Glass.visible = not names.is_empty()
	$Tray/Scroll/List/Tracked.visible = not names.is_empty()
	if not names.is_empty():
		y += 26 + 24  # the two-line title
		var hint = Game.todo_hint() if hint_open else null
		_hint_name = hint.name if hint != null else ""
		y = _hint_button(y) + 10
		if hint_open:
			y = _hint_card(hint, y, w) + 16
		if Game.ctx.get("tracked") == null and detail == "":  # a nudge, not a pick (the user, 2026-11-26); in the panel when it's open
			var tip := Tok.label("Tap items to view details", 13, Color("#b3becd"), 700)  # the user's words, 2026-11-26
			tip.position = Vector2(20, y)
			tip.set_meta("cmp", "todo:tip")
			_list.add_child(tip)
			y += 22
			var g := Tok.icon("🔍", 15)
			g.position = Vector2(20, y + 1)
			_list.add_child(g)
			var t2 := Tok.label("Track item parts to guide your journey!", 13, Color("#e2b25a"), 700)
			t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t2.custom_minimum_size = Vector2(w - 20, 0)
			t2.position = Vector2(40, y)
			_list.add_child(t2)
			t2.size = Vector2(w - 20, 0)
			y += 6 + ceilf(Tok.font(700).get_multiline_string_size(t2.text, HORIZONTAL_ALIGNMENT_LEFT, w - 20, 13).y)
		y += 4
		for n in names:
			y = _row(Catalog.entry(n), y, _scroll.size.x)
	# The empty space under the rows: a tap closes the details panel (✕ too).
	var below := Control.new()
	below.position = Vector2(0, y)
	below.size = Vector2(_scroll.size.x, maxf(20, _scroll.size.y - y))
	below.mouse_filter = MOUSE_FILTER_PASS
	below.set_meta("cmp", "todo:below")
	below.gui_input.connect(func(ev): if Tap.tap(ev) and detail != "":
		detail = ""
		_redraw())
	_list.add_child(below)
	$Tray/Scroll/List.custom_minimum_size = Vector2(_scroll.size.x, y + 20)
	_scroll.set_deferred("scroll_vertical", keep)
	_details()


## How close a pinned item is to being made, for the list's order: craftable
## now first, then the share of its parts owned, then points (as a tiebreak).
static func _closeness(n: String) -> float:
	var e: Dictionary = Catalog.entry(n)
	var pc := RefTree.parts(e)
	return (1000.0 if RefTree.ready(n) else 0.0) + 100.0 * pc.x / maxf(1, pc.y) + e.points / 1000.0


## A row's name size (fitted to the room beside the details panel) and its
## line under it; the list's width: the widest row, its pin, a margin.
func _name_px(name: String) -> int:
	return Tok.fit_px(name, Tok.font(800), 15, LEFT_W - 56 - 4)


func _sub_text(e: Dictionary) -> String:
	var pc := RefTree.parts(e)
	return "%d   %s" % [int(e.points), "crafted" if Catalog.owns(Game.state, e.name) else "%d/%d parts" % [pc.x, pc.y]]


func _list_width(names: Array) -> float:
	var widest := 0.0
	for n in names:
		var e: Dictionary = Catalog.entry(n)
		widest = maxf(widest, Tok.font(800).get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_px(n)).x)
		widest = maxf(widest, 15 + Tok.font(700).get_string_size(_sub_text(e), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	return maxf(210, 56 + widest + 22 + 22 + 24)  # some air either side of the pins (the user: squished)


func _show(name: String) -> void:
	detail = "" if detail == name else name
	if detail != "":
		expanded["refroot/" + detail] = true
	_redraw()


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
	b.gui_input.connect(func(ev): if Tap.tap(ev):
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


## The hint's card, line by line (the user, 2026-11-26): "Try crafting...",
## the item (icon, name; the green dot when it can be crafted now), "Needed
## for:" and each pinned item that needs it, then where it's made.
func _hint_card(hint, y: float, w: float) -> float:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Tok.box(Color(1, 1, 1, 0.06), 12))
	card.position = Vector2(20, y)
	card.set_meta("cmp", "todo:hintcard")
	_list.add_child(card)
	if hint == null:
		var none := Tok.label("Everything on your list is already crafted!", 13, Color("#b3becd"), 700)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(w - 28, 0)
		none.position = Vector2(14, 12)
		card.add_child(none)
		none.size = Vector2(w - 28, 0)
		var nh := ceilf(Tok.font(700).get_multiline_string_size(none.text, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 13).y)
		card.size = Vector2(w, nh + 24)
		return y + card.size.y
	var ly := 10.0
	var top := Tok.label("Try crafting...", 13, Color("#b3becd"), 800)
	top.position = Vector2(14, ly)
	card.add_child(top)
	ly += 24
	ly = _icon_line(card, hint.entry.emoji, hint.name, ly, w, 26, 16, Color.WHITE, 900)
	var others: Array = hint.roots.filter(func(r): return r != hint.name)
	if not others.is_empty():
		ly += 4
		var nf := Tok.label("Needed for:", 12, Color("#b3becd"), 800)
		nf.position = Vector2(14, ly)
		card.add_child(nf)
		ly += 20
		for r in others:
			ly = _icon_line(card, Catalog.entry(r).emoji, r, ly, w, 18, 13, Color("#e8edf4"), 700)
	ly += 4
	for h in hint.homes:  # where it's made
		ly = _icon_line(card, Catalog.station(h).emoji, h, ly, w, 16, 12, Color("#e2b25a"), 700)
	card.size = Vector2(w, ly + 8)
	return y + card.size.y


## One line of the hint card: an icon and a name beside it (shrunk to fit
## the narrow tray); returns the next line's top.
func _icon_line(card: Control, emoji: String, text: String, ly: float, w: float, ipx: float, px: int, color: Color, weight: int) -> float:
	var ic := Tok.icon(emoji, ipx)
	ic.position = Vector2(14, ly)
	card.add_child(ic)
	var fpx := Tok.fit_px(text, Tok.font(weight), px, w - 14 - ipx - 8 - 10)
	var l := Tok.label(text, fpx, color, weight)
	l.position = Vector2(14 + ipx + 8, ly + (ipx - Tok.font(weight).get_height(fpx)) / 2)
	card.add_child(l)
	return ly + ipx + 6


## A pinned item's row: icon (a green dot when craftable now, a 🔍 when the
## tracked item is it or in it), name, points and parts owned, its 📌. A tap
## shows it in the details panel. Returns its bottom.
func _row(e: Dictionary, y: float, w: float) -> float:
	var owned := Catalog.owns(Game.state, e.name)
	var row := Control.new()
	row.position = Vector2(0, y)
	row.size = Vector2(w, ROW_H)
	row.mouse_filter = MOUSE_FILTER_PASS  # a drag scrolls the list
	row.set_meta("cmp", "todo:quest:" + e.name)
	row.gui_input.connect(func(ev): if Tap.tap(ev): _show(e.name))
	_list.add_child(row)
	if detail == e.name:
		var sel := ColorRect.new()  # lit while the panel shows it: a stronger wash and a gold edge
		sel.color = Color(1, 1, 1, 0.16)
		sel.size = row.size
		sel.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(sel)
		var edge := ColorRect.new()
		edge.color = Tok.GOLD
		edge.size = Vector2(4, ROW_H)
		edge.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(edge)
	var ic := Tok.icon(e.emoji, 30)
	ic.position = Vector2(16, 6)
	row.add_child(ic)
	row.add_child(RefTree.suit_row(e.name, Vector2(31, 41), 11))  # its suit cost, under the picture
	if e.name == lead():  # the tracked item is this, or in it
		var g := Tok.icon("🔍", 16)
		g.position = Vector2(6, 6)
		g.set_meta("cmp", "todo:lead")
		row.add_child(g)
	var px := _name_px(e.name)  # the name stays readable beside the details panel
	var nl := Tok.label(e.name, px, Color("#5fd38a") if owned else Color.WHITE, 800)
	nl.position = Vector2(56, 10 + (15 - px) * 0.6)
	row.add_child(nl)
	var pc := RefTree.parts(e)
	var star := Tok.star(Color("#f5b400"), 11)
	star.position = Vector2(56, 35)
	row.add_child(star)
	var pts := Tok.label("%d   " % int(e.points), 12, Color("#8fa3b5"), 700)
	pts.position = Vector2(71, 31)
	row.add_child(pts)
	var sub := Tok.label("crafted" if owned else "%d/%d parts" % [pc.x, pc.y], 12, RefTree.GREEN if RefTree.ready(e.name) else Color("#8fa3b5"), 700)
	sub.position = Vector2(71 + Tok.font(700).get_string_size(pts.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, 31)
	sub.set_meta("cmp", "todo:bar:%d/%d" % [pc.x, pc.y])
	row.add_child(sub)
	var pin := Tok.icon("📌", 22)  # drop it from the list
	pin.position = Vector2(w - 24 - 22, (ROW_H - 22) / 2)
	pin.mouse_filter = MOUSE_FILTER_STOP
	pin.set_meta("cmp", "todo:pin:" + e.name)
	pin.gui_input.connect(func(ev): if Tap.tap(ev):
		pin.accept_event()
		App.pin(e.name))
	row.add_child(pin)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.07)
	line.position = Vector2(14, ROW_H - 1)
	line.size = Vector2(w - 28, 1)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(line)
	return y + ROW_H


static var _detail_keep := 0  # the details panel's scroll, kept across redraws


## The details panel over the list's right side: ✕, the item (its icon opens
## its card), points, where it's made, a parts bar, then its parts' tree.
func _details() -> void:
	var old := $Tray.get_node_or_null("Details")
	var was_open := old != null
	if old:
		var sc := old.get_node_or_null("Scroll")
		if sc:
			_detail_keep = sc.scroll_vertical
		old.free()
	var e = Catalog.entry(detail) if detail != "" else null
	if e == null:
		_detail_keep = 0
		return
	var dw := minf(size.x, 560) - LEFT_W  # past the list's tray, over the screen behind
	var h: float = $Tray.size.y
	var panel := Panel.new()
	panel.name = "Details"
	panel.add_theme_stylebox_override("panel", Tok.box(Color("#1d4456"), 0, 0, Color.BLACK, 14, 0, Color(0, 0, 0, 0.5)))
	panel.position = Vector2(LEFT_W, 0)
	panel.size = Vector2(dw, h)
	panel.set_meta("cmp", "todo:details")
	$Tray.add_child(panel)
	if not was_open:
		Juice.slide_in(panel, Vector2(dw, 0))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size = panel.size
	panel.add_child(scroll)
	var body := Control.new()
	body.mouse_filter = MOUSE_FILTER_PASS
	scroll.add_child(body)
	var close := TextureRect.new()
	close.texture = load("res://assets/ui/btn_close.webp")
	close.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close.size = Vector2(34, 34)
	close.position = Vector2(dw - 34 - 10, 10)
	close.set_meta("cmp", "todo:close")
	close.gui_input.connect(func(ev): if Tap.tap(ev):
		close.accept_event()
		detail = ""
		_redraw())
	body.add_child(close)
	var ic := Tok.icon(e.emoji, 44)
	ic.position = Vector2(14, 14)
	ic.mouse_filter = MOUSE_FILTER_STOP
	ic.set_meta("cmp", "todo:card:" + e.name)
	ic.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.show_card(e.name))
	body.add_child(ic)
	body.add_child(RefTree.suit_row(e.name, Vector2(36, 64), 14))  # its suit cost, under the picture
	var px := Tok.fit_px(e.name, Tok.font(900), 19, dw - 68 - 50)
	var nl := Tok.label(e.name, px, Color.WHITE, 900)
	nl.position = Vector2(68, 12 + (19 - px) * 0.6)
	body.add_child(nl)
	var pc := RefTree.parts(e)
	var star := Tok.star(Color("#f5b400"), 12)
	star.position = Vector2(68, 42)
	body.add_child(star)
	var dpts := Tok.label("%d   " % int(e.points), 13, Color("#b3becd"), 700)
	dpts.position = Vector2(84, 38)
	body.add_child(dpts)
	var line := Tok.label("%d/%d parts" % [pc.x, pc.y], 13, RefTree.GREEN if RefTree.ready(e.name) else Color("#b3becd"), 700)
	line.position = Vector2(84 + Tok.font(700).get_string_size(dpts.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, 38)
	body.add_child(line)
	var bar := Panel.new()  # the parts bar
	bar.add_theme_stylebox_override("panel", Tok.box(Color(1, 1, 1, 0.12), 4))
	bar.position = Vector2(68, 62)
	bar.size = Vector2(dw - 68 - 16, 8)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	if pc.x > 0:
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel", Tok.box(Tok.OK, 4))
		fill.size = Vector2(maxf(8, bar.size.x * pc.x / maxf(1, pc.y)), 8)
		fill.mouse_filter = MOUSE_FILTER_IGNORE
		bar.add_child(fill)
	body.add_child(bar)
	var hx := 68.0  # where it's made
	for st in Data.t("ENTRIES").filter(func(x): return x.name == e.name).map(func(x): return x.station):
		var sic := Tok.icon(Catalog.station(st).emoji, 14)
		sic.position = Vector2(hx, 80)
		body.add_child(sic)
		var sl := Tok.label(st, 12, Color("#b3becd"), 600)
		sl.position = Vector2(hx + 17, 78)
		body.add_child(sl)
		hx += 17 + Tok.font(600).get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
	var head := Tok.label("PARTS", 11, Color("#8fa3b5"), 800)
	head.position = Vector2(14, 104)
	body.add_child(head)
	if Game.ctx.get("tracked") == null:  # a nudge, not a pick
		var tip := Tok.label("Tap 🔍 on a part to track it", 12, Color("#e2b25a"), 700)
		tip.position = Vector2(62, 103)
		tip.set_meta("cmp", "todo:tip")
		body.add_child(tip)
	var tree := RefTree.new(RefTree.FLAT, _toggle)
	tree.hint_name = _hint_name if hint_open else focus
	var y := tree.nodes(body, RefTree.components(e), "ref/" + e.name, {e.name: true}, Vector2(8, 122), dw - 16)
	body.custom_minimum_size = Vector2(dw, y + 24)
	scroll.set_deferred("scroll_vertical", _detail_keep)
