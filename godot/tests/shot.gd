## Screenshot runner (PLAN.md, "Screen comparison"). Opens one screen,
## optionally with a save loaded, saves a PNG of it and quits:
##   Godot_console.exe --path godot res://tests/shot.tscn -- --screen res://tests/icon_sheet.gd --out C:/x/shot.png [--save step.json] [--scale 2]
## --screen: a .tscn, or a .gd script extending Control.
## --save: a JSON file holding {state, ctx} (a golden step's "before") or a
## bare HTML-game save. Needs a normal run (not --headless): headless
## can't draw.
extends Node

func _ready() -> void:
	var a := _args()
	Progress.autosave = false  # never touch the player's files
	# As html_shot.mjs: every collection already found, so no "New collection!".
	Progress.prefs.everUnlockedMatCollections = Mat.collections().map(func(c): return c.id)
	if a.has("save"):
		Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string(a.save)))
	var res = load(a.get("screen", "res://main.tscn"))
	var screen: Node = res.instantiate() if res is PackedScene else res.new()
	add_child(screen)
	if screen is Control:
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scale := float(a.get("scale", "1"))
	get_window().size = Vector2i(roundi(390 * scale), roundi(844 * scale))
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if a.has("rects"):  # every node tagged with meta "cmp": [x, y, w, h] in 390-wide design pixels
		var rects := {}
		var walk := func(n: Node, self_ref: Callable) -> void:
			if n is Control and n.has_meta("cmp") and n.is_visible_in_tree():
				var r: Rect2 = n.get_global_rect()
				rects[n.get_meta("cmp")] = [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]
			for c in n.get_children():
				self_ref.call(c, self_ref)
		walk.call(screen, walk)
		var f := FileAccess.open(a.rects, FileAccess.WRITE)
		f.store_string(JSON.stringify(rects))
		f.close()
	var out: String = a.get("out", "user://shot.png")
	var err := get_viewport().get_texture().get_image().save_png(out)
	print("saved " + out if err == OK else "FAILED to save %s (%d)" % [out, err])
	get_tree().quit(0 if err == OK else 1)

static func _args() -> Dictionary:
	var a := {}
	var list := OS.get_cmdline_user_args()
	for i in range(0, list.size() - 1, 2):
		a[list[i].trim_prefix("--")] = list[i + 1]
	return a
