## The 💡 on a hint's target (Hints): a small round badge off the target's
## top-right corner, one soft fade-in. A child of the target, so it moves,
## hides and goes with it. A tap on it: tapped.
class_name HintBadge
extends Control

@export var diameter := 24.0
@export var fade := 0.5
@export var fill := Color("#fff6dc")
@export var ring := Color("#e2b25a")

signal tapped

var fade_in := true  # false: already showing before a redraw rebuilt its target
var tappable := true  # false: just a mark (a craftable shop card's), taps go to the card


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -diameter * 0.7
	offset_right = diameter * 0.3
	offset_top = -diameter * 0.3
	offset_bottom = diameter * 0.7
	mouse_filter = MOUSE_FILTER_STOP if tappable else MOUSE_FILTER_IGNORE
	var bulb := TextureRect.new()
	bulb.texture = Data.icon("💡")
	bulb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bulb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bulb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bulb.offset_left = diameter * 0.17
	bulb.offset_top = diameter * 0.17
	bulb.offset_right = -diameter * 0.17
	bulb.offset_bottom = -diameter * 0.17
	bulb.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bulb)
	if fade_in and not Progress.prefs.get("lowMotion"):
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, fade)
	gui_input.connect(func(ev):
		if Tap.tap(ev):
			accept_event()
			tapped.emit())


func _draw() -> void:
	var r := diameter / 2
	draw_circle(Vector2(r, r), r, fill)
	draw_circle(Vector2(r, r), r - 0.75, ring, false, 1.5, true)
