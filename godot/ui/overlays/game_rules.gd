## Game Rules (#settingsRules): switches, saved with Save; ✕ leaves them.
## Tutorial tips: off hides the game's tips; turning it back on brings back
## every tip hidden with its ✕. The layout is ui/overlays/game_rules.tscn.
## shortcut: Mini-games (M7), Auto card inspection, Low motion (M8) and the
## 5x5 BINGO card aren't in the Godot game yet, so their switches aren't shown.
class_name GameRules
extends ParchDialog

const SCENE := "res://ui/overlays/game_rules.tscn"


func _ready() -> void:
	super()
	$Window/Content/Tips.on = Progress.prefs.get("guidedTutorialEnabled", true) != false
	$Window/Content/SaveRow/Save.set_meta("button", true)
	$Window/Content/SaveRow/Save.gui_input.connect(func(ev): if _tap(ev): _save())


func _save() -> void:
	var tips: bool = $Window/Content/Tips.on
	if tips and Progress.prefs.get("guidedTutorialEnabled", true) == false:
		Progress.prefs.hiddenTips = []
	Progress.prefs.guidedTutorialEnabled = tips
	Progress.save_all()
	close()
