## The Lock-In reward (showLockInRewardModal(), #lockInRewardOverlay): a
## parchment "Bonus Dice" window, a "+" and the dice popping in left to right
## (or "No bonus dice this time"), "+1 Unknown Element" at the top
## breakpoint, and Nice. The corner "?" says why; the "?" square what an
## Unknown Element does. Nice or a tap outside runs on_done (the travel).
class_name LockInReward
extends Control

## The layout is ui/overlays/lock_in_reward.tscn (texts, styles, the "?"
## corner); this fills in the dice and stacks the lines that are showing.
const SCENE := "res://ui/overlays/lock_in_reward.tscn"

## Where the first line starts, and the parchment under Nice.
@export var top := 72.0
@export var bottom_pad := 30.0
## The corner "?" line's texts (%s: the Quarks; %d: the dice).
@export_multiline var why_none := "%s Quarks: below the first breakpoint\nNo bonus dice this time"
@export_multiline var why_dice := "%s Quarks: +%d dice at every station\nuntil the next board check"

var dice := 0
var unknown := false  # the top breakpoint's "?" element
var quarks := 0.0
var on_done: Callable


static func make() -> LockInReward:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Dim.gui_input.connect(func(ev): if Tap.tap(ev): _done())
	$Window/Nice.gui_input.connect(func(ev): if Tap.tap(ev): _done())
	$Window/Help.gui_input.connect(func(ev): if Tap.tap(ev):
		$Window/Why.visible = not $Window/Why.visible
		_layout())
	var w := minf(420, size.x - 40)
	var inner := w - 2 * 38
	$Window.size.x = w
	_dice_row(inner)
	var q := Util.thousands(int(quarks))
	$Window/Why.text = why_none % q if dice == 0 else why_dice % [q, dice]
	$Window/Why.visible = false
	$Window/Hint.visible = false
	$Window/Unknown.visible = unknown
	if unknown:  # "+1 Unknown Element" and its "?" square, centred together
		var t: Label = $Window/Unknown/Text
		var tw := t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.get_theme_font_size("font_size")).x
		var lx := (inner - tw - 10 - 34) / 2
		t.position.x = lx
		t.size.x = tw
		var sq := unknown_square(34)
		sq.position = Vector2(lx + tw + 10, 0)
		sq.mouse_filter = MOUSE_FILTER_STOP
		sq.gui_input.connect(func(ev): if Tap.tap(ev):
			$Window/Hint.visible = not $Window/Hint.visible
			_layout())
		$Window/Unknown.add_child(sq)
	var nice: Control = $Window/Nice
	var nt: Label = nice.get_node("Text")
	nice.size.x = nt.get_theme_font("font").get_string_size(nt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nt.get_theme_font_size("font_size")).x + 44
	nice.position.x = (w - nice.size.x) / 2
	_layout()



func _done() -> void:
	queue_free()
	on_done.call()


## "+" and the dice popping in left to right, centred (bounceIn, 150ms
## apart); or "No bonus dice this time".
func _dice_row(inner: float) -> void:
	var row: Control = $Window/Dice
	var plus: Label = $Window/Dice/Plus
	$Window/Dice/None.visible = dice == 0
	plus.visible = dice > 0
	if dice == 0:
		return
	var pw := plus.get_theme_font("font").get_string_size("+", HORIZONTAL_ALIGNMENT_LEFT, -1, plus.get_theme_font_size("font_size")).x
	var x := (inner - (pw + dice * 36 + 14 * dice)) / 2
	plus.position.x = x
	plus.size.x = pw
	x += pw + 14
	for i in dice:
		var c := Tok.icon("🎲", 36)
		c.position = Vector2(x, 4)
		c.pivot_offset = c.size / 2
		c.modulate.a = 0
		c.scale = Vector2(0.82, 0.82)
		var tw := c.create_tween()
		tw.tween_interval(i * 0.15)
		tw.tween_property(c, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(c, "scale", Vector2(1.05, 1.05), 0.22)
		tw.tween_property(c, "scale", Vector2.ONE, 0.18)
		row.add_child(c)
		x += 36 + 14


## Stacks the lines that are showing (a "?" opens or closes one), then sizes
## and centres the window to them.
func _layout() -> void:
	var why: bool = $Window/Why.visible
	var y := top + 44.0
	if why:
		$Window/Why.position.y = y + 16
		y += 16 + 13 * 1.4 * 2
	if unknown:
		y += 4.0 + (0.0 if why else 8.0)
		$Window/Unknown.position.y = y
		y += 34
		if $Window/Hint.visible:
			$Window/Hint.position.y = y + 8
			y += 8 + 13 * 1.4 * 2
	$Window/Nice.position.y = y + 16
	var h := y + 16 + 46 + bottom_pad
	var win: Control = $Window
	win.size.y = h
	win.position = Vector2((size.x - win.size.x) / 2, maxf(20, (size.y - HubBar.H - h) / 2))


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
