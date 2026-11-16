## Startup. For the M3 proof of concept: the Display Mat, with the player's
## saved run if there is one, else a demo run (a recorded run's turn-18 mat).
extends Control


func _ready() -> void:
	Progress.load_all()
	if not Progress.has_save():
		Progress.autosave = false  # the demo board never becomes the player's saved run
		Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_mat.json")))
	add_child(DisplayMatScreen.new())
