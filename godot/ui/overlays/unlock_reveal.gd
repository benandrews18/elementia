## "New Items Unlocked!" (#unlockReveal, maybeShowUnlockReveal()): after a
## capstone's card closes, the items it opened up pop onto a dark screen in
## full colour, one after another, under the title and "<capstone> opened up
## N new items". A tap after 2s ("Tap to continue" fades in then) closes it.
class_name UnlockReveal
extends Control

const LOCK := 2.0
var _ready_at := 0


static func show_on(on: Control, cap: String, names: Array) -> UnlockReveal:
	var r := UnlockReveal.new()
	r.size = on.size
	on.add_child(r)
	r._build(cap, names)
	return r


func _build(cap: String, names: Array) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_ready_at = Time.get_ticks_msec()
	var dim := ColorRect.new()
	dim.color = Color(4 / 255.0, 6 / 255.0, 10 / 255.0, 0.9)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	# The cards: rows of up to 3, 104 wide, centred; the text above and below.
	var cols := mini(3, names.size())
	var cw := 104.0
	var ch := cw * 1.4
	var gap := 12.0
	var rows := ceili(names.size() / float(cols))
	var grid_h := rows * ch + (rows - 1) * gap
	var top := (size.y - grid_h) / 2 - 20
	var title := Tok.label("New Items Unlocked!", 30, Color("#ffe08a"), 900)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(16, top - 96)
	title.size = Vector2(size.x - 32, 40)
	add_child(title)
	var e = Catalog.entry(cap)
	var line := "%s opened up %s" % [cap, "a new item" if names.size() == 1 else "%d new items" % names.size()]
	var sub := Tok.label(line, 15, Color(1, 1, 1, 0.85), 700)
	var tw := sub.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var icon := Tok.icon(e.emoji if e else "", 22)
	icon.position = Vector2((size.x - tw - 28) / 2, top - 50)
	add_child(icon)
	sub.clip_text = true  # before its size (Tok.centre_name)
	sub.position = Vector2(icon.position.x + 28, top - 50)
	sub.size = Vector2(tw + 2, 22)
	add_child(sub)
	for i in names.size():
		var row := i / cols
		var in_row := mini(cols, names.size() - row * cols)
		var x0 := (size.x - (in_row * cw + (in_row - 1) * gap)) / 2
		var card := ItemCard.make(names[i])
		card.size = Vector2(cw, ch)
		card.position = Vector2(x0 + (i % cols) * (cw + gap), top + row * (ch + gap))
		card.pivot_offset = card.size / 2
		card.scale = Vector2.ZERO
		card.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(card)
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.4).set_delay(0.3 + i * 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tap := Tok.label("Tap to continue", 13, Color(1, 1, 1, 0.65), 700)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.position = Vector2(16, top + grid_h + 28)
	tap.size = Vector2(size.x - 32, 18)
	tap.modulate.a = 0
	add_child(tap)
	tap.create_tween().tween_property(tap, "modulate:a", 1.0, 0.3).set_delay(LOCK)


func _gui_input(ev: InputEvent) -> void:
	if Tap.tap(ev) and Time.get_ticks_msec() - _ready_at >= LOCK * 1000 / Engine.time_scale:
		queue_free()
