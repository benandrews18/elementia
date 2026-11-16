## The game's frame: the current screen (map / station), the panel open over
## it (the drawer with the Display Mat), and the hub bar on top of
## everything. Decides the Home button's face and what tapping it does
## (hub.js hubHomeFace() and its click handler).
class_name App
extends Control

var panel := ""  # "" or "drawer"
var _screen: Control
var _panel_node: Control
var _hub: HubBar


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hub = HubBar.new()
	_hub.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_hub)
	_hub.pressed.connect(_on_hub)
	Game.state_changed.connect(_sync_hub)
	_sync_hub()


## Opens a panel over the screen ("drawer": the Display Mat).
func open_panel(name: String) -> void:
	close_panel()
	panel = name
	if name == "drawer":
		_panel_node = DisplayMatScreen.new()
		add_child(_panel_node)
		move_child(_panel_node, _hub.get_index())  # under the hub
	_sync_hub()


func close_panel() -> void:
	if is_instance_valid(_panel_node):
		_panel_node.queue_free()
	_panel_node = null
	panel = ""
	_sync_hub()


## hubHomeFace(): what Home does right now.
func home_face() -> String:
	var s := Game.state
	var c := Game.ctx
	var sel = c.get("selectedMapStation")
	if s.get("finalCheckPending") and (panel == "" or panel == "drawer"):
		return "final"
	if panel == "drawer" and c.screen == "map" and sel and can_travel_to(sel) and c.get("travelPromptFor") == sel:
		return "lockin"
	if panel != "":
		return "close"
	if c.current and not s.get("rolledHere"):
		return "roll"
	if c.screen == "map" and sel and sel == s.get("lastStation"):
		return "shop"
	if c.screen == "map" and sel and can_travel_to(sel):
		return "travel"
	if c.screen == "map" and not sel and s.get("lastStation"):
		return "shop"
	return "map"


## canTravelTo(): not where you are, reachable (a path, or a Helicopter), run not over.
func can_travel_to(name) -> bool:
	var s := Game.state
	return name != null and name != s.get("lastStation") and not s.get("ended") \
		and (Catalog.owns(s, "Helicopter") or Catalog.is_map_connected(s.get("lastStation"), name))


func _sync_hub() -> void:
	var s := Game.state
	var sel = Game.ctx.get("selectedMapStation")
	var badges := {}
	if not (s.get("marketVisited") and not s.get("marketUnseen")):
		badges.market = "!"
	_hub.show_state(home_face(), {"inv": panel == "drawer"}, badges,
		sel != null and not Catalog.is_map_connected(s.get("lastStation"), sel))


## shortcut: only the drawer and Close are wired; the other buttons and faces
## come with their screens in M4.
func _on_hub(id: String) -> void:
	match id:
		"inv":
			if panel == "drawer":
				close_panel()
			else:
				open_panel("drawer")
		"home":
			if home_face() == "close":
				close_panel()
