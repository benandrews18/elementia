## A settings row (.setting-row): an icon, a label (and a smaller line
## under it), and at the right either a button (Open, View) or a switch.
## Two looks share this script: ui/pieces/setting_row.tscn (glossy wood, the
## Settings and Game Rules windows) and ui/pieces/plain_row.tscn (a
## parchment card, Tutorial Messages). The whole row is the button.
@tool
class_name SettingRow
extends Control

signal pressed
signal toggled(on: bool)

@export var text := "Label":
	set(v):
		text = v
		_refresh()
@export_multiline var sub := "":
	set(v):
		sub = v
		_refresh()
@export var icon: Texture2D:
	set(v):
		icon = v
		_refresh()
## The icon by its emoji, when there's no texture (the game's image for it).
@export var emoji := "":
	set(v):
		emoji = v
		_refresh()
@export var button_text := "Open":
	set(v):
		button_text = v
		_refresh()
## A switch at the right instead of the button.
@export var is_switch := false:
	set(v):
		is_switch = v
		_refresh()
@export var on := false:
	set(v):
		on = v
		if is_node_ready():
			$Switch.queue_redraw()
## Space inside the frame (top/bottom), and the label's line height (CSS).
@export var pad := 15.0
@export var right_pad := 16.0  # the button or switch from the right edge
@export var line := 19.6
@export var sub_line := 16.2
@export var switch_on := Color("#3fb46c")
@export var switch_off := Color("#e6cf9f")
@export var switch_edge := Color("#c9a571")


static func make(plain := false) -> SettingRow:
	return load("res://ui/pieces/%s.tscn" % ("plain_row" if plain else "setting_row")).instantiate()


func _ready() -> void:
	$Switch.draw.connect(_draw_switch)
	if not Engine.is_editor_hint():
		gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			if is_switch:
				on = not on
				toggled.emit(on)
			else:
				pressed.emit())
	resized.connect(_refresh)
	_refresh()


## Fills and lays out the row for its width; the height follows the text.
func _refresh() -> void:
	if not is_node_ready():
		return
	$Icon.texture = icon if icon or emoji == "" or Engine.is_editor_hint() else Data.icon(emoji)
	var lab: Label = $Body/Label
	var sl: Label = $Body/Sub
	lab.text = text
	sl.text = sub
	sl.visible = sub != ""
	$Button.visible = not is_switch
	$Switch.visible = is_switch
	$Button/Text.text = button_text
	# The button fits its text; the body takes what's between it and the icon.
	var bt: Label = $Button/Text
	var bw := bt.get_theme_font("font").get_string_size(button_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bt.get_theme_font_size("font_size")).x + 26
	$Button.size.x = bw
	var right: float = $Switch.size.x if is_switch else bw
	var body: Control = $Body
	var bwidth: float = size.x - body.position.x - right - 12 - right_pad
	var lf := lab.get_theme_font("font")
	var lpx := lab.get_theme_font_size("font_size")
	var lines := roundf(lf.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, bwidth, lpx).y / lf.get_height(lpx))
	lab.add_theme_constant_override("line_spacing", int(round(line - lf.get_height(lpx))))
	var label_h := lines * line
	var body_h := label_h
	lab.position = Vector2.ZERO
	lab.size = Vector2(bwidth, 0)  # grows to its text
	if sub != "":
		var sf := sl.get_theme_font("font")
		var spx := sl.get_theme_font_size("font_size")
		sl.add_theme_constant_override("line_spacing", int(round(sub_line - sf.get_height(spx))))
		var sub_h := roundf(sf.get_multiline_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, bwidth, spx).y / sf.get_height(spx)) * sub_line
		sl.position = Vector2(0, label_h + 2)
		sl.size = Vector2(bwidth, 0)
		body_h += 2 + sub_h
	var inner := maxf(body_h, maxf($Tile.size.y if has_node("Tile") else $Icon.size.y, $Button.size.y if not is_switch else $Switch.size.y))
	custom_minimum_size.y = pad * 2 + inner
	size.y = custom_minimum_size.y
	var mid := size.y / 2
	body.position.y = mid - body_h / 2
	body.size = Vector2(bwidth, body_h)
	if has_node("Tile"):
		$Tile.position.y = mid - $Tile.size.y / 2
		$Icon.position = $Tile.position + ($Tile.size - $Icon.size) / 2
	else:
		$Icon.position.y = mid - $Icon.size.y / 2
	$Button.position = Vector2(size.x - right_pad - bw, mid - $Button.size.y / 2)
	$Switch.position = Vector2(size.x - right_pad - $Switch.size.x, mid - $Switch.size.y / 2)


## .switch: a pill, green when on, the white knob at its end.
func _draw_switch() -> void:
	var sw: Control = $Switch
	var r := sw.size.y / 2
	var box := StyleBoxFlat.new()
	box.bg_color = switch_on if on else switch_off
	box.border_color = switch_on if on else switch_edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(r))
	box.anti_aliasing = true
	sw.draw_style_box(box, Rect2(Vector2.ZERO, sw.size))
	var knob := Vector2(sw.size.x - r if on else r, r)
	sw.draw_circle(knob + Vector2(0, 1), r - 3, Color(0, 0, 0, 0.3))
	sw.draw_circle(knob, r - 3, Color.WHITE)
