## One station on the map (.map-node): a navy disc in a brass rim with the
## station's icon. Green ring where you are (with "YOU ARE HERE" under it),
## gold ring where you've picked, greyed where you can't go. Edit the look in
## ui/pieces/map_node.tscn; each station's copy sits in ui/screens/map.tscn,
## where it can be dragged. The size is the copy's size.
@tool
class_name MapNode
extends Control

signal tapped(station: String)

@export var station := ""
## The station's icon (set per station in map.tscn).
@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready():
			$Icon.texture = v

var here := false
var picked := false
var reachable := true


func _ready() -> void:
	$Icon.texture = icon
	if Engine.is_editor_hint():
		return
	set_meta("cmp", "map:" + station)
	gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed: tapped.emit(station))
	# "YOU ARE HERE" fits its text.
	var pill: Control = $HerePill
	var tw := Tok.font(900).get_string_size($HerePill/Label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	pill.size = Vector2(tw + 24, pill.size.y)
	pill.position.x = (size.x - pill.size.x) / 2
	pill.set_meta("cmp", "map:here")
	$HerePill/Label.add_theme_font_override("font", Tok.font(900))


func show_state(is_here: bool, is_picked: bool, can_reach: bool) -> void:
	here = is_here
	picked = is_picked
	reachable = can_reach or is_here
	var grey := MapScreen._greyed() if not reachable else null
	$Rim.material = grey
	$Icon.material = grey
	$HerePill.visible = here
	queue_redraw()


func _draw() -> void:
	var d := size.x
	var mid := size / 2
	if picked:  # 8px gold ring and glow
		draw_circle(mid, d / 2 + 14, Color(Tok.GOLD, 0.18))
		draw_circle(mid, d / 2 + 8, Tok.GOLD)
	elif here:  # 4px green ring and glow
		draw_circle(mid, d / 2 + 12, Color(Tok.OK, 0.2))
		draw_circle(mid, d / 2 + 4, Tok.OK)
	draw_circle(mid, d / 2 * 0.84, Color("#122e3c").darkened(0.0 if reachable else 0.45))
