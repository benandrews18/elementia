## Startup: the app with the player's saved run under the title screen
## (every launch opens on it, like the HTML game; Play -> Continue / New
## Game).
extends Control


func _ready() -> void:
	Progress.load_all()
	var app := App.new()
	add_child(app)
	app.show_welcome.call_deferred()  # after the app's own deferred end screen, so it's on top
