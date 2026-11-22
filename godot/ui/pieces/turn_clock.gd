## The turn clock on the map (turnClockSVG(), .clockpill): a 24-round dial
## in a brass rim, 24 at the top. The check rounds (every MAT_CHECK_EVERY)
## are numbered, the others are ticks; the current one is marked in gold, a
## shaded slice covers the rounds gone, and the hand points at this round.
## The round number sits in the middle (the user, 2026-11-21); past round
## 24 (Overtime) the hand keeps going round and the middle reads OT.
## shortcut: no tap-for-info window (openClockInfo()) yet, add it when the
## clock gets its info.
class_name TurnClock
extends Control

const SIZE := 96.0  # the rim; the dial is 68 inside it
const INK := Color("#2a2018")
const GOLD := Color("#e2b25a")

var visits := 0


static func make(v: int) -> TurnClock:
	var c := TurnClock.new()
	c.visits = v
	c.size = Vector2(SIZE, SIZE)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	var rim := TextureRect.new()
	rim.texture = load("res://assets/ui/clock_rim.webp")
	rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rim.size = c.size
	rim.show_behind_parent = true
	rim.mouse_filter = MOUSE_FILTER_IGNORE
	c.add_child(rim)
	var n := int(Data.t("RUN_COMPLETE_VISIT"))
	var mid := Tok.label("OT" if v > n else str(v), 18, INK, 900)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mid.clip_text = true  # before size (Tok.centre_name)
	mid.size = Vector2(28, 24)
	mid.position = (c.size - mid.size) / 2
	c.add_child(mid)
	return c


func _draw() -> void:
	var n := int(Data.t("RUN_COMPLETE_VISIT"))
	var every := int(Data.t("MAT_CHECK_EVERY"))
	var k := 68.0 / 100.0  # the HTML's 100-unit viewBox, drawn 68px
	var o := size / 2
	var at := func(i: float, r: float) -> Vector2:
		var t := i / n * TAU
		return o + Vector2(sin(t), -cos(t)) * r * k
	var cur := ((visits - 1) % n) + 1 if visits > 0 else 0
	draw_circle(o, 48 * k, Color("#f4ead2"))
	if cur == n:
		draw_circle(o, 46.5 * k, Color("#c9b07a"))
	elif cur > 0:  # the rounds gone: a slice from the top round to the hand
		var pts := PackedVector2Array([o])
		for s in 33:
			pts.append(at.call(cur * s / 32.0, 46.5))
		draw_colored_polygon(pts, Color("#c9b07a"))
	draw_arc(o, 48 * k, 0, TAU, 64, GOLD, 3.5 * k, true)
	var f := Tok.font(900)
	for i in range(1, n + 1):
		if i % every == 0:
			var p: Vector2 = at.call(i, 36)
			if i == cur:
				draw_circle(p, 10.5 * k, GOLD)
			var txt := str(i)
			var fs := int(round(15 * k))
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, p + Vector2(-tw.x / 2, f.get_ascent(fs) - tw.y / 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
		else:
			if i == cur:
				draw_circle(at.call(i, 42), 5.5 * k, GOLD)
			draw_line(at.call(i, 39), at.call(i, 45), Color("#6b5a3a"), 2.5 * k, true)
	if cur:  # the hand, from outside the round number to the round
		var tip: Vector2 = at.call(cur, 25 if cur % every == 0 else 34)
		var dir := (tip - o).normalized()
		draw_line(o + dir * 13, tip, INK, 4 * k, true)
	draw_circle(o, 12.5, Color("#f4ead2"))  # behind the round number
