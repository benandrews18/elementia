## The redraw budget (review 2026-11-27, fix 6): one state change with each
## screen and panel open, on a late-run save (tests/fixtures/late_run.json),
## best of 5. A budget about twice the desktop time when it was set: a
## phone is 3-5x slower, so a rebuild that grows past it shows as a stutter.
## Run by tools/check.py full.
extends Node

const BUDGET_MS := {"map": 20.0, "station": 40.0, "drawer": 30.0, "market": 35.0, "todo": 20.0, "codex": 35.0}


func _ready() -> void:
	await get_tree().process_frame
	Progress.autosave = false
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/late_run.json")))
	var app := App.new()
	app.size = Vector2(390, 844)
	add_child(app)
	await get_tree().process_frame
	var failed := 0
	for where in ["map", "drawer", "market", "todo", "codex", "station"]:
		if where == "station":
			app.close_panel()
			Game.ctx.current = Game.state.lastStation
			Game.ctx.screen = "station"
			Game.state_changed.emit()
		elif where != "map":
			app.open_panel(where)
		await get_tree().process_frame
		var best := 1e9
		for i in 5:
			var t := Time.get_ticks_usec()
			Game.state_changed.emit()
			best = minf(best, (Time.get_ticks_usec() - t) / 1000.0)
			await get_tree().process_frame
		var ok: bool = best <= BUDGET_MS[where]
		failed += 0 if ok else 1
		print("%s  %s %.1f ms (budget %.0f, %d nodes)" % ["ok  " if ok else "FAIL", where, best, BUDGET_MS[where], get_tree().get_node_count()])
	print("perf: PASS" if failed == 0 else "perf: %d over budget" % failed)
	get_tree().quit()
