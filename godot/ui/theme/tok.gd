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


## The HTML game's font stack (base.css): the device's own UI font, so text
## matches it letter for letter. shortcut: SystemFont finds nothing on the
## web export (falls back to Godot's font); bundle a font before M3's preview.
static func font(weight := 400) -> Font:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = weight
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
