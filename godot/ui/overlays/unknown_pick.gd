## Spending an Unknown Element (openEmptyElPicker(), #emptyElPick): "Pick an
## element" with the "?" square on the banner, this station's elements in a
## row; a tap turns one "?" into that element. A tap outside closes it.
## The layout is ui/overlays/unknown_pick.tscn; this fills in the station.
class_name UnknownPick
extends Control

const SCENE := "res://ui/overlays/unknown_pick.tscn"

## The element chips: their biggest size and the gap between them.
@export var chip_max := 44.0
@export var chip_gap := 4.0


static func open(on: Control) -> UnknownPick:
	var p: UnknownPick = load(SCENE).instantiate()
	p.size = on.size
	on.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Dim.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	var at = Game.ctx.current if Game.ctx.current else Game.state.get("lastStation")
	if not at:
		queue_free()
		return
	var st := Catalog.station(at)
	var dice := Catalog.sorted_dice(st)
	var w := minf(360, size.x - 40)
	var inner := w - 2 * 30
	var cw := minf(chip_max, (inner - chip_gap * (dice.size() - 1)) / dice.size())
	var chips: Control = $Window/Chips
	var h := chips.position.y + cw + 14 + 30
	var win: Control = $Window
	win.size = Vector2(w, h)
	win.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	var banner: Control = $Window/Banner
	var sq := LockInReward.unknown_square(24)  # room for it: the title starts with spaces
	sq.position = Vector2(26, (banner.size.y - 24) / 2 - 1)
	banner.add_child(sq)
	# The station's emoji and name, centred together.
	var em: TextureRect = $Window/Emoji
	var nl: Label = $Window/Name
	em.texture = Data.icon(st.emoji)
	nl.text = at
	var name_w := nl.get_theme_font("font").get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, nl.get_theme_font_size("font_size")).x
	em.position.x = (w - name_w - 32) / 2
	nl.position.x = em.position.x + 32
	var x0 := (w - (dice.size() * cw + (dice.size() - 1) * chip_gap)) / 2
	for i in dice.size():
		var sym: String = dice[i]
		var c := StationScreen.element_chip(sym, cw)
		c.get_node("Num").visible = false  # the user, 2026-11-26: no atomic numbers, white names
		var nm: Label = c.get_node("Name")
		nm.add_theme_color_override("font_color", Color.WHITE)
		nm.add_theme_color_override("font_outline_color", Color("#3b2412"))
		nm.add_theme_constant_override("outline_size", 4)
		c.position = Vector2(x0 + i * (cw + chip_gap), 0)
		c.mouse_filter = MOUSE_FILTER_STOP
		c.gui_input.connect(func(ev): if Tap.tap(ev):
			queue_free()
			Game.spend_unknown(sym))
		chips.add_child(c)
