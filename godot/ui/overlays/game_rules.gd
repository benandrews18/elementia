## Game Rules (#settingsRules): switches, saved with Save; ✕ leaves them.
## Low motion: no tap feedback motion (Juice). Vibration: the buzz on big
## moments. Tutorial tips: off hides the 💡 hints (Hints); turning it back on brings
## back every hint hidden with "Don't show again". The layout is ui/overlays/game_rules.tscn.
## shortcut: Mini-games (M7), Auto card inspection, Low motion (M8) and the
## 5x5 BINGO card aren't in the Godot game yet, so their switches aren't shown.
class_name GameRules
extends ParchDialog

const SCENE := "res://ui/overlays/game_rules.tscn"


func _ready() -> void:
	super()
	$Window/Content/Tips.on = Hints.enabled()
	$Window/Content/LowMotion.on = Progress.prefs.get("lowMotion", false) == true
	$Window/Content/Vibration.on = Progress.prefs.get("vibration", true) != false
	$Window/Content/SaveRow/Save.set_meta("button", true)
	$Window/Content/SaveRow/Save.gui_input.connect(func(ev): if Tap.tap(ev): _save())


func _save() -> void:
	var tips: bool = $Window/Content/Tips.on
	if tips and not Hints.enabled():
		Progress.prefs.hiddenTips = []
	Progress.prefs.hints = tips
	Progress.prefs.lowMotion = $Window/Content/LowMotion.on
	Progress.prefs.vibration = $Window/Content/Vibration.on
	Progress.save_all()
	close()
