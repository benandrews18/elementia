## The opening's capstone choice (opening.js): "Choose a Capstone Project",
## the eight capstones in a 4-wide grid; a tap opens its confirm window (its
## station's card, the capstone, its components, Back / "Start at <station>
## and track <capstone>"). Start flies the station's elements into the
## Inventory, then fades into that station with the run begun.
## Then the fade into its station (the pinning tip is a 💡 hint now).
class_name CapstoneChoice
extends Control

const INK := Color("#3b2412")
const INK2 := Color("#5e4026")

## The layout is ui/overlays/capstone_choice.tscn: the two windows (Choice,
## Confirm), their texts and styles; this fills in the capstones.
const SCENE := "res://ui/overlays/capstone_choice.tscn"

## The Start button's two lines (%s: the station, the capstone).
@export var start_text := "Start at %s"
@export var track_text := "and track %s"
@export var points_text := "%d pts"
## The grid: columns and the gap between tiles.
@export var columns := 4
@export var cell_gap := 8.0

var _busy := false
var _card: Control  # the confirm window's station card (its chips fly at Start)
var _shown_name := ""  # the capstone it shows


static func make() -> CapstoneChoice:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var star := Tok.star(Color("#f5b400"), 14)  # drawn: Nunito has no ★
	$Confirm/Star.add_child(star)
	$Confirm/Back.gui_input.connect(func(ev): if Tap.tap(ev) and not _busy: _choice())
	$Confirm/Start.set_meta("cmp", "cap:start")
	$Confirm/Start.gui_input.connect(func(ev): if Tap.tap(ev): _start(_shown_name, _card))
	_choice()



## Shows one window, centred above the hub.
func _swap(box: Control) -> void:
	for w in [$Choice, $Confirm]:
		w.visible = w == box
	box.position = Vector2((size.x - box.size.x) / 2, maxf(20, (size.y - HubBar.H - box.size.y) / 2))


## The grid of capstones (openCapstoneChoice()).
func _choice() -> void:
	var box: Control = $Choice
	var w := minf(420, size.x - 40)
	var inner := w - 2 * 38
	var sub: Label = $Choice/Sub
	var f := sub.get_theme_font("font")
	var px := sub.get_theme_font_size("font_size")
	var lines := roundf(f.get_multiline_string_size(sub.text, HORIZONTAL_ALIGNMENT_LEFT, inner, px).y / f.get_height(px))
	var sub_h := lines * px * 1.5  # its 1.5 line height (the label itself grows to the font's)
	sub.size = Vector2(inner, sub_h)
	var grid: Control = $Choice/Grid
	for c in grid.get_children():
		c.queue_free()
	var caps := Market.capstone_choices()
	var cell := (inner - (columns - 1) * cell_gap) / columns
	var gy := sub.position.y + sub_h + 14
	var rows := ceili(caps.size() / float(columns))
	var h := gy + rows * cell + (rows - 1) * cell_gap + 30
	box.size = Vector2(w, h)
	for i in caps.size():
		var c := _cell(caps[i], cell)
		c.position = Vector2(sub.position.x + (i % columns) * (cell + cell_gap), gy + (i / columns) * (cell + cell_gap))
		grid.add_child(c)
	_swap(box)


## .bingo-cell: a cream tile, the capstone's icon, its station's at the
## top-left, its name along the bottom.
func _cell(name: String, sz: float) -> Control:
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", Tok.box(Color("#f7efdf"), 12, 1.5, Color("#d9c39a"), 3, 2, Color(0, 0, 0, 0.25)))
	c.size = Vector2(sz, sz)
	var ic := Tok.icon(Data.t("ITEM_EMOJI")[name], sz * 0.62)
	ic.position = Vector2(sz * 0.19, sz * 0.08)
	c.add_child(ic)
	var st := Tok.icon(Catalog.station(String(Data.t("CORE_ITEM_STATION")[name])).emoji, sz * 0.3)
	st.position = Vector2(2, 2)
	c.add_child(st)
	var n := Tok.label(name, 9, INK, 800)
	Tok.centre_name(n, sz, sz - 15, 12)
	c.add_child(n)
	c.set_meta("cmp", "cap:" + name)
	c.gui_input.connect(func(ev): if Tap.tap(ev): _confirm(name))
	return c


## The confirm window (openCapstoneConfirm()).
func _confirm(name: String) -> void:
	var box: Control = $Confirm
	_shown_name = name
	var e: Dictionary = Catalog.entry(name)
	var st_name := String(Data.t("CORE_ITEM_STATION")[name])
	var w := minf(420, size.x - 24)
	var inner := w - 2 * 20
	box.size.x = w
	if is_instance_valid(_card):
		_card.queue_free()
	_card = MapScreen.station_card(st_name, inner, true)
	_card.position = Vector2(20, 30)
	$Confirm/Card.add_child(_card)
	var y := _card.position.y + _card.size.y + 14
	var ic: TextureRect = $Confirm/Emoji
	ic.texture = Data.icon(e.emoji)
	ic.position = Vector2((w - ic.size.x) / 2, y)
	y += 66
	$Confirm/Name.text = name
	$Confirm/Name.position.y = y
	y += 30
	var pts: Label = $Confirm/Points
	pts.text = points_text % e.points
	var pw := pts.get_theme_font("font").get_string_size(pts.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts.get_theme_font_size("font_size")).x
	$Confirm/Star.position = Vector2((w - pw - 18) / 2, y + 2)
	pts.position = Vector2($Confirm/Star.position.x + 18, y)
	y += 22 + 4
	$Confirm/Components.position.y = y
	y += 22
	for c in $Confirm/Parts.get_children():
		c.queue_free()
	y = _components($Confirm/Parts, e, y, w) + 16
	var back: Control = $Confirm/Back
	back.size = back.get_combined_minimum_size().max(Vector2(80, 46))
	back.position = Vector2((w - back.size.x) / 2, y)
	y += 46 + 10
	var go: Control = $Confirm/Start
	var line1: Label = go.get_node("Text")
	line1.text = start_text % st_name
	go.get_node("Small").text = track_text % name
	go.size.x = line1.get_theme_font("font").get_string_size(line1.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line1.get_theme_font_size("font_size")).x + 44
	go.position = Vector2((w - go.size.x) / 2, y)
	box.size.y = y + go.size.y + 30
	_swap(box)


## The capstone's components, each once (elements first): a square (an
## element: white with its colour's border; an item: its icon) over its name.
func _components(box: Control, e: Dictionary, y: float, w: float) -> float:
	var seen := {}
	var toks := []
	for r in e.reqs:
		if not seen.has(r.kind + ":" + r.name):
			seen[r.kind + ":" + r.name] = true
			toks.append(r)
	var pts: Dictionary = Data.t("ITEM_POINTS")
	toks = toks.filter(func(r): return r.kind == "element") + Util.stable_sort(toks.filter(func(r): return r.kind != "element"),
		func(a, b): return pts.get(a.name, 0) - pts.get(b.name, 0))
	var col := minf(60, (w - 24 - 6 * (toks.size() - 1)) / toks.size())
	var sq := minf(46, col)
	var x := (w - (toks.size() * col + (toks.size() - 1) * 6)) / 2
	var tallest := 0.0
	for r in toks:
		var el: bool = r.kind == "element"
		var p := Panel.new()
		p.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 12, 4, Color(Data.t("ELEMENT_COLOR").get(r.name, "#8a94a6"))) if el
			else Tok.box(Color("#ead9b4"), 12, 2, Color("#c9a571")))
		p.size = Vector2(sq, sq)
		p.position = Vector2(x + (col - sq) / 2, y)
		if el:
			var s := Tok.label(r.name, 18, Color("#221f1a"), 800)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			s.size = p.size
			p.add_child(s)
		else:
			var ic := Tok.icon(Data.t("ITEM_EMOJI").get(r.name, ""), 32)
			ic.position = Vector2((sq - 32) / 2, (sq - 32) / 2)
			p.add_child(ic)
		box.add_child(p)
		var label: String = Data.t("ELEMENT_NAMES").get(r.name, r.name) if el else r.name
		var nm := Tok.label(label, 10, INK2, 700)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.position = Vector2(x - 2, y + sq + 3)
		nm.size = Vector2(col + 4, 24)
		box.add_child(nm)
		var lines := roundf(Tok.font(700).get_multiline_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, col + 4, 10).y / Tok.font(700).get_height(10))
		tallest = maxf(tallest, sq + 3 + lines * 11.5)
		x += col + 6
	return y + tallest


## confirmCapstoneChoice(): the station's element chips fly into the
## Inventory button (80ms apart), then a fade into the station, run begun.
func _start(name: String, card: Control) -> void:
	if _busy:
		return
	_busy = true
	var app := App.current
	var to := app._hub.button_center("inv")
	app._hub.spotlight("inv", true)  # lit above the dim while the elements fly in (introInvLit)
	var chips := card.get_children().filter(func(c): return c.has_meta("sym"))
	for i in chips.size():
		var chip: Control = chips[i]
		var fly := StationScreen.element_chip(chip.get_meta("sym"), chip.size.x)
		fly.position = chip.global_position
		fly.pivot_offset = fly.size / 2
		fly.z_index = 2  # over the lit Inventory
		app.add_child(fly)
		chip.modulate.a = 0.25
		var d := to - (chip.global_position + chip.size / 2)
		var tw := fly.create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(fly, "position", fly.position + Vector2(d.x * 0.15, d.y * 0.15 - 40), 0.14).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fly, "position", fly.position + d, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(fly, "scale", Vector2(0.45, 0.45), 0.26)
		tw.tween_property(fly, "scale", Vector2(0.12, 0.12), 0.16)
		tw.parallel().tween_property(fly, "modulate:a", 0.0, 0.16)
		tw.tween_callback(fly.queue_free)
		get_tree().create_timer(i * 0.08 + 0.56 * 0.72).timeout.connect(app._hub.punch.bind("inv"))
	await get_tree().create_timer((chips.size() - 1) * 0.08 + 0.56 + 0.15).timeout
	app._hub.spotlight("inv", false)
	var go := func(): app.fade_through_black(func(): Game.start_run(name))
	if not Progress.is_pinned(name):
		Progress.toggle_pin(name)
	queue_free()  # the pinning tip is the To-Do's 💡 hint now (Hints)
	go.call()
