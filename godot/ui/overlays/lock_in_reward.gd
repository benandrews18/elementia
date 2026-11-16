## The Lock-In reward (showLockInRewardModal(), #lockInRewardOverlay): a
## parchment "Bonus Dice" window, a "+" and the dice popping in left to right
## (or "No bonus dice this time"), "+1 Unknown Element" at the top
## breakpoint, and Nice. The corner "?" says why; the "?" square what an
## Unknown Element does. Nice or a tap outside runs on_done (the travel).
class_name LockInReward
extends Control

var dice := 0
var unknown := false  # the top breakpoint's "?" element
var quarks := 0.0
var on_done: Callable
var _why := false
var _hint := false
var _box: Control
var _popped := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(10 / 255.0, 14 / 255.0, 20 / 255.0, 0.72)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: _done())
	add_child(dim)
	_build()


func _done() -> void:
	queue_free()
	on_done.call()


## Rebuilt when a "?" opens or closes its line (the window grows).
func _build() -> void:
	if is_instance_valid(_box):
		_box.queue_free()
	var w := minf(420, size.x - 40)
	var inner := w - 2 * 38
	var parts := []  # [control, height, gap above]
	var row := Control.new()  # .lockin-reward-dice: centred, gap 14, min height 44
	if dice == 0:
		var none := _center(Tok.label("No bonus dice this time", 15, Color("#7a5a3a"), 800), inner, 44)
		row.add_child(none)
	else:
		var items := [Tok.label("+", 36, Color("#3b2412"), 900)]
		for i in dice:
			items.append(Tok.icon("🎲", 36))
		var widths := items.map(func(c): return Tok.font(900).get_string_size("+", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x if c is Label else 36.0)
		var total := 0.0
		for x in widths:
			total += x
		total += 14 * (items.size() - 1)
		var x := (inner - total) / 2
		for i in items.size():
			var c: Control = items[i]
			c.size = Vector2(widths[i], 44 if c is Label else 36)
			c.position = Vector2(x, (44 - c.size.y) / 2)
			c.pivot_offset = c.size / 2
			if c is Label:
				c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			elif not _popped:  # bounceIn, 150ms apart
				c.modulate.a = 0
				var tw := c.create_tween()
				tw.tween_interval((i - 1) * 0.15)
				tw.tween_property(c, "modulate:a", 1.0, 0.1)
				c.scale = Vector2(0.82, 0.82)
				tw.parallel().tween_property(c, "scale", Vector2(1.05, 1.05), 0.22)
				tw.tween_property(c, "scale", Vector2.ONE, 0.18)
			row.add_child(c)
			x += widths[i] + 14
	_popped = true
	parts.append([row, 44.0, 0.0])
	if _why:
		var q := Util.thousands(int(quarks))
		var txt := ("%s Quarks: below the first breakpoint\nNo bonus dice this time" % q if dice == 0
			else "%s Quarks: +%d dice at every station\nuntil the next board check" % [q, dice])
		parts.append([_hint_label(txt, inner), 13 * 1.4 * 2, 8.0 + 8])
	if unknown:
		var line := Control.new()
		var t := Tok.label("+1 Unknown Element", 18, Color("#3b2412"), 900)
		var tw := Tok.font(900).get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var lx := (inner - tw - 10 - 34) / 2
		t.position = Vector2(lx, 0)
		t.size = Vector2(tw, 34)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(t)
		var sq := unknown_square(34)
		sq.position = Vector2(lx + tw + 10, 0)
		sq.mouse_filter = MOUSE_FILTER_STOP
		sq.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed:
			_hint = not _hint
			_build())
		line.add_child(sq)
		parts.append([line, 34.0, 4.0 + (0.0 if _why else 8.0)])
		if _hint:
			parts.append([_hint_label("Becomes any element at your station\nUse it from the Convert menu", inner), 13 * 1.4 * 2, 8.0])
	var nice := RollPopup._pill_button("Nice", Vector2(Tok.font(800).get_string_size("Nice", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44, 46))
	nice.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: _done())
	parts.append([nice, 46.0, 12.0 + 4])
	var y := 72.0
	for p in parts:
		y += p[2]
		var c: Control = p[0]
		c.position = Vector2(38 + ((inner - c.size.x) / 2 if c == nice else 0.0), y)
		if c != nice:
			c.size = Vector2(inner, p[1])
		y += p[1]
	var h := y + 30
	_box = ConfirmDialog.window(Vector2(w, h), "Bonus Dice")
	_box.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	add_child(_box)
	for p in parts:
		_box.add_child(p[0])
	var why := TextureRect.new()  # the mat's help sprite, lower-right corner
	why.texture = load("res://assets/ui/btn_help.webp")
	why.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	why.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	why.size = Vector2(34, 34)
	why.position = Vector2(w + 14 - 34, h + 14 - 34)
	why.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed:
		_why = not _why
		_build())
	_box.add_child(why)


func _hint_label(text: String, inner: float) -> Label:
	var l := Tok.label(text, 13, Color("#7a5a3a"), 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(inner, 13 * 1.4 * 2)
	return l


static func _center(l: Label, w: float, h: float) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(w, h)
	return l


## emptyElSquareHTML(): an element square with a "?" (white face, 3px black
## border) and a solid black suit badge in its corner.
static func unknown_square(px: float) -> Control:
	var sq := Panel.new()
	sq.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 7, 3, Color.BLACK))
	sq.size = Vector2(px, px)
	var q := _center(Tok.label("?", int(round(px * 0.55)), Color("#181614"), 800), px, px)
	q.mouse_filter = MOUSE_FILTER_IGNORE
	sq.add_child(q)
	var b := Panel.new()
	var bp := roundf(px * 0.42)
	b.add_theme_stylebox_override("panel", Tok.box(Color.BLACK, bp / 2))
	b.size = Vector2(bp, bp)
	b.position = Vector2(px - bp - 1, 1)
	b.mouse_filter = MOUSE_FILTER_IGNORE
	sq.add_child(b)
	return sq
