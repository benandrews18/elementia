extends Node
# Temporary: does dragging on an Items row scroll the list, and does lifting tap it? (review 7)
func _ready() -> void:
	await get_tree().process_frame
	Progress.autosave = false
	Input.emulate_touch_from_mouse = true
	print("touchscreen=", DisplayServer.is_touchscreen_available())
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mat_visit18.json")))
	TodoTray.expanded.clear()
	var app := App.new()
	add_child(app)
	await get_tree().process_frame
	app.open_panel("codex")
	for i in 5:
		await get_tree().process_frame
	var scr: ItemsScreen = app._panel_node
	var row: RefRow = scr._rows[3]
	var p := row.get_global_rect().get_center()
	var nm := row.item
	var scroll: ScrollContainer = scr.get_node("Scroll")
	var before := scroll.scroll_vertical
	_mouse(p, true)
	for k in 12:
		await get_tree().process_frame
		var m := InputEventMouseMotion.new()
		m.device = InputEvent.DEVICE_ID_MOUSE; m.position = p - Vector2(0, 8 * (k + 1)); m.global_position = m.position
		m.relative = Vector2(0, -8); m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
	await get_tree().process_frame
	_mouse(p - Vector2(0, 96), false)
	for i in 3:
		await get_tree().process_frame
	print("drag on %s: scrolled %d -> %d, row opened: %s" % [nm, before, scroll.scroll_vertical, TodoTray.expanded.has("refroot/" + nm)])
	TodoTray.expanded.clear()
	scr._redraw()
	for i in 3:
		await get_tree().process_frame
	var r2: RefRow = scr._rows[2]
	var p2 := r2.get_global_rect().get_center()
	var nm2 := r2.item
	print("row2 at ", p2, " viewport ", get_viewport().get_visible_rect().size)
	_mouse(p2, true)
	await get_tree().process_frame
	_mouse(p2, false)
	for i in 3:
		await get_tree().process_frame
	print("plain tap on %s: opened %s" % [nm2, TodoTray.expanded.has("refroot/" + nm2)])
	get_tree().quit()

func _mouse(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_MOUSE; e.position = p; e.global_position = p; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)

func _probe(n: Node, p: Vector2) -> void:
	for c in n.get_children():
		if c is Control and c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p):
			print("  under: ", c.get_path(), " filter=", c.mouse_filter)
		_probe(c, p)
