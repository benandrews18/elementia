## The Crafting Bench (display-mat.css): wood in the hub buttons' brass frame
## (ui/hub_frame.webp as a 9-slice: 58px corners drawn 16px wide), the title
## above, and one child laid out inside the padding (30px top, 18px sides
## and bottom). Also the Market panel's frame (title "").
class_name BenchPanel
extends Container

const SLICE := 58.0  # border-image-slice, source pixels
const EDGE := 16.0  # border-image-width, design pixels
const PAD := [18.0, 30.0, 18.0, 18.0]  # left, top, right, bottom

static var _frame: StyleBoxTexture

var title := "Crafting Bench"


func _init() -> void:
	set_meta("cmp", "bench")


func _ready() -> void:
	if title != "":
		var t := Tok.label(title.to_upper(), 11, Color("#ffe08a"), 900)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 0)
		t.add_theme_color_override("font_shadow_color", Color.BLACK)
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 1)
		t.set_meta("cmp", "bench:title")
		t.set_meta("bench_title", true)
		add_child(t)
		# letter-spacing .14em
		var fv := FontVariation.new()
		fv.base_font = Tok.font(900)
		fv.spacing_glyph = int(round(11 * 0.14))
		t.add_theme_font_override("font", fv)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if not c is Control:
				continue
			if c.has_meta("bench_title"):
				c.position = Vector2(0, 9 - 3)  # CSS top:9px is the line box; Godot's is ~3px taller
				c.size = Vector2(size.x, c.get_minimum_size().y)
			else:
				fit_child_in_rect(c, Rect2(PAD[0], PAD[1], size.x - PAD[0] - PAD[2], size.y - PAD[1] - PAD[3]))
	elif what == NOTIFICATION_DRAW:
		# box-shadow 0 6px 12px -4px
		draw_style_box(Tok.box(Color(0, 0, 0, 0), 4, 0, Color.BLACK, 8, 6, Color(0, 0, 0, 0.5)), Rect2(4, 4, size.x - 8, size.y - 8))
		# Corners are 58 source px drawn at 16: draw scaled down, at full resolution.
		var k := EDGE / SLICE
		draw_set_transform(Vector2.ZERO, 0, Vector2(k, k))
		draw_style_box(_frame_box(), Rect2(Vector2.ZERO, size / k))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		if c is Control and not c.has_meta("bench_title"):
			m = m.max(c.get_combined_minimum_size())
	return m + Vector2(PAD[0] + PAD[2], PAD[1] + PAD[3])


static func _frame_box() -> StyleBoxTexture:
	if _frame == null:
		_frame = StyleBoxTexture.new()
		_frame.texture = load("res://assets/ui/hub_frame.webp")
		_frame.set_texture_margin_all(SLICE)
		_frame.draw_center = true
	return _frame
