## The challenge window (openOrderInfo(), #comboInfoOverlay): the round
## clock on its top-left corner, "<name> Request!" or "Restriction!" on the
## banner, what it asks and its multiplier, the rule in icons, and the swap
## button (one Unknown Element for another challenge) beside OK. Also the
## challenge's line on the shutter (orderShutterLine()). Names and wording
## live here: Orders holds only the rules.
class_name OrderInfo
extends Control

## id -> [name, description ("%s": the station / suit word)]
const WORDS := {
	"stationWeek": ["Station Week", "3 %s cards"], "collector": ["Collector", "1 Named collection"],
	"fullRecipe": ["Full Recipe", "A card with its whole recipe"], "suitSet": ["Suit Set", "3 %s cards"],
	"commonThread": ["Common Thread", "3 cards sharing a component"], "drought": ["Drought", "No %s cards"],
	"closedStation": ["Closed Station", "No %s cards"], "freshFaces": ["Fresh Faces", "Half your cards or fewer from the last check"],
	"shortTable": ["Short Table", "1 empty slot"], "thinStock": ["Thin Stock", "At most 3 tier 1 cards"],
	"trendShift": ["Trend Shift", "No %s combo"], "doubleDrought": ["Double Drought", "No %s cards"],
	"spreadOut": ["Spread Out", "No 4 cards from one station"],
}


static func is_request(o: Dictionary) -> bool:
	return o.id != "grand" and Orders.KINDS[o.id][0] == "request"


static func _suit_word(su: String) -> String:
	return String(Data.t("ELEMENT_SUIT_LABEL")[su]).capitalize()


static func desc(o: Dictionary) -> String:
	var d: String = WORDS[o.id][1]
	if not d.contains("%s"):
		return d
	var p: String = o.p
	return d % (" or ".join(Array(p.split("|")).map(_suit_word)) if o.id in ["suitSet", "drought", "doubleDrought"] else p)


static func mult_label(o: Dictionary) -> String:
	if o.id == "grand":
		return Util.thousands(int(Data.t("GRAND_EXHIBITION_TARGET")))
	return "×" + Util.js_str(Data.t("ORDER_REQUEST_MULT") if is_request(o) else Data.t("ORDER_RESTRICT_MULT"))


## orderShutterLine()
static func shutter_line(o) -> String:
	if o == null:
		return ""
	if o.id == "grand":
		return "Grand Exhibition: reach %s Quarks!" % mult_label(o)
	return "%s: %s (%s)" % ["Request" if is_request(o) else "Restriction", WORDS[o.id][0], mult_label(o)]


static func open(on: Control) -> OrderInfo:
	var w := OrderInfo.new()
	w.size = on.size
	on.add_child(w)
	return w


var _box: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ConfirmDialog.dim(self, queue_free)
	_build()


func _build() -> void:
	if is_instance_valid(_box):
		_box.queue_free()
	var o = Orders.current(Game.state)
	if o == null:
		queue_free()
		return
	var grand: bool = o.id == "grand"
	var title := "Grand Exhibition!" if grand else "%s %s!" % [o.p if o.id == "stationWeek" else WORDS[o.id][0], "Request" if is_request(o) else "Restriction"]
	var w := minf(420, size.x - 40)
	var inner := w - 2 * 38
	var text := ("Reach %s ⚛ at the final check" % mult_label(o)) if grand else "%s: %s⚛%s" % [desc(o), mult_label(o), "" if is_request(o) else " if broken"]
	var d := Tok.label(text.replace("⚛", ""), 15, Color("#5e4026"), 800)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := Tok.font(800).get_multiline_string_size(d.text + "  ", HORIZONTAL_ALIGNMENT_LEFT, inner - 24, 15).y / Tok.font(800).get_height(15)
	var dh := roundf(lines) * 15 * 1.5
	d.size = Vector2(inner, dh)
	d.position = Vector2(38, 59)
	var rule := _rule(o)
	rule.position = Vector2(38 + (inner - rule.size.x) / 2, 59 + dh + 6 + 4)
	var by := rule.position.y + rule.size.y + 12 + 18
	var h := by + 46 + 30
	_box = ConfirmDialog.window(Vector2(w, h), title)
	_box.position = Vector2((size.x - w) / 2, maxf(40, (size.y - HubBar.H - h) / 2))
	add_child(_box)
	_box.add_child(d)
	# The multiplier's atom, after the text (a Noto image: not in Nunito).
	var atom := Tok.icon("⚛️", 16)
	var tw := Tok.font(800).get_string_size(d.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	if tw < inner - 20:
		var mx := Tok.font(800).get_string_size(text.get_slice("⚛", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var after := Tok.font(800).get_string_size(text.get_slice("⚛", 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		d.text = text.get_slice("⚛", 0)
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
		var x0 := 38 + (inner - (mx + 18 + after)) / 2
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		d.position.x = x0
		atom.position = Vector2(x0 + mx + 1, d.position.y + (dh - 16) / 2)
		_box.add_child(atom)
		if after > 0:
			var rest := Tok.label(text.get_slice("⚛", 1), 15, Color("#5e4026"), 800)
			rest.position = Vector2(x0 + mx + 18, d.position.y)
			rest.size = Vector2(after + 4, dh)
			rest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_box.add_child(rest)
		d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_box.add_child(rule)
	ConfirmDialog.close_x(_box, queue_free)
	var clock := _clock(int(o.round))
	clock.position = Vector2(-22, -22)
	_box.add_child(clock)
	# Buttons: the swap (sunken; ↻ and a "?" square) and OK, centred.
	var ok := RollPopup._pill_button("OK", Vector2(Tok.font(800).get_string_size("OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44, 46))
	ok.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed: queue_free())
	var btns: Array[Control] = [ok]
	if not grand:
		var can: bool = Util.get_or(Game.state, "emptyElements", 0) > 0 and not Game.ctx.lockInCommitted \
			and Orders.draw(Game.state, int(o.round), o) != null
		var sw := Panel.new()
		sw.add_theme_stylebox_override("panel", Tok.parch_box())
		sw.size = Vector2(22 + 8 + 28 + 44, 46)
		var arrow := Tok.loop_arrow(Color("#3b2412"), 28, true)
		arrow.position = Vector2(22, 9)
		sw.add_child(arrow)
		var sq := LockInReward.unknown_square(22)
		sq.position = Vector2(22 + 28 + 8, 12)
		sq.mouse_filter = MOUSE_FILTER_IGNORE
		sw.add_child(sq)
		if can:
			sw.gui_input.connect(func(ev): if ev is InputEventMouseButton and not ev.pressed and Game.reroll_order(): _build())
		else:
			sw.modulate.a = 0.45
		btns.push_front(sw)
	var total := -10.0
	for b in btns:
		total += b.size.x + 10
	var x := 38 + (inner - total) / 2
	for b in btns:
		b.position = Vector2(x, by)
		_box.add_child(b)
		x += b.size.x + 10


## .ord-rule: the rule in icons and figures, 30px, 8px apart.
func _rule(o: Dictionary) -> Control:
	var parts: Array[Control] = []
	var p = o.p
	var st := func(): return Tok.icon(Catalog.station(p).emoji, 34)
	var txt := func(t: String): return Tok.label(t, 30, Color("#3b2412"), 900)
	match o.id:
		"grand": parts = [Tok.icon("⚛️", 34), txt.call(mult_label(o))]
		"stationWeek": parts = [txt.call("3+"), st.call()]
		"collector": parts = [Tok.star(Tok.GOLD, 34), Tok.tick(Tok.OK, 30)]
		"fullRecipe": parts = [Tok.icon("🧩", 34), txt.call("×2")]
		"suitSet": parts = [txt.call("3+"), _suit(p)]
		"commonThread": parts = [Tok.icon("🧵", 34), txt.call("3+")]
		"drought": parts = [Tok.icon("🚫", 34), _suit(p)]
		"closedStation": parts = [Tok.icon("🚫", 34), st.call()]
		"freshFaces": parts = [Tok.loop_arrow(Color("#3b2412"), 30), txt.call("≤ ½")]
		"shortTable": parts = [Tok.icon("⬜", 34), txt.call("1+")]
		"thinStock": parts = [txt.call("I ≤ 3")]
		"trendShift": parts = [Tok.icon("🚫", 34), txt.call("3+"), st.call()]
		"doubleDrought":
			parts = [Tok.icon("🚫", 34)]
			for su in String(p).split("|"):
				parts.append(_suit(su))
		"spreadOut": parts = [Tok.icon("🚫", 34), txt.call("4+"), Tok.icon("🏠", 34)]
	var row := Control.new()
	var x := 0.0
	for c in parts:
		var sz := Vector2(Tok.font(900).get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x, 41) if c is Label else c.size
		if c is TextureRect:
			sz = Vector2(34, 34)
		c.size = sz
		c.position = Vector2(x, (41 - sz.y) / 2)
		row.add_child(c)
		x += sz.x + 8
	row.size = Vector2(x - 8, 41)
	return row


## .ord-suit: a 38px circle in the suit's colour with its white icon.
func _suit(su: String) -> Control:
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(su), 19))
	c.size = Vector2(38, 38)
	var ic := Tok.icon("suit:" + su, 24)
	ic.position = Vector2(7, 7)
	ic.material = Tok.white()
	c.add_child(ic)
	return c


## roundClockSVG(): a cream clock face with ticks and the round number.
static func _clock(n: int) -> Control:
	var c := Control.new()
	c.size = Vector2(58, 58)
	c.draw.connect(func():
		var k := 58.0 / 60.0
		var o := Vector2(30, 30) * k
		c.draw_circle(o + Vector2(0, 2), 28 * k, Color(0, 0, 0, 0.3))
		c.draw_circle(o, 28 * k, Color("#fff7e0"))
		c.draw_arc(o, 28 * k, 0, TAU, 48, Color("#a8730f"), 3 * k, true)
		for i in 12:
			var a := i * PI / 6
			var r1 := (22.0 if i % 3 else 19.0) * k
			var dir := Vector2(sin(a), -cos(a))
			c.draw_line(o + dir * r1, o + dir * 25.5 * k, Color("#5e4026"), 2 * k, true))
	var l := Tok.label(str(n), 21, Color("#3b2412"), 900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = c.size
	c.add_child(l)
	return c
