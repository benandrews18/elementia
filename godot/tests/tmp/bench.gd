extends Node
# Temporary: times one state change with each screen/panel open (review pass 4).
func _ready() -> void:
	await get_tree().process_frame
	Progress.autosave = false
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://build/late.json")))
	var app := App.new()
	app.size = Vector2(390, 844)
	add_child(app)
	await get_tree().process_frame
	for p in ["", "drawer", "market", "todo", "codex"]:
		if p != "":
			app.open_panel(p)
		await get_tree().process_frame
		var best := 1e9
		for i in 5:
			var t := Time.get_ticks_usec()
			Game._changed()
			best = minf(best, Time.get_ticks_usec() - t)
			await get_tree().process_frame
		var t2 := Time.get_ticks_usec()
		Progress.autosave = true
		Progress.save_all()
		var save_us := Time.get_ticks_usec() - t2
		Progress.autosave = false
		print("panel=%s change_ms=%.1f save_ms=%.1f nodes=%d" % [p if p else "map", best / 1000.0, save_us / 1000.0, get_tree().get_node_count()])
	Game.ctx.current = Game.state.lastStation; Game.ctx.screen = "station"; app.close_panel()
	await get_tree().process_frame
	var t3 := Time.get_ticks_usec()
	Game._changed()
	print("station change_ms=%.1f nodes=%d" % [(Time.get_ticks_usec() - t3) / 1000.0, get_tree().get_node_count()])
	get_tree().quit()
