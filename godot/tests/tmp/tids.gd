extends Node
func _ready() -> void:
	var miss := []
	for t in Trophies.all():
		if Data.icon(t.icon) == null and not miss.has(t.icon):
			miss.append(t.icon)
	for e in ["🕓", "⧉"]:
		if Data.icon(e) == null: miss.append(e)
	print("missing=", " ".join(miss), " | ", " ".join(miss.map(func(e): return "-".join(Array(e.to_utf32_buffer().to_int32_array()).map(func(c): return "%x" % c)))))
	get_tree().quit()
