## One saved layout in Saved Layouts (.ml-slot): its points and name, then
## its combo chips (small, one row) and its cards' icons (8 to a row); 🗑
## off the top-right corner. A tap loads it (signal), 🗑 asks first. The look
## is ui/pieces/layout_row.tscn.
class_name LayoutRow
extends Panel

const SCENE := "res://ui/pieces/layout_row.tscn"

signal load_pressed
signal delete_pressed

@export var chip_scale := 22.0 / 27.0  # .ml-body .mm-cico: 22px circles (the mat's are 27)
@export var icon_px := 20.0  # .ml-body .mmr-ic img: at most 20px, in one row, 1px apart (they shrink to fit)
@export var icon_slot := 24.0
@export var chip_gap := 7.0


static func make() -> LayoutRow:
	return load(SCENE).instantiate()


## layout: {name, items}; w: the row's width. Returns its height.
func fill(layout: Dictionary, w: float) -> float:
	var cards: Array = layout.get("items", []).map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
	var sc := Mat.score(cards, Game.state, Game.ctx)
	$Top/Pts/Num.text = str(int(Util.js_round(sc.total)))
	$Top/Name.text = layout.get("name", "")
	$Del/Icon.texture = Data.icon("🗑️")
	size.x = w
	var y: float = $Top.position.y + $Top.size.y + 3
	# The combo chips, small, in one row; what doesn't fit is cut off (overflow:hidden).
	var chips: Control = $Chips
	chips.position.y = y
	var x := 0.0
	for c: Control in DisplayMatScreen.combo_chips(sc, false):
		c.mouse_filter = MOUSE_FILTER_IGNORE
		for n in c.get_child(0).get_children():  # no counts here (.ml-body .mm-ccount)
			if n is Label:
				n.visible = false
		c.scale = Vector2(chip_scale, chip_scale)
		c.size = c.custom_minimum_size
		c.position = Vector2(x - 3 * chip_scale, -6 * chip_scale + 5)
		chips.add_child(c)
		x += (c.size.x - 10) * chip_scale + chip_gap
	chips.visible = chips.get_child_count() > 0
	if chips.visible:
		y += 27
	# The cards' icons, in one row (.mmr-icons).
	var icons: Control = $Icons
	icons.position.y = y
	var slot := minf(icon_slot, (w - 20 - maxf(0, cards.size() - 1)) / maxf(1, cards.size()))
	var px := minf(icon_px, slot)
	for i in cards.size():
		var ic := Tok.icon(cards[i].emoji, px)
		ic.position = Vector2(i * (slot + 1) + (slot - ic.size.x) / 2, (22 - ic.size.y) / 2)
		icons.add_child(ic)
	y += 22 + 7
	size.y = y
	$Top.gui_input.connect(func(ev): if Tap.tap(ev): load_pressed.emit())
	gui_input.connect(func(ev): if Tap.tap(ev): load_pressed.emit())
	$Del.gui_input.connect(func(ev): if Tap.tap(ev): delete_pressed.emit())
	return y
