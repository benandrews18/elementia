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
var yes_text := ""  # "" keeps the scene's
var no_text := ""
var on_no := Callable()  # Cancel (not a tap outside)
var check_text := ""  # a tick box above the buttons ("Don't ask again")
var checked := false
## Parchment below the buttons.
@export var bottom_pad := 49.0


## Shows the dialog over `on` (the app); opts sets the vars above (title,
## yes_text, no_text, on_no, check_text).
static func ask(on: Control, msg: String, yes: Callable, opts := {}) -> ConfirmDialog:
	var d: ConfirmDialog = load(SCENE).instantiate()
	d.message = msg
	d.on_yes = yes
	for k in opts:
		d.set(k, opts[k])
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
	var plain := RegEx.create_from_string("[{][^{}]+[}]").sub(message, "MM", true)  # an inline icon is about two letters wide
	var lines := f.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, inner, px).y / f.get_height(px)
	msg.custom_minimum_size = Vector2(inner, roundf(lines) * px * 1.5)
	if plain != message:  # {emoji} tokens: icons inline (ParchDialog.emojify), the same font and size
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.scroll_active = false
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.mouse_filter = MOUSE_FILTER_IGNORE
		rt.add_theme_font_override("normal_font", f)
		rt.add_theme_font_size_override("normal_font_size", px)
		rt.add_theme_color_override("default_color", msg.get_theme_color("font_color"))
		rt.add_theme_constant_override("line_separation", int(round(px * 1.5 - f.get_height(px))))
		rt.text = ParchDialog.emojify(message, px + 2)
		rt.custom_minimum_size = msg.custom_minimum_size
		rt.set_meta("cmp", "confirm:message")
		content.add_child(rt)
		content.move_child(rt, msg.get_index())
		msg.visible = false
	if yes_text != "":
		$Window/Content/Buttons/Yes/Text.text = yes_text
	if no_text != "":
		$Window/Content/Buttons/Cancel.text = no_text
	var check_h := 0.0
	if check_text != "":
		var row := _check_row()
		content.add_child(row)
		content.move_child(row, $Window/Content/Buttons.get_index())
		check_h = row.custom_minimum_size.y + content.get_theme_constant("separation")
	# Each button fits its text with 22px either side.
	for b in [$Window/Content/Buttons/Yes, $Window/Content/Buttons/Cancel]:
		var l: Label = b if b is Label else b.get_node("Text")
		b.custom_minimum_size = Vector2(l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 44, 46)
	$Window/Content/Buttons/Yes.gui_input.connect(func(ev): if Tap.tap(ev):
		queue_free()
		on_yes.call())
	$Window/Content/Buttons/Cancel.gui_input.connect(func(ev): if Tap.tap(ev):
		queue_free()
		if on_no.is_valid():
			on_no.call())
	# The content's height from its parts (a wrapping label reports a huge minimum).
	var content_h: float = msg.custom_minimum_size.y + content.get_theme_constant("separation") + check_h + $Window/Content/Buttons.get_combined_minimum_size().y
	content.size = Vector2(inner, content_h)
	var h := content.position.y + content_h + bottom_pad
	win.size = Vector2(w, h)
	win.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))


## The tick box and its words; the whole row toggles it.
func _check_row() -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 26)
	row.set_meta("cmp", "confirm:check")
	var box := Panel.new()
	box.size = Vector2(24, 24)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(box)
	var tick := Tok.tick(Tok.OK, 18)
	tick.position = Vector2(3, 3)
	box.add_child(tick)
	var l := Tok.label(check_text, 15, Color("#5e4026"), 700)
	l.position = Vector2(34, 1)
	row.add_child(l)
	var show := func():
		box.add_theme_stylebox_override("panel", Tok.box(Color("#fffaf0"), 6, 2, Color("#8a6a48")))
		tick.visible = checked
	show.call()
	row.gui_input.connect(func(ev): if Tap.tap(ev):
		checked = not checked
		show.call())
	return row
