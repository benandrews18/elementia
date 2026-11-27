## One finished run in History (.histentry): turns, its best Quark score,
## its capstones and ▸, and ⧉ (copies the run as JSON); a tap opens its
## turn-by-turn log under it (where it went, what it collected and crafted).
## The look is ui/pieces/hist_entry.tscn (a turn: ui/pieces/hist_turn.tscn).
class_name HistEntry
extends PanelContainer

const SCENE := "res://ui/pieces/hist_entry.tscn"
const TURN := "res://ui/pieces/hist_turn.tscn"

const MUTE := Color("#8a6a48")  # the parchment's --mute

signal toggled
signal copied(json: String)


static func make() -> HistEntry:
	return Tok.make(SCENE)


## h: a Progress.history entry; open: its turns shown.
func fill(h: Dictionary, open: bool) -> void:
	var row := $Body/Line/Row/Pad/H
	var v := int(h.get("visits", 0))
	row.get_node("Visits").text = "%d turn%s" % [v, "" if v == 1 else "s"]
	var new_kind: bool = h.get("itemScore") != null  # older runs kept only item points as score
	row.get_node("Score/Icon").visible = new_kind
	row.get_node("Score/Text").text = Util.thousands(int(h.get("score", 0))) if new_kind else "%d pts" % int(h.get("score", 0))
	var caps: HBoxContainer = row.get_node("Caps")
	var names: Array = h.get("capstones", [])
	for n in names:
		var ic := Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), 17)
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		caps.add_child(ic)
	row.get_node("None").visible = names.is_empty()
	var arrow := RefTree.arrow(open, MUTE)
	arrow.scale = Vector2(0.6, 0.6)
	arrow.position = Vector2(0, 5)
	row.get_node("Arrow").add_child(arrow)
	$Body/Line/Copy/Glyph.add_child(Tok.copy_glyph(MUTE, 14))
	$Body/Line/Row.gui_input.connect(func(ev): if Tap.tap(ev): toggled.emit())
	$Body/Line/Copy.gui_input.connect(func(ev): if Tap.tap(ev): copied.emit(JSON.stringify(h, "  ")))
	$Body/Detail.visible = open
	if open:
		_turns(h)


## histTurnsHTML(): each visit's station, then what it collected and crafted.
func _turns(h: Dictionary) -> void:
	var list: VBoxContainer = $Body/Detail/Pad/Turns
	var log: Array = h.get("visitLog", [])
	$Body/Detail/Pad/Empty.visible = log.is_empty()
	for i in log.size():
		var t: Dictionary = log[i]
		var turn: Control = Tok.make(TURN)
		turn.get_node("Rule").visible = i > 0
		turn.get_node("Head/N").text = str(i + 1)
		var st: String = t.get("station", "")
		turn.get_node("Head/Icon").texture = Data.icon(Catalog.station(st).emoji) if Data.t("STATION_BY_NAME").has(st) else null
		turn.get_node("Head/Station").text = st
		var els: Dictionary = t.get("elements", {})
		var tally: Array = els.keys().map(func(s): return "%s×%d" % [s, int(els[s])] if int(els[s]) > 1 else s)
		_line(turn.get_node("Collected"), ", ".join(tally))
		_line(turn.get_node("Crafted"), ", ".join(t.get("items", [])))
		list.add_child(turn)


## A "Collected" / "Crafted" line: its text, or a muted dash when empty.
static func _line(line: Control, text: String) -> void:
	line.get_node("Text").text = text if text != "" else "—"
	if text == "":
		line.get_node("Text").add_theme_color_override("font_color", line.get_node("Label").get_theme_color("font_color"))


## The ⧉ shows ✓ for a moment after copying.
func show_copied() -> void:
	var g: Control = $Body/Line/Copy/Glyph
	g.get_child(0).visible = false
	var t := Tok.tick(Color("#3fb46c"), 15)
	g.add_child(t)
	t.create_tween().tween_callback(func():  # dies with the tick
		t.queue_free()
		g.get_child(0).visible = true).set_delay(1.8)
