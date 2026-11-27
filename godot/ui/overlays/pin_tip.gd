## The opening's pinning tip (#pinTip), over the To-Do List: a parchment
## window, Got it, and "✕ Hide" (never again).
class_name PinTip
extends Control

var on_done: Callable


const SCENE := "res://ui/overlays/pin_tip.tscn"  # its layout, texts and styles


static func open(on: Control, done: Callable) -> PinTip:
	var t: PinTip = Tok.make(SCENE)
	t.on_done = done
	t.size = on.size
	on.add_child(t)
	return t


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var win: ParchmentWindow = $Window
	var w := minf(420, size.x - 40)
	var h := win.size.y
	win.size.x = w
	win.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	# The first line and its pin, centred together.
	var line: Label = $Window/Line
	var tw := line.get_theme_font("font").get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line.get_theme_font_size("font_size")).x
	line.position.x = (w - tw - 24) / 2
	$Window/Pin.position.x = line.position.x + tw + 6
	var line2: Label = $Window/Line2  # ...and the second, with its 🔍
	var tw2 := line2.get_theme_font("font").get_string_size(line2.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line2.get_theme_font_size("font_size")).x
	line2.position.x = (w - tw2 - 24) / 2
	$Window/Glass.position.x = line2.position.x + tw2 + 6
	$Window/Hint.size.x = w - 2 * $Window/Hint.position.x
	var ok: Control = $Window/GotIt
	var ot: Label = ok.get_node("Text")
	ok.size.x = ot.get_theme_font("font").get_string_size(ot.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ot.get_theme_font_size("font_size")).x + 44
	ok.position.x = (w - ok.size.x) / 2
	ok.gui_input.connect(func(ev): if Tap.tap(ev): _done())
	$Window/Hide.gui_input.connect(func(ev): if Tap.tap(ev):
		Progress.hide_tip("pinTip")
		_done())


func _done() -> void:
	queue_free()
	on_done.call()
