## The Crafting Bench (display-mat.css): wood in the hub buttons' brass frame
## (ui/hub_frame.webp as a 9-slice: 58px corners drawn 16px wide), the title
## above, and one child laid out inside the padding (30px top, 18px sides
## and bottom). Also the Market panel's frame (title "").
class_name BenchPanel
extends Container

const PAD := [18.0, 30.0, 18.0, 18.0]  # left, top, right, bottom
const PAD_TITLED := 24.0  # the top with the title pill on the edge


var title := "Crafting Bench"


func _init() -> void:
	set_meta("cmp", "bench")


func _ready() -> void:
	if title != "":  # a pill sitting on the frame's top edge (the user, 2026-11-28)
		var t := Tok.label(title.to_upper(), 15, Color("#ffe08a"), 900)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 0)
		t.add_theme_color_override("font_shadow_color", Color.BLACK)
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 1)
		var sb := Tok.box(Color("#3b2312"), 15, 2.5, Tok.GOLD, 4, 2, Color(0, 0, 0, 0.45))
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		t.add_theme_stylebox_override("normal", sb)
		t.set_meta("cmp", "bench:title")
		t.set_meta("bench_title", true)
		add_child(t)
		t.add_theme_font_override("font", Tok.font(900, 2))  # letter-spacing .14em


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if not c is Control:
				continue
			if c.has_meta("bench_title"):
				c.size = c.get_minimum_size()
				c.position = Vector2((size.x - c.size.x) / 2, -c.size.y / 2 + 3)  # centred on the top edge
			else:
				var top: float = PAD_TITLED if title != "" else PAD[1]
				fit_child_in_rect(c, Rect2(PAD[0], top, size.x - PAD[0] - PAD[2], size.y - top - PAD[3]))
	elif what == NOTIFICATION_DRAW:
		# box-shadow 0 6px 12px -4px
		draw_style_box(Tok.box(Color(0, 0, 0, 0), 4, 0, Color.BLACK, 8, 6, Color(0, 0, 0, 0.5)), Rect2(4, 4, size.x - 8, size.y - 8))
		Frame9.draw_frame(self, Rect2(Vector2.ZERO, size), preload("res://assets/ui/hub_frame.webp"))


func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		if c is Control and not c.has_meta("bench_title"):
			m = m.max(c.get_combined_minimum_size())
	return m + Vector2(PAD[0] + PAD[2], PAD[1] + PAD[3])
