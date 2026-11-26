## Saved Layouts (mat-layouts.js; the mat's Layouts tab): name the mat's
## arrangement and 💾 save it, ⧉ copy them all as JSON; search (a layout's
## name, its cards or their parts), sort by points, filter by station or
## suit; one LayoutRow each, a tap loads it, 🗑 deletes it (asks first).
## A dark window: the brass frame on the game's blues, as wide as the screen
## allows, its list scrolling to keep it above the hub. The layout is
## ui/overlays/layouts.tscn.
class_name LayoutsWindow
extends ParchDialog

const SCENE := "res://ui/overlays/layouts.tscn"

## The view (kept for the session, like the HTML's mlFilt).
static var query := ""
static var ascending := false
static var stations := {}
static var suits := {}

@export var top_room := 40.0  # the window keeps this much screen free (and the hub)
@export var off_alpha := 0.5  # a filter that's off (.mat-fbtn: opacity .5)


static func show_on(on: Control) -> LayoutsWindow:
	return ParchDialog.open(on, SCENE) as LayoutsWindow


func _ready() -> void:
	$Window.icon = Data.icon("💾")
	var c := $Window/Content
	c.get_node("SaveRow/Row/Save/Icon").texture = Data.icon("💾")
	var glyph := Tok.copy_glyph(Tok.INK, 18)
	glyph.position = Vector2(10, 10)
	c.get_node("SaveRow/Row/Export").add_child(glyph)
	c.get_node("SaveRow/Row/Save").gui_input.connect(func(ev): if Tap.tap(ev): _save())
	c.get_node("SaveRow/Row/Name").text_submitted.connect(func(_t): _save())
	c.get_node("SaveRow/Row/Export").gui_input.connect(func(ev): if Tap.tap(ev): _export())
	c.get_node("SearchRow/Row/Search/Icon").texture = Data.icon("🔍")
	var search: LineEdit = c.get_node("SearchRow/Row/Search")
	search.text = query
	search.text_changed.connect(func(t): query = t.strip_edges(); _build())
	c.get_node("SearchRow/Row/Sort").gui_input.connect(func(ev): if Tap.tap(ev): ascending = not ascending; _build())
	_filters()
	_build()
	super()


## The 8 station and 4 suit filter buttons (ORed within a group, ANDed across).
func _filters() -> void:
	var grid: GridContainer = $Window/Content/Filters/Grid
	for st in Data.t("STATION_TRACKER_ORDER"):
		grid.add_child(_filter_button(Catalog.station(st).emoji, Tok.station_color(st), stations, st, true))
	for su in Data.t("ELEMENT_SUIT_LABEL").keys():
		grid.add_child(_filter_button("suit:" + su, Tok.suit_color(su), suits, su, false))


func _filter_button(icon: String, bg: Color, group: Dictionary, key: String, outline: bool) -> Panel:
	var b := Panel.new()
	b.custom_minimum_size = Vector2(0, 24.1)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	var ic := Tok.icon(icon, 17)
	if outline:
		ic.material = Tok.outline(17)
	ic.set_anchors_and_offsets_preset(PRESET_CENTER)
	ic.position -= ic.size / 2
	b.add_child(ic)
	var sync := func():
		var on := group.has(key)
		b.add_theme_stylebox_override("panel", Tok.box(bg, 8, 1.5, Tok.GOLD if on else Color("#2a5a72")))
		b.modulate.a = 1.0 if on else off_alpha
	sync.call()
	b.gui_input.connect(func(ev): if Tap.tap(ev):
		if group.has(key):
			group.erase(key)
		else:
			group[key] = true
		sync.call()
		_build())
	return b


## renderMatLayoutsList(): every saved layout that matches, by points.
func _build() -> void:
	var rows: VBoxContainer = $Window/Content/Scroll/Pad/Rows
	for r in rows.get_children():
		r.queue_free()
	var saved: Array = Util.get_or(Progress.prefs, "savedMatLayouts", [])
	var q := query.to_lower()
	var shown := []
	for i in saved.size():
		var L: Dictionary = saved[i]
		var mat: Array = L.get("items", []).map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
		var match_q: bool = q == "" or String(L.name).to_lower().contains(q) or mat.any(func(c):
			return String(c.name).to_lower().contains(q) or c.components.any(func(r): return String(r.name).to_lower().contains(q)))
		var match_st := stations.is_empty() or mat.any(func(c): return c.stations.any(func(st): return stations.has(st)))
		var match_su := suits.is_empty() or mat.any(func(c): return c.pips.any(func(p): return suits.has(p)))
		if match_q and match_st and match_su:
			shown.append([i, Mat.score(mat, Game.state, Game.ctx).total])
	shown = Util.stable_sort(shown, func(a, b): return a[1] - b[1] if ascending else b[1] - a[1])
	var sort_l: Label = $Window/Content/SearchRow/Row/Sort/Row/Text
	sort_l.text = "Points"
	var arrow_box: Control = $Window/Content/SearchRow/Row/Sort/Row/Arrow
	for a in arrow_box.get_children():
		a.queue_free()
	var arrow := RefTree.arrow(true, Tok.INK)  # ↓ (most points first), ↑ when ascending
	arrow.scale = Vector2(0.8, 0.8)
	arrow.position = Vector2(0, -4)
	if ascending:
		arrow.rotation_degrees = 180
		arrow.position = Vector2(8, 4)
	arrow_box.add_child(arrow)
	var empty: Label = $Window/Content/Empty
	empty.visible = shown.is_empty()
	empty.text = "No saved layouts yet -- arrange the mat, then save it above." if saved.is_empty() else "No layouts match."
	$Window/Content/Scroll.visible = not shown.is_empty()
	for s in shown:
		var i: int = s[0]
		var row := LayoutRow.make()
		rows.add_child(row)
		row.custom_minimum_size.y = row.fill(saved[i], 322)
		row.load_pressed.connect(func():  # loadMatLayout(): what fits now, in saved order
			Progress.load_layout(i)
			close())
		row.delete_pressed.connect(func():
			ConfirmDialog.ask(get_parent(), "Delete the layout \"%s\"? This can't be undone." % saved[i].name, func():
				Progress.delete_layout(i)
				_build()))


func _save() -> void:
	var name_box: LineEdit = $Window/Content/SaveRow/Row/Name
	if name_box.text.strip_edges() == "":
		return
	Progress.save_layout(name_box.text)
	name_box.text = ""
	_build()


## ⧉: every saved layout as JSON, then ✓ for a moment.
func _export() -> void:
	DisplayServer.clipboard_set(JSON.stringify(Util.get_or(Progress.prefs, "savedMatLayouts", []), "  "))
	var box: Control = $Window/Content/SaveRow/Row/Export
	box.get_child(0).visible = false
	var t := Tok.tick(Tok.OK, 18)
	t.position = Vector2(10, 10)
	box.add_child(t)
	t.create_tween().tween_callback(func():  # dies with the tick
		t.queue_free()
		box.get_child(0).visible = true).set_delay(1.8)


## The list takes what's left of the screen above the hub, and scrolls.
func _layout() -> void:
	var scroll: ScrollContainer = $Window/Content/Scroll
	var rows_h: float = $Window/Content/Scroll/Pad.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = 0
	var rest: float = $Window/Content.get_combined_minimum_size().y
	var room: float = size.y - top_room - HubBar.H - ($Window/Content.position.y + bottom_pad) - rest
	scroll.custom_minimum_size.y = clampf(rows_h, 0, maxf(room, 120))
	super()
