## The pins tray (pins.js #pinsTray; the 🔍 button): every pinned item as a
## chip (PinChip); a tap tracks it, or stops tracking it. It rests on the hub
## (Home reads Close); the 🔍 button and the tracked pill stay above it.
## The layout is ui/overlays/pins_tray.tscn.
class_name PinsTray
extends Control

const SCENE := "res://ui/overlays/pins_tray.tscn"

@export var max_height := 0.45  # of the screen (#pinsTray max-height:45vh)


static func make() -> PinsTray:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.state_changed.connect(_redraw)
	resized.connect(_place)
	$Tray/Body.minimum_size_changed.connect(_place)  # the chips laid out
	_redraw()


func _redraw() -> void:
	var chips: HFlowContainer = $Tray/Body/Chips
	for c in chips.get_children():
		c.queue_free()
	var names: Array = Progress.prefs.pinnedItems.filter(func(n): return Catalog.entry(n) != null)
	$Tray/Body/Empty.visible = names.is_empty()
	for n in names:
		var chip := PinChip.make()
		chip.fill(n, Game.ctx.get("tracked") == n)
		var item: String = n
		chip.gui_input.connect(func(ev): if Tap.tap(ev):  # toggleJobSelect()
			Game.set_tracked(null if Game.ctx.get("tracked") == item else item))
		chips.add_child(chip)
	_place()


## As tall as its chips (at most max_height), resting on the hub.
func _place() -> void:
	var tray: Control = $Tray
	tray.size.x = size.x
	var h := minf($Tray/Body.get_combined_minimum_size().y + 2, size.y * max_height)
	tray.position = Vector2(0, size.y - HubBar.H - h)
	tray.size.y = h + HubBar.H  # tucked under the hub
	$Tray/Body.size = Vector2(size.x, h - 2)
