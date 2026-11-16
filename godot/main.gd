## Startup: the app with the player's saved run, or, with no save, a new
## run's opening.
extends Control


func _ready() -> void:
	Progress.load_all()
	var app := App.new()
	add_child(app)
	if not Progress.has_save():
		app.new_game.call_deferred()
