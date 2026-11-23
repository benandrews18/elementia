## The display-size badge (the user, 2026-11-22/23): a circle like the
## card's other corner circles, in its bottom-left corner, holding gold
## blocks for how much mat space its card takes: 1 for a tier 1 card, 2
## stacked for tiers 2 and 3 (a full card), 2x2 for a capstone. On the full
## card view and cards in the hand. (No numeral: the Market keeps its own.)
##   SizeBadge.make("Glass", 27, 1.5)
class_name SizeBadge
extends Panel

const FILL := Color("#2b3a4a")

var tier := ""


static func make(item: String, d: float, border: float) -> SizeBadge:
	var b := SizeBadge.new()
	var e = Catalog.entry(item)
	b.tier = e.tier if e else ""
	b.size = Vector2(d, d)
	b.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := Tok.box(FILL, d / 2, border, Color.BLACK)
	if d >= 40:  # the full card's circles have a soft shadow
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("panel", sb)
	b.set_meta("cmp", item + ":size")
	return b


## The blocks, gold, centred.
func _draw() -> void:
	var d := size.x
	var c := d * 0.2
	var g := c * 0.25
	var rows := 1 if tier == "MATERIAL" else 2
	var cols := 2 if tier == "CAPSTONE" else 1
	var x0 := (d - (cols * c + (cols - 1) * g)) / 2
	var y0 := (d - (rows * c + (rows - 1) * g)) / 2
	for r in rows:
		for k in cols:
			draw_rect(Rect2(x0 + k * (c + g), y0 + r * (c + g), c, c), Tok.GOLD)
