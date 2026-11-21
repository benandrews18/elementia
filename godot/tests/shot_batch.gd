## Shoots many tests/shot_states.gd states in one Godot run (tools/shot_diff.py):
##   G --path godot --fixed-fps 60 --disable-vsync res://tests/shot_batch.tscn -- --plan C:/x/plan.json
## plan.json: [{"state", "save" (res:// path), "out" (png path)}]. Each state
## gets the same start as a run of its own (shot.gd): its save loaded, the
## prefs, context and static UI state put back, a fresh screen, a 1.2s settle
## (game time: --fixed-fps makes that 72 frames, drawn as fast as it can).
## Prints "shot_batch: N saved" when done; a failed state stops the batch.
extends Node

const WAIT := 1.2


func _ready() -> void:
	Progress.autosave = false  # never touch the player's files
	OS.low_processor_usage_mode = false  # every frame drawn, so frame_post_draw fires
	Progress.prefs.everUnlockedMatCollections = Mat.collections().map(func(c): return c.id)
	var prefs: Dictionary = Progress.prefs.duplicate(true)
	var ctx: Dictionary = Game.ctx.duplicate(true)
	get_window().size = Vector2i(390, 844)
	var plan: Array = JSON.parse_string(FileAccess.get_file_as_string(load("res://tests/shot.gd")._args().plan))
	var n := 0
	for job in plan:
		print("state " + job.state)  # so an error below can be traced to its state
		# A clean start: what one state leaves behind must not reach the next.
		Progress.prefs = prefs.duplicate(true)
		Game.ctx = ctx.duplicate(true)
		TodoTray.expanded = {}
		TodoTray.hint_open = false
		ItemsScreen.query = ""
		ItemsScreen.sort_mode = 0
		Engine.time_scale = 1.0
		Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string(job.save)))
		var screen: Control = load("res://tests/shot_states.gd").new()
		screen.state = job.state
		add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for i in 3:
			await get_tree().process_frame
		await get_tree().create_timer(WAIT).timeout
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(job.out) != OK:
			print("FAILED to save " + job.out)
			get_tree().quit(1)
			return
		n += 1
		screen.free()
		await get_tree().process_frame
	print("shot_batch: %d saved" % n)
	get_tree().quit(0)
