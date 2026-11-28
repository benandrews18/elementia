## An item card (matCardHTML(), .mm-card in display-mat.css): parchment
## face, points badge top-left, suit pips top-right, icon, name, station
## badges on the bottom edge. The parent sets its size (the grid cell).
##   ItemCard.make("Water", {"mini": true})
## opts: mini (tier 1 small card), in_grid (false = on the mat: a mini card
## drops its name), wide (capstone art 1.5x), complete (points doubled),
## tag (the name its parts are measured under in comparisons; default the
## item), no_stations (no station badges: the station shop), on (already on the mat: dimmed), lit_suits / lit_stations (names in a live
## combo: their badges get a solid gold ring), combo (the card is in a live
## combo: a solid gold border, the rest black; no glow: the user,
## 2026-11-26), star (a ⭐ in the top right: a known collection it's part of
## can be finished from the hand), size (the size badge, bottom right:
## cards in the hand, whose right side shows in the fan).
class_name ItemCard
extends Control

## Names on two lines on every small card (station, Inventory, mat; not
## the full card): the user, 2026-11-23 and 2026-11-26.
const WRAP_NAMES := ["Aluminum Alloy", "Stainless Steel", "Natural Gas"]
## Wide art that draws small in a square box: this many times as wide on
## the small cards and the full card (the user, 2026-11-26).
const BIG_ART := {"Metropolis": 2.0}
const ROUND := preload("res://assets/ui/btn_round.webp")  # the star's rim (🔍's)

const SHOP_ICON := 42.0  # a station shop card's item image, every tier (opts.shop)
const SHOP_NAME := 13  # its name
const SHOP_CIRCLE := 26.0  # its points circle and suit pips

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
	var c: ItemCard = Tok.make(SCENE)
	c.item = name
	c.opts = o if o.has("wrap") or not WRAP_NAMES.has(name) else o.merged({"wrap": true})
	c.set_meta("cmp", name)
	return c


func _ready() -> void:
	var card: Dictionary = Catalog.mat_card(item)
	if opts.has("tag"):
		set_meta("cmp", opts.tag)
	var mini: bool = opts.get("mini", false)
	var grid_mini: bool = mini and opts.get("in_grid", true)
	var shop: bool = opts.get("shop", false)  # a station shop card: one icon, name and circle size on every tier (the user, 2026-11-23)
	var border := 3 if mini else 4
	# Face: parchment, black border, rounded, soft shadow.
	var fs: StyleBox = face_mini if mini else face
	if opts.get("combo"):
		fs = fs.duplicate()
		fs.border_color = Tok.GOLD
	$Face.add_theme_stylebox_override("panel", fs)
	# Icon over name, centred (a grid mini card starts from the top).
	var col: VBoxContainer = $Col
	# CSS padding: 5px 3px 3px (mini 2px; 3px on top in a grid).
	var side := 2 if mini else 3
	col.offset_left = border + side
	col.offset_right = -(border + side)
	col.offset_top = border + (3 if grid_mini else 2 if mini else 5)
	if opts.get("wide") and not shop:
		col.offset_top -= 19  # capstone art rides up into the free top centre (margin-top:-19px)
	col.offset_bottom = -(border + side)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN if grid_mini and not shop and not opts.get("no_name", false) else BoxContainer.ALIGNMENT_CENTER
	var icon_px := (17.0 if opts.get("wrap") else 26.0) if grid_mini else 32.0 if mini else 66.0 if opts.get("wide") else 44.0
	if shop:
		icon_px = SHOP_ICON * (0.75 if opts.get("wrap") else 1.0)
	icon_px = opts.get("icon_px", icon_px)  # a caller's own size (the craft's poke-up cards)
	var ic := art(card.emoji, icon_px, BIG_ART.get(item, 1.0))
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	ic.set_meta("cmp", opts.get("tag", item) + ":icon")
	if not mini and not opts.get("wide") and not shop:
		col.add_child(_gap(5.6))  # .mm-icon margin-top:3px, + 2.6px of line box above the inline image
	if opts.get("wide") and not shop:
		col.add_child(_gap(5))  # the HTML icon's line box sits ~5px above 66px art (inline image)
	col.add_child(ic)
	if (not mini or grid_mini) and not opts.get("no_name", false):  # no_name: the Display Mat's cards (the user, 2026-11-27)
		# shortcut: wraps by the size set before _ready (fine while parents size cards first), re-measure on resize when a container sizes them
		col.add_child(_name_box(item, grid_mini, size.x - 2 * (border + side)))
	# Points badge, top-left, straddling the border.
	var pts: int = int(card.points) * (2 if opts.get("complete") else 1)
	var bsz := SHOP_CIRCLE if shop else 22.0 if mini else 28.0
	var num: Label = $Badge/Num
	num.text = str(pts)
	if mini or shop:
		num.add_theme_font_size_override("font_size", 13 if shop else 11)
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
	var psz := _pip_px()
	for i in card.pips.size():
		var su: String = card.pips[i]
		var pip := Panel.new()
		var lit_su: bool = opts.get("lit_suits", []).has(su)
		pip.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(su), psz / 2, 2.5 if lit_su else 1.5, Tok.GOLD if lit_su else Color.BLACK))
		pip.size = Vector2(psz, psz)
		pip.mouse_filter = MOUSE_FILTER_IGNORE
		var g := Tok.icon("suit:" + su, psz * 0.6 if shop else 11.0 if mini else 16.0)
		g.position = (pip.size - g.size) / 2
		pip.add_child(g)
		if opts.get("fade_suits") and not Game.suit_held(su):  # a shop card: a suit you hold none of (the user, 2026-11-24)
			pip.modulate.a = 0.35
		pip.set_meta("cmp", "%s:pip%d" % [opts.get("tag", item), i])
		$Pips.add_child(pip)
		_pips.append(pip)
	# Station badges: a row centred on the bottom edge (placed in _place()).
	var ssz := 18.0 if mini else 26.0
	for st in card.stations:
		var b := Panel.new()
		var lit_st: bool = opts.get("lit_stations", []).has(st)
		b.add_theme_stylebox_override("panel", Tok.box(Tok.station_color(st), ssz / 2, 2.5 if lit_st else 1.5, Tok.GOLD if lit_st else Color.BLACK))
		b.custom_minimum_size = Vector2(ssz, ssz)
		b.mouse_filter = MOUSE_FILTER_IGNORE
		var g := Tok.icon(Catalog.station(st).emoji, 12.0 if mini else 17.0)
		g.material = Tok.outline(12.0 if mini else 17.0)
		var k := "%s:st%d" % [opts.get("tag", item), _stations.get_child_count()]
		b.set_meta("cmp", k)
		g.set_meta("cmp", k + "icon")
		g.position = (Vector2(ssz, ssz) - g.size) / 2
		b.add_child(g)
		_stations.add_child(b)
	_stations.set_meta("cmp", opts.get("tag", item) + ":stations")
	_stations.visible = not opts.get("no_stations", false)
	if opts.get("size"):  # the bottom-left corner circle, the pips' size
		var sb := SizeBadge.make(item, psz, 1.5)
		sb.name = "Size"
		add_child(sb)
	if opts.get("star"):  # on the picture's top-right corner
		var star := star_button(minf(16.0 if mini else 24.0, icon_px * 0.6), opts.star)
		star.name = "Star"
		star.position = Vector2(icon_px - star.size.x * 0.6, -star.size.x * 0.3)
		ic.add_child(star)
	if opts.get("on"):
		modulate = Color(0.6, 0.6, 0.6)
	resized.connect(_place)
	_place()


## The name (.mm-name): 10.5px bold, line-height 1.1, padding 1px 2px; a
## grid mini card shows one line with 14px sides. Godot gives a line the
## font's full height, so a holder sized to the CSS line boxes keeps the
## card's layout the same and the text is centred in it.
func _name_box(text: String, one_line: bool, width: float) -> Control:
	var shop: bool = opts.get("shop", false)
	var SIZE: int = SHOP_NAME if shop else 11  # Godot font sizes are whole pixels (CSS 10.5)
	var line: float = (float(SHOP_NAME) if shop else 10.5) * 1.1
	var side := 14.0 if one_line and not shop else 2.0
	var f := Tok.font(800)
	var lines := 1
	if opts.get("wrap") and text.contains(" "):  # two lines, split at the first space (the shop's wrapped names)
		text = text.substr(0, text.find(" ")) + "\n" + text.substr(text.find(" ") + 1)
		lines = 2
	if lines == 1 and width > 0 and text.contains(" ") and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Tok.MIN_TEXT).x > width - 2 * side - 2:
		var cut := _middle_space(text)  # under the smallest text on one line: two lines (Stainless Steel)
		text = text.substr(0, cut) + "\n" + text.substr(cut + 1)
		lines = 2
	var longest := ""
	for part in text.split("\n"):
		longest = part if part.length() > longest.length() else longest
	var px := Tok.fit_px(longest, f, SIZE, width - 2 * side - 2) if width > 0 else SIZE  # one line always (the user, 2026-11-23), but for wrapped names
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, (line - 2) * lines + 2 + (1 if one_line else 2))
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	holder.set_meta("cmp", opts.get("tag", item) + ":name")
	var nm := Tok.label(text, px, Tok.CARD_INK, 800)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if lines > 1:
		nm.add_theme_constant_override("line_spacing", -3)
	nm.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	nm.offset_left = side
	nm.offset_right = -side
	nm.offset_top = 1
	nm.offset_bottom = 0 if one_line else -1
	holder.add_child(nm)
	return holder


## "Lit" (part of a live combo): a 3.5px gold ring and a 10px glow, behind
## the badge (.mm-pip.lit, .mm-station.lit).
## The collection ⭐ (a found collection the hand can finish; the user,
## 2026-11-26): a gold star in 🔍's round rim, on the item picture's top
## right. A tap opens Collections on that collection (col_id), lit.
static func star_button(px: float, col_id: String) -> Control:
	var b := TextureRect.new()
	b.texture = ROUND
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(px, px)
	b.mouse_filter = MOUSE_FILTER_STOP  # its tap isn't the card's
	b.set_meta("cmp", "card:star")
	b.set_meta("collection", col_id)
	var st := Tok.star(Color("#ffd166"), px * 0.56)
	st.position = (b.size - st.size) / 2
	b.add_child(st)
	b.gui_input.connect(func(ev): if Tap.tap(ev) and App.current:
		CollectionsWindow.show_on(App.current, false, col_id))
	return b


## An item's picture px wide (k times that for BIG_ART), its box only as
## tall as the art when scaled up, so the name stays under it.
static func art(emoji: String, px: float, k := 1.0) -> TextureRect:
	var ic := Tok.icon(emoji, px * k)
	if k != 1.0 and ic.texture:
		var h := minf(px * k, px * k * ic.texture.get_height() / ic.texture.get_width())
		ic.custom_minimum_size.y = h
		ic.size.y = h
	return ic


## The space nearest the middle of text (where a name splits in two).
static func _middle_space(text: String) -> int:
	var best := -1
	for i in text.length():
		if text[i] == " " and (best < 0 or absi(i - text.length() / 2) < absi(best - text.length() / 2)):
			best = i
	return best


static func _gap(px: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	return g


## The badges that hang off the edges follow the card's size.
func _place() -> void:
	var mini: bool = opts.get("mini", false)
	var psz := _pip_px()
	var border := 3 if mini else 4
	# CSS offsets are from inside the border: top/right -3px, bottom -3px (mini -6px).
	# A tall stack (Cruise Ship, Planet: 4 suits) shrinks just enough to stay on the card.
	var room := size.y - 2 * (border - 3)
	var k := minf(1.0, (room + 2) / maxf(1.0, _pips.size() * (psz + 2)))
	for i in _pips.size():
		_pips[i].scale = Vector2(k, k)
		_pips[i].position = Vector2(size.x - border + 3 - psz * k, border - 3 + i * (psz * k + 2))
	_stations.size = _stations.get_combined_minimum_size()
	_stations.position = Vector2((size.x - _stations.size.x) / 2, size.y - border + (6 if mini else 3) - _stations.size.y)
	if opts.get("stations_right"):  # from the bottom-right corner (the left one is the shop's pin)
		_stations.position.x = size.x - border + 3 - _stations.size.x
		_stations.position.y += 4  # straddling the edge: clear of the name
	elif opts.get("stations_left"):  # the bottom-left corner, left to right (the Inventory and the Combo Lab: the user, 2026-11-27)
		_stations.position.x = border - 3
		_stations.position.y += 4
	var sb := get_node_or_null("Size") as Control
	if sb:  # bottom-left, straddling the border like the points badge; the stations centre right of it
		sb.position = Vector2(border - 3, size.y - border + 3 - psz)
		var left := sb.position.x + psz + 2
		_stations.position.x = maxf(left, left + (size.x - left - _stations.size.x) / 2 - psz / 2)


func _pip_px() -> float:
	return SHOP_CIRCLE if opts.get("shop", false) else 18.0 if opts.get("mini", false) else 27.0
