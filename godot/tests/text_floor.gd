## The minimum text size (step 20d, the user 2026-11-26: 11 px; 12 was the first ask,
## then 11): every visible text drawn smaller than MIN on screen (its font
## size times its scale, so a shrunk card counts) -> "size  text  path".
extends RefCounted

const MIN := 11.0


static func small(root: Node) -> Array:
	var out := []
	_walk(root, out)
	return out


static func _walk(n: Node, out: Array) -> void:
	if n is CanvasItem and not n.visible:
		return
	if (n is Label or n is RichTextLabel or n is Button or n is LineEdit) and n.get("text") and n.is_visible_in_tree() and n.modulate.a > 0.05:
		var key := "normal_font_size" if n is RichTextLabel else "font_size"
		var px: float = n.get_theme_font_size(key) * absf(n.get_global_transform_with_canvas().get_scale().y)
		var r: Rect2 = n.get_global_rect()
		if px < MIN - 0.25 and r.size.x > 0 and r.end.y > 0 and r.position.y < 844 and r.end.x > 0 and r.position.x < 390:
			out.append("%.1f  %s  %s" % [px, String(n.text).replace("\n", " ").left(30), n.get_path()])
	for c in n.get_children():
		_walk(c, out)
