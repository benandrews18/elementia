## The hub's wood: a dark-brown vertical gradient with faint grain lines,
## a 3px brass top edge and a soft highlight under it.
## flip: the Quark bar's copy, brass edge at the bottom.
@tool
class_name HubWood
extends Control

@export var flip := false:
	set(v):
		flip = v
		queue_redraw()
@export var top_color := Color("#7a4a25")
@export var mid_color := Color("#5a3418")
@export var bottom_color := Color("#43260f")
@export var edge_color := Color("#d9a441")


func _draw() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([top_color, mid_color, bottom_color])
	var steps := 24
	for i in steps:
		var y0 := size.y * i / steps
		var t := (i + 0.5) / steps
		draw_rect(Rect2(0, y0, size.x, size.y / steps + 1), g.sample(1.0 - t if flip else t))
	for x in range(0, int(size.x), 22):
		draw_rect(Rect2(x, 0, 3, size.y), Color(0, 0, 0, 0.05))
	if flip:
		draw_set_transform(Vector2(0, size.y), 0, Vector2(1, -1))
	draw_rect(Rect2(0, 0, size.x, 3), edge_color)
	draw_rect(Rect2(0, 3, size.x, 2), Color(1, 0.86, 0.55, 0.25))
