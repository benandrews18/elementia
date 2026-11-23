## Tutorial Messages (#settingsTuts): every tip window, to read again; a row
## closes this and shows its window. ✕ goes back to Settings. The layout is
## ui/overlays/tutorial_messages.tscn.
class_name TutorialMessages
extends ParchDialog

const SCENE := "res://ui/overlays/tutorial_messages.tscn"


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)


func _on_pressed(button: String) -> void:
	var app := App.current
	close()
	match button:
		"Back": SettingsWindow.show_on(app)
		"HowToPlay": HowToPlay.play(app, func(): pass, true)
		"PinTip": PinTip.open(app, func(): pass)
		"BoardChecks": MatRules.show_on(app)
		"Challenges": MatRules.order_tip(app)
		"Unknown": ParchDialog.open(app, UnknownTip.SCENE)
		"Elements": app.show_elements()
