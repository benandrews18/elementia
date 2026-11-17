## The brass pill behind "YOU ARE HERE" (pill_short, 9-slice: 52px corners
## drawn 13px wide).
@tool
extends Control

const TEX := preload("res://assets/ui/pill_short.webp")


func _draw() -> void:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX
	sb.set_texture_margin_all(52)
	var k := 13.0 / 52.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(k, k))
	draw_style_box(sb, Rect2(Vector2.ZERO, size / k))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
