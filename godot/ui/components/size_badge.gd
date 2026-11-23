## The tier / display-size badge (the user, 2026-11-22): the item's tier as
## a Roman numeral and how much mat space its card takes as blocks: 1 for
## a small (tier I) card, 2 stacked for a full one, 4 for a capstone. On
## the full card view, the Crafting Bench and cards in the hand.
##   SizeBadge.make("Glass", 22)
class_name SizeBadge
extends Panel

const NUMERAL := {"MATERIAL": "I", "COMPONENT": "II", "CREATION": "III", "CAPSTONE": "IV"}

var tier := ""
var px := 22.0  # the badge's height


static func make(item: String, h := 22.0) -> SizeBadge:
	var b := SizeBadge.new()
	var e = Catalog.entry(item)
	b.tier = e.tier if e else ""
	b.px = h
	b.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("panel", Tok.box(Color("#2b3a4a"), h / 2, 1.5, Color.WHITE))
	var t := Tok.label(NUMERAL.get(b.tier, "?"), h * 0.55, Color.WHITE, 900)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.position = Vector2(h * 0.32, 0)
	t.size = Vector2(t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.55)).x + 2, h)
	b.add_child(t)
	b.size = Vector2(t.position.x + t.size.x + h * 0.18 + b._blocks_w() + h * 0.32, h)
	b.set_meta("cmp", item + ":size")
	return b


func _blocks() -> int:
	return 4 if tier == "CAPSTONE" else 1 if tier == "MATERIAL" else 2


func _cell() -> float:
	return px * 0.26


func _blocks_w() -> float:
	return _cell() * (2 if _blocks() == 4 else 1) + (_cell() * 0.25 if _blocks() == 4 else 0.0)


func _draw() -> void:
	var c := _cell()
	var g := c * 0.25
	var x0 := size.x - px * 0.32 - _blocks_w()
	var rows := 1 if _blocks() == 1 else 2
	var cols := 2 if _blocks() == 4 else 1
	var y0 := (size.y - (rows * c + (rows - 1) * g)) / 2
	for r in rows:
		for k in cols:
			draw_rect(Rect2(x0 + k * (c + g), y0 + r * (c + g), c, c), Tok.GOLD)
