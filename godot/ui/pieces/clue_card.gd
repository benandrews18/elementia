## A collection's card in the gift and discovery windows (.clue-card): a
## kicker ("New clue", "Collection discovered!", "New collection!"), its
## name, its items (the newly shown one ringed in gold, unknown ones "?"),
## and a line under them. Found (discovered) it turns green. The look is
## ui/pieces/clue_card.tscn.
class_name ClueCard
extends PanelContainer

const SCENE := "res://ui/pieces/clue_card.tscn"

@export var found_style: StyleBox
@export var found_kicker := Color("#1e7a43")
@export var tile_style: StyleBox
@export var new_tile_style: StyleBox
@export var unknown_style: StyleBox


static func make() -> ClueCard:
	return Tok.make(SCENE)


## c: a Mat.collections() entry; known: the items shown (all, when found);
## fresh: the one just revealed (ringed), or "".
func fill(c: Dictionary, known: Array, fresh: String, found: bool, kicker: String, line: String) -> void:
	if found:
		add_theme_stylebox_override("panel", found_style)
		$Box/Kicker.add_theme_color_override("font_color", found_kicker)
	$Box/Kicker.text = kicker.to_upper()
	$Box/Name.text = c.name
	$Box/Line.text = line
	for n in c.items:
		var t := Panel.new()
		t.custom_minimum_size = Vector2(46, 46)
		if known.has(n):
			t.add_theme_stylebox_override("panel", new_tile_style if n == fresh else tile_style)
			var ic := Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), 34)
			ic.position = Vector2(6, 6)
			t.add_child(ic)
		else:
			t.add_theme_stylebox_override("panel", unknown_style)
			var q := Tok.label("?", 22, Color("#a08a66"), 900)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			t.add_child(q)
		$Box/Icons.add_child(t)
