## An image stretched to any size by its edges (CSS border-image): the
## corners keep their shape, the middle stretches. The parchment window, the
## wooden banner, the pill buttons and the brass pills are all this, with
## their own image. corner: how tall the top edge is drawn on screen, so a
## large, sharp source image draws small and stays crisp.
@tool
class_name NineSlice
extends Control

@export var texture: Texture2D:
	set(v):
		texture = v
		_sb = null
		queue_redraw()
## The image's edge widths, in its own pixels (left/right, top/bottom).
@export var margin_x := 56.0:
	set(v):
		margin_x = v
		_sb = null
		queue_redraw()
@export var margin_y := 56.0:
	set(v):
		margin_y = v
		_sb = null
		queue_redraw()
## Draw the middle too (CSS border-image "fill"); off: only the frame (the
## dark windows put their own body inside).
@export var fill := true:
	set(v):
		fill = v
		_sb = null
		queue_redraw()
## The top edge's height on screen.
@export var corner := 30.0:
	set(v):
		corner = v
		queue_redraw()

var _sb: StyleBoxTexture


func _draw() -> void:
	if texture == null:
		return
	if _sb == null:
		_sb = StyleBoxTexture.new()
		_sb.texture = texture
		_sb.texture_margin_left = margin_x
		_sb.texture_margin_right = margin_x
		_sb.texture_margin_top = margin_y
		_sb.texture_margin_bottom = margin_y
		_sb.draw_center = fill
	var k := corner / margin_y
	draw_set_transform(Vector2.ZERO, 0, Vector2(k, k))
	draw_style_box(_sb, Rect2(Vector2.ZERO, size / k))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
