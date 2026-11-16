## The Quark Meter along the top of every screen once the mat has been
## checked (#quarkTopBar, topbar.css): the hub's wood, mirrored, with a brass
## bottom edge, holding the meter line for the current mat.
class_name QuarkTopBar
extends Control

const H := 46.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var wood := HubBar.HubWood.new()
	wood.flip = true
	wood.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	wood.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(wood)
	var qm := QuarkMeter.new()
	qm.position = Vector2(14, 8)
	qm.size = Vector2(size.x - 28, qm.custom_minimum_size.y)
	add_child(qm)
	var s := Game.state
	qm.show_score(Mat.score(Mat.on_mat(s), s, Game.ctx).total, Orders.tiers(Orders.check_round(s)))
	set_meta("cmp", "qtop")
