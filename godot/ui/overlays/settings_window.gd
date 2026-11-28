## Settings (the gear; #settings): How to Play, Game Rules, Tutorial
## Messages; Home (the title screen; the run stays saved); Reset (a new run,
## after asking); the version: 5 quick taps show (or hide) Dev Tools
## (dev.js). The layout is ui/overlays/settings.tscn.
class_name SettingsWindow
extends ParchDialog

const SCENE := "res://ui/overlays/settings.tscn"

var _taps := 0
var _last_tap := 0


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
	_sync_dev()


func _sync_dev() -> void:
	var on: bool = Progress.prefs.get("devUnlocked") == true
	$Window/Content/DevTools.visible = on
	$Window/Content/DevGap.visible = on


func _on_pressed(button: String) -> void:
	var app := App.current
	var on: Control = get_parent()  # its windows open where it is (over Quick Rules: the top layer)
	if button in ["HowToPlay", "Home"]:
		app.leave_quick_rules()
		on = app
	match button:
		"HowToPlay":  # Quick Rules again
			close()
			app.replay_tutorial()
		"Rules":
			close()
			ParchDialog.open(on, GameRules.SCENE)
		"Tuts":
			close()
			ParchDialog.open(on, TutorialMessages.SCENE)
		"Home":
			close()
			app.show_welcome()
		"DevTools":
			close()
			ParchDialog.open(on, DevTools.SCENE)
		"Version":  # five taps, each within 1.5s of the last
			var now := Time.get_ticks_msec()
			_taps = _taps + 1 if now - _last_tap < 1500 else 1
			_last_tap = now
			if _taps < 5:
				return
			_taps = 0
			Progress.prefs.devUnlocked = not Progress.prefs.get("devUnlocked", false)
			if not Progress.prefs.devUnlocked:
				Progress.prefs.devMode = false
			Progress.save_all()
			app.sync_dev()
			_sync_dev()
		"Reset":
			ConfirmDialog.ask(on, "Start a new run? Your inventory and visits will be cleared.", func():
				app.leave_quick_rules()
				close()
				app.new_game())
