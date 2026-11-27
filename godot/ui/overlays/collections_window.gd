## Collections (the title screen's Collections, and from a run; reworked
## for reading, the user 2026-11-26): how many of the named collections are
## found, then one CollectionRow each for the found ones (in a run: where
## each item is, the closest to done first, with a legend) and the ones a
## clue has started, then how many are left to discover. As tall as the
## room between the top bar and the hub. From the title screen: the Stars bubble by the title, and the clue
## buttons (one clue for CLUE_COST Stars, or all the Stars allow), which open
## the gifts (ClueOpen). A dark window like Saved Layouts. The layout is
## ui/overlays/collections.tscn.
class_name CollectionsWindow
extends ParchDialog

const SCENE := "res://ui/overlays/collections.tscn"

@export var top_room := 40.0
@export var banner_x := 49.1  # from the title screen the title sits left of the Stars bubble (.coll-head)

var from_menu := false
var focus := ""  # a collection's id: its row lit and scrolled to (a card's ⭐)


static func show_on(on: Control, menu := false, focus_id := "") -> CollectionsWindow:
	var d: CollectionsWindow = Tok.make(SCENE)
	d.from_menu = menu
	d.focus = focus_id
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	$Window.icon = Data.icon("🏆")
	var shop: Control = $Window/Content/Shop
	shop.visible = from_menu
	$Window/Content/ShopGap.visible = from_menu
	$Window/Stars.visible = from_menu
	for b in ["One", "All"]:
		shop.get_node(b + "/Row/Gift").texture = Data.icon("🎁")
	shop.get_node("One/Row/Star").texture = Data.icon("⭐")
	$Window/Stars/Row/Star.texture = Data.icon("⭐")
	shop.get_node("One").gui_input.connect(func(ev): if Tap.tap(ev): _buy(1))
	shop.get_node("All").gui_input.connect(func(ev): if Tap.tap(ev): _buy(9999))
	var legend := HBoxContainer.new()  # what a tile's colour means (in a run)
	legend.name = "Legend"
	legend.add_theme_constant_override("separation", 14)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in [["On the mat", CollectionRow.MAT, 0.2], ["In your hand", CollectionRow.HAND, 0.2], ["Owned", Color("#2a5a72"), 0.0]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		var sw := Panel.new()
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.add_theme_stylebox_override("panel", Tok.box(Color(k[1], k[2]) if k[2] > 0 else Color(0, 0, 0, 0.18), 4, 2, k[1]))
		item.add_child(sw)
		item.add_child(Tok.label(k[0], 12, Color.WHITE, 800))
		legend.add_child(item)
	legend.custom_minimum_size.y = 28
	legend.set_meta("cmp", "coll:legend")
	$Window/Content.add_child(legend)
	$Window/Content.move_child(legend, $Window/Content/Count.get_index() + 1)
	Game.state_changed.connect(_build)
	_build()
	super()


func _build() -> void:
	var all := Mat.collections()
	var found: Array = Util.get_or(Progress.prefs, "everUnlockedMatCollections", [])
	var clues: Dictionary = Util.get_or(Progress.prefs, "collectionClues", {})
	$Window/Content/Count.text = "%d / %d Collections Unlocked" % [all.filter(func(c): return found.has(c.id)).size(), all.size()]
	var stars := int(Util.get_or(Progress.prefs, "stars", 0))
	var cost := int(Data.t("CLUE_COST"))
	var can := stars / cost
	var left := all.size() - all.filter(func(c): return found.has(c.id)).size()
	$Window/Stars/Row/Num.text = str(stars)
	var shop: Control = $Window/Content/Shop
	shop.get_node("One/Row/Text").text = "1 clue · %d" % cost
	shop.get_node("All/Row/Text").text = "Open all" + (" (%d)" % can if can > 1 else "")
	shop.get_node("One").modulate.a = 1.0 if can > 0 and left > 0 else 0.45
	shop.get_node("All").modulate.a = 1.0 if can > 1 and left > 0 else 0.45
	# Found ones (in a run: the closest to done first), then clue leads.
	var run: bool = not from_menu and Game.state.get("mode") != null and not Game.state.get("ended", false)
	var got: Array = all.filter(func(c): return found.has(c.id))
	if run:
		var near := {}
		for c in got:
			near[c.id] = CollectionRow.closeness(c)
		got.sort_custom(func(a, b): return near[a.id] > near[b.id])
	var shown: Array = got + all.filter(func(c): return not found.has(c.id) and clues.has(c.id))
	$Window/Content/Legend.visible = run and not got.is_empty()
	var rows: VBoxContainer = $Window/Content/Scroll/Pad/Rows
	var keep: int = $Window/Content/Scroll.scroll_vertical
	for r in rows.get_children():
		r.queue_free()
	$Window/Content/Empty.visible = shown.is_empty()
	$Window/Content/Scroll.visible = not shown.is_empty()
	for c in shown:
		var row := CollectionRow.make()
		rows.add_child(row)
		row.custom_minimum_size.y = row.fill(c, null if found.has(c.id) else clues[c.id], 322, run)
		row.set_meta("collection", c.id)
		if c.id == focus:
			var ring := Panel.new()
			ring.add_theme_stylebox_override("panel", Tok.box(Color(Tok.GOLD, 0.1), 12, 3, Tok.GOLD))
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.set_meta("cmp", "coll:focus")
			row.add_child(ring)
			row.move_child(ring, 0)  # behind the name and tiles
			_scroll_to.call_deferred(row)
			keep = -1
	var hidden := all.size() - shown.size()
	if hidden > 0:
		var more := Tok.label("%d more to discover" % hidden + ("" if from_menu else ": finish one on your mat, or trade Stars for clues on the title screen"), 14, Color("#b9c4d0"), 800)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.custom_minimum_size = Vector2(322, 60)
		more.set_meta("cmp", "coll:more")
		rows.add_child(more)
	if keep >= 0:
		$Window/Content/Scroll.set_deferred("scroll_vertical", keep)


func _scroll_to(row: Control) -> void:
	if is_instance_valid(row):
		$Window/Content/Scroll.ensure_control_visible(row)


## buyClues(n): the Stars are spent first, then the gifts open one by one.
func _buy(n: int) -> void:
	var got := Progress.buy_clues(n)
	if not got.is_empty():
		ClueOpen.show_on(get_parent(), got)


func _layout() -> void:
	var scroll: ScrollContainer = $Window/Content/Scroll
	var rows_h: float = $Window/Content/Scroll/Pad.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = 0
	var rest: float = $Window/Content.get_combined_minimum_size().y
	var room: float = size.y - top_room - HubBar.H - ($Window/Content.position.y + bottom_pad) - rest
	scroll.custom_minimum_size.y = maxf(room, 120)  # always tall: the list in the same place every time
	super()
	if from_menu:
		$Window/Banner.position.x = banner_x
		var st: Control = $Window/Stars
		st.size = st.get_combined_minimum_size()
		st.position = Vector2($Window.size.x - 26 - st.size.x, 36.7)
