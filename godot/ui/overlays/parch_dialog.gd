## A parchment dialog whose content is all in its scene: the window
## (ui/pieces/parchment_window.tscn) with a `Content` VBox under its title,
## stacked top to bottom (texts, icons, rows, buttons, spacers), and the
## window sized to fit and centred above the hub. The scenes are the
## Settings windows and the rules and tips (ui/overlays/*.tscn); everything
## in them can be edited in the editor.
## Texts may hold {🕒}-style tokens: the emoji's image, inline at the text's
## size (left out if the game has no image for it), and {name} tokens filled
## from `values` (e.g. a multiplier from the game data).
## Closing pops it out (Juice.leave moves it into a holder first): listen
## to `closed`, never tree_exited, which then fires twice.
## Buttons by name, anywhere in the scene: "Close" (✕) and "Ok" close it;
## "Hide" hides this tip for good (tip_id) and closes it. Others emit
## `pressed(name)` (connect from the script that opened it).
class_name ParchDialog
extends Control

signal pressed(button: String)
signal closed

## Hides this tip for good from its "✕ Hide" (Progress.hide_tip).
@export var tip_id := ""
## Parchment under the content, and the gap above it under the title.
@export var bottom_pad := 36.0
@export var top_gap := 12.0
## A tap on the dim closes it.
@export var dim_closes := false
@export var max_width := 420.0
@export var side_margin := 20.0  # from the screen's sides (the wide dark windows: 4)


var values := {}


static func open(on: Control, scene: String, vals := {}) -> ParchDialog:
	var d: ParchDialog = Tok.make(scene)
	d.values = vals
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if has_node("Dim"):
		$Dim.gui_input.connect(func(ev): if Tap.tap(ev) and dim_closes: close())
	_wire(self)
	_fill(self)
	$Window/Content.minimum_size_changed.connect(_layout)
	resized.connect(_layout)
	_layout()
	Juice.pop_in($Window, get_node_or_null("Dim"))


## Hooks every button-like node by its name (see the class comment).
func _wire(n: Node) -> void:
	for c in n.get_children():
		if c is Control and c.name in ["Close", "Ok", "Hide"]:
			var nm: String = c.name
			c.mouse_filter = MOUSE_FILTER_STOP
			if nm == "Close":  # play testers missed the corner ✕ (the user, 2026-11-28)
				Tok.grow_hit(c, 12)
			c.gui_input.connect(func(ev): if Tap.tap(ev):
				if nm == "Hide" and tip_id != "":
					Progress.hide_tip(tip_id)
				close())
		elif c is SettingRow:
			var nm2: String = c.name
			c.pressed.connect(func(): pressed.emit(nm2))
		elif c is Control and c.has_meta("button"):  # any other tappable: meta "button"
			var nm3: String = c.name
			c.mouse_filter = MOUSE_FILTER_STOP
			c.gui_input.connect(func(ev): if Tap.tap(ev): pressed.emit(nm3))
		_wire(c)


## Fills {value} and {emoji} tokens in every text.
func _fill(n: Node) -> void:
	for c in n.get_children():
		if c is RichTextLabel:
			var px: int = c.get_theme_font_size("normal_font_size")
			c.text = emojify(c.text.format(values), px)
		elif c is Label:
			c.text = c.text.format(values)
		_fill(c)


## {🕒} -> the emoji's image at px, inline ([img]); dropped when there's none.
## Also the game's own pictures by key: {suit:organic}, {ui:market}.
static func emojify(text: String, px: int) -> String:
	var re := RegEx.create_from_string("[{]((?:__[A-Z_]+__)|(?:(?:ui|suit):[a-z_]+)|[^{}a-zA-Z0-9_ ][^{}]*)[}]")
	for m in re.search_all(text):
		var key := m.get_string(1)
		if key.begins_with("suit:"):  # on its coloured circle, as on the cards' suit pips (tools/suit_discs.py)
			key = "suitdisc:" + key.substr(5)
		var tex := Data.icon(key)
		var img := "[img=%dx%d]%s[/img]" % [px, px, tex.resource_path] if tex else ""
		text = text.replace(m.get_string(), img)
	return text



## Closes it: shrinks and fades out (Juice.leave: already out of the
## tree's way, so the window under it takes taps at once).
func close() -> void:
	closed.emit()
	Juice.leave(self, $Window)


## The window: full width (at most max_width), the content under the title,
## as tall as the content; centred above the hub.
func _layout() -> void:
	var win: ParchmentWindow = $Window
	var content: VBoxContainer = $Window/Content
	var w := minf(max_width, size.x - side_margin * 2)
	win.size.x = w
	content.size.x = w - 2 * content.position.x
	for c in content.get_children():  # wrapped texts measure at the content's width
		if c is Control and c.get("autowrap_mode") != null and c.autowrap_mode != TextServer.AUTOWRAP_OFF:
			c.custom_minimum_size.x = content.size.x
	content.position.y = 59 + top_gap + win.extra_height
	content.size.y = 0
	var h := content.position.y + content.get_combined_minimum_size().y + bottom_pad
	win.size.y = h
	win.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	var spot := content.get_node_or_null("BannerSpot") as Control
	if spot != null:  # the title's banner sits there, under an icon (h2 after the icon in the HTML)
		var banner: Control = $Window/Banner
		banner.position.y = content.position.y + spot.position.y + (spot.size.y - banner.size.y) / 2
