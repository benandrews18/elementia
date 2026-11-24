## The bottom hub (#hub, topbar.css): a wooden bar with a brass top edge, two
## framed buttons each side (To-Do List, Inventory | Market, Items) and the
## raised Home circle in the middle, whose face says what it does now
## (Roll, Shop, Travel, Lock In, End, Map, Close; see App.home_face()).
## Emits pressed(id): "jobs", "inv", "home", "market", "codex".
class_name HubBar
extends Control

signal pressed(id: String)

## The layout is ui/components/hub_bar.tscn: the wood, the four framed side
## buttons (their icons and labels) and the Home circle; this places them
## across the width and shows the state (lit, badges, Home's face).
const SCENE := "res://ui/components/hub_bar.tscn"
const H := 65.0  # the bar itself; buttons rise above it
const SIDE_H := 75.2
const HOME := 76.0
const SIDES := [["jobs", "Jobs"], ["inv", "Inv"], ["market", "Market"], ["codex", "Codex"]]  # id, node

## Home's faces: id -> [emoji, label, colour ("" = flat, inert)].
@export var faces := {
	"roll": ["🎲", "Roll", "#3fb46c"], "shop": ["🛒", "Shop", "#b5501a"], "travel": ["🥾", "Travel", "#3aa9a0"],
	"lockin": ["🔒", "Lock In", "#8a5ce0"], "final": ["🏁", "End", "#e2b25a"], "map": ["🗺️", "Map", "#4d7cf2"],
	"close": ["⬅️", "Close", ""], "draw": ["🃏", "Draw", "#1c1f26"],
}
## A check with cards (card playing): the side buttons become these
## (id -> [emoji, label]); see App._hand_tap().
@export var hand_sides := {"jobs": ["🎯", "Challenge"], "inv": ["🗑️", "Discard"], "market": ["↩️", "Take Back"], "codex": ["🔒", "Lock In"]}
@export var frame: Texture2D
@export var active_frame: Texture2D  # a lit side button (its panel is open)
@export var label_color := Color.WHITE
@export var active_label_color := Color("#ffe08a")

var face := "map"
var shop_glyph := ""  # the Shop face's icon: the station you're at (else its 🛒)
var greyed := false  # Home tapped and busy (the Lock-In count): grey, its tap ignored
var active := {}  # id -> true for a lit side button (its panel is open)
var badges := {}  # id -> text of its red badge ("!")
var via_air := false  # Travel by helicopter (off the paths): 🚁 instead of 🥾
var hand := false  # a check with cards: hand_sides on the side buttons
var off := {}  # id -> true for a greyed side button (its tap still comes, the screen says why)
var _own := {}  # id -> [icon, label]: the side buttons' own, for after a check

static var _ball: Shader


static func make() -> HubBar:
	return load(SCENE).instantiate()


func _ready() -> void:
	for s in SIDES:
		get_node(s[1]).gui_input.connect(_tap.bind(s[0]))
		_own[s[0]] = [get_node(s[1] + "/Icon").texture, get_node(s[1] + "/Label").text]
	$Home.gui_input.connect(_tap.bind("home"))
	resized.connect(_build)
	_build()


## A button by id ("home", or a side one: inv, jobs, market, codex), e.g. for
## a tip's spotlight.
func button(id: String) -> Control:
	if id == "home":
		return $Home
	for s in SIDES:
		if s[0] == id:
			return get_node(s[1])
	return null


## Where a side button's centre is (in this bar's coordinates), e.g. for
## things flying into the Inventory.
func button_center(id: String) -> Vector2:
	var side_w := (size.x - (HOME + 8)) / 4 - 4
	var i := SIDES.map(func(x): return x[0]).find(id)
	var x := 2.0 + i * (side_w + 4) + (HOME + 8 if i >= 2 else 0.0)
	return Vector2(x + side_w / 2, size.y - H - 16.2 + SIDE_H / 2)


## introInvLit: a side button lit and drawn above everything (a window's dim
## included), glowing gold, while things fly into it; off puts it back.
func spotlight(id: String, on: bool) -> void:
	var b: Frame9 = button(id)
	b.z_index = 1 if on else 0
	b.texture = active_frame if on or active.get(id) else frame
	b.get_node("Label").add_theme_color_override("font_color", active_label_color if on or active.get(id) else label_color)
	var glow := b.get_node_or_null("Glow")
	if on and glow == null:
		glow = Panel.new()
		glow.name = "Glow"
		glow.show_behind_parent = true
		glow.mouse_filter = MOUSE_FILTER_IGNORE
		glow.add_theme_stylebox_override("panel", Tok.box(Color(1, 0.84, 0.47, 0.35), 14, 0, Color.BLACK, 14, 0, Color(1, 0.84, 0.47, 0.8)))
		glow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		b.add_child(glow)
	elif not on and glow:
		glow.queue_free()


## punchInventory(): a quick bounce as something lands in a button.
func punch(id: String) -> void:
	var b := button(id)
	b.pivot_offset = b.size / 2
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.32, 1.32), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


## Shows a new state: face, lit buttons, badges (and a check with cards:
## hand_sides, some greyed).
func show_state(new_face: String, new_active: Dictionary, new_badges: Dictionary, air := false, hand_on := false, new_off := {}) -> void:
	face = new_face
	active = new_active
	badges = new_badges
	via_air = air
	hand = hand_on
	off = new_off
	_build()


func _build() -> void:
	var top := size.y - H
	$Wood.position = Vector2(0, top)
	$Wood.size = Vector2(size.x, H)
	# Side buttons share what the Home circle leaves, 2px margins each side.
	var side_w := (size.x - (HOME + 8)) / 4 - 4
	for i in 4:
		var x := 2.0 + i * (side_w + 4) + (HOME + 8 if i >= 2 else 0.0)
		_side_button(SIDES[i][0], get_node(SIDES[i][1]), Rect2(x, top - 16.2, side_w, SIDE_H))
	_home_button(Vector2((size.x - HOME) / 2, top - 21))


func _side_button(id: String, b: Frame9, r: Rect2) -> void:
	b.texture = active_frame if active.get(id) else frame
	b.position = r.position
	b.size = r.size
	b.modulate = Color(0.6, 0.6, 0.6, 0.75) if off.get(id) else Color.WHITE
	var ic: TextureRect = b.get_node("Icon")
	if not _own.is_empty():
		ic.texture = Data.icon(hand_sides[id][0]) if hand else _own[id][0]
		b.get_node("Label").text = hand_sides[id][1] if hand else _own[id][1]
	var tex := ic.texture
	ic.size = Vector2(42.0 * tex.get_width() / tex.get_height(), 42)
	ic.position = Vector2((r.size.x - ic.size.x) / 2, 9)
	b.get_node("Label").add_theme_color_override("font_color", active_label_color if active.get(id) else label_color)
	for c in b.get_children():
		if c.has_meta("badge"):
			c.queue_free()
	if badges.has(id):
		var bd := _badge(badges[id], Vector2(r.size.x / 2 + 22 - 17, 2))
		bd.set_meta("badge", true)
		b.add_child(bd)


func _home_button(at: Vector2) -> void:
	var f: Array = faces.get(face, faces.map)
	var b: Control = $Home
	b.position = at
	$Home/Flat.visible = f[2] == ""  # Close: flat pale blue-grey, deliberately inert
	$Home/Ball.visible = f[2] != ""
	if f[2] != "":
		var c := Color("#8e8e8e") if greyed else Color(f[2])
		if _ball == null:
			_ball = load("res://ui/theme/ball.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _ball
		m.set_shader_parameter("light", c.lerp(Color.WHITE, 0.45))
		m.set_shader_parameter("base", c)
		m.set_shader_parameter("dark", c.lerp(Color.BLACK, 0.25))
		$Home/Ball.material = m
	var glyph: String = "🚁" if face == "travel" and via_air else shop_glyph if face == "shop" and shop_glyph != "" else f[0]
	var tex := Data.icon(glyph)
	$Home/Icon.texture = tex
	$Home/Icon.visible = tex != null
	$Home/Glyph.visible = tex == null  # shortcut: no Noto image yet for this face's emoji; the font's (desktop only)
	$Home/Glyph.text = glyph
	var light_label := face in ["shop", "map", "draw"]  # Draw: a very dark ball, white text (the user, 2026-11-23)
	var l: Label = $Home/Label
	l.text = f[1]
	l.add_theme_color_override("font_color", Color.WHITE if light_label else Color.BLACK)
	l.add_theme_color_override("font_shadow_color", Color.BLACK if light_label else Color.TRANSPARENT)


func _label(text: String, px: float, color: Color, shadow := true) -> Label:
	var l := Tok.label(text, px, color, 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color.BLACK)
		l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## The red "!" bubble (.hub-badge).
static func _badge(text: String, at: Vector2) -> Control:
	var l := Tok.label(text, 10, Color.WHITE, 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", Tok.box(Tok.BAD, 8.5, 2, Tok.CARD))
	l.position = at - Vector2(2, 2)
	l.size = Vector2(17 + 4, 17 + 4)
	return l


func _tap(ev: InputEvent, id: String) -> void:
	if Tap.tap(ev):
		pressed.emit(id)
