## The HTML game's design tokens (game/css/base.css :root), fonts, and small
## drawing helpers shared by every component. Colours: ui/theme/tokens.tres.
class_name Tok

## The colours come from ui/theme/tokens.tres (edit them in the Godot
## editor's Inspector); the names stay as they were.
static var T: Tokens = load("res://ui/theme/tokens.tres")
static var INK: Color = T.ink
static var INK2: Color = T.ink2
static var MUTE: Color = T.mute
static var LINE: Color = T.line
static var LINE2: Color = T.line2
static var BG: Color = T.bg
static var CARD: Color = T.card
static var BG_SOFT: Color = T.bg_soft
static var SUNKEN: Color = T.sunken
static var OK: Color = T.ok
static var BAD: Color = T.bad
static var GOLD: Color = T.gold
static var GOLD_SOFT: Color = T.gold_soft
static var PARCHMENT: Color = T.parchment  # .mm-card face
static var CARD_INK: Color = T.card_ink
static var SHADOW: Color = T.shadow

static var _fonts := {}
static var _outlines := {}
static var _tints := {}  # colour -> its tint material


## The game's font: Nunito (chosen 2026-11-15; assets/fonts, OFL), one
## variable file drawn at any weight. Bundled, so text looks the same on every
## device and on the web, where Godot can't use the phone's own fonts.
static func font(weight := 400, spacing := 0) -> Font:
	var key := "%d/%d" % [weight, spacing]
	var path := "res://ui/theme/fonts/nunito_%d.tres" % weight  # shared with the scenes
	if not _fonts.has(key) and spacing == 0 and ResourceLoader.exists(path):
		_fonts[key] = load(path)
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load("res://assets/fonts/Nunito-VariableFont_wght.ttf")
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f.spacing_glyph = spacing  # CSS letter-spacing, whole pixels
		_fonts[key] = f
	return _fonts[key]


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


## A name label centred on a tile w wide at y: as wide as its text (at
## least the tile), so a long name spills evenly past both edges. Its own
## width is set: a label sized before it's in the tree widens to the theme's
## default font size and centres off the tile.
static func centre_name(n: Label, w: float, y: float, h: float) -> void:
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true  # its minimum width 0, so the size below holds
	var tw := n.get_theme_font("font").get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, n.get_theme_font_size("font_size")).x + 2
	var lw := maxf(w, tw)
	n.position = Vector2((w - lw) / 2, y)
	n.size = Vector2(lw, h)


## The largest font size up to px at which text fits on one line in w (a
## card's name never wraps: the user, 2026-11-23). Never below 6.
static func fit_px(text: String, f: Font, px: int, w: float) -> int:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return px if tw <= w or tw <= 0 else maxi(6, floori(px * w / tw))


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


## Draws an icon all white, keeping its shape (the suit glyphs on coloured badges).
static func white() -> ShaderMaterial:
	return tinted(Color.WHITE)


## An icon painted one colour (e.g. a suit glyph in its suit's colour).
static func tinted(color: Color) -> ShaderMaterial:
	if not _tints.has(color):
		var m := ShaderMaterial.new()
		m.shader = load("res://ui/theme/tint.gdshader")
		m.set_shader_parameter("tint", color)
		_tints[color] = m
	return _tints[color]


## A tick (✓), drawn: Nunito has none. In a coloured circle when bg is set.
## ⧉ (two overlapping squares: copy), drawn (not in Nunito).
static func copy_glyph(color: Color, px: float) -> Control:
	var c := Control.new()
	c.size = Vector2(px, px)
	c.custom_minimum_size = c.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var s := px * 0.62
		var w := maxf(1.2, px / 11.0)
		c.draw_rect(Rect2(Vector2(px - s, 0) + Vector2(w, w) / 2, Vector2(s, s) - Vector2(w, w)), color, false, w)
		c.draw_rect(Rect2(Vector2(0, px - s) + Vector2(w, w) / 2, Vector2(s, s) - Vector2(w, w)), color, false, w))
	return c


static func tick(color: Color, px: float, bg := Color.TRANSPARENT, ring := Color.TRANSPARENT) -> Control:
	var c := Control.new()
	c.size = Vector2(px, px)
	c.custom_minimum_size = c.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		if ring.a > 0:
			c.draw_circle(Vector2(px, px) / 2, px / 2 + 2, ring)
		if bg.a > 0:
			c.draw_circle(Vector2(px, px) / 2, px / 2, bg)
		var k := px / 14.0
		c.draw_polyline(PackedVector2Array([Vector2(3.5, 7.2) * k, Vector2(6, 9.8) * k, Vector2(10.5, 4.5) * k]), color, maxf(1.5, 1.8 * k), true))
	return c


## Greyscale (CSS filter:grayscale(1)): the unpinned pin.
static func grey() -> ShaderMaterial:
	if not _fonts.has("__grey"):
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); COLOR = vec4(vec3(dot(c.rgb, vec3(0.299, 0.587, 0.114))), c.a); }"
		m.shader = sh
		_fonts["__grey"] = m
	return _fonts["__grey"]
