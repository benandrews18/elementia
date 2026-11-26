## One collection in the Collections window (the user, 2026-11-26: a
## reference players open often, so readable first): the name and bonus,
## then a tile per item, its icon with its name under it. In a run each
## tile says where that item is: on the mat (green), in the check's hand
## (gold), owned (plain) or not yet (faded); the right of the top line
## counts them ("2 / 3"), a green ✓ once all are on the mat. A clue lead
## shows what's known and "?" for the rest. The look is
## ui/pieces/collection_row.tscn.
class_name CollectionRow
extends Panel

const SCENE := "res://ui/pieces/collection_row.tscn"
const MAT := Color("#3fb46c")
const HAND := Color("#e2b25a")

@export var owned_style: StyleBox  # every item on the mat: the green edge
@export var icon_px := 38.0
@export var tile_w := 66.0
@export var tile_gap := 6.0


static func make() -> CollectionRow:
	return load(SCENE).instantiate()


## Where an item is in this run: "mat", "hand", "owned", "" (not yet).
static func where(n: String) -> String:
	var s := Game.state
	if s.get("mat", []).has(n):
		return "mat"
	var h = Game.check_hand()
	if h != null and h.hand.has(n):
		return "hand"
	return "owned" if Catalog.owns(s, n) else ""


## How close a run is to it: on the mat counts most, then in hand, owned.
static func closeness(c: Dictionary) -> float:
	var score := 0.0
	for n in c.items:
		score += {"mat": 1.0, "hand": 0.9, "owned": 0.7}.get(where(n), 0.0)
	return score / c.items.size()


## c: a Mat.collections() entry; known: the clue's items (a lead), or null
## (found); run: show where each item is. Returns the row's height at width w.
func fill(c: Dictionary, known: Variant, w: float, run := false) -> float:
	size.x = w
	var found := known == null
	$Main/Line1/Name.text = c.name
	$Main/Line1/Bonus.text = "+%d" % int(c.bonus)
	$Main/Line1/Clue.visible = not found
	$Main/Line1/Clue/Icon.texture = Data.icon("🔎")
	var places: Array = c.items.map(func(n): return where(n) if run and found else "owned")
	var on_mat: int = places.count("mat")
	var have: int = places.filter(func(p): return p != "").size()
	var prog: Label = $Main/Line1/Progress
	prog.visible = run and found and on_mat < c.items.size()
	prog.text = "%d / %d" % [have, c.items.size()]
	$Check.visible = run and found and on_mat == c.items.size()
	if $Check.visible:
		add_theme_stylebox_override("panel", owned_style)
		var tk := Tok.tick(Color.WHITE, 14)
		tk.position = Vector2(4, 4)
		$Check.add_child(tk)
	var tiles: Control = $Main/Tiles
	var room := w - 28
	var per := maxi(1, int((room + tile_gap) / (tile_w + tile_gap)))
	var th := 0.0
	for i in c.items.size():
		var n: String = c.items[i]
		var t := _tile(n, places[i], found or known.has(n))
		t.position = Vector2((i % per) * (tile_w + tile_gap), (i / per) * (t.size.y + tile_gap))
		tiles.add_child(t)
		th = t.size.y
	var lines: int = (c.items.size() + per - 1) / per
	tiles.custom_minimum_size = Vector2(room, lines * th + (lines - 1) * tile_gap)
	var h: float = 12 + 22 + 8 + tiles.custom_minimum_size.y + 12
	size.y = h
	return h


## An item: its icon in a rounded tile, its name under it (two lines at
## most); place colours the tile, "" fades it; unknown: "?".
func _tile(n: String, place: String, shown: bool) -> Control:
	var t := Panel.new()
	t.mouse_filter = MOUSE_FILTER_IGNORE
	var edge: Color = MAT if place == "mat" else HAND if place == "hand" else Color("#2a5a72")
	var bg := Color(edge, 0.2) if place in ["mat", "hand"] else Color(0, 0, 0, 0.18)
	t.add_theme_stylebox_override("panel", Tok.box(bg, 10, 2 if place in ["mat", "hand"] else 1, edge))
	t.set_meta("cmp", "coll:item:" + n)
	t.set_meta("place", place)
	var ic: Control
	if shown:
		ic = Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), icon_px)
		if place == "":
			ic.modulate.a = 0.4
			ic.material = Tok.grey()
	else:
		ic = Tok.label("?", 24, Color("#7d8899"), 900)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ic.size = Vector2(icon_px, icon_px)
	ic.position = Vector2((tile_w - icon_px) / 2, 4)
	t.add_child(ic)
	var nm := Tok.label(n if shown else "???", 12, Color.WHITE if place != "" else Color("#9aa7b5"), 800)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.add_theme_constant_override("line_spacing", -3)
	nm.position = Vector2(1, icon_px + 5)
	nm.size = Vector2(tile_w - 2, 28)
	t.add_child(nm)
	t.size = Vector2(tile_w, icon_px + 5 + 28 + 3)
	return t
