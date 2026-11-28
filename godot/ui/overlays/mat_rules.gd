## The Display Mat rules (openMatRules(), #matRulesOverlay), two pages: how
## a board check works, then Quark combos (the stations, the suits and some
## items as icons). Opened by the mat's "?", from Tutorial Messages, and at
## a run's first check until hidden (✕ Hide: matRules; step 25). The layout
## is ui/overlays/mat_rules.tscn.
## Also opens the challenge tip (order_tip.tscn).
class_name MatRules
extends ParchDialog

const SCENE := "res://ui/overlays/mat_rules.tscn"
const ORDER_TIP := "res://ui/overlays/order_tip.tscn"

## Pages 2 and 3's titles (page 1's is the window's).
@export var combos_title := "Quark Combos"
@export var multiplier_title := "Combo Multiplier"
@export var combo_items: PackedStringArray = ["Water", "Sand", "Tree", "Wheel"]
## Page 2's tree: this card over the pieces of its recipe (all on the mat: DOUBLE).
@export var double_item := "Apple"


static func show_on(on: Control) -> MatRules:
	return ParchDialog.open(on, SCENE, {"every": int(Data.t("MAT_CHECK_EVERY"))}) as MatRules


## Display Mat Challenges, with this game's multipliers.
static func order_tip(on: Control) -> ParchDialog:
	return ParchDialog.open(on, ORDER_TIP, {"req": Util.js_str(Data.t("ORDER_REQUEST_MULT")), "res": Util.js_str(Data.t("ORDER_RESTRICT_MULT"))})


func _ready() -> void:
	super()
	pressed.connect(func(button: String):
		if button == "Next":
			_page(2, combos_title)
		elif button == "Next2":
			_page(3, multiplier_title))
	var p2 := "Window/Content/Page3/"
	get_node(p2 + "Stations").add_theme_constant_override("h_separation", 3)
	for st in Data.t("MAP_NODE_POS").keys():  # .liqt-ic: a 24px circle in its colour
		var s := Catalog.station(st)
		get_node(p2 + "Stations").add_child(_circle(Data.t("DATA").suits[s.suit].color, s.emoji, 28))  # 8 in one row
	for su in Data.t("ELEMENT_SUIT_LABEL").keys():
		var c := _circle(Tok.suit_color(su).to_html(), "suit:" + su)  # its dark icon on its colour, as on the cards
		get_node(p2 + "Suits").add_child(c)
	for n in combo_items:
		get_node(p2 + "Items").add_child(_circle("#4a4f5c", Data.t("ITEM_EMOJI").get(n, "")))
	$Window/Content/Page2.add_child(_recipe_tree(double_item))
	$Window/Content/Page2.move_child($Window/Content/Page2/Tree, $Window/Content/Page2/D2.get_index() + 1)


func _page(n: int, title: String) -> void:
	for k in [1, 2, 3]:
		get_node("Window/Content/Page%d" % k).visible = k == n
	$Window.icon = null
	$Window.title = title


static func _circle(color: String, key: String, px := 34.0) -> Control:
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", Tok.box(Color(color), px / 2, 1.5, Color.BLACK))  # as on the cards
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	var ip := roundf(px * 0.65)
	var ic := Tok.icon(key, ip)
	ic.position = Vector2(px - ip, px - ip) / 2
	c.add_child(ic)
	return c


## A card over the pieces of its recipe (the user, 2026-11-27: a little tree
## of puzzle pieces), lines from it down to each; ×2 on the card.
static func _recipe_tree(item: String) -> Control:
	const BIG := 48.0
	const SMALL := 36.0
	const DROP := 30.0
	var e = Catalog.entry(item)
	var parts: Array = e.reqs.filter(func(r): return r.kind == "item").map(func(r): return r.name) if e else []
	var t := Control.new()
	t.name = "Tree"
	t.mouse_filter = MOUSE_FILTER_IGNORE
	t.custom_minimum_size = Vector2(0, 14 + BIG + DROP + SMALL + 4)
	var tile := func(n: String, px: float) -> Control:
		var p := Panel.new()
		p.add_theme_stylebox_override("panel", Tok.box(Color("#f3e6c8"), px * 0.22, 2, Color.BLACK, 3, 2, Color(0, 0, 0, 0.3)))  # a card's parchment
		p.size = Vector2(px, px)
		p.mouse_filter = MOUSE_FILTER_IGNORE
		var ic := Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), px * 0.7)
		ic.position = p.size * 0.15
		p.add_child(ic)
		return p
	var top: Control = tile.call(item, BIG)
	var kids: Array = parts.map(func(n): return tile.call(n, SMALL))
	t.add_child(top)
	for k in kids:
		t.add_child(k)
	var x2 := Tok.label("×2", 14, Color.WHITE, 900)
	x2.add_theme_stylebox_override("normal", Tok.box(Color("#b5541b"), 9, 1.5, Color.BLACK))
	x2.size = Vector2(30, 19)
	x2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(x2)
	var lay := func():  # centred in whatever width the window gives
		var w := t.size.x
		top.position = Vector2((w - BIG) / 2, 14)
		x2.position = top.position + Vector2(BIG - 12, -10)
		var gap := 14.0
		var row := kids.size() * SMALL + (kids.size() - 1) * gap
		for i in kids.size():
			kids[i].position = Vector2((w - row) / 2 + i * (SMALL + gap), 14 + BIG + DROP)
		t.queue_redraw()
	t.resized.connect(lay)
	t.draw.connect(func():
		var from := top.position + Vector2(BIG / 2, BIG)
		var mid := from.y + DROP / 2
		for k in kids:
			var to: Vector2 = k.position + Vector2(SMALL / 2, 0)
			t.draw_polyline(PackedVector2Array([from, Vector2(from.x, mid), Vector2(to.x, mid), to]), Color("#8a6a48"), 2.5, true))
	return t
