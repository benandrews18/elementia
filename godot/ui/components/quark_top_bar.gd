## The Quark Meter along the top of every screen once the mat has been
## checked (#quarkTopBar, topbar.css): the hub's wood, mirrored, with a brass
## bottom edge, holding the meter line for the current mat.
class_name QuarkTopBar
extends Control

const H := 46.0
const SCENE := "res://ui/components/quark_top_bar.tscn"  # its wood (HubWood, flipped)


static func make() -> QuarkTopBar:
	return load(SCENE).instantiate()


func _ready() -> void:
	var qm := QuarkMeter.new()
	qm.position = Vector2(14, 8)
	qm.size = Vector2(size.x - 28, qm.custom_minimum_size.y)
	add_child(qm)
	for c in qm.get_children():  # measured apart from the drawer's own meter
		if c.has_meta("cmp"):
			c.set_meta("cmp", "qtop:" + c.get_meta("cmp"))
	var s := Game.state
	qm.show_score(Mat.score(Mat.on_mat(s), s, Game.ctx).total, Orders.tiers(Orders.check_round(s)))
