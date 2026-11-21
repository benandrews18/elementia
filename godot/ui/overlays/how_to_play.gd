## The opening's quick how-to-play (classicTutSlides(), #classicTut): three
## slides on a navy card, one idea a line, examples from the real game data:
## the goal (the 8 capstones), gather & craft (elements spent, items kept),
## the Display Mat (Quarks earn dice, combos multiply). Next / "Let's play";
## a tap on the slide also goes on; "✕ Hide" skips it for good.
class_name HowToPlay
extends Control

const GOLD_TEXT := "#f5c04a"
const EDGE := Color("#2a5a72")

## The layout is ui/overlays/how_to_play.tscn (the card, ✕ Hide, the dots,
## Next); the slides' examples are built from the game data, their words are
## below ([b]...[/b]: bold, in gold).
const SCENE := "res://ui/overlays/how_to_play.tscn"

## The current slide's dot (the others keep the scene's).
@export var dot_on: StyleBox
@export var next_text := "Next"
@export var last_text := "Let's play"
@export_group("Slide 1: the goal")
@export var goal_kicker := "The goal"
@export var goal_line := "Discover and craft the 8 [b]Capstones[/b]"
@export_group("Slide 2: gather & craft")
@export var gather_kicker := "Gather & craft"
@export var gather_note := "Every station has its own pool of elements"
@export var spent_text := "spent"
@export var kept_text := "∞ kept"
@export_multiline var gather_line := "Spend elements like currency.\n[b]Item cards are yours forever![/b]"
@export_group("Slide 3: the Display Mat")
@export var mat_kicker := "Display Mat"
@export var mat_line := "Arrange a [b]Display Mat[/b] to earn [b]Quark Points[/b]"
@export var combo_station := "3+ from the [b]same station[/b]"
@export var combo_suit := "3+ of the [b]same suit[/b]"
@export var combo_shared := "3+ that [b]share an item[/b]"
@export var combo_recipe := "An item with its recipe = [b]2× points[/b]"
@export var combo_collection := "Secret [b]collections[/b] for bonus Quarks"
@export var turns_text := "%d Turns in a game!"

var on_done: Callable
var _i := 0
var _dot_off: StyleBox


static func make() -> HowToPlay:
	return load(SCENE).instantiate()


## Plays the slides over `on` (straight to then_do if hidden for good).
static func play(on: Control, then_do: Callable, force := false) -> void:
	if Progress.tip_hidden("classicTut") and not force:  # force: Settings' How to Play
		then_do.call()
		return
	var h := make()
	h.on_done = then_do
	h.size = on.size
	on.add_child(h)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_dot_off = $Card/Dots/Dot0.get_theme_stylebox("panel")
	$Card/Slide.gui_input.connect(func(ev): if Tap.tap(ev): _next())
	$Card/Next.gui_input.connect(func(ev): if Tap.tap(ev): _next())
	$Card/Hide.gui_input.connect(func(ev): if Tap.tap(ev):
		Progress.hide_tip("classicTut")
		_next(true))
	_show()


func _next(skip_rest := false) -> void:
	if not skip_rest and _i < 2:
		_i += 1
		_show()
		return
	queue_free()
	on_done.call()


func _show() -> void:
	var card: Control = $Card
	var slide: Control = $Card/Slide
	for c in slide.get_children():
		c.queue_free()
	var w := minf(360, size.x - 40)
	var inner := w - 2 * slide.position.x
	var h: float = [_goal, _gather, _mat][_i].call(slide, inner)
	slide.size = Vector2(inner, h)
	card.size = Vector2(w, slide.position.y + h + 18 + 40 + 18)
	card.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - card.size.y) / 2))
	for d in 3:
		card.get_node("Dots/Dot%d" % d).add_theme_stylebox_override("panel", dot_on if d == _i else _dot_off)
	var nx: Control = $Card/Next
	var nt: Label = nx.get_node("Text")
	nt.text = last_text if _i == 2 else next_text
	nx.offset_left = nx.offset_right - (nt.get_theme_font("font").get_string_size(nt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nt.get_theme_font_size("font_size")).x + 60)


## The kicker over a slide (THE GOAL ...); returns the y under it.
static func _kicker(slide: Control, text: String, w: float) -> float:
	var k := Tok.label(text.to_upper(), 12, Color("#ffe08a"), 900)
	k.add_theme_font_override("font", Tok.font(900, 2))
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.size = Vector2(w, 16)
	slide.add_child(k)
	return 26.0


## A line (centred unless at x) with [b]bold[/b] parts in gold; returns its height.
static func _line(slide: Control, bb: String, y: float, w: float, px := 14.0, color := "#e8edf4", x := -1.0) -> float:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", Tok.font(700))
	r.add_theme_font_override("bold_font", Tok.font(900))
	r.add_theme_font_size_override("normal_font_size", int(px))
	r.add_theme_font_size_override("bold_font_size", int(px))
	r.add_theme_color_override("default_color", Color(color))
	var body := bb.replace("[b]", "[b][color=%s]" % GOLD_TEXT).replace("[/b]", "[/color][/b]")
	r.text = body if x >= 0 else "[center]" + body + "[/center]"
	r.position = Vector2(maxf(x, 0), y)
	r.size = Vector2(w, 0)
	slide.add_child(r)
	var plain := bb.replace("[b]", "").replace("[/b]", "")
	var lines := 0
	for part in plain.split("\n"):
		lines += int(ceil(Tok.font(900).get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / w))
	return maxf(1, lines) * px * 1.4


## A cream tile with an icon (and a corner badge).
static func _tile(key: String, sz: float, badge := "") -> Control:
	var t := Panel.new()
	t.add_theme_stylebox_override("panel", Tok.box(Color("#f2e6cc"), sz * 0.22, 0, Color.BLACK, 2, 2, Color(0, 0, 0, 0.35)))
	t.size = Vector2(sz, sz)
	t.mouse_filter = MOUSE_FILTER_IGNORE
	var ic := Tok.icon(key, sz * 0.62)
	ic.position = Vector2(sz * 0.19, sz * 0.19)
	t.add_child(ic)
	if badge != "":
		var b := Tok.icon(badge, sz * 0.42)
		b.position = Vector2(sz * 0.62, sz * 0.62)
		t.add_child(b)
	return t


## Lays out controls in a centred row; returns the row's height.
static func _row(slide: Control, parts: Array, y: float, w: float, gap := 8.0) -> float:
	var total := -gap
	var h := 0.0
	for c in parts:
		total += c.size.x + gap
		h = maxf(h, c.size.y)
	var x := (w - total) / 2
	for c in parts:
		c.position = Vector2(x, y + (h - c.size.y) / 2)
		slide.add_child(c)
		x += c.size.x + gap
	return h


## 1: the goal, the 8 capstones (with their stations).
func _goal(slide: Control, w: float) -> float:
	var y := _kicker(slide, goal_kicker, w)
	var stations: Array = Data.t("STATION_BY_NAME").values()
	var cell := (w - 3 * 10) / 4
	for i in stations.size():
		var st: Dictionary = stations[i]
		var t := _tile(st.capstone[0], cell)
		var se := Tok.icon(st.emoji, cell * 0.24)
		se.position = Vector2(4, 4)
		t.add_child(se)
		t.position = Vector2((i % 4) * (cell + 10), y + (i / 4) * (cell + 10))
		slide.add_child(t)
	y += 2 * cell + 10 + 14
	y += _row(slide, stations.map(func(st): return Tok.icon(st.emoji, 22)), y, w, 6) + 6
	return y + _line(slide, goal_line, y, w)


## 2: gather & craft: a station's dice, then elements spent, an item kept.
func _gather(slide: Control, w: float) -> float:
	var y := _kicker(slide, gather_kicker, w)
	var st := _example_station()
	var parts: Array = [Tok.icon(st.emoji, 40), Tok.icon("🎲", 20)]
	for d in Catalog.sorted_dice(st):
		parts.append(_chip(d, 30))
	y += _row(slide, parts, y, w, 7) + 10
	y += _line(slide, gather_note, y, w, 12.5, "#b3becd") + 14
	# An item made only of elements, sold here, else anywhere (as the HTML game).
	var plain := func(e): return e.reqs.size() >= 2 and e.reqs.all(func(r): return r.kind == "element")
	var ex = null
	for e in Data.t("ENTRIES"):
		if e.station == st.name and plain.call(e):
			ex = e
			break
	if ex == null:
		for e in Data.t("ENTRIES"):
			if plain.call(e):
				ex = e
				break
	var spent := Control.new()
	var chips: Array = ex.reqs.map(func(r): return _chip(r.name, 30))
	var cx := 0.0
	for c in chips:
		c.position = Vector2(cx, 0)
		spent.add_child(c)
		cx += 36
	var coin := _coin(7)
	var sw := Tok.font(800).get_string_size(spent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	coin.position = Vector2((cx - 6 - (14 + 4 + sw)) / 2, 37)
	spent.add_child(coin)
	var sl := Tok.label(spent_text, 12, Color("#e8edf4"), 800)
	sl.position = Vector2(coin.position.x + 18, 33)
	spent.add_child(sl)
	spent.size = Vector2(cx - 6, 50)
	var kept := Control.new()
	var item := Panel.new()
	item.add_theme_stylebox_override("panel", Tok.box(Color("#16301f"), 10, 2, Color("#4fe583")))
	item.size = Vector2(52, 52)
	var ic := Tok.icon(ex.emoji, 34)
	ic.position = Vector2(9, 9)
	item.add_child(ic)
	kept.add_child(item)
	var kl := Tok.label(kept_text, 12, Color("#e8edf4"), 800)
	kl.position = Vector2(4, 54)
	kept.add_child(kl)
	kept.size = Vector2(52, 70)
	y += _row(slide, [spent, ConvertTray._arrow_glyph(Color("#ffe08a")), kept], y, w, 14) + 12
	return y + _line(slide, gather_line, y, w)


## 3: the Display Mat: its cards earn Quarks, Quarks earn dice; the combos;
## 24 turns.
func _mat(slide: Control, w: float) -> float:
	var y := _kicker(slide, mat_kicker, w)
	var st := _example_station()
	var emoji: Dictionary = Data.t("ITEM_EMOJI")
	var names: Array = [st.capstone[1]] + Data.t("CORE_ITEM_NAMES")
	var mat := Panel.new()
	mat.add_theme_stylebox_override("panel", Tok.box(Color("#cda874"), 8, 2, Color("#a67c4a")))
	mat.size = Vector2(4 * 30 + 14, 38)
	var shown := []
	for n in names:
		if emoji.has(n) and not shown.has(n) and shown.size() < 4:
			shown.append(n)
	for i in shown.size():
		var t := _tile(emoji[shown[i]], 26)
		t.position = Vector2(7 + i * 30, 6)
		mat.add_child(t)
	var dice := Control.new()
	for i in 3:
		var d := Tok.icon("🎲", 22)
		d.position = Vector2(i * 24, 0)
		dice.add_child(d)
	dice.size = Vector2(70, 22)
	y += _row(slide, [mat, ConvertTray._arrow_glyph(Color("#ffe08a")), Tok.icon("⚛️", 30), ConvertTray._arrow_glyph(Color("#ffe08a")), dice], y, w, 8) + 10
	y += _line(slide, mat_line, y, w) + 10
	# The combos, in a box.
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Tok.box(Color(1, 1, 1, 0.04), 12, 1.5, EDGE))
	box.position = Vector2(0, y)
	slide.add_child(box)
	var rows := _combos(st)
	var ry := 10.0
	for r in rows:
		var icons: Control = r[0]
		icons.position = Vector2(10, ry)
		box.add_child(icons)
		var lh := _line(box, r[1], ry + 4, w - 130, 12, "#e8edf4", 120)
		ry += maxf(icons.size.y, lh) + 8
	box.size = Vector2(w, ry + 2)
	y += box.size.y + 12
	var clock := OrderInfo._clock(int(Data.t("RUN_COMPLETE_VISIT")))
	clock.scale = Vector2(0.75, 0.75)
	clock.size = Vector2(44, 44)
	var tl := Control.new()
	var turns := Tok.label(turns_text % Data.t("RUN_COMPLETE_VISIT"), 13, Color("#e8edf4"), 800)
	tl.add_child(turns)
	tl.size = Vector2(Tok.font(800).get_string_size(turns.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, 20)
	return y + _row(slide, [clock, tl], y, w, 10)


## The five combo examples: [icons, label].
func _combos(st: Dictionary) -> Array:
	var emoji: Dictionary = Data.t("ITEM_EMOJI")
	var strip := func(parts: Array) -> Control:
		var c := Control.new()
		var x := 0.0
		for p in parts:
			p.position = Vector2(x, (26 - p.size.y) / 2)
			c.add_child(p)
			x += p.size.x + 4
		c.size = Vector2(x - 4, 26)
		return c
	var out := []
	out.append([strip.call([_tile(st.emoji, 26), _tile(st.emoji, 26), _tile(st.emoji, 26)]), combo_station])
	var suit: String = Data.t("ELEMENT_SUIT_LABEL").keys()[0]
	var suits := []
	for i in 3:
		var c := Panel.new()
		c.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(suit), 13))
		c.size = Vector2(26, 26)
		var g := Tok.icon("suit:" + suit, 15)
		g.position = Vector2(5.5, 5.5)
		g.material = Tok.white()
		c.add_child(g)
		suits.append(c)
	out.append([strip.call(suits), combo_suit])
	# A component shared by the most cards, and a card with its 2-item recipe.
	var shared := {}
	for c in Data.t("MAT_CARDS"):
		for n in Mat.direct_items(c):
			if not shared.has(n):
				shared[n] = []
			shared[n].append(c.name)
	var comp = null
	for n in shared:
		if emoji.has(n) and shared[n].size() >= 3 and (comp == null or shared[n].size() > shared[comp].size()):
			comp = n
	if comp != null:
		out.append([strip.call(shared[comp].slice(0, 3).map(func(n): return _tile(emoji[n], 26, emoji[comp]))), combo_shared])
	for c in Data.t("MAT_CARDS"):
		if Mat.direct_items(c).size() == 2 and c.tier != "CAPSTONE":
			var plus := Tok.label("+", 14, Color.WHITE, 900)
			plus.size = Vector2(10, 26)
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			out.append([strip.call([_tile(emoji[c.name], 26), plus] + Mat.direct_items(c).map(func(n): return _tile(emoji[n], 26))),
				combo_recipe])
			break
	for col in Data.t("MAT_COLLECTIONS_RAW"):
		if col.items.size() == 3 and col.items.all(func(n): return emoji.has(n)):
			out.append([strip.call([Tok.star(Color.WHITE, 12)] + col.items.map(func(n): return _tile(emoji[n], 26))), combo_collection])
			break
	return out


## The Ocean, or the first station if it's ever renamed.
static func _example_station() -> Dictionary:
	var all: Dictionary = Data.t("STATION_BY_NAME")
	return all.get("The Ocean", all.values()[0])


static func _chip(sym: String, w: float) -> Control:
	var c := StationScreen.element_chip(sym, w)
	for i in range(2, c.get_child_count()):  # just the square and symbol: no number, badge or name
		c.get_child(i).visible = false
	c.size.y = w
	return c


## 🪙, drawn: a gold coin.
static func _coin(r: float) -> Control:
	var c := Control.new()
	c.size = Vector2(r * 2, r * 2)
	c.draw.connect(func():
		c.draw_circle(Vector2(r, r), r, Color("#e2b25a"))
		c.draw_arc(Vector2(r, r), r * 0.62, 0, TAU, 20, Color("#a8730f"), 1.5, true))
	return c
