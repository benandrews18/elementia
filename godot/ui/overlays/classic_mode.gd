## The Classic window (#modeOverlay, after the title screen's Play): the
## save's visits and points (or "New"), Continue (back into the saved run,
## or a new run's opening when there's none) and New Game (asks first when
## there's a save). Either one also closes the title screen under it.
## The layout is ui/overlays/classic_mode.tscn.
## Its History row opens History (HistoryWindow); How to Play, Quick
## Rules; Back, the title screen again.
class_name ClassicMode
extends ParchDialog

const SCENE := "res://ui/overlays/classic_mode.tscn"

var _welcome: Node  # the title screen this came from


static func show_on(on: Control, welcome: Node = null) -> ClassicMode:
	var d := ParchDialog.open(on, SCENE) as ClassicMode
	d._welcome = welcome
	return d


func _ready() -> void:
	super()
	var s := Game.state
	var pts := 0.0
	for n in s.get("items", []):
		pts += Data.t("ITEM_POINTS").get(n, 0)
	var stats: Label = $Window/Content/Card/Body/Info/StatsWrap/Stats
	stats.text = "%d visits · %d points" % [int(s.get("visits", 0)), int(pts)] if Progress.has_save() and int(s.get("visits", 0)) > 0 else "New"
	pressed.connect(_on_pressed)


func _on_pressed(button: String) -> void:
	var app := App.current
	match button:
		"Continue":  # continueRun(): the save, or a fresh start (a run still at visit 0 restarts its opening)
			_done()
			if not Progress.has_save() or int(Game.state.get("visits", 0)) == 0:
				app.new_game()
		"History":
			HistoryWindow.show_on(app)
		"HowToPlay":
			app.replay_tutorial()
		"Back":  # to the title screen (the user, 2026-11-27)
			close()
		"NewGame":
			if not Progress.has_save():
				_done()
				app.new_game()
			else:
				ConfirmDialog.ask(app, "Start a new run? Your current save will be erased.", func():
					_done()
					app.new_game())


func _done() -> void:
	if is_instance_valid(_welcome):
		_welcome.queue_free()
	close()
