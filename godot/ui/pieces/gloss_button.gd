## A glossy button (.bigbtn on the parchment windows and the title screen):
## a vertical gradient face, a dark rim, a lighter line along its top, a
## ledge under it, and an icon (by emoji) before its text. Wood by default;
## the colours are Inspector values (e.g. the green Continue). The whole
## button is the tap area (connect gui_input with Tap.tap, or give it the
## meta "button" inside a ParchDialog).
@tool
class_name GlossButton
extends Control

@export var text := "Button":
	set(v):
		text = v
		_refresh()
## The icon by its emoji (the game's image for it).
@export var emoji := "":
	set(v):
		emoji = v
		_refresh()
@export var font_size := 15:
	set(v):
		font_size = v
		_refresh()
@export var top := Color("#9a6534"):
	set(v):
		top = v
		_refresh()
@export var bottom := Color("#6b3f1c"):  # reached at 62% down, then flat
	set(v):
		bottom = v
		_refresh()
@export var edge := Color("#3b2412"):  # the rim and the ledge
	set(v):
		edge = v
		_refresh()
@export var shine := Color(1, 0.862745, 0.627451, 0.35):  # the line along the top
	set(v):
		shine = v
		_refresh()
@export var ink := Color("#fff7e0"):
	set(v):
		ink = v
		_refresh()
@export var ink_shadow := true:
	set(v):
		ink_shadow = v
		_refresh()
@export var radius := 14:
	set(v):
		radius = v
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var box := func(fill: bool, col: Color) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.draw_center = fill
		b.bg_color = col
		b.set_corner_radius_all(radius)
		if not fill:
			b.border_color = col
			b.set_border_width_all(2)
		return b
	var ledge: StyleBoxFlat = box.call(true, edge)
	ledge.shadow_color = Color(0, 0, 0, 0.3)
	ledge.shadow_size = 6
	ledge.shadow_offset = Vector2(0, 2)
	$Ledge.add_theme_stylebox_override("panel", ledge)
	$Face.add_theme_stylebox_override("panel", box.call(true, Color.WHITE))
	$Edge.add_theme_stylebox_override("panel", box.call(false, edge))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.62, 1])
	g.colors = PackedColorArray([top, bottom, bottom])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 64
	gt.fill_to = Vector2(0, 1)
	$Face/Grad.texture = gt
	$Face/Shine.color = shine
	var lab: Label = $Row/Text
	lab.text = text
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", ink)
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45) if ink_shadow else Color(0, 0, 0, 0))
	var ic: TextureRect = $Row/Icon
	ic.texture = null if emoji == "" or Engine.is_editor_hint() else Data.icon(emoji)
	ic.visible = ic.texture != null
	ic.custom_minimum_size = Vector2(font_size, font_size) * 1.2
