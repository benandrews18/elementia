## One collection in the Collections window (namedCollectionCardHTML() /
## its clue lead): the name and bonus, its items (faded when not owned),
## a green ✓ once every item is owned (no on/off switch: the mat changes
## only by playing cards, the user 2026-11-26). A clue lead shows what's known and "?" for the
## rest. The look is ui/pieces/collection_row.tscn.
class_name CollectionRow
extends Panel

const SCENE := "res://ui/pieces/collection_row.tscn"

@export var owned_style: StyleBox  # .collection-card.owns-all: the green edge
@export var icon_px := 38.0


static func make() -> CollectionRow:
	return load(SCENE).instantiate()


## c: a Mat.collections() entry; known: the clue's items (a lead), or null
## (found). Returns the row's height at width w.
func fill(c: Dictionary, known: Variant, w: float) -> float:
	size.x = w
	var s := Game.state
	var found := known == null
	$Main/Line1/Name.text = c.name
	$Main/Line1/Bonus.text = "+%d" % int(c.bonus)
	$Main/Line1/Clue.visible = not found
	$Main/Line1/Clue/Icon.texture = Data.icon("🔎")
	var owns_all: bool = c.items.all(func(n): return Catalog.owns(s, n))
	$Check.visible = found and owns_all
	if found and owns_all:
		add_theme_stylebox_override("panel", owned_style)
		var tk := Tok.tick(Color.WHITE, 12)
		tk.position = Vector2(4, 4)
		$Check.add_child(tk)
	var icons: HFlowContainer = $Main/Icons
	for n in c.items:
		if found or known.has(n):
			var ic := Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), icon_px)
			ic.custom_minimum_size = ic.size
			if found and not Catalog.owns(s, n):
				ic.modulate.a = 0.35
				ic.material = Tok.grey()
			icons.add_child(ic)
		else:
			icons.add_child(_unknown())
	# Height from the icons' rows (the flow container lays out a frame later).
	var room := w - 28
	$Main.size.x = room
	var rows := 1
	var x := 0.0
	for n in c.items:
		var iw := icon_px if found or known.has(n) else 28.0
		if x > 0 and x + iw > room:
			rows += 1
			x = 0
		x += iw + 8
	var h: float = 11 + 18.2 + 8 + rows * icon_px + (rows - 1) * 8 + 11
	size.y = h
	return h


## An item a clue hasn't shown yet: "?" in a dashed-looking box (.cr-unknown).
func _unknown() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(28, icon_px)
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Tok.box(Color(0, 0, 0, 0), 8, 2, Color("#2a5a72")))
	box.position = Vector2(0, (icon_px - 28) / 2)
	box.size = Vector2(28, 28)
	var q := Tok.label("?", 20, Color("#7d8899"), 900)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.add_child(q)
	holder.add_child(box)
	return holder

