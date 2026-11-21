## Settings (the gear; #settings): How to Play, Game Rules, Tutorial
## Messages; Reset (a new run, after asking); the version. The layout is
## ui/overlays/settings.tscn.
## shortcut: no Home button until the welcome screen exists (M6 step 4), no
## Dev Tools row until dev mode (step 9).
class_name SettingsWindow
extends ParchDialog

const SCENE := "res://ui/overlays/settings.tscn"


static func show_on(on: Control) -> SettingsWindow:
	return ParchDialog.open(on, SCENE, {"version": Data.t("DATA").version}) as SettingsWindow


func _ready() -> void:
	super()
	var arrow := Tok.loop_arrow(Color("#2a0d07"), 16)  # ↺ before "Reset" (not in Nunito)
	var t: Label = $Window/Content/Buttons/Reset/Text
	t.text = "     Reset"
	t.add_child(arrow)
	t.resized.connect(func():
		var tw := t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.get_theme_font_size("font_size")).x
		arrow.position = Vector2((t.size.x - tw) / 2, (t.size.y - 16) / 2))
	pressed.connect(_on_pressed)


func _on_pressed(button: String) -> void:
	var app := App.current
	match button:
		"HowToPlay":
			close()
			HowToPlay.play(app, func(): pass, true)
		"Rules":
			close()
			ParchDialog.open(app, GameRules.SCENE)
		"Tuts":
			close()
			ParchDialog.open(app, TutorialMessages.SCENE)
		"Reset":
			ConfirmDialog.ask(app, "Start a new run? Your inventory and visits will be cleared.", func():
				close()
				app.new_game())
