## Every exported icon in a grid with its key, to check they all import.
extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#0f2733")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.position = Vector2(6, 6)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	for key in Data.icons:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(40, 56)
		var tex := TextureRect.new()
		tex.texture = Data.icon(key)
		tex.custom_minimum_size = Vector2(40, 40)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(tex)
		var l := Label.new()
		l.text = key.trim_prefix("__").trim_suffix("__").left(6).to_lower()
		l.add_theme_font_size_override("font_size", 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		grid.add_child(box)
