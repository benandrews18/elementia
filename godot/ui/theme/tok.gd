## The HTML game's design tokens (game/css/base.css :root), fonts, and small
## drawing helpers shared by every component. Change a colour here, once.
class_name Tok

const INK := Color("#e8edf4")
const INK2 := Color("#b3becd")
const MUTE := Color("#7d8899")
const LINE := Color("#2a5a72")
const LINE2 := Color("#1c4257")
const BG := Color("#0f2733")
const CARD := Color("#163544")
const BG_SOFT := Color("#122e3c")
const SUNKEN := Color("#1c4257")
const OK := Color("#3fb46c")
const BAD := Color("#f0674c")
const GOLD := Color("#e2b25a")
const GOLD_SOFT := Color("#3a2e14")
const PARCHMENT := Color("#f2e6cc")  # .mm-card face
const CARD_INK := Color("#181614")
const SHADOW := Color(0, 0, 0, 0.45)

static var _fonts := {}
static var _outlines := {}


## The game's font: Nunito (chosen 2026-11-15; assets/fonts, OFL), one
## variable file drawn at any weight. Bundled, so text looks the same on every
## device and on the web, where Godot can't use the phone's own fonts.
static func font(weight := 400) -> Font:
	if not _fonts.has(weight):
		var f := FontVariation.new()
		f.base_font = load("res://assets/fonts/Nunito-VariableFont_wght.ttf")
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = f
	return _fonts[weight]


static func suit_color(suit: String) -> Color:
	return Color(Data.t("SUIT_COLOR").get(suit, "#8a94a6"))


static func station_color(station: String) -> Color:
	return Color(Data.t("DATA").suits[Catalog.station(station).suit].color)


## A rounded box style (CSS background + border + border-radius + box-shadow).
static func box(bg: Color, radius: float, border := 0.0, border_color := Color.BLACK,
		shadow_size := 0, shadow_y := 0.0, shadow_color := Color(0, 0, 0, 0.35)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.set_border_width_all(int(round(border)))
	s.border_color = border_color
	s.shadow_size = shadow_size
	s.shadow_offset = Vector2(0, shadow_y)
	s.shadow_color = shadow_color
	s.anti_aliasing = true
	return s


## A label in the game's font.
static func label(text: String, size: float, color: Color, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", int(round(size)))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## An icon by its key (an item's emoji, __NAME__, suit:x), sized to fit.
static func icon(key: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Data.icon(key)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## The --icon-outline look: a dark edge around the shape of an icon drawn
## icon_px wide. CSS stacks eight 0.45-0.6px drop-shadows, each thickening
## the last, so the edge it draws is about 1.5px.
static func outline(icon_px: float) -> ShaderMaterial:
	if not _outlines.has(icon_px):
		var m := ShaderMaterial.new()
		m.shader = load("res://ui/theme/icon_outline.gdshader")
		m.set_shader_parameter("width", 1.5 / icon_px)
		_outlines[icon_px] = m
	return _outlines[icon_px]


## A five-point star, drawn (Nunito has no ★, and the web has no fallback font).
static func star(color: Color, px: float) -> Control:
	var c := Control.new()
	c.size = Vector2(px, px)
	c.custom_minimum_size = c.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var pts := PackedVector2Array()
		for i in 10:
			var r := px * (0.5 if i % 2 == 0 else 0.2)
			var a := -PI / 2 + i * PI / 5
			pts.append(Vector2(px / 2, px / 2 + px * 0.04) + Vector2(cos(a), sin(a)) * r)
		c.draw_colored_polygon(pts, color))
	return c


## A circular arrow (↺, or ↻ when clockwise), drawn: Nunito has neither.
static func loop_arrow(color: Color, px: float, clockwise := false) -> Control:
	var c := Control.new()
	c.size = Vector2(px, px)
	c.custom_minimum_size = c.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var mid := Vector2(px, px) / 2
		var r := px * 0.34
		var w := px * 0.13
		# The arc leaves a gap at the top; the arrowhead sits on one end of it.
		var a0 := -PI / 2 + 0.55
		var a1 := -PI / 2 + TAU - 0.15
		if clockwise:
			c.draw_set_transform(Vector2(px, 0), 0, Vector2(-1, 1))
		c.draw_arc(mid, r, a0, a1, 24, color, w, true)
		var tip := mid + Vector2(cos(a0), sin(a0)) * r
		var dir := Vector2(-sin(a0), cos(a0))  # along the arc, away from the gap
		var out := Vector2(cos(a0), sin(a0))
		c.draw_colored_polygon(PackedVector2Array([tip - dir * w * 2.2, tip + out * w * 1.8 + dir * w * 0.6, tip - out * w * 1.8 + dir * w * 0.6]), color))
	return c
