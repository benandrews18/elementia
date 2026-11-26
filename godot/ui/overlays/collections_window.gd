## Collections (renderCollectionsList(); the title screen's Collections, and
## from a run): how many of the named collections are found, then one
## CollectionRow each for the found ones and the ones a clue has started. From the title screen: the Stars bubble by the title, and the clue
## buttons (one clue for CLUE_COST Stars, or all the Stars allow), which open
## the gifts (ClueOpen). A dark window like Saved Layouts. The layout is
## ui/overlays/collections.tscn.
class_name CollectionsWindow
extends ParchDialog

const SCENE := "res://ui/overlays/collections.tscn"

@export var top_room := 40.0
@export var banner_x := 49.1  # from the title screen the title sits left of the Stars bubble (.coll-head)

var from_menu := false


static func show_on(on: Control, menu := false) -> CollectionsWindow:
	var d: CollectionsWindow = load(SCENE).instantiate()
	d.from_menu = menu
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
	# Found ones and clue leads, in collection order.
	var shown: Array = all.filter(func(c): return found.has(c.id) or clues.has(c.id))
	var rows: VBoxContainer = $Window/Content/Scroll/Pad/Rows
	var keep: int = $Window/Content/Scroll.scroll_vertical
	for r in rows.get_children():
		r.queue_free()
	$Window/Content/Empty.visible = shown.is_empty()
	$Window/Content/Scroll.visible = not shown.is_empty()
	for c in shown:
		var row := CollectionRow.make()
		rows.add_child(row)
		row.custom_minimum_size.y = row.fill(c, null if found.has(c.id) else clues[c.id], 322)
	$Window/Content/Scroll.set_deferred("scroll_vertical", keep)


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
	scroll.custom_minimum_size.y = clampf(rows_h, 0, maxf(room, 120))
	super()
	if from_menu:
		$Window/Banner.position.x = banner_x
		var st: Control = $Window/Stars
		st.size = st.get_combined_minimum_size()
		st.position = Vector2($Window.size.x - 26 - st.size.x, 36.7)
