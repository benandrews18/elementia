## The run: `state` (same JSON shape as the HTML game's state, so the same
## save loads in both), the globals outside it that rules read (`ctx`), and
## the player actions. Screens call actions and redraw on state_changed.
## Actions are ported in M1, named like the JS functions in snake_case
## (goStation -> go_station); tests/parity.gd finds them by that name.
extends Node

signal state_changed

var state: Dictionary = {}
var ctx: Dictionary = {"current": null, "screen": "map", "travelPromptFor": null,
	"selectedMapStation": null, "lockInCommitted": false}

func load_snapshot(s: Dictionary) -> void:
	state = s.get("state", s).duplicate(true)
	if s.has("ctx"):
		ctx = s.ctx.duplicate(true)
	state_changed.emit()

func snapshot() -> Dictionary:
	return {"state": state, "ctx": ctx}
