## The map (renderMap(), game-mode.css): the map art filling the screen
## between the Quark bar and the hub; a node per station (navy disc in a
## brass rim: green ring where you are, gold where you've picked, grey where
## you can't go); dashed gold paths from where you are; and, for the picked
## station, the wooden card at the top (its elements, items, capstone).
## The layout is ui/screens/map.tscn: the art, and the 8 stations (MapNode)
## anchored to their spots on it, which can be dragged in the editor (the
## paths follow them). This script only shows the run's state on it.
class_name MapScreen
extends Control

const SCENE := "res://ui/screens/map.tscn"
const AREA_W := 402.0  # the map area's width on the 390px phone (it overhangs 6px each side)

static var _grey: ShaderMaterial


static func make() -> MapScreen:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Base.color = Tok.CARD
	for n in _nodes():
		n.tapped.connect(_on_node)
	$Area/Paths.draw.connect(_draw_paths)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
	_redraw()


func _nodes() -> Array:
	return $Area.get_children().filter(func(c): return c is MapNode)


func _redraw() -> void:
	if is_queued_for_deletion():
		return
	for c in $Dynamic.get_children():
		c.queue_free()
	var s := Game.state
	var ctx := Game.ctx
	var checked: bool = s.get("matChecked", false)
	var top := (QuarkTopBar.H + 4) if checked else 0.0
	# The map runs from under the Quark bar (when it's showing) to the hub.
	$Base.offset_top = top
	$Art.offset_top = top
	$Area.offset_top = top + 1
	var app := _app()
	# A station is 19.5% of the map's width (.map-node): the scene's size is for
	# the phone's 402px, so a wider screen (a tablet) scales them up.
	var k: float = $Area.size.x / AREA_W
	for n in _nodes():
		n.pivot_offset = n.size / 2
		n.scale = Vector2(k, k)
		var here: bool = n.station == s.get("lastStation")
		var reach: bool = not here and not s.get("ended") and (s.get("lastStation") == null or app == null or app.can_travel_to(n.station))
		n.show_state(here, n.station == ctx.get("selectedMapStation"), reach)
	$Area/Paths.queue_redraw()
	if checked:
		var qt := QuarkTopBar.make()
		qt.size = Vector2(size.x, QuarkTopBar.H)
		$Dynamic.add_child(qt)
	StationScreen.corner_buttons($Dynamic, false)
	if ctx.get("selectedMapStation"):  # over the Quark bar, as in the HTML game
		$Dynamic.add_child(station_card(ctx.selectedMapStation, size.x))


## Dashed paths between the stations (MAP_EDGES), wherever their nodes sit:
## bright gold out of where you are, faint white elsewhere.
func _draw_paths() -> void:
	var here = Game.state.get("lastStation")
	if here == null:
		return
	var c: Control = $Area/Paths
	var at := {}
	for n in _nodes():
		at[n.station] = n.position + n.size / 2
	for e in Data.t("MAP_EDGES"):
		if not at.has(e[0]) or not at.has(e[1]):
			continue
		var active: bool = e[0] == here or e[1] == here
		if active:  # a dark halo under the gold so it reads over the art
			_dashed(c, at[e[0]], at[e[1]], Color(0, 0, 0, 0.55), 7.2)
		_dashed(c, at[e[0]], at[e[1]], Color("#ffce54") if active else Color(1, 1, 1, 0.2), 5.2 if active else 4.2)


## stroke-dasharray 5 4.5 with round caps.
static func _dashed(c: Control, a: Vector2, b: Vector2, color: Color, w: float) -> void:
	var d := b - a
	var n := d.length()
	var u := d / n
	var t := 0.0
	while t < n:
		var e := minf(t + 5, n)
		c.draw_line(a + u * t, a + u * e, color, w)
		c.draw_circle(a + u * t, w / 2, color)
		c.draw_circle(a + u * e, w / 2, color)
		t += 9.5


## The picked station's card at the top (mapCardHTML()). Also the opening's
## capstone confirm (boxed: all corners round, no capstone line).
static func station_card(name: String, w: float, boxed := false) -> Control:
	var st := Catalog.station(name)
	var card := Control.new()
	card.set_meta("cmp", "map:card")
	var y := 14.0
	var em := Tok.icon(st.emoji, 31)
	em.position = Vector2(19, y + 0.8)
	card.add_child(em)
	var h2 := Tok.label(name, 19, Color("#fff7e0"), 800)
	h2.position = Vector2(61, y + 1)
	card.add_child(h2)
	y += 32.6 + 11
	var dice := Catalog.sorted_dice(st)
	var cw := (w - 38 - 4 * 5) / 6
	for i in dice.size():
		var chip := StationScreen.element_chip(dice[i], cw)
		chip.position = Vector2(19 + i * (cw + 4), y)
		chip.set_meta("sym", dice[i])  # the opening flies these to the Inventory
		_opens(chip, "", dice[i])
		card.add_child(chip)
	y += cw + 13.8 + 11
	# Every item sold here, icon only (owned: gold-soft square with a tick).
	var items := StationScreen.shop_entries(name).filter(func(e): return e.tier != "CAPSTONE")
	var slot := minf(25.0, (w - 38 - 5 * (items.size() - 1)) / max(1, items.size()))
	var x0 := (w - (items.size() * slot + (items.size() - 1) * 5)) / 2
	for i in items.size():
		var e: Dictionary = items[i]
		var owned := Catalog.owns(Game.state, e.name)
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD_SOFT if owned else Color.TRANSPARENT, 7))
		box.position = Vector2(x0 + i * (slot + 5), y + 9)
		box.size = Vector2(slot, slot)
		_opens(box, e.name)
		var ic := Tok.icon(e.emoji, slot - 6)
		ic.position = Vector2(3, 3)
		box.add_child(ic)
		if owned:
			var t := Tok.tick(Color.WHITE, 14, Tok.OK, Color("#3b210d"))
			t.position = Vector2(slot - 9, -5)
			box.add_child(t)
		card.add_child(box)
	y += 43 + 11
	if boxed:
		y -= 11
	# The capstone, under a dashed rule.
	var rule := Control.new()  # the dashed rule (a child: drawn over the card's wood)
	rule.visible = not boxed
	rule.position = Vector2(19, y)
	rule.size = Vector2(w - 38, 1)
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	rule.draw.connect(func(): rule.draw_dashed_line(Vector2.ZERO, Vector2(rule.size.x, 0), Tok.LINE, 1, 4))
	card.add_child(rule)
	var cap: Array = st.capstone
	var done := Catalog.owns(Game.state, cap[1])
	var cem := Tok.icon(cap[0], 28.5)
	cem.visible = not boxed
	cem.position = Vector2(19, y + 10 + 1.4)
	card.add_child(cem)
	_opens(cem, cap[1])
	var cn := Tok.label(cap[1], 20, Tok.OK if done else Color("#fff7e0"), 700)
	_opens(cn, cap[1])
	cn.visible = not boxed
	cn.position = Vector2(19 + 28.5 + 12, y + 10 + 2)
	card.add_child(cn)
	y += 0.0 if boxed else 41.3 + 14
	card.size = Vector2(w, y)
	card.draw.connect(func():
		var sb := Tok.box(Color("#4a2b13"), 16, 3, Color("#d9a441"), 10, 6, Color(0, 0, 0, 0.45))
		if not boxed:
			sb.border_width_top = 0
			sb.corner_radius_top_left = 0
			sb.corner_radius_top_right = 0
		card.draw_style_box(sb, Rect2(Vector2.ZERO, card.size)))
	return card


## A tap on c opens an item's card (or an element's).
static func _opens(c: Control, item: String, element := "") -> void:
	c.mouse_filter = MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev): if ConvertTray._tap(ev) and App.current:
		if element != "":
			App.current.show_element_card(element)
		else:
			App.current.show_card(item))


func _on_node(name: String) -> void:
	Game.ctx.selectedMapStation = name
	Game.state_changed.emit()


func _app() -> App:
	var p := get_parent()
	return p if p is App else null


## Greyscale and darker (.map-node.unreachable: grayscale(1) brightness(.55)).
static func _greyed() -> ShaderMaterial:
	if _grey == null:
		_grey = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.299, 0.587, 0.114)) * 0.55; COLOR = vec4(vec3(g), c.a); }"
		_grey.shader = sh
	return _grey
