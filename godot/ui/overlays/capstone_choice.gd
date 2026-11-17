## The opening's capstone choice (opening.js): "Choose a Capstone Project",
## the eight capstones in a 4-wide grid; a tap opens its confirm window (its
## station's card, the capstone, its components, Back / "Start at <station>
## and track <capstone>"). Start flies the station's elements into the
## Inventory, then fades into that station with the run begun.
## Then the To-Do List with the capstone's breakdown and the pinning tip
## (unless hidden for good), and the fade into its station.
class_name CapstoneChoice
extends Control

const INK := Color("#3b2412")
const INK2 := Color("#5e4026")
const MUTE := Color("#8a6a48")

var _box: Control
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ConfirmDialog.dim(self)
	_choice()


func _swap(box: Control) -> void:
	if is_instance_valid(_box):
		_box.queue_free()
	_box = box
	box.position = Vector2((size.x - box.size.x) / 2, maxf(20, (size.y - HubBar.H - box.size.y) / 2))
	add_child(box)


## The grid of capstones (openCapstoneChoice()).
func _choice() -> void:
	var w := minf(420, size.x - 40)
	var inner := w - 2 * 38
	var sub := Tok.label("Completing Capstone Projects will guide your journey through Elementia!", 14, INK2, 400)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := roundf(Tok.font(400).get_multiline_string_size(sub.text, HORIZONTAL_ALIGNMENT_LEFT, inner, 14).y / Tok.font(400).get_height(14))
	sub.size = Vector2(inner, lines * 14 * 1.5)
	sub.position = Vector2(38, 59)
	var caps := Market.capstone_choices()
	var cell := (inner - 3 * 8) / 4
	var gy := sub.position.y + sub.size.y + 14
	var rows := ceili(caps.size() / 4.0)
	var h := gy + rows * cell + (rows - 1) * 8 + 30
	var box := ConfirmDialog.window(Vector2(w, h), "Choose a Capstone Project")
	box.add_child(sub)
	for i in caps.size():
		var c := _cell(caps[i], cell)
		c.position = Vector2(38 + (i % 4) * (cell + 8), gy + (i / 4) * (cell + 8))
		box.add_child(c)
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
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.position = Vector2(0, sz - 15)
	n.size = Vector2(sz, 12)
	n.clip_text = true
	c.add_child(n)
	c.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: _confirm(name))
	return c


## The confirm window (openCapstoneConfirm()).
func _confirm(name: String) -> void:
	var e: Dictionary = Catalog.entry(name)
	var st_name := String(Data.t("CORE_ITEM_STATION")[name])
	var w := minf(420, size.x - 24)
	var inner := w - 2 * 20
	var box := ConfirmDialog.window(Vector2(w, 100), "")
	var card := MapScreen.station_card(st_name, inner, true)
	card.position = Vector2(20, 30)
	box.add_child(card)
	var y := card.position.y + card.size.y + 14
	var ic := Tok.icon(e.emoji, 64)
	ic.position = Vector2((w - 64) / 2, y)
	box.add_child(ic)
	y += 66
	var n := Tok.label(name, 20, INK, 800)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.position = Vector2(0, y)
	n.size = Vector2(w, 28)
	box.add_child(n)
	y += 30
	var pts := Tok.label("%d pts" % e.points, 13, Color("#b7791f"), 700)
	var pw := Tok.font(700).get_string_size(pts.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var star := Tok.star(Color("#f5b400"), 14)
	star.position = Vector2((w - pw - 18) / 2, y + 2)
	box.add_child(star)
	pts.position = Vector2(star.position.x + 18, y)
	box.add_child(pts)
	y += 22 + 4
	var lab := Tok.label("COMPONENTS", 12, MUTE, 800)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.position = Vector2(0, y)
	lab.size = Vector2(w, 16)
	box.add_child(lab)
	y += 22
	y = _components(box, e, y, w) + 16
	var back := Tok.parch_button("Back", Vector2(80, 46))
	back.position = Vector2((w - 80) / 2, y)
	back.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed and not _busy: _choice())
	box.add_child(back)
	y += 46 + 10
	var line1 := "Start at " + st_name
	var go_w := maxf(Tok.font(800).get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 0) + 44
	var go := RollPopup._pill_button(line1, Vector2(go_w, 54))
	var l: Label = go.get_child(0)
	l.size.y = 38
	var small := Tok.label("and track " + name, 12, Color(1, 1, 1, 0.85), 700)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.position = Vector2(0, 30)
	small.size = Vector2(go_w, 16)
	go.add_child(small)
	go.position = Vector2((w - go_w) / 2, y)
	go.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: _start(name, card))
	box.add_child(go)
	box.size.y = y + 54 + 30
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
	var chips := card.get_children().filter(func(c): return c.has_meta("sym"))
	for i in chips.size():
		var chip: Control = chips[i]
		var fly := StationScreen.element_chip(chip.get_meta("sym"), chip.size.x)
		fly.position = chip.global_position
		fly.pivot_offset = fly.size / 2
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
	await get_tree().create_timer((chips.size() - 1) * 0.08 + 0.56 + 0.15).timeout
	var go := func(): app.fade_through_black(func(): Game.start_run(name))
	if Progress.tip_hidden("pinTip"):
		queue_free()
		go.call()
		return
	visible = false  # freed once the tip is up (a freed node's await never resumes)
	# Beat 2: the To-Do List with the capstone pinned and its breakdown
	# open, and the pinning tip over it; Got it goes on into the station.
	if not Progress.is_pinned(name):
		Progress.toggle_pin(name)
	TodoTray.expanded["refroot/" + name] = true
	app.open_panel("todo")
	await get_tree().create_timer(0.45).timeout
	PinTip.open(app, func():
		app.close_panel()
		go.call())
	queue_free()
