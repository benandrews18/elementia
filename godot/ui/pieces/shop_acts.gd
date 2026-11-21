## The pin and Craft button under a shop card (.st-acts). Its looks are
## ui/pieces/shop_acts.tscn: the pin pinned / not, and the button's three
## states (can craft, owned, can't yet), each a style and a text colour.
class_name ShopActs
extends Control

const SCENE := "res://ui/pieces/shop_acts.tscn"

@export var pin_on: StyleBox
@export var pin_off: StyleBox
@export var needed_style: StyleBox  # in the pin's place: the tracked item's icon (it still needs this)
@export var can_style: StyleBox
@export var owned_style: StyleBox
@export var locked_style: StyleBox
@export var can_color := Color.WHITE
@export var owned_color := Color("#3fb46c")
@export var locked_color := Color("#7d8899")
@export var craft_text := "Craft"
@export var owned_text := "    Owned"  # room for the drawn tick (not in Nunito)


static func make() -> ShopActs:
	return load(SCENE).instantiate()


## Lays the two out across w (the pin, an h square; then the button) and shows the state.
func show_state(w: float, h: float, pinned: bool, can: bool, owned: bool) -> void:
	var pin: Control = $Pin
	pin.size = Vector2(h, h)
	size = Vector2(w, h)
	pin.add_theme_stylebox_override("panel", pin_on if pinned else pin_off)
	pin.modulate.a = 1.0 if pinned else 0.5
	$Pin/Icon.material = null if pinned else Tok.grey()
	var btn: Label = $Craft
	btn.position.x = h + 3
	btn.size.x = w - h - 3
	btn.text = owned_text if owned else craft_text
	btn.add_theme_stylebox_override("normal", can_style if can else owned_style if owned else locked_style)
	btn.add_theme_color_override("font_color", can_color if can else owned_color if owned else locked_color)
	if not can:
		btn.add_theme_constant_override("shadow_offset_y", 0)
		btn.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	if owned:
		var tk := Tok.tick(owned_color, 13)
		tk.position = Vector2(4, 11)
		btn.add_child(tk)


## The tracked item still needs this card (pinSlotHTML()): its icon in the
## pin's place, green-ringed.
func show_needed(icon: Texture2D) -> void:
	$Pin.add_theme_stylebox_override("panel", needed_style)
	$Pin.modulate.a = 1.0
	$Pin/Icon.material = null
	$Pin/Icon.texture = icon
