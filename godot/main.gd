## Startup: the app with the player's saved run, or, with no save, a new
## run's opening.
extends Control


func _ready() -> void:
	Progress.load_all()
	var app := App.new()
	add_child(app)
	# Also a run still at visit 0: New Game saves before the capstone is chosen.
	if not Progress.has_save() or int(Game.state.get("visits", 0)) == 0:
		app.new_game.call_deferred()
