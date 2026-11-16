## The map (renderMap(), game-mode.css): the map art filling the screen
## between the Quark bar and the hub; a node per station (navy disc in a
## brass rim: green ring where you are, gold where you've picked, grey where
## you can't go); dashed gold paths from where you are; and, for the picked
## station, the wooden card at the top (its elements, items, capstone).
class_name MapScreen
extends Control

const NODE := 0.195  # node width, share of the map's width
const RIM := preload("res://assets/ui/clock_rim.webp")

static var _grey: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
	_redraw()


func _redraw() -> void:
	if is_queued_for_deletion():
		return
	for c in get_children():
		c.queue_free()
	var s := Game.state
	var ctx := Game.ctx
	var checked: bool = s.get("matChecked", false)
	var top := (QuarkTopBar.H + 4) if checked else 0.0
	# The map: 6px past each side, from under the Quark bar down to the hub.
	var r := Rect2(-6, top, size.x + 12, size.y - HubBar.H - top)
	var base := ColorRect.new()
	base.color = Tok.CARD
	base.position = r.position
	base.size = r.size
	add_child(base)
	var art := TextureRect.new()
	art.texture = load("res://assets/backdrops/diamond_map_full.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.position = r.position
	art.size = r.size
	art.modulate.a = 0.96
	art.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(art)
	var nodes := Rect2(r.position + Vector2(0, 1), r.size - Vector2(0, 2))  # inside the 1px borders
	var here = s.get("lastStation")
	if here != null:
		add_child(_paths(nodes, here))
	var pos: Dictionary = Data.t("MAP_NODE_POS")
	for name in pos:
		add_child(_node(name, _center(nodes, name), nodes.size.x * NODE))
	if checked:
		var qt := QuarkTopBar.new()
		qt.size = Vector2(size.x, QuarkTopBar.H)
		add_child(qt)
	StationScreen.corner_buttons(self, false)
	if ctx.get("selectedMapStation"):  # over the Quark bar, as in the HTML game
		add_child(station_card(ctx.selectedMapStation, size.x))


## A node's centre: its MAP_NODE_POS percentage, nudged down by
## MAP_NODE_MM_SHIFT millimetres (mapNodeTopStyle()).
static func _center(r: Rect2, name: String) -> Vector2:
	var p: Array = Data.t("MAP_NODE_POS")[name]
	var mm: float = Data.t("MAP_NODE_MM_SHIFT").get(name, 0)
	return r.position + Vector2(p[0] / 100.0 * r.size.x, p[1] / 100.0 * r.size.y + mm * float(Data.t("MM_TO_PX")))


## Dashed paths: bright gold out of where you are, faint white elsewhere.
func _paths(r: Rect2, here: String) -> Control:
	var c := Control.new()
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	c.draw.connect(func():
		for e in Data.t("MAP_EDGES"):
			var a := _center(r, e[0])
			var b := _center(r, e[1])
			var active: bool = e[0] == here or e[1] == here
			if active:  # a dark halo under the gold so it reads over the art
				_dashed(c, a, b, Color(0, 0, 0, 0.55), 7.2)
			_dashed(c, a, b, Color("#ffce54") if active else Color(1, 1, 1, 0.2), 5.2 if active else 4.2))
	return c


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


func _node(name: String, at: Vector2, d: float) -> Control:
	var s := Game.state
	var here: bool = name == s.get("lastStation")
	var app := _app()
	var reach: bool = not here and not s.get("ended") and (s.get("lastStation") == null or app == null or app.can_travel_to(name))
	var picked: bool = name == Game.ctx.get("selectedMapStation")
	var n := Control.new()
	n.position = at - Vector2(d, d) / 2
	n.size = Vector2(d, d)
	n.set_meta("cmp", "map:" + name)
	n.gui_input.connect(_on_node.bind(name))
	n.draw.connect(func():
		var mid := Vector2(d, d) / 2
		if picked:  # 8px gold ring and glow
			n.draw_circle(mid, d / 2 + 14, Color(Tok.GOLD, 0.18))
			n.draw_circle(mid, d / 2 + 8, Tok.GOLD)
		elif here:  # 4px green ring and glow
			n.draw_circle(mid, d / 2 + 12, Color(Tok.OK, 0.2))
			n.draw_circle(mid, d / 2 + 4, Tok.OK)
		n.draw_circle(mid, d / 2 * 0.84, Color("#122e3c").darkened(0.45 if not reach and not here else 0.0)))
	var rim := TextureRect.new()
	rim.texture = RIM
	rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rim.stretch_mode = TextureRect.STRETCH_SCALE
	rim.size = Vector2(d, d)
	rim.mouse_filter = MOUSE_FILTER_IGNORE
	if not reach and not here:
		rim.material = _greyed()
	n.add_child(rim)
	var ic := Tok.icon(Catalog.station(name).emoji, d * 0.5)
	ic.position = (n.size - ic.size) / 2
	if not reach and not here:
		ic.material = _greyed()
	n.add_child(ic)
	if here:
		n.add_child(_here_label(d))
	return n


## "YOU ARE HERE" on its brass pill, under the node.
func _here_label(d: float) -> Control:
	var text := "YOU ARE HERE"
	var f := Tok.font(900)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var pill := Control.new()
	pill.size = Vector2(tw + 24, 22.2)
	pill.position = Vector2((d - pill.size.x) / 2, d + 6)
	pill.mouse_filter = MOUSE_FILTER_IGNORE
	var tex: Texture2D = load("res://assets/ui/pill_short.webp")
	pill.draw.connect(func():
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(52)
		var k := 13.0 / 52.0
		pill.draw_set_transform(Vector2.ZERO, 0, Vector2(k, k))
		pill.draw_style_box(sb, Rect2(Vector2.ZERO, pill.size / k))
		pill.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE))
	var l := Tok.label(text, 10.5, Color.WHITE, 900)
	l.add_theme_font_override("font", f)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.size = pill.size
	pill.add_child(l)
	pill.set_meta("cmp", "map:here")
	return pill


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
		box.mouse_filter = MOUSE_FILTER_IGNORE
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
	var cn := Tok.label(cap[1], 20, Tok.OK if done else Color("#fff7e0"), 700)
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


func _on_node(ev: InputEvent, name: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
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
