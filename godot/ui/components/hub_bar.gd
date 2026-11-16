## The bottom hub (#hub, topbar.css): a wooden bar with a brass top edge, two
## framed buttons each side (To-Do List, Inventory | Market, Items) and the
## raised Home circle in the middle, whose face says what it does now
## (Roll, Shop, Travel, Lock In, End, Map, Close; see App.home_face()).
## Emits pressed(id): "jobs", "inv", "home", "market", "codex".
class_name HubBar
extends Control

signal pressed(id: String)

const H := 65.0  # the bar itself; buttons rise above it
const SIDE_W := 72.5
const SIDE_H := 75.2
const HOME := 76.0
const FACES := {
	"roll": ["🎲", "Roll", "#3fb46c"], "shop": ["🛒", "Shop", "#b5501a"], "travel": ["🥾", "Travel", "#3aa9a0"],
	"lockin": ["🔒", "Lock In", "#8a5ce0"], "final": ["🏁", "End", "#e2b25a"], "map": ["🗺️", "Map", "#4d7cf2"],
	"close": ["⬅️", "Close", ""],
}
const SIDES := [["jobs", "To-Do List", "icon_todo"], ["inv", "Inventory", "icon_inventory"],
	["market", "Market", "icon_market"], ["codex", "Items", "icon_items"]]

var face := "map"
var active := {}  # id -> true for a lit side button (its panel is open)
var badges := {}  # id -> text of its red badge ("!")
var via_air := false  # Travel by helicopter (off the paths): 🚁 instead of 🥾

static var _ball: Shader


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()


## Where a side button's centre is (in this bar's coordinates), e.g. for
## things flying into the Inventory.
func button_center(id: String) -> Vector2:
	var side_w := (size.x - (HOME + 8)) / 4 - 4
	var i := SIDES.map(func(x): return x[0]).find(id)
	var x := 2.0 + i * (side_w + 4) + (HOME + 8 if i >= 2 else 0.0)
	return Vector2(x + side_w / 2, size.y - H - 16.2 + SIDE_H / 2)


## Shows a new state: face, lit buttons, badges.
func show_state(new_face: String, new_active: Dictionary, new_badges: Dictionary, air := false) -> void:
	face = new_face
	active = new_active
	badges = new_badges
	via_air = air
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var top := size.y - H
	var bar := HubWood.new()
	bar.position = Vector2(0, top)
	bar.size = Vector2(size.x, H)
	bar.set_meta("cmp", "hub")
	add_child(bar)
	# Side buttons share what the Home circle leaves, 2px margins each side.
	var side_w := (size.x - (HOME + 8)) / 4 - 4
	for i in 4:
		var s: Array = SIDES[i]
		var x := 2.0 + i * (side_w + 4) + (HOME + 8 if i >= 2 else 0.0)
		add_child(_side_button(s[0], s[1], s[2], Rect2(x, top - 16.2, side_w, SIDE_H)))
	add_child(_home_button(Vector2((size.x - HOME) / 2, top - 21)))


func _side_button(id: String, label: String, art: String, r: Rect2) -> Control:
	var b := Frame9.new()
	b.texture = load("res://assets/ui/hub_frame%s.webp" % ("_active" if active.get(id) else ""))
	b.position = r.position
	b.size = r.size
	b.set_meta("cmp", "hub:" + id)
	b.mouse_filter = MOUSE_FILTER_STOP
	b.gui_input.connect(_tap.bind(id))
	var tex: Texture2D = load("res://assets/ui/%s.webp" % art)
	var ic := TextureRect.new()
	ic.texture = tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size = Vector2(42.0 * tex.get_width() / tex.get_height(), 42)
	ic.position = Vector2((r.size.x - ic.size.x) / 2, 9)
	ic.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var l := _label(label, 10.5, Color("#ffe08a") if active.get(id) else Color.WHITE)
	l.position = Vector2(0, 53)
	l.size = Vector2(r.size.x, 14.2)
	b.add_child(l)
	if badges.has(id):
		b.add_child(_badge(badges[id], Vector2(r.size.x / 2 + 22 - 17, 2)))
	return b


func _home_button(at: Vector2) -> Control:
	var f: Array = FACES.get(face, FACES.map)
	var b := Control.new()
	b.position = at
	b.size = Vector2(HOME, HOME)
	b.set_meta("cmp", "hub:home")
	b.gui_input.connect(_tap.bind("home"))
	if f[2] == "":  # Close: flat pale blue-grey, deliberately inert
		var flat := Panel.new()
		flat.add_theme_stylebox_override("panel", Tok.box(Color("#d3e0f1"), HOME / 2))
		flat.size = b.size
		flat.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(flat)
	else:
		var c := Color(f[2])
		var ball := ColorRect.new()
		ball.size = b.size
		ball.mouse_filter = MOUSE_FILTER_IGNORE
		if _ball == null:
			_ball = load("res://ui/theme/ball.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _ball
		m.set_shader_parameter("light", c.lerp(Color.WHITE, 0.45))
		m.set_shader_parameter("base", c)
		m.set_shader_parameter("dark", c.lerp(Color.BLACK, 0.25))
		ball.material = m
		b.add_child(ball)
	var rim := TextureRect.new()
	rim.texture = load("res://assets/ui/clock_rim.webp")
	rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rim.stretch_mode = TextureRect.STRETCH_SCALE
	rim.position = Vector2(-5, -5)
	rim.size = b.size + Vector2(10, 10)
	rim.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(rim)
	var glyph: String = "🚁" if face == "travel" and via_air else f[0]
	var ic := Tok.icon(glyph, 37)
	if ic.texture == null:  # shortcut: no Noto image yet for this face's emoji; the font's (desktop only)
		ic.queue_free()
		ic = null
		var t := Tok.label(glyph, 37, Color.WHITE)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.position = Vector2(0, 7)
		t.size = Vector2(HOME, 44)
		b.add_child(t)
	else:
		ic.position = Vector2((HOME - 37) / 2, 12.3)
		b.add_child(ic)
	var light_label := face in ["shop", "map"]
	var l := _label(f[1], 10, Color.WHITE if light_label else Color.BLACK, light_label)
	l.position = Vector2(0, 50.3)
	l.size = Vector2(HOME, 13.5)
	b.add_child(l)
	return b


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
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		pressed.emit(id)


## The bar's wood: a dark-brown vertical gradient with faint grain lines,
## a 3px brass top edge and a soft highlight under it.
## flip: the Quark bar's copy, brass edge at the bottom.
class HubWood extends Control:
	var flip := false

	func _draw() -> void:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		g.colors = PackedColorArray([Color("#7a4a25"), Color("#5a3418"), Color("#43260f")])
		var steps := 24
		for i in steps:
			var y0 := size.y * i / steps
			var t := (i + 0.5) / steps
			draw_rect(Rect2(0, y0, size.x, size.y / steps + 1), g.sample(1.0 - t if flip else t))
		for x in range(0, int(size.x), 22):
			draw_rect(Rect2(x, 0, 3, size.y), Color(0, 0, 0, 0.05))
		if flip:
			draw_set_transform(Vector2(0, size.y), 0, Vector2(1, -1))
		draw_rect(Rect2(0, 0, size.x, 3), Color("#d9a441"))
		draw_rect(Rect2(0, 3, size.x, 2), Color(1, 0.86, 0.55, 0.25))
