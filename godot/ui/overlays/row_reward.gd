## A finished Market row's reward (openBingoClearOverlay()): "Row complete!"
## on the banner, "+n" and a "?" square per row, Nice (on_done collects it).
class_name RowReward
extends Control

var rows := 1
var on_done: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ConfirmDialog.dim(self)
	var w := minf(420, size.x - 40)
	var h := 59 + 26 + 14 + 48 + 18 + 46 + 30
	var box := ConfirmDialog.window(Vector2(w, h), "Row complete!")
	box.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	add_child(box)
	var t := Tok.label("Here's your reward" if rows == 1 else "%d rows complete" % rows, 15, Color("#5e4026"), 400)
	t.position = Vector2(38, 59)
	box.add_child(t)
	var plus := Tok.label("+%d" % rows, 24, Color("#3b2412"), 900)
	var pw := Tok.font(900).get_string_size(plus.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var total := pw + 10 + rows * 48 + (rows - 1) * 8
	var x := (w - total) / 2
	plus.position = Vector2(x, 59 + 26 + 14 + 8)
	box.add_child(plus)
	x += pw + 10
	for i in rows:
		var sq := LockInReward.unknown_square(48)
		sq.position = Vector2(x, 59 + 26 + 14)
		box.add_child(sq)
		x += 56
	var nice := RollPopup._pill_button("Nice!", Vector2(Tok.font(800).get_string_size("Nice!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44, 46))
	nice.position = Vector2(38, h - 30 - 46)
	nice.gui_input.connect(func(ev): if ConvertTray._tap(ev):
		queue_free()
		on_done.call())
	box.add_child(nice)
