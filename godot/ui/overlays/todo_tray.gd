## The To-Do List (the hub's To-Do List button): a tray sliding in from the
## left, a quest log (the user, 2026-11-26: questline games keep one
## objective in view, chapters with counts, progress from what's owned).
## Each pinned item is a quest: icon (its card), name, points, where it's
## made, its 📌 (drop it), a bar of its direct parts owned. A tap folds or
## opens it; open, its parts are rows (RefTree, one level per tap) with 🔍
## Track. The quest holding the tracked item leads, open down to it; the
## others are folded. Facts only, no advice; "Get a Hint" stays, asked for.
class_name TodoTray
extends Control

const INK := Color("#2a1f14")

static var expanded := {}  # "refroot/<item>" and "ref/<root>/.../<item>" paths shown open
static var hint_open := false
static var focus := ""  # a shop card's tracked-item badge was tapped: this one lit in the tracked item's breakdown

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
	if t:  # the leading quest open down to the tracked item (or to the shop's 🔍 tap)
		_open_to(lead(), focus if focus != "" else t)
	tree_exiting.connect(func(): focus = "")
	var w := minf(400, size.x * 0.92)
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
	var w := _scroll.size.x - 40
	var names: Array = Progress.prefs.pinnedItems.filter(func(n): return Catalog.entry(n) != null)
	var first := lead()
	if names.has(first):  # the quest holding the tracked item leads
		names.erase(first)
		names.push_front(first)
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
		if Game.ctx.get("tracked") == null:  # a nudge, not a pick (the user, 2026-11-26)
			var tip := Tok.label("Tip: tap 🔍 on a part to track it.", 13, Color("#b3becd"), 700)
			tip.position = Vector2(20, y)
			tip.set_meta("cmp", "todo:tip")
			_list.add_child(tip)
			y += 24
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


## A quest: a parchment card with its pushpin; returns its bottom. The
## tracked item's quest wears a gold ring and a 🔍 badge.
func _row(e: Dictionary, at: Vector2, w: float) -> float:
	var owned := Catalog.owns(Game.state, e.name)
	var path: String = "refroot/" + e.name
	var open := expanded.has(path)
	var tracked: bool = e.name == Game.ctx.get("tracked")
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Tok.box(Color("#dff2e2") if owned else Color("#f3e6c8"), 14, 4 if tracked else 2,
		Tok.GOLD if tracked else Color("#4fbf7a") if owned else Color("#c9a571"), 4, 2, Color(0, 0, 0, 0.3)))
	card.position = at
	card.mouse_filter = MOUSE_FILTER_PASS  # a drag scrolls the list; a tap folds or opens it
	card.set_meta("cmp", "todo:quest:" + e.name)
	card.gui_input.connect(func(ev): if Tap.tap(ev): _toggle(path))
	_list.add_child(card)
	if tracked:  # a 🔍 badge off its top-right corner
		var badge := Panel.new()
		badge.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD, 17, 2, Color.BLACK, 3, 2, Color(0, 0, 0, 0.4)))
		badge.position = Vector2(w - 24, -12)
		badge.size = Vector2(34, 34)
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		var gl := Tok.icon("🔍", 18)
		gl.position = Vector2(8, 8)
		badge.add_child(gl)
		card.add_child(badge)
	var tack := Panel.new()  # the red pushpin at the top
	tack.add_theme_stylebox_override("panel", Tok.box(Color("#d9483c"), 6.5, 0, Color.BLACK, 2, 1, Color(0, 0, 0, 0.4)))
	tack.size = Vector2(13, 13)
	tack.position = Vector2(w / 2 - 6.5, -6)
	tack.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(tack)
	var ic := Tok.icon(e.emoji, 40)  # a tap: its card
	ic.position = Vector2(14, 14)
	ic.mouse_filter = MOUSE_FILTER_STOP
	ic.set_meta("cmp", "todo:card:" + e.name)
	ic.gui_input.connect(func(ev): if Tap.tap(ev):
		ic.accept_event()
		if App.current: App.current.show_card(e.name))
	card.add_child(ic)
	if RefTree.ready(e.name):
		card.add_child(RefTree.ready_dot(Vector2(48, 10)))
	var arrow := RefTree.arrow(open, Color("#8a5a1a"))
	arrow.position = Vector2(64, 21)
	arrow.set_meta("cmp", "todo:fold:" + e.name)
	card.add_child(arrow)
	var pts := Panel.new()  # ⭐ points
	pts.add_theme_stylebox_override("panel", Tok.box(Color("#fbe9b5"), 10))
	pts.mouse_filter = MOUSE_FILTER_IGNORE
	var ptxt := str(int(e.points))
	pts.size = Vector2(20 + Tok.font(900).get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14, 20)
	pts.position = Vector2(w - 54 - pts.size.x, 16)
	var star := Tok.star(Color("#f5b400"), 12)
	star.position = Vector2(7, 4)
	pts.add_child(star)
	var pl := Tok.label(ptxt, 12, INK, 900)
	pl.position = Vector2(23, 1)
	pts.add_child(pl)
	card.add_child(pts)
	var room := pts.position.x - 8 - 80 - (22.0 if owned else 0.0)
	var px := Tok.fit_px(e.name, Tok.font(900), 17, room)
	var name_l := Tok.label(e.name, px, INK, 900)
	name_l.position = Vector2(80, 13 + (17 - px) * 0.6)
	card.add_child(name_l)
	if owned:
		var t := Tok.tick(Color.WHITE, 16, Tok.OK)
		t.position = Vector2(80 + Tok.font(900).get_string_size(e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 6, 17)
		card.add_child(t)
	# The parts bar: direct parts owned of all (a quest's chapters).
	var pc := RefTree.parts(e)
	var bar_w := 84.0
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", Tok.box(Color("#e3cfa4"), 5))
	bar.position = Vector2(80, 44)
	bar.size = Vector2(bar_w, 10)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.set_meta("cmp", "todo:bar:%d/%d" % [pc.x, pc.y])
	if pc.x > 0:
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel", Tok.box(Tok.OK, 5))
		fill.size = Vector2(maxf(10, bar_w * pc.x / maxf(1, pc.y)), 10)
		fill.mouse_filter = MOUSE_FILTER_IGNORE
		bar.add_child(fill)
	card.add_child(bar)
	var cl := Tok.label("%d/%d parts" % [pc.x, pc.y], 12, Color("#8a5a1a"), 800)
	cl.position = Vector2(80 + bar_w + 8, 39)
	card.add_child(cl)
	var hx := 80 + bar_w + 8 + Tok.font(800).get_string_size(cl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
	for h in Data.t("ENTRIES").filter(func(x): return x.name == e.name).map(func(x): return x.station):  # where it's made
		if hx + 16 > w - 54:
			break
		var sic := Tok.icon(Catalog.station(h).emoji, 16)
		sic.position = Vector2(hx, 40)
		card.add_child(sic)
		hx += 20
	card.add_child(_pin_button(e.name, Vector2(w - 48, 14)))
	var h := 70.0
	if open:
		var tree := RefTree.new(RefTree.PARCHMENT, _toggle)
		tree.hint_name = _hint_name if hint_open else focus
		h = tree.nodes(card, RefTree.components(e), "ref/" + e.name, {e.name: true}, Vector2(16, h + 4), w - 32) + 12
	card.size = Vector2(w, h)
	return at.y + h


## A quest's pin (the big dark one): drops it from the list.
func _pin_button(name: String, at: Vector2) -> Control:
	var pinned := Progress.is_pinned(name)
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", Tok.box(Color("#3a2414"), 8, 2, Tok.GOLD if pinned else Color("#b9b0a0"), 3, 2, Color(0, 0, 0, 0.3)))
	b.size = Vector2(34, 34)
	b.position = at
	b.set_meta("cmp", "todo:pin:" + name)
	var ic := Tok.icon("📌", 18)
	ic.position = (b.size - Vector2(18, 18)) / 2
	if not pinned:
		ic.material = Tok.grey()
	b.add_child(ic)
	b.gui_input.connect(func(ev): if Tap.tap(ev):
		b.accept_event()
		App.pin(name))
	return b
