extends Node
func _ready() -> void:
	var ps: PackedScene = load("res://ui/pieces/ref_row.tscn")
	for rep in 3:
		var t := Time.get_ticks_usec()
		var a := []
		for i in 99:
			a.append(ps.instantiate())
		var t1 := Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		for i in 99:
			a[i] = load("res://ui/pieces/ref_row.tscn")
		var t2 := Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		for i in 99:
			var p := Panel.new(); var l := Label.new(); l.text = "Hello"; p.add_child(l); a[i] = p
		print("instantiate=%.1fms load=%.1fms plain=%.1fms" % [t1 / 1000.0, t2 / 1000.0, (Time.get_ticks_usec() - t) / 1000.0])
	get_tree().quit()
