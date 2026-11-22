## The turn clock's window (openClockInfo(), #clockInfo): the clock, "Round
## n / 24", what a round is, and the Display Mat check every 3 rounds. The
## layout is ui/overlays/clock_info.tscn.
class_name ClockInfo
extends ParchDialog

const SCENE := "res://ui/overlays/clock_info.tscn"


static func show_on(on: Control) -> void:
	var v := int(Game.state.get("visits", 0))
	var n := int(Data.t("RUN_COMPLETE_VISIT"))
	ParchDialog.open(on, SCENE, {"round": str(v) + (" (Overtime)" if v > n else ""), "rounds": str(n), "every": str(int(Data.t("MAT_CHECK_EVERY")))})


func _ready() -> void:
	super()
	var clock := TurnClock.make(int(Game.state.get("visits", 0)))
	var holder: Control = $Window/Content/Square
	holder.custom_minimum_size.y = TurnClock.SIZE
	holder.add_child(clock)
	holder.resized.connect(func(): clock.position = Vector2((holder.size.x - TurnClock.SIZE) / 2, 0))
