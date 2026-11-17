## Crafting from the Market (openBingoCraftOverlay(), #bingoCraftOverlay):
## the square's shop row on a Crafting Bench over the tray, so it can be
## made without travelling. Closes once it's crafted, or on a tap outside.
class_name MarketCraft
extends Control

var item := ""
var _bench: Control


static func open(on: Control, name: String) -> MarketCraft:
	var m := MarketCraft.new()
	m.item = name
	m.size = on.size
	on.add_child(m)
	return m


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ConfirmDialog.dim(self, queue_free)
	Game.state_changed.connect(_redraw)
	_redraw()


func _redraw() -> void:
	if Catalog.owns(Game.state, item):
		queue_free()
		return
	if is_instance_valid(_bench):
		_bench.queue_free()
	var w := minf(390, size.x - 20)
	_bench = BenchPanel.new()
	_bench.add_child(ShopRow.make(Catalog.entry(item), w - 36, func(n, at: Rect2): App.current.craft_tap(n, at), func(n):
		Progress.toggle_pin(n)
		Game._changed()))
	_bench.size = Vector2(w, 30 + ShopRow.H + 18)
	_bench.position = Vector2((size.x - w) / 2, (size.y - HubBar.H - _bench.size.y) / 2)
	add_child(_bench)
