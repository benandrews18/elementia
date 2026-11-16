## Spending an Unknown Element (openEmptyElPicker(), #emptyElPick): "Pick an
## element" with the "?" square on the banner, this station's elements in a
## row; a tap turns one "?" into that element. A tap outside closes it.
class_name UnknownPick
extends Control


static func open(on: Control) -> UnknownPick:
	var p := UnknownPick.new()
	p.size = on.size
	on.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(10 / 255.0, 14 / 255.0, 20 / 255.0, 0.72)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ConvertTray._tap(ev): queue_free())
	add_child(dim)
	var at = Game.ctx.current if Game.ctx.current else Game.state.get("lastStation")
	if not at:
		queue_free()
		return
	var st := Catalog.station(at)
	var dice := Catalog.sorted_dice(st)
	var w := minf(360, size.x - 40)
	var inner := w - 2 * 30
	var cw := minf(44, (inner - 4 * (dice.size() - 1)) / dice.size())
	var h := 59 + 34 + cw + 14 + 30
	var title := "    Pick an element"  # room for the "?" square on the banner
	var box := ConfirmDialog.window(Vector2(w, h), title)
	box.position = Vector2((size.x - w) / 2, maxf(20, (size.y - HubBar.H - h) / 2))
	add_child(box)
	var banner: Control = box.get_child(0)
	var sq := LockInReward.unknown_square(24)
	sq.position = Vector2(26, (banner.size.y - 24) / 2 - 1)
	banner.add_child(sq)
	var name_w := Tok.font(800).get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var em := Tok.icon(st.emoji, 26)
	em.position = Vector2((w - name_w - 32) / 2, 59)
	box.add_child(em)
	var nl := Tok.label(at, 18, Color("#3b2412"), 800)
	nl.position = Vector2(em.position.x + 32, 59 + 1)
	box.add_child(nl)
	var x0 := (w - (dice.size() * cw + (dice.size() - 1) * 4)) / 2
	for i in dice.size():
		var sym: String = dice[i]
		var c := StationScreen.element_chip(sym, cw)
		c.position = Vector2(x0 + i * (cw + 4), 59 + 34)
		c.mouse_filter = MOUSE_FILTER_STOP
		c.gui_input.connect(func(ev): if ConvertTray._tap(ev):
			queue_free()
			Game.spend_unknown(sym))
		box.add_child(c)
