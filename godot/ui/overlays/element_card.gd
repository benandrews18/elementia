## An element's card (showElCardPop(), #elCardPop): white, framed thick in the
## element's colour; its atomic number in bubbles top-left and bottom-right,
## its suit glyph top-right and bottom-left; the symbol, the name, the suit on
## a pill. The only place the atomic number shows. A tap closes it.
## The layout is ui/overlays/element_card.tscn (the bubbles' look: `bubble`);
## this colours it for the element.
class_name ElementCard
extends Control

const SCENE := "res://ui/overlays/element_card.tscn"

## The four corner bubbles (drawn under their numbers and glyphs).
@export var bubble: StyleBox

var sym := ""


static func open(on: Control, s: String) -> ElementCard:
	var p: ElementCard = load(SCENE).instantiate()
	p.sym = s
	p.size = on.size
	on.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for n in [$Dim, $Card]:
		n.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
	var card: Panel = $Card
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	sb.border_color = color
	card.add_theme_stylebox_override("panel", sb)
	var bub: StyleBoxFlat = bubble.duplicate()
	bub.border_color = color
	# The bubbles: the four corner boxes as the scene places them (drawn over
	# the frame, under the numbers and glyphs).
	var boxes: Array = [$Card/NumTL, $Card/NumBR, $Card/GlyphTR, $Card/GlyphBL].map(func(n): return Rect2(n.position, n.size))
	card.draw.connect(func():
		for r in boxes:
			card.draw_style_box(bub, r))
	var num := str(int(Data.t("ATOMIC_NUMBER").get(sym, 0)))
	$Card/NumTL.text = num
	$Card/NumBR.text = num
	var big := suit == "metal"  # metal's glyph is drawn 1.5x
	for g: TextureRect in [$Card/GlyphTR, $Card/GlyphBL]:
		var box := Rect2(g.position, g.size)
		var inner := (box.size.x - 20) * (0.87 if big else 0.58)  # of the bubble inside its 10px ring
		g.texture = Data.icon("suit:" + suit) if suit != "" else null
		g.size = Vector2(inner, inner)
		g.position = box.get_center() - g.size / 2
	$Card/Sym.text = sym
	$Card/Name.text = Data.t("ELEMENT_NAMES").get(sym, sym)
	# A Godot line is the font's full height, taller than the CSS line box:
	# centre each on the box the scene gives it (its top and height there).
	for l: Label in [$Card/Sym, $Card/Name]:
		var box_top := l.offset_top
		var box_h := l.offset_bottom - l.offset_top
		var h := l.get_minimum_size().y
		l.offset_top = box_top + (box_h - h) / 2
		l.offset_bottom = l.offset_top + h
	var pill: Label = $Card/Pill
	pill.text = String(Data.t("ELEMENT_SUIT_LABEL").get(suit, "")).to_upper()
	pill.visible = pill.text != ""
	pill.add_theme_stylebox_override("normal", Tok.box(color, 13))
	var pw := pill.get_theme_font("font").get_string_size(pill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pill.get_theme_font_size("font_size")).x + 28
	pill.size.x = pw
	pill.position.x = (card.size.x - pw) / 2
	card.position = Vector2((size.x - card.size.x) / 2, maxf(20, (size.y - HubBar.H - card.size.y) / 2))
