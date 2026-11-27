## The Items screen (renderCodex(), Item Reference; the hub's Items button):
## every item that's open (capstone unlocks stay hidden until their capstone
## is made), one row each (RefRow), pinned ones in their own table on top.
## Search filters by name, tier, station or recipe; sort by name or points.
## The search bar sticks under the Quark bar as the list scrolls. A row opens
## its breakdown (RefTree, dark). Item Info on a card jumps here (jump_to).
## The layout is ui/screens/items_screen.tscn.
class_name ItemsScreen
extends Control

const SCENE := "res://ui/screens/items_screen.tscn"

static var sort_mode := 0  # 0 A-Z, 1 points low-high, 2 points high-low (refSortMode, kept for the session)
static var query := ""  # the search (refFilterQuery)

@export var table_gap := 14.0  # under the search bar, and between the tables
@export var pinned_gap := 20.0

var _rows: Array[RefRow] = []
var _kept := {}  # item -> [its row, what it was filled with]: unchanged rows are kept
var _jump := ""
@onready var _scroll: ScrollContainer = $Scroll
@onready var _page: Control = $Scroll/Page


static func make() -> ItemsScreen:
	return Tok.make(SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Scroll/Page/Title/Icon.texture = Data.icon("📖")
	$Scroll/Page/Title/Icon.visible = $Scroll/Page/Title/Icon.texture != null
	$Bar/Search.text = query
	$Bar/Search.text_changed.connect(func(t):
		query = t
		_layout())
	$Bar/Sort.selected = sort_mode
	$Bar/Sort.item_selected.connect(func(i):
		sort_mode = i
		_redraw())
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _stick())
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
	_redraw()


## Opens name's breakdown (and only it), scrolled to its row (goToRefItem()).
func jump_to(name: String) -> void:
	TodoTray.expanded.clear()
	TodoTray.expanded["refroot/" + name] = true
	_jump = name
	_redraw()


func _redraw() -> void:
	if is_queued_for_deletion():
		return
	var keep := _scroll.scroll_vertical
	var s := Game.state
	var top := QuarkTopBar.H if s.get("matChecked") else 0.0
	for c in $Top.get_children():
		c.queue_free()
	if top > 0:
		var qt := QuarkTopBar.make()
		qt.size = Vector2(size.x, top)
		$Top.add_child(qt)
	StationScreen.corner_buttons($Top, true, false)  # the gear; no Convert here
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(size.x, size.y - top - HubBar.H)
	# Every open item once, sorted; the pinned ones in their own table.
	var seen := {}
	var items := []
	for e in Data.t("ENTRIES"):
		if not seen.has(e.name) and Catalog.item_open(s, e.name):
			seen[e.name] = true
			items.append(e)
	var by_name := func(a, b): return -1 if a.name.naturalnocasecmp_to(b.name) < 0 else (1 if a.name.naturalnocasecmp_to(b.name) > 0 else 0)
	match sort_mode:
		1: items = Util.stable_sort(items, func(a, b): return int(a.points - b.points) if a.points != b.points else by_name.call(a, b))
		2: items = Util.stable_sort(items, func(a, b): return int(b.points - a.points) if a.points != b.points else by_name.call(a, b))
		_: items = Util.stable_sort(items, by_name)
	# A row is made again only when what it shows changed (rebuilding all
	# ~99 took ~360 ms per change: review 11). An open row always is: its
	# breakdown shows what else is owned.
	_rows.clear()
	var w: float = size.x - 24 - 2
	var tree := RefTree.new(RefTree.DARK, func(path):
		if TodoTray.expanded.has(path):
			TodoTray.expanded.erase(path)
		else:
			TodoTray.expanded[path] = true
		_redraw())
	var kept := {}
	var at := {$Scroll/Page/PinTable: 0, $Scroll/Page/Table: 0}
	for e in items:
		var path: String = "refroot/" + e.name
		var open := TodoTray.expanded.has(path)
		var pinned := Progress.is_pinned(e.name)
		var sig := [Catalog.owns(s, e.name), pinned, w]
		var old: Array = _kept.get(e.name, [])
		var row: RefRow
		if not open and not old.is_empty() and old[1] == sig:
			row = old[0]
			_kept.erase(e.name)
		else:
			row = RefRow.make()
			row.fill(e, w, open, tree)
			row.set_meta("search", RefRow.search_text(e))
			row.gui_input.connect(func(ev): if Tap.tap(ev): tree.on_toggle.call(path))
		kept[e.name] = [row, sig if not open else []]
		var table: Control = $Scroll/Page/PinTable if pinned else $Scroll/Page/Table
		if row.get_parent() != table:
			if row.get_parent():
				row.reparent(table, false)
			else:
				table.add_child(row)
		table.move_child(row, at[table])
		at[table] += 1
		_rows.append(row)
	for left in _kept.values():  # rows no longer shown, or made again
		left[0].queue_free()
	_kept = kept
	_layout()
	var i := 0
	for t in [$Scroll/Page/PinTable, $Scroll/Page/Table]:  # tagged (meta cmp) in page order
		for r in t.get_children().filter(func(c): return c is RefRow):
			r.tag("ref:row%d" % i)
			i += 1
	if _jump != "":  # the row's top just under the search bar
		for r in _rows:
			if r.item == _jump:
				var table: Control = r.get_parent()
				keep = int(maxf(0, table.position.y + r.position.y - $Bar.size.y - 12))
		_jump = ""
	_scroll.set_deferred("scroll_vertical", keep)
	_stick.call_deferred()


## Stacks the rows the search keeps, in their tables, and sizes the page.
func _layout() -> void:
	var q := query.strip_edges().to_lower()
	var title_h := 40.5
	var y: float = 4.0 + title_h + 6 + $Bar.size.y + table_gap
	var pin_head: Control = $Scroll/Page/PinHead
	for t: Control in [$Scroll/Page/PinTable, $Scroll/Page/Table]:
		var ty := 1.0
		for r: RefRow in t.get_children().filter(func(c): return c is RefRow and not c.is_queued_for_deletion()):
			r.visible = q == "" or String(r.get_meta("search")).contains(q)
			if r.visible:
				r.position = Vector2(1, ty)
				ty += r.size.y
		t.visible = ty > 1.0
		if t == $Scroll/Page/PinTable:
			pin_head.visible = t.visible
			if t.visible:
				pin_head.position.y = y + 4
				y += 4 + 15 + 8
		t.position = Vector2(12, y)
		t.size = Vector2(size.x - 24, ty + 1)
		if t.visible:
			y += t.size.y + (pinned_gap if t == $Scroll/Page/PinTable else 0.0)
	_page.custom_minimum_size = Vector2(size.x, y + 20)
	$Bar.size.x = size.x - 24


## The search bar: under the title, then stuck under the Quark bar (sticky).
func _stick() -> void:
	$Bar.position = Vector2(12, _scroll.position.y + maxf(0, 50.5 - _scroll.scroll_vertical))
