## What an Unknown Element is (showEmptyElTip(), #emptyElTip): the "?"
## square over its title, what it does, where to use it and how to earn one.
## The layout is ui/overlays/unknown_tip.tscn.
class_name UnknownTip
extends ParchDialog

const SCENE := "res://ui/overlays/unknown_tip.tscn"


func _ready() -> void:
	super()
	var sq := LockInReward.unknown_square(56)  # drawn: its banner overlaps its foot
	var holder: Control = $Window/Content/Square
	holder.add_child(sq)
	holder.resized.connect(func(): sq.position = Vector2((holder.size.x - 56) / 2, 0))
