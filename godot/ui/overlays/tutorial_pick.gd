## How to Play (decisions 2026-11-27): the Guided Tutorial (Professor Mouse
## plays a real game with you) or Quick Rules (a tour of every part).
## From the Play menu it replays one; on the first New Game it's asked once,
## with "Just play" too and no ✕, and whatever is picked goes on into that
## new game (`then`: its opening). The layout is
## ui/overlays/tutorial_pick.tscn.
class_name TutorialPick
extends ParchDialog

const SCENE := "res://ui/overlays/tutorial_pick.tscn"

var first := false
var then := Callable()


static func show_on(on: Control, first_game := false, done := Callable()) -> TutorialPick:
	var d: TutorialPick = Tok.make(SCENE)
	d.first = first_game
	d.then = done
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	if first:  # a choice to make: nothing closes it
		$Window/Close.free()
	else:
		$Window/Content/Play.free()
	super()
	pressed.connect(_on_pressed)


func _on_pressed(button: String) -> void:
	var app := App.current
	if first:
		Progress.prefs.tutorialSeen = true  # asked once (the user, 2026-11-27)
		Progress.save_all()
	close()
	match button:
		"Guided":
			if first:
				then.call()
				app.tutorial.start()
			else:
				app.replay_tutorial()
		"Quick":
			QuickRules.begin(app, then)
		"Play":
			HowToPlay.play(app, then)
