## Crafting from the Market (openBingoCraftOverlay(), #bingoCraftOverlay):
## the square's shop row on a Crafting Bench over the tray, so it can be
## made without travelling. Closes once it's crafted, or on a tap outside.
## The layout is ui/overlays/market_craft.tscn; this fills in the row.
class_name MarketCraft
extends Control

const SCENE := "res://ui/overlays/market_craft.tscn"

## The bench's widest size.
@export var max_width := 390.0

var item := ""
var _row: Control


static func open(on: Control, name: String) -> MarketCraft:
	var m: MarketCraft = load(SCENE).instantiate()
	m.item = name
	m.size = on.size
	on.add_child(m)
	return m


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Dim.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	Game.state_changed.connect(_redraw)
	_redraw()


func _redraw() -> void:
	if Catalog.owns(Game.state, item):
		queue_free()
		return
	if is_instance_valid(_row):
		_row.queue_free()
	var bench: Control = $Bench
	var w := minf(max_width, size.x - 20)
	_row = ShopRow.make(Catalog.entry(item), w - 36, func(n, at: Rect2): App.current.craft_tap(n, at), func(n):
		Game.toggle_pin(n))
	bench.add_child(_row)
	bench.size = Vector2(w, 30 + ShopRow.H + 18)
	bench.position = Vector2((size.x - w) / 2, (size.y - HubBar.H - bench.size.y) / 2)
