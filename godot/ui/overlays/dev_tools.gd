## Dev Tools (#settingsDev; Settings, once unlocked by 5 taps on the
## version): the Developer mode switch (the 🛠 Dev Panel), Restore my real
## save (when a dev run kept one), Clear Cache (everything gone, a fresh
## title screen) and History. The layout is ui/overlays/dev_tools.tscn.
## shortcut: Clear Cache isn't red like the HTML's .setting-row.warn.
class_name DevTools
extends ParchDialog

const SCENE := "res://ui/overlays/dev_tools.tscn"


func _ready() -> void:
	super()
	$Window/Content/DevMode.on = Progress.prefs.get("devMode") == true
	$Window/Content/DevMode.toggled.connect(func(on):
		Progress.prefs.devMode = on
		Progress.save_all()
		App.current.sync_dev())
	$Window/Content/Restore.visible = Dev.has_backup()
	pressed.connect(_on_pressed)


func _on_pressed(button: String) -> void:
	var app := App.current
	match button:
		"Restore":
			ConfirmDialog.ask(app, "Replace the current run with your real save from before the Dev Panel changed it?", func():
				close()
				Dev.restore())
		"ClearCache":
			ConfirmDialog.ask(app, "Reset the game completely? This clears your save, all settings, and every tutorial message, then reloads to a fresh Main Menu. This can't be undone.", func():
				close()
				Dev.clear_all())
		"History":
			close()
			HistoryWindow.show_on(app)
