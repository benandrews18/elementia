extends Node
# Temporary: where the Items screen's time goes (review 11).
func _ready() -> void:
	await get_tree().process_frame
	Progress.autosave = false
	Game.load_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://build/late.json")))
	var entries := []
	var seen := {}
	for e in Data.t("ENTRIES"):
		if not seen.has(e.name):
			seen[e.name] = true
			entries.append(e)
	for rep in 3:
		var holder := Control.new()
		add_child(holder)
		var tree := RefTree.new(RefTree.DARK, func(_p): pass)
		var t := Time.get_ticks_usec()
		var rows := []
		for e in entries:
			rows.append(RefRow.make())
		var t_make := Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		for i in rows.size():
			holder.add_child(rows[i])
		var t_add := Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		for i in rows.size():
			rows[i].fill(entries[i], 364, false, tree)
		var t_fill := Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		for e in entries:
			RefRow.search_text(e)
		var t_search := Time.get_ticks_usec() - t
		print("rows=%d make=%.1fms add=%.1fms fill=%.1fms search=%.1fms" % [rows.size(), t_make / 1000.0, t_add / 1000.0, t_fill / 1000.0, t_search / 1000.0])

	get_tree().quit()
