## The tier / display-size badge (the user, 2026-11-22/23): a circle like
## the card's other corner circles, in its bottom-left corner: the item's
## tier as a Roman numeral over blocks for how much mat space its card
## takes (1 small, 2 stacked for a full card, 4 for a capstone). On the
## full card view and cards in the hand.
##   SizeBadge.make("Glass", 27, 1.5)
class_name SizeBadge
extends Panel

const NUMERAL := {"MATERIAL": "I", "COMPONENT": "II", "CREATION": "III", "CAPSTONE": "IV"}
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
	var t := Tok.label(NUMERAL.get(b.tier, "?"), roundf(d * 0.3), Color.WHITE, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.position = Vector2(0, d * 0.1)
	t.size = Vector2(d, d * 0.42)
	b.add_child(t)
	b.set_meta("cmp", item + ":size")
	return b


## A rule over and under the numeral (so a lone I can't read as "!"),
## then the blocks under it, gold.
func _draw() -> void:
	var d := size.x
	var t: Label = get_child(0)
	var tw := t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.get_theme_font_size("font_size")).x
	var rw := maxf(tw + d * 0.08, d * 0.2)
	var lw := maxf(1.0, d * 0.035)
	for ry in [d * 0.16, d * 0.49]:
		draw_line(Vector2((d - rw) / 2, ry), Vector2((d + rw) / 2, ry), Color.WHITE, lw)
	var c := d * 0.13
	var g := c * 0.3
	var rows := 1 if tier == "MATERIAL" else 2
	var cols := 2 if tier == "CAPSTONE" else 1
	var x0 := (d - (cols * c + (cols - 1) * g)) / 2
	var y0 := d * 0.53 + (c + g if rows == 1 else 0.0) / 2
	for r in rows:
		for k in cols:
			draw_rect(Rect2(x0 + k * (c + g), y0 + r * (c + g), c, c), Tok.GOLD)
