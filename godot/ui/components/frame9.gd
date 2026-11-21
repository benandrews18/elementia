## A brass-framed wooden panel: the hub_frame art as a 9-slice (CSS
## border-image: 58 fill / 16px). The 58px source corners are drawn 16px wide,
## scaled down from full resolution so they stay crisp. Used by the hub's
## side buttons and the Crafting Bench (BenchPanel).
@tool
class_name Frame9
extends Control

const SLICE := 58.0  # border-image-slice, source pixels
const EDGE := 16.0  # border-image-width, design pixels

static var _boxes := {}

@export var texture: Texture2D = preload("res://assets/ui/hub_frame.webp"):
	set(v):
		texture = v
		queue_redraw()


func _draw() -> void:
	draw_frame(self, Rect2(Vector2.ZERO, size), texture)


static func draw_frame(ci: CanvasItem, r: Rect2, tex: Texture2D) -> void:
	if not _boxes.has(tex):
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(SLICE)
		sb.draw_center = true
		_boxes[tex] = sb
	var k := EDGE / SLICE
	ci.draw_set_transform(r.position, 0, Vector2(k, k))
	ci.draw_style_box(_boxes[tex], Rect2(Vector2.ZERO, r.size / k))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
