## The parchment window (.sheetbox.parch) with its title on a wooden banner
## over the top edge; every dialog sits on one. Edit the look in
## ui/pieces/parchment_window.tscn. The banner keeps its width fitted to the
## title (its height, place and the title's style are the scene's).
@tool
class_name ParchmentWindow
extends NineSlice

@export var title := "Title":
	set(v):
		title = v
		if is_node_ready():
			_fit()
## An icon before the title (⚙️ Settings); none: the title alone.
@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready():
			_fit()


func _ready() -> void:
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var banner: Control = $Banner
	var t: Label = $Banner/Title
	t.text = title
	banner.visible = title != ""
	var tw := t.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, t.get_theme_font_size("font_size")).x
	var ic: TextureRect = $Banner/Icon
	ic.texture = icon
	ic.visible = icon != null
	var iw := ic.size.x + 8 if icon else 0.0  # the icon and its gap
	banner.size.x = tw + 60 + iw
	banner.position.x = (size.x - banner.size.x) / 2
	t.offset_left = iw  # the title centred in what's left of the icon
	ic.position = Vector2((banner.size.x - tw - iw) / 2, (banner.size.y - ic.size.y) / 2 - 1)
