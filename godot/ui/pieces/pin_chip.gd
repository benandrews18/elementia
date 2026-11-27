## One pinned item in the pins tray (.map-job-chip): its icon and name; the
## tracked one is green with a 🔍 before it. The look is
## ui/pieces/pin_chip.tscn.
class_name PinChip
extends PanelContainer

const SCENE := "res://ui/pieces/pin_chip.tscn"

@export var on_style: StyleBox
@export var off_style: StyleBox
@export var on_ink := Color("#3fb46c")  # --ok


static func make() -> PinChip:
	return Tok.make(SCENE)


func fill(name: String, tracked: bool) -> void:
	add_theme_stylebox_override("panel", on_style if tracked else off_style)
	$Row/Glass.visible = tracked
	$Row/Icon.texture = Data.icon(Catalog.entry(name).emoji)
	$Row/Name.text = name
	if tracked:
		$Row/Name.add_theme_color_override("font_color", on_ink)
