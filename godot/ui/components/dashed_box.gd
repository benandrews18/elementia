## A rounded 2px dashed outline (CSS border:2px dashed), for empty slots.
class_name DashedBox
extends Control

var radius := 12.0
var color := Tok.LINE


func _draw() -> void:
	var r := radius
	var w := size.x
	var h := size.y
	var dash := 6.0
	draw_dashed_line(Vector2(r, 1), Vector2(w - r, 1), color, 2, dash)
	draw_dashed_line(Vector2(r, h - 1), Vector2(w - r, h - 1), color, 2, dash)
	draw_dashed_line(Vector2(1, r), Vector2(1, h - r), color, 2, dash)
	draw_dashed_line(Vector2(w - 1, r), Vector2(w - 1, h - r), color, 2, dash)
	for c in [Vector2(r, r), Vector2(w - r, r), Vector2(w - r, h - r), Vector2(r, h - r)]:
		var start: float = {Vector2(r, r): PI, Vector2(w - r, r): -PI / 2, Vector2(w - r, h - r): 0.0, Vector2(r, h - r): PI / 2}[c]
		draw_arc(c, r - 1, start, start + PI / 2, 8, color, 2, true)
