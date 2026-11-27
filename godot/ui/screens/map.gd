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
	gui_input.connect(_on_map_tap)
	Game.state_changed.connect(_redraw)
	resized.connect(_redraw)
	var fresh := fresh_stations()
	if Juice.on():
		for st in fresh:
			_pending[st] = true
	_redraw()
	_reveal(fresh)


## The map discovered as you go (step 28, the user 2026-11-26): only the
## stations found show (Catalog.found_stations: worked out from the visits,
## nothing saved). Back from a station, what leaving it found is new: its
## paths grow out of it and each station bounces in as its path arrives.
var _pending := {}  # station -> true until it bounces in
var _grow := {}  # station -> 0..1: the path from here growing toward it


## What leaving this station found: found now, not found without it.
static func fresh_stations() -> Array:
	var s := Game.state
	var here = s.get("lastStation")
	if here == null or Game.ctx.get("awaitingStart"):
		return []
	var before := Catalog.found_stations(s, Util.get_or(s, "visitedStations", {}).keys().filter(func(v): return v != here))
	return Catalog.found_stations(s).keys().filter(func(st): return not before.has(st))


func _reveal(fresh: Array) -> void:
	if _pending.is_empty():
		return
	var adj: Array = Data.t("MAP_ADJ").get(Game.state.lastStation, [])
	var badges: Control = $Area/Badges
	badges.modulate.a = 0.0
	var i := 0
	var last := 0.0
	for st in fresh:
		var n: MapNode = _node(st)
		var start := 0.3 + i * 0.14
		var tw: Tween = n.create_tween()
		tw.tween_interval(start)
		if adj.has(st):  # its path grows out of here first
			_grow[st] = 0.0
			tw.tween_method(func(v: float):
				_grow[st] = v
				$Area/Paths.queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			_pending.erase(st)
			_grow.erase(st)
			$Area/Paths.queue_redraw())
		var k: float = $Area.size.x / AREA_W
		tw.tween_property(n, "scale", Vector2(k, k), 0.4).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last = maxf(last, start + 0.45 + 0.4)
		i += 1
	var bt: Tween = badges.create_tween()
	bt.tween_interval(last)
	bt.tween_property(badges, "modulate:a", 1.0, 0.25)


func _node(st: String) -> MapNode:
	for n in _nodes():
		if n.station == st:
			return n
	return null


func _nodes() -> Array:
	return $Area.get_children().filter(func(c): return c is MapNode)


var stale := false  # a redraw skipped while covered (App.screen_covered())


func _redraw() -> void:
	if is_queued_for_deletion():
		return
	if App.current and App.current.screen_covered():  # under the Display Mat: redrawn when it closes
		stale = true
		return
	stale = false
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
	var found := Catalog.found_stations(s)
	for n in _nodes():
		n.pivot_offset = n.size / 2
		n.scale = Vector2.ZERO if _pending.has(n.station) else Vector2(k, k)
		var here: bool = n.station == s.get("lastStation")
		var reach: bool = not here and not s.get("ended") and (s.get("lastStation") == null or app == null or app.can_travel_to(n.station))
		n.show_state(here, n.station == ctx.get("selectedMapStation"), reach)
		n.visible = here or (not ctx.get("awaitingStart") and found.has(n.station))  # the opening: only where you start
	$Area/Paths.visible = not ctx.get("awaitingStart")
	$Area/Paths.queue_redraw()
	_badges(k)
	if checked:
		var qt := QuarkTopBar.make()
		qt.size = Vector2(size.x, QuarkTopBar.H)
		$Dynamic.add_child(qt)
	if s.get("lastStation") != null:  # the turn clock, top-left (not on the first pick)
		var clock := TurnClock.make(int(s.get("visits", 0)))
		clock.position = Vector2(8, top + 4)
		clock.mouse_filter = MOUSE_FILTER_STOP
		clock.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: ClockInfo.show_on(App.current))
		$Dynamic.add_child(clock)
	StationScreen.corner_buttons($Dynamic, true)  # Settings from every screen (the user, 2026-11-26)
	if ctx.get("selectedMapStation"):  # over the Quark bar, as in the HTML game
		$Dynamic.add_child(station_card(ctx.selectedMapStation, size.x))


## The tracked item's marks, over the station circles (the user: the HTML had
## them behind, half hidden; renderMap()): its
## own station gets a gold badge with its icon (top-left), stations selling
## anything it still needs a small 🔍 (top-right). None on the first pick.
## A tap on either says what it means in a small bubble (the user, 2026-11-23).
func _badges(k: float) -> void:
	var holder: Control = $Area/Badges
	for c in holder.get_children():
		c.queue_free()
	var t = Game.ctx.get("tracked")
	var e = Catalog.entry(t) if t else null
	if e == null or Game.state.get("lastStation") == null or Game.ctx.get("awaitingStart"):
		return
	var comps := {}
	for n in Catalog.still_needed(Game.state, t):
		for x in Data.t("ENTRIES"):
			if x.name == n:
				comps[x.station] = true
	var off: float = $Area.size.x * 0.066  # margin-left/top:-6.6% (of the map's width)
	for n: MapNode in _nodes():
		if not n.visible:  # not found yet (step 28)
			continue
		var c := n.position + n.size / 2
		if n.station == e.station:
			var b := Panel.new()
			b.add_theme_stylebox_override("panel", Tok.box(Tok.CARD, 18, 2.5, Tok.GOLD, 4, 1))
			b.size = Vector2(36, 36) * k
			b.position = c + Vector2(-off, -off) - b.size / 2
			var ic := Tok.icon(e.emoji, 21 * k)
			ic.position = (b.size - ic.size) / 2
			b.add_child(ic)
			holder.add_child(b)
			_on_badge(b, "You are {🔍} tracking {%s}!" % e.emoji)
		if comps.has(n.station):
			var g := TextureRect.new()
			g.texture = load("res://assets/ui/btn_search.webp")
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.size = Vector2(28, 28) * k
			g.position = c + Vector2(off, -off) - g.size / 2
			holder.add_child(g)
			_on_badge(g, "Components for {%s} are here!" % e.emoji)


func _on_badge(b: Control, says: String) -> void:
	b.mouse_filter = MOUSE_FILTER_STOP  # the tap is the badge's, not the station's under it
	for c in b.get_children():
		c.mouse_filter = MOUSE_FILTER_IGNORE
	b.gui_input.connect(func(ev): if Tap.tap(ev): _say(b, says))


var _bubble: Control  # the badge's words showing (one at a time)


## A small dark bubble just above at, saying text ({emoji}: its image),
## kept on screen; gone after a few seconds.
func _say(at: Control, text: String) -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	var box := PanelContainer.new()
	var sb := Tok.box(Color("#2b1d0e"), 14, 2, Tok.GOLD, 6, 4, Color(0, 0, 0, 0.4))
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	box.add_theme_stylebox_override("panel", sb)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.scroll_active = false
	t.add_theme_color_override("default_color", Color.WHITE)
	t.add_theme_font_size_override("normal_font_size", 14)
	t.text = ParchDialog.emojify(text, 18)
	t.mouse_filter = MOUSE_FILTER_IGNORE
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(t)
	add_child(box)
	box.size = box.get_combined_minimum_size()
	var r := at.get_global_rect()
	var p := Vector2(r.get_center().x - box.size.x / 2, r.position.y - box.size.y - 6) - global_position
	box.position = Vector2(clampf(p.x, 8, size.x - box.size.x - 8), maxf(p.y, 8))
	_bubble = box
	Juice.pop_in(box)
	box.create_tween().tween_callback(box.queue_free).set_delay(2.5)  # dies with the box (a timer's lambda would call into a freed one)


## Dashed paths between the stations (MAP_EDGES), wherever their nodes sit:
## bright gold out of where you are, faint white elsewhere.
func _draw_paths() -> void:
	var here = Game.state.get("lastStation")
	if here == null:
		return
	var c: Control = $Area/Paths
	var at := {}
	for n in _nodes():
		if n.visible:  # found stations only (step 28)
			at[n.station] = n.position + n.size / 2
	for e in Data.t("MAP_EDGES"):
		if not at.has(e[0]) or not at.has(e[1]):
			continue
		var growing = e[1] if e[0] == here and _grow.has(e[1]) else e[0] if e[1] == here and _grow.has(e[0]) else null
		if growing != null:  # step 28: out of here toward a station just found
			var tip: Vector2 = at[here].lerp(at[growing], _grow[growing])
			if _grow[growing] > 0.01:
				_dashed(c, at[here], tip, Color(0, 0, 0, 0.55), 7.2)
				_dashed(c, at[here], tip, Color("#ffce54"), 5.2)
			continue
		if _pending.has(e[0]) or _pending.has(e[1]):
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
	var tname = Game.ctx.get("tracked")
	var tracked = Catalog.entry(tname) if tname else null
	var right := w
	if not boxed:  # on the map: Settings at the title row's end (the card covers the corner gear)
		var gear := StationScreen.gear_button(34)
		gear.position = Vector2(w - 19 - 34, y)
		card.add_child(gear)
		right -= 42
	if tracked != null:  # .mc-tracked-wrap: the 🔍 circle and a gold pill naming it, top right
		card.add_child(_tracked_tag(tracked, right, y))
	var job := {}  # the tracked item and what it still needs: gold rings below
	if tracked != null:
		job[tname] = true
		for n in Catalog.still_needed(Game.state, tname):
			job[n] = true
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
	# Every item sold here, icon only, a thin dark edge round each picture (owned: a tick; no
	# square behind it, the user 2026-11-26);
	# bigger than before (36 px), rows of 5, each row centred (the user, 2026-11-26).
	var items := StationScreen.shop_entries(name).filter(func(e): return e.tier != "CAPSTONE")
	const PER := 5
	const GAP := 8.0
	var slot := minf(36.0, (w - 38 - GAP * (PER - 1)) / PER)  # 50 was too large (the user)
	var rows := ceili(items.size() / float(PER))
	for i in items.size():
		var e: Dictionary = items[i]
		var owned := Catalog.owns(Game.state, e.name)
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 7))
		if job.has(e.name):  # .station-item-icon.job-highlight
			box.add_theme_stylebox_override("panel", Tok.box(Color.TRANSPARENT, 7, 3, Tok.GOLD, 10, 0, Color(0.886, 0.698, 0.353, 0.55)))
		var in_row := mini(PER, items.size() - i / PER * PER)
		var x0 := (w - (in_row * slot + (in_row - 1) * GAP)) / 2
		box.position = Vector2(x0 + i % PER * (slot + GAP), y + 9 + i / PER * (slot + GAP))
		box.size = Vector2(slot, slot)
		_opens(box, e.name)
		var ic := Tok.icon(e.emoji, slot - 6)
		ic.position = Vector2(3, 3)
		ic.material = Tok.outline(slot - 6)
		box.add_child(ic)
		if owned:
			var t := Tok.tick(Color.WHITE, 16, Tok.OK, Color("#3b210d"))
			t.position = Vector2(slot - 10, -6)
			box.add_child(t)
		card.add_child(box)
	y += rows * (slot + GAP) - GAP + 18 + 11
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
## The tracked item on the station card's top row: the 🔍 button's circle
## overlapping a gold pill with its icon and name (at most half the card).
static func _tracked_tag(e: Dictionary, w: float, y: float) -> Control:
	var tag := Control.new()
	tag.mouse_filter = MOUSE_FILTER_IGNORE
	var name_l := Tok.label(e.name, 12.5, Tok.INK, 800)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var full := name_l.get_theme_font("font").get_string_size(e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_l.get_theme_font_size("font_size")).x
	var nw := minf(full, w / 2 - 34 + 12 - 16 - 15 - 6 - 10 - 6)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", Tok.box(Tok.GOLD_SOFT, 14, 3, Tok.GOLD))
	pill.size = Vector2(16 + 15 + 6 + nw + 10, 28)
	pill.position = Vector2(34 - 12, 3)
	var ic := Tok.icon(e.emoji, 15)
	ic.position = Vector2(16, (28 - 15) / 2.0)
	pill.add_child(ic)
	name_l.size = Vector2(nw, 28)
	name_l.position = Vector2(16 + 15 + 6, 0)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(name_l)
	tag.add_child(pill)
	var glass := TextureRect.new()
	glass.texture = load("res://assets/ui/btn_search.webp")
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.size = Vector2(34, 34)
	tag.add_child(glass)
	tag.size = Vector2(pill.position.x + pill.size.x, 34)
	tag.position = Vector2(w - 19 - tag.size.x, y)
	return tag


static func _opens(c: Control, item: String, element := "") -> void:
	c.mouse_filter = MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev): if Tap.tap(ev) and App.current:
		if element != "":
			App.current.show_element_card(element)
		else:
			App.current.show_card(item))


func _on_node(name: String) -> void:
	Game.ctx.selectedMapStation = name
	Game.state_changed.emit()


## A tap on the map itself (not a station, not the card) puts the picked
## station's card away.
func _on_map_tap(ev: InputEvent) -> void:
	if not Tap.tap(ev):
		return
	Juice.dust(self, get_global_transform().affine_inverse() * ev.global_position)  # off a station: a dust poof
	if App.current and App.current.panel == "pins":  # the pins tray goes too (the user, 2026-11-23)
		App.current.close_panel()
	if Game.ctx.get("selectedMapStation"):
		Game.ctx.selectedMapStation = null
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
