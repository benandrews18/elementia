## The Trophies window (openTrophies(); the title screen's Trophies): how many
## are earned, then every trophy as an icon (TrophyTile), five to a row,
## scrolling past 55% of the screen's height; a tap opens its detail
## (TrophyDetail). The layout is ui/overlays/trophies.tscn.
class_name TrophiesWindow
extends ParchDialog

const SCENE := "res://ui/overlays/trophies.tscn"

@export var max_list := 0.55  # of the screen's height (.trophy-mini-grid max-height:55vh)


static func show_on(on: Control) -> TrophiesWindow:
	return ParchDialog.open(on, SCENE) as TrophiesWindow


func _ready() -> void:
	var got: Dictionary = Progress.trophies
	var all := Trophies.all()
	$Window/Content/Count.text = "%d of %d earned -- each can be earned again once a day. Tap one to see how." % [
		all.filter(func(t): return got.has(t.id)).size(), all.size()]
	var grid: GridContainer = $Window/Content/Scroll/Pad/Grid
	for t in all:
		var tile := TrophyTile.make()
		tile.fill(t, got.get(t.id))
		var tid: String = t.id
		tile.gui_input.connect(func(ev): if Tap.tap(ev): TrophyDetail.show_on(get_parent(), tid))
		grid.add_child(tile)
	super()


## The list as tall as its tiles, at most max_list of the screen.
func _layout() -> void:
	var scroll: ScrollContainer = $Window/Content/Scroll
	scroll.custom_minimum_size.y = minf($Window/Content/Scroll/Pad.get_combined_minimum_size().y, size.y * max_list)
	super()
