## "Are you sure?" (askConfirm(), #confirmBox): the screen dims; a parchment
## window (panel_parchment 9-slice) with the title on a wooden banner, the
## message, and "Yes, do it" / Cancel. on_yes runs on Yes; Cancel or a tap
## outside just closes it.
class_name ConfirmDialog
extends Control

## The layout is ui/overlays/confirm.tscn (title, button texts, gaps, fonts);
## this fills in the message and sizes the window to it.
const SCENE := "res://ui/overlays/confirm.tscn"

var message: String
var on_yes: Callable
var title := ""  # "" keeps the scene's title
## Parchment below the buttons.
@export var bottom_pad := 49.0


## Shows the dialog over `on` (the app).
static func ask(on: Control, msg: String, yes: Callable) -> ConfirmDialog:
	var d: ConfirmDialog = load(SCENE).instantiate()
	d.message = msg
	d.on_yes = yes
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Dim.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	var win: ParchmentWindow = $Window
	if title != "":
		win.title = title
	var content: VBoxContainer = $Window/Content
	var w := minf(420, size.x - 40)
	var inner := w - 2 * content.position.x
	# The message wraps at 1.5 line height (its height from the font: a label
	# only knows it once laid out).
	var msg: Label = $Window/Content/Message
	msg.text = message
	var f := msg.get_theme_font("font")
	var px := msg.get_theme_font_size("font_size")
	msg.add_theme_constant_override("line_spacing", int(round(px * 1.5 - f.get_height(px))))
	var lines := f.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, inner, px).y / f.get_height(px)
	msg.custom_minimum_size = Vector2(inner, roundf(lines) * px * 1.5)
	# Each button fits its text with 22px either side.
	for b in [$Window/Content/Buttons/Yes, $Window/Content/Buttons/Cancel]:
		var l: Label = b if b is Label else b.get_node("Text")
		b.custom_minimum_size = Vector2(l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 44, 46)
	$Window/Content/Buttons/Yes.gui_input.connect(func(ev): if Tap.tap(ev):
		queue_free()
		on_yes.call())
	$Window/Content/Buttons/Cancel.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	# The content's height from its parts (a wrapping label reports a huge minimum).
	var content_h: float = msg.custom_minimum_size.y + content.get_theme_constant("separation") + $Window/Content/Buttons.get_combined_minimum_size().y
	content.size = Vector2(inner, content_h)
	var h := content.position.y + content_h + bottom_pad
	win.size = Vector2(w, h)
	win.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
