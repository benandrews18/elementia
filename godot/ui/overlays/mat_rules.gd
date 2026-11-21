## The Display Mat rules (openMatRules(), #matRulesOverlay), two pages: how
## a board check works, then Quark combos (the stations, the suits and some
## items as icons). Opened by the mat's "?", from Tutorial Messages, and at
## the first board check ever. The layout is ui/overlays/mat_rules.tscn.
## Also opens the challenge tip (order_tip.tscn).
class_name MatRules
extends ParchDialog

const SCENE := "res://ui/overlays/mat_rules.tscn"
const ORDER_TIP := "res://ui/overlays/order_tip.tscn"

## Page 2's title (page 1's is the window's).
@export var combos_title := "Quark Combos"
@export var combo_items: PackedStringArray = ["Water", "Sand", "Tree", "Wheel"]


static func show_on(on: Control) -> MatRules:
	return ParchDialog.open(on, SCENE) as MatRules


## Display Mat Challenges, with this game's multipliers.
static func order_tip(on: Control) -> ParchDialog:
	return ParchDialog.open(on, ORDER_TIP, {"req": Util.js_str(Data.t("ORDER_REQUEST_MULT")), "res": Util.js_str(Data.t("ORDER_RESTRICT_MULT"))})


func _ready() -> void:
	super()
	pressed.connect(func(button: String): if button == "Next": _page2())
	var p2 := "Window/Content/Page2/"
	for st in Data.t("MAP_NODE_POS").keys():  # .liqt-ic: a 24px circle in its colour
		var s := Catalog.station(st)
		get_node(p2 + "Stations").add_child(_circle(Data.t("DATA").suits[s.suit].color, s.emoji))
	for su in Data.t("ELEMENT_SUIT_LABEL").keys():
		var c := _circle(Tok.suit_color(su).to_html(), "suit:" + su)
		c.get_child(0).material = Tok.white()
		get_node(p2 + "Suits").add_child(c)
	for n in combo_items:
		get_node(p2 + "Items").add_child(_circle("#4a4f5c", Data.t("ITEM_EMOJI").get(n, "")))


func _page2() -> void:
	$Window/Content/Page1.visible = false
	$Window/Content/Page2.visible = true
	$Window.icon = null
	$Window.title = combos_title


static func _circle(color: String, key: String) -> Control:
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", Tok.box(Color(color), 12))
	c.custom_minimum_size = Vector2(24, 24)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	var ic := Tok.icon(key, 16)
	ic.position = Vector2(4, 4)
	c.add_child(ic)
	return c
