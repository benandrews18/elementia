## A finished Market row's reward (openBingoClearOverlay()): "Row complete!"
## on the banner, "+n" and a "?" square per row, Nice (on_done collects it).
class_name RowReward
extends Control

var rows := 1
var on_done: Callable


## Its layout, texts and styles: ui/overlays/row_reward.tscn.
static func make(n: int, done: Callable) -> RowReward:
	var r: RowReward = Tok.make("res://ui/overlays/row_reward.tscn")
	r.rows = n
	r.on_done = done
	return r


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var win: ParchmentWindow = $Window
	var w := minf(420, size.x - 40)
	var h := win.size.y
	win.size.x = w
	win.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	if rows > 1:  # a "?" per Market square made (the user, 2026-11-26)
		$Window.title = "      %d Market items made!" % rows
	# "+n" and a "?" square per row, centred together.
	var plus: Label = $Window/Plus
	plus.text = "+%d" % rows
	var pw := plus.get_theme_font("font").get_string_size(plus.text, HORIZONTAL_ALIGNMENT_LEFT, -1, plus.get_theme_font_size("font_size")).x
	var total := pw + 10 + rows * 48 + (rows - 1) * 8
	var x := (w - total) / 2
	plus.position.x = x
	x += pw + 10
	for i in rows:
		var sq := LockInReward.unknown_square(48)
		sq.position = Vector2(x, 0)
		sq.mouse_filter = MOUSE_FILTER_STOP  # a tap: what an Unknown Element is (the user, 2026-11-27)
		sq.set_meta("cmp", "row:unknown")
		sq.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.show_tip("unknown"))
		$Window/Squares.add_child(sq)
		x += 56
	var nice: Control = $Window/Nice
	var nt: Label = nice.get_node("Text")
	nice.size.x = nt.get_theme_font("font").get_string_size(nt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nt.get_theme_font_size("font_size")).x + 44
	nice.gui_input.connect(func(ev): if Tap.tap(ev):
		queue_free()
		on_done.call())
