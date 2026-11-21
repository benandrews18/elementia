## An item card (matCardHTML(), .mm-card in display-mat.css): parchment
## face, points badge top-left, suit pips top-right, icon, name, station
## badges on the bottom edge. The parent sets its size (the grid cell).
##   ItemCard.make("Water", {"mini": true})
## opts: mini (tier 1 small card), in_grid (false = on the mat: a mini card
## drops its name), wide (capstone art 1.5x), complete (points doubled),
## tag (the name its parts are measured under in comparisons; default the
## item), on (already on the mat: dimmed), lit_suits / lit_stations (names in a live
## combo: their badges get a gold halo).
class_name ItemCard
extends Control

## The layout is ui/components/item_card.tscn: the face and points badge
## (full size and mini), the badge's number, the station row's gap. The
## icon, name, pips and badges come from the item.
const SCENE := "res://ui/components/item_card.tscn"

@export var face: StyleBox
@export var face_mini: StyleBox
@export var badge: StyleBox
@export var badge_mini: StyleBox

var item: String
var opts: Dictionary
var _pips: Array[Control] = []
@onready var _stations: HBoxContainer = $Stations


static func make(name: String, o := {}) -> ItemCard:
	var c: ItemCard = load(SCENE).instantiate()
	c.item = name
	c.opts = o
	c.set_meta("cmp", name)
	return c


func _ready() -> void:
	var card: Dictionary = Catalog.mat_card(item)
	if opts.has("tag"):
		set_meta("cmp", opts.tag)
	var mini: bool = opts.get("mini", false)
	var grid_mini: bool = mini and opts.get("in_grid", true)
	var border := 3 if mini else 4
	# Face: parchment, black border, rounded, soft shadow.
	$Face.add_theme_stylebox_override("panel", face_mini if mini else face)
	# Icon over name, centred (a grid mini card starts from the top).
	var col: VBoxContainer = $Col
	# CSS padding: 5px 3px 3px (mini 2px; 3px on top in a grid).
	var side := 2 if mini else 3
	col.offset_left = border + side
	col.offset_right = -(border + side)
	col.offset_top = border + (3 if grid_mini else 2 if mini else 5)
	if opts.get("wide"):
		col.offset_top -= 19  # capstone art rides up into the free top centre (margin-top:-19px)
	col.offset_bottom = -(border + side)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN if grid_mini else BoxContainer.ALIGNMENT_CENTER
	var icon_px := 26.0 if grid_mini else 32.0 if mini else 66.0 if opts.get("wide") else 44.0
	var ic := Tok.icon(card.emoji, icon_px)
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	ic.set_meta("cmp", opts.get("tag", item) + ":icon")
	if not mini and not opts.get("wide"):
		col.add_child(_gap(5.6))  # .mm-icon margin-top:3px, + 2.6px of line box above the inline image
	if opts.get("wide"):
		col.add_child(_gap(5))  # the HTML icon's line box sits ~5px above 66px art (inline image)
	col.add_child(ic)
	if not mini or grid_mini:
		# shortcut: wraps by the size set before _ready (fine while parents size cards first), re-measure on resize when a container sizes them
		col.add_child(_name_box(item, grid_mini, size.x - 2 * (border + side)))
	# Points badge, top-left, straddling the border.
	var pts: int = int(card.points) * (2 if opts.get("complete") else 1)
	var bsz := 22.0 if mini else 28.0
	var num: Label = $Badge/Num
	num.text = str(pts)
	if mini:
		num.add_theme_font_size_override("font_size", 11)
	var b_panel: Panel = $Badge
	b_panel.add_theme_stylebox_override("panel", badge_mini if mini else badge)
	# CSS top/left are from inside the border: -3px (mini -5px).
	var off := border - (5 if mini else 3)
	b_panel.position = Vector2(off, off)
	# min-width 28px (mini 22), padding 0 4px, border 2px.
	var text_w := num.get_theme_font("font").get_string_size(num.text, HORIZONTAL_ALIGNMENT_LEFT, -1, num.get_theme_font_size("font_size")).x
	b_panel.size = Vector2(maxf(bsz, ceilf(text_w) + 12), bsz)
	if opts.get("complete"):
		# Whole recipe on the mat: a 2px gold ring and glow round the badge (.mm-card.complete .mm-pts).
		var glow := Panel.new()
		glow.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD, bsz / 2 + 2, 0, Color.BLACK, 3, 0, Color(Tok.GOLD, 0.85)))
		glow.mouse_filter = MOUSE_FILTER_IGNORE
		glow.position = b_panel.position - Vector2(2, 2)
		glow.size = b_panel.size + Vector2(4, 4)
		add_child(glow)
		move_child(glow, b_panel.get_index())  # behind the badge
	b_panel.set_meta("cmp", opts.get("tag", item) + ":pts")
	# Suit pips: a column down the top-right corner (placed in _place()).
	var psz := 18.0 if mini else 27.0
	for i in card.pips.size():
		var su: String = card.pips[i]
		var pip := Panel.new()
		pip.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(su), psz / 2, 1.5))
		pip.size = Vector2(psz, psz)
		pip.mouse_filter = MOUSE_FILTER_IGNORE
		var g := Tok.icon("suit:" + su, 11.0 if mini else 16.0)
		g.position = (pip.size - g.size) / 2
		pip.add_child(g)
		if opts.get("lit_suits", []).has(su):
			pip.add_child(_halo(psz))
		pip.set_meta("cmp", "%s:pip%d" % [opts.get("tag", item), i])
		$Pips.add_child(pip)
		_pips.append(pip)
	# Station badges: a row centred on the bottom edge (placed in _place()).
	var ssz := 18.0 if mini else 26.0
	for st in card.stations:
		var b := Panel.new()
		b.add_theme_stylebox_override("panel", Tok.box(Tok.station_color(st), ssz / 2, 1.5))
		b.custom_minimum_size = Vector2(ssz, ssz)
		b.mouse_filter = MOUSE_FILTER_IGNORE
		var g := Tok.icon(Catalog.station(st).emoji, 12.0 if mini else 17.0)
		g.material = Tok.outline(12.0 if mini else 17.0)
		if opts.get("lit_stations", []).has(st):
			b.add_child(_halo(ssz))
		var k := "%s:st%d" % [opts.get("tag", item), _stations.get_child_count()]
		b.set_meta("cmp", k)
		g.set_meta("cmp", k + "icon")
		g.position = (Vector2(ssz, ssz) - g.size) / 2
		b.add_child(g)
		_stations.add_child(b)
	_stations.set_meta("cmp", opts.get("tag", item) + ":stations")
	if opts.get("on"):
		modulate = Color(0.6, 0.6, 0.6)
	resized.connect(_place)
	_place()


## The name (.mm-name): 10.5px bold, line-height 1.1, padding 1px 2px; a
## grid mini card shows one line with 14px sides. Godot gives a line the
## font's full height, so a holder sized to the CSS line boxes keeps the
## card's layout the same and the text is centred in it.
func _name_box(text: String, one_line: bool, width: float) -> Control:
	const SIZE := 11  # Godot font sizes are whole pixels (CSS 10.5)
	var line := 10.5 * 1.1
	var side := 14.0 if one_line else 2.0
	var f := Tok.font(800)
	var lines := 1
	if not one_line and width > 0:
		lines = 2 if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x > width - 2 * side else 1
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, lines * line + (1 if one_line else 2))
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	holder.set_meta("cmp", opts.get("tag", item) + ":name")
	var nm := Tok.label(text, SIZE, Tok.CARD_INK, 800)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if one_line:
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.max_lines_visible = 2
	nm.add_theme_constant_override("line_spacing", int(round(line - f.get_height(SIZE))))
	nm.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	nm.offset_left = side
	nm.offset_right = -side
	nm.offset_top = 1
	nm.offset_bottom = 0 if one_line else -1
	holder.add_child(nm)
	return holder


## "Lit" (part of a live combo): a 3.5px gold ring and a 10px glow, behind
## the badge (.mm-pip.lit, .mm-station.lit).
static func _halo(px: float) -> Panel:
	var h := Panel.new()
	h.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD, px / 2 + 3.5, 0, Color.BLACK, 5, 0, Color(Tok.GOLD, 0.9)))
	h.position = Vector2(-3.5, -3.5)
	h.size = Vector2(px + 7, px + 7)
	h.show_behind_parent = true
	h.mouse_filter = MOUSE_FILTER_IGNORE
	return h


static func _gap(px: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	return g


## The badges that hang off the edges follow the card's size.
func _place() -> void:
	var mini: bool = opts.get("mini", false)
	var psz := 18.0 if mini else 27.0
	var border := 3 if mini else 4
	# CSS offsets are from inside the border: top/right -3px, bottom -3px (mini -6px).
	for i in _pips.size():
		_pips[i].position = Vector2(size.x - border + 3 - psz, border - 3 + i * (psz + 2))
	_stations.size = _stations.get_combined_minimum_size()
	_stations.position = Vector2((size.x - _stations.size.x) / 2, size.y - border + (6 if mini else 3) - _stations.size.y)
