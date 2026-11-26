## The challenge window (openOrderInfo(), #comboInfoOverlay): the round
## clock on its top-left corner, what it asks in plain words on the banner
## (TITLES: "3 Ocean Cards", "No Organic Cards"; always one line), the rule
## in big icons, Reroll (one Unknown Element for another challenge) beside
## OK, and a pill on the bottom edge: "REQUEST ×2" or "RESTRICTION −25%"
## (the user, 2026-11-26). Also the
## challenge's line on the shutter (orderShutterLine()). Names and wording
## live here: Orders holds only the rules.
class_name OrderInfo
extends Control

## The banner: what the challenge asks, in plain words ("%s": the station
## or suit names). The user, 2026-11-21: a title that says the ask itself.
const TITLES := {
	"stationWeek": "3 %s Cards", "collector": "Complete a Collection", "fullRecipe": "A Card and Its Whole Recipe",
	"suitSet": "3 %s Cards", "commonThread": "3 Cards Sharing a Part", "drought": "No %s Cards",
	"closedStation": "No %s Cards", "freshFaces": "Mostly New Cards", "shortTable": "Leave 1 Slot Empty",
	"rainbow": "All 4 Suits", "grandTour": "5 Stations",
	"thinStock": "3 or Fewer Tier I Cards", "trendShift": "No %s Combo", "doubleDrought": "No %s Cards",
	"spreadOut": "No 4 Cards From One Station",
}
const ICON := 52.0  # the rule's icons (the user: large and clear)


## The banner's title for o.
static func title_of(o: Dictionary) -> String:
	if o.id == "grand":
		return "Grand Exhibition!"
	var t: String = TITLES[o.id]
	if not t.contains("%s"):
		return t
	var p: String = o.p
	if o.id in ["suitSet", "drought", "doubleDrought"]:
		return t % " or ".join(Array(p.split("|")).map(_suit_word))
	return t % p.trim_prefix("The ")


static func is_request(o: Dictionary) -> bool:
	return o.id != "grand" and Orders.KINDS[o.id][0] == "request"


static func _suit_word(su: String) -> String:
	return String(Data.t("ELEMENT_SUIT_LABEL")[su]).capitalize()


## The pill's words: "REQUEST ×2", "RESTRICTION −25%".
static func pill_text(o: Dictionary) -> String:
	if is_request(o):
		return "REQUEST ×" + Util.js_str(Data.t("ORDER_REQUEST_MULT"))
	return "RESTRICTION −%d%%" % roundi((1.0 - float(Data.t("ORDER_RESTRICT_MULT"))) * 100)


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
	return "%s: %s (%s)" % ["Request" if is_request(o) else "Restriction", title_of(o), mult_label(o)]


## The layout is ui/overlays/order_info.tscn (the window, the text's style,
## the swap and OK buttons); this fills in the challenge.
const SCENE := "res://ui/overlays/order_info.tscn"


static func open(on: Control) -> OrderInfo:
	var w: OrderInfo = load(SCENE).instantiate()
	w.size = on.size
	on.add_child(w)
	return w


var _can_swap := false
var _pill: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var tap := func(ev): return Tap.tap(ev)
	$Dim.gui_input.connect(func(ev): if tap.call(ev): queue_free())
	$Window/Close.gui_input.connect(func(ev): if tap.call(ev): queue_free())
	$Window/OK.gui_input.connect(func(ev): if Tap.tap(ev): queue_free())
	# The swap: ↻ and a "?" square (one Unknown Element for another challenge).
	var sw: Control = $Window/Swap
	# Reroll: ↻, the word, and what it costs (a "?" square).
	var arrow := Tok.loop_arrow(Color("#3b2412"), 24, true)
	arrow.position = Vector2(14, 11)
	sw.add_child(arrow)
	var word := Tok.label("Reroll", 16, Color("#3b2412"), 900)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ww := Tok.font(900).get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	word.clip_text = true
	word.position = Vector2(14 + 24 + 6, 0)
	word.size = Vector2(ww + 2, 46)
	sw.add_child(word)
	var sq := LockInReward.unknown_square(22)
	sq.position = Vector2(word.position.x + ww + 8, 12)
	sq.mouse_filter = MOUSE_FILTER_IGNORE
	sw.add_child(sq)
	sw.size.x = sq.position.x + 22 + 14
	sw.gui_input.connect(func(ev): if Tap.tap(ev) and _can_swap and Game.reroll_order(): _build())
	_build()


func _build() -> void:
	var o = Orders.current(Game.state)
	if o == null:
		queue_free()
		return
	var grand: bool = o.id == "grand"
	var win: ParchmentWindow = $Window
	var w := minf(420, size.x - 40)
	var inner := w - 2 * 38
	win.size.x = w  # first: the title fits this width
	win.fit_title = true
	win.title = title_of(o)
	var text := "Reach %s ⚛ at the final check" % mult_label(o)  # the Grand Exhibition's; a challenge's: its pill
	var d: Label = $Window/Desc
	d.visible = grand
	var f := d.get_theme_font("font")
	var px := d.get_theme_font_size("font_size")
	d.text = text.replace("⚛", "")
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := f.get_multiline_string_size(d.text + "  ", HORIZONTAL_ALIGNMENT_LEFT, inner - 24, px).y / f.get_height(px)
	var dh := roundf(lines) * px * 1.5 if grand else 0.0
	d.size = Vector2(inner, dh)
	d.position = Vector2(38, 59 + win.extra_height)
	var rule: Control = $Window/Rule
	for c in rule.get_children():
		c.queue_free()
	_rule(o, rule)
	rule.position = Vector2(38 + (inner - rule.size.x) / 2, d.position.y + dh + 6 + 4)
	var by := rule.position.y + rule.size.y + 12 + 18
	var h := by + 46 + 30
	win.size = Vector2(w, h)
	win.position = Vector2((size.x - w) / 2, maxf(40, (size.y - HubBar.H - h) / 2))
	# The multiplier's atom, after the text (a Noto image: not in Nunito),
	# when it all fits on one line.
	var atom: Control = $Window/Atom
	var rest: Label = $Window/Rest
	var tw := f.get_string_size(d.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	atom.visible = grand and tw < inner - 20
	rest.visible = false
	if atom.visible:
		var mx := f.get_string_size(text.get_slice("⚛", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var after := f.get_string_size(text.get_slice("⚛", 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		d.text = text.get_slice("⚛", 0)
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
		var x0 := 38 + (inner - (mx + 18 + after)) / 2
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		d.position.x = x0
		atom.position = Vector2(x0 + mx + 1, d.position.y + (dh - 16) / 2)
		if after > 0:
			rest.visible = true
			rest.text = text.get_slice("⚛", 1)
			rest.position = Vector2(x0 + mx + 18, d.position.y)
			rest.size = Vector2(after + 4, dh)
		d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_instance_valid(_pill):
		_pill.queue_free()
	if not grand:
		_pill = _make_pill(o)
		_pill.position = Vector2((w - _pill.size.x) / 2, h - _pill.size.y / 2 - 6)
		win.add_child(_pill)
	var clock: Control = $Window/Clock
	for c in clock.get_children():
		c.queue_free()
	clock.add_child(_clock(int(o.round)))
	# Buttons: the swap (not for the Grand Exhibition) and OK, centred.
	var ok: Control = $Window/OK
	var ot: Label = ok.get_node("Text")
	ok.size.x = f.get_string_size(ot.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ot.get_theme_font_size("font_size")).x + 44
	var sw: Control = $Window/Swap
	sw.visible = not grand
	_can_swap = not grand and Util.get_or(Game.state, "emptyElements", 0) > 0 and not Game.ctx.lockInCommitted \
		and Orders.draw(Game.state, int(o.round), o) != null
	sw.modulate.a = 1.0 if _can_swap else 0.45
	var btns: Array = [sw, ok] if sw.visible else [ok]
	var total := -10.0
	for b in btns:
		total += b.size.x + 10
	var x := 38 + (inner - total) / 2
	for b in btns:
		b.position = Vector2(x, by)
		x += b.size.x + 10


## The pill on the window's bottom edge: green for a request, red for a
## restriction.
func _make_pill(o: Dictionary) -> Label:
	var p := Tok.label(pill_text(o), 13, Color.WHITE, 900)
	var sb := Tok.box(Tok.OK if is_request(o) else Tok.BAD, 14, 2, Color("#3b2412"), 3, 2, Color(0, 0, 0, 0.35))
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("normal", sb)
	p.size = p.get_minimum_size()
	p.set_meta("cmp", "order:pill")
	return p


## .ord-rule: the rule in big icons and figures (ICON), 12px apart.
func _rule(o: Dictionary, row: Control) -> void:
	var parts: Array[Control] = []
	var p = o.p
	var I := ICON
	var st := func(): return Tok.icon(Catalog.station(p).emoji, I)
	var txt := func(t: String): return Tok.label(t, I * 0.85, Color("#3b2412"), 900)
	var no := func(c: Control) -> Control:  # the red cross-out on top of what's restricted (the user, 2026-11-23)
		var x := Tok.icon("🚫", I)
		x.mouse_filter = MOUSE_FILTER_IGNORE
		c.add_child(x)
		x.set_anchors_and_offsets_preset(PRESET_FULL_RECT)  # follows the icon's size, set below
		return c
	match o.id:
		"grand": parts = [Tok.icon("⚛️", I), txt.call(mult_label(o))]
		"stationWeek": parts = [txt.call("3+"), st.call()]
		"collector": parts = [Tok.star(Tok.GOLD, I), Tok.tick(Tok.OK, I * 0.9)]
		"fullRecipe": parts = [Tok.icon("🧩", I), txt.call("×2")]
		"suitSet": parts = [txt.call("3+"), _suit(p)]
		"commonThread": parts = [Tok.icon("🧵", I), txt.call("3+")]
		"rainbow":
			for su in Data.t("ELEMENT_SUIT_LABEL"):
				parts.append(_suit(su))
		"grandTour": parts = [txt.call("%d+" % int(Data.t("ORDER_GRAND_TOUR_STATIONS"))), Tok.icon("🗺️", I)]
		"drought": parts = [no.call(_suit(p))]
		"closedStation": parts = [no.call(st.call())]
		"freshFaces": parts = [Tok.loop_arrow(Color("#3b2412"), I * 0.9), txt.call("≤ ½")]
		"shortTable": parts = [Tok.icon("⬜", I), txt.call("1+")]
		"thinStock": parts = [txt.call("I ≤ 3")]
		"trendShift": parts = [txt.call("3+"), no.call(st.call())]
		"doubleDrought":
			for su in String(p).split("|"):
				parts.append(no.call(_suit(su)))
		"spreadOut": parts = [txt.call("4+"), no.call(Tok.icon("🏠", I))]
	var rh := I * 1.2
	var x := 0.0
	for c in parts:
		var sz := Vector2(Tok.font(900).get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(I * 0.85))).x, rh) if c is Label else c.size
		if c is TextureRect:
			sz = Vector2(I, I)
		c.size = sz
		c.position = Vector2(x, (rh - sz.y) / 2)
		row.add_child(c)
		x += sz.x + 12
	row.size = Vector2(x - 12, rh)


## .ord-suit: a circle in the suit's colour with its white icon.
func _suit(su: String) -> Control:
	var c := Panel.new()
	var d := ICON * 1.1
	c.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(su), d / 2))
	c.size = Vector2(d, d)
	var ic := Tok.icon("suit:" + su, d * 0.63)
	ic.position = Vector2(d * 0.185, d * 0.185)
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
