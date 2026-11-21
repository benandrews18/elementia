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
## The title wraps to a second line when too wide for the window (as the
## HTML's tip windows do); off, it stays on one line.
@export var wrap_title := false:
	set(v):
		wrap_title = v
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


## How much taller than one line the title's banner is (a wrapped title);
## a window's content starts this much lower.
var extra_height := 0.0


func _fit() -> void:
	var banner: Control = $Banner
	var t: Label = $Banner/Title
	t.text = title
	banner.visible = title != ""
	var f := t.get_theme_font("font")
	var px := t.get_theme_font_size("font_size")
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var ic: TextureRect = $Banner/Icon
	ic.texture = icon
	ic.visible = icon != null
	var iw := ic.size.x + 8 if icon else 0.0  # the icon and its gap
	# Too wide for the window (inside its 38px sides): the title wraps, the
	# banner takes the full width and grows a line (.sheetbox.parch > h2).
	var room := size.x - 76
	var wraps := wrap_title and tw + iw + 108 > room and room > 0  # the HTML banner's padding and edges: 108px
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wraps else TextServer.AUTOWRAP_OFF
	extra_height = 0.0
	var inset := 0.0  # a wrapped title: the text narrower than the banner by the HTML's edges
	if wraps:
		inset = 54.0  # the text exactly text_w wide
		var text_w := room - 108 - iw
		var lines := roundf(f.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, text_w, px).y / f.get_height(px))
		extra_height = (lines - 1) * px * 1.35
		tw = text_w + 48
	banner.size = Vector2(tw + 60 + iw, 54 + extra_height)
	banner.position.x = (size.x - banner.size.x) / 2
	t.offset_left = iw + inset  # the title centred in what's left of the icon
	t.offset_right = -inset
	ic.position = Vector2((banner.size.x - tw - iw) / 2, (banner.size.y - ic.size.y) / 2 - 1)
