## A shop row (itemHTML(), .shop .item in station.css): the item's icon in a
## dark square, its name and suit-cost badges, its recipe (elements as
## outlined chips, items as icons, joined by "+", a tick on what you have),
## and the Craft button at the right; the pin hangs off the top-left corner.
## The Crafting Bench shows one; the list view a column of them.
class_name ShopRow
extends Control

## The layout is ui/components/shop_row.tscn (the face, icon box, name,
## Craft button and pin, their styles); this fills in the item.
const SCENE := "res://ui/components/shop_row.tscn"
const H := 86.0

@export var can_style: StyleBox
@export var locked_style: StyleBox
@export var locked_color := Color("#7d8899")
@export var pin_on: StyleBox
@export var pin_off: StyleBox
@export var needed_style: StyleBox  # in the pin's place: the tracked item's icon (it still needs this)

var entry: Dictionary
var on_craft: Callable
var on_pin: Callable
var plain := false  # the Inventory's row (matShopRowHTML()): no have/missing marks


static func make(e: Dictionary, width: float, craft: Callable, pin: Callable, plain_row := false) -> ShopRow:
	var r: ShopRow = load(SCENE).instantiate()
	r.plain = plain_row
	r.entry = e
	r.on_craft = craft
	r.on_pin = pin
	r.size = Vector2(width, H)
	r.custom_minimum_size = r.size
	return r


func _ready() -> void:
	var s := Game.state
	var e := entry
	var owned := Catalog.owns(s, e.name)
	var can := not owned and Catalog.can_craft(s, e) and Game.suit_cost_payable(e.name)
	set_meta("cmp", "row:" + e.name)
	if owned:
		$Face.modulate.a = 0.62
	$IconBox/Icon.texture = Data.icon(e.emoji)
	var name_l: Label = $Name
	name_l.text = e.name
	# Suit-cost badges after the name: lit while the surplus covers them.
	var x := name_l.position.x + name_l.get_theme_font("font").get_string_size(e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_l.get_theme_font_size("font_size")).x + 12
	var reserved: Dictionary = Catalog.needs_of(e.reqs).els
	var seen := {}
	for su in Data.t("ITEM_SUIT_COST_TABLE").get(e.name, []):
		var k: int = seen.get(su, 0)
		seen[su] = k + 1
		var lit: bool = owned or Game.suit_surplus(su, reserved) > k
		var b := Panel.new()
		b.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(su) if lit else Color("#8a94a6"), 11))
		b.position = Vector2(x, 8.1)
		b.size = Vector2(22, 22)
		b.mouse_filter = MOUSE_FILTER_IGNORE
		var g := Tok.icon("suit:" + su, 13)
		g.position = Vector2(4.5, 4.5)
		g.material = Tok.white()
		b.add_child(g)
		$Badges.add_child(b)
		x += 26
	_recipe(Vector2(94, 53))
	# Craft (centred down the right edge), or the owned tick.
	var btn: Label = $Craft
	btn.visible = not owned
	if can:
		btn.add_theme_stylebox_override("normal", can_style)
		btn.mouse_filter = MOUSE_FILTER_STOP
		btn.gui_input.connect(func(ev): if Tap.tap(ev): on_craft.call(e.name, btn.get_global_rect()))
	else:
		btn.add_theme_color_override("font_color", locked_color)
		btn.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		btn.add_theme_constant_override("shadow_offset_y", 0)
		btn.add_theme_stylebox_override("normal", locked_style)
	if owned:  # .item.owned::after: a 28px tick, top right
		var t := Tok.tick(Color.WHITE, 28, Tok.OK, Tok.CARD)
		t.position = Vector2(size.x - 20, -8)
		$Tick.add_child(t)
	# The pin, off the top-left corner (14px out from inside the border).
	var pinned := Progress.is_pinned(e.name)
	var pin: Panel = $Pin
	pin.add_theme_stylebox_override("panel", pin_on if pinned else pin_off)
	pin.modulate.a = 1.0 if pinned else 0.5
	if not pinned:
		$Pin/Icon.material = Tok.grey()
	if Game.feeds_tracked(e.name):  # .item-pin-badge: the tracked item's icon; a tap: the To-Do List
		pin.add_theme_stylebox_override("panel", needed_style)
		pin.modulate.a = 1.0
		$Pin/Icon.material = null
		$Pin/Icon.texture = Data.icon(Catalog.entry(Game.ctx.tracked).emoji)
		pin.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.open_panel("todo"))
		return
	pin.gui_input.connect(func(ev): if Tap.tap(ev): on_pin.call(e.name))


## The recipe tokens: elements first (declared order), then items by points,
## each once, "+" between (recipeHTML() / sortIngredientTokens()).
func _recipe(at: Vector2) -> void:
	var e := entry
	var s := Game.state
	var n := Catalog.needs_of(e.reqs)
	var seen := {}
	var toks := []
	for r in e.reqs:
		var k: String = r.kind + ":" + r.name
		if not seen.has(k):
			seen[k] = true
			toks.append(r)
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var els := toks.filter(func(r): return r.kind == "element")
	var items := Util.stable_sort(toks.filter(func(r): return r.kind != "element"), func(a, b): return pts.get(a.name, 0) - pts.get(b.name, 0))
	var x := at.x
	var first := true
	var convertible := 0
	for v in s.elements.values():
		convertible += int(v) / int(Data.t("CONVERT_RATE"))
	for r in els + items:
		if not first:
			var plus := Tok.label("+", 14, Color("#4d6076"), 700)
			plus.position = Vector2(x + 5, at.y + 2)
			$Recipe.add_child(plus)
			x += 5 + 9.9 + 5
		first = false
		var have: bool
		var w: float
		if r.kind == "element":
			have = plain or Catalog.count(s, r.name) >= n.els[r.name]
			var color := Color("#1c2b3d") if have else Color("#a3311d")
			var tw := Tok.font(800).get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			w = tw + 22 + 3
			var chip := Label.new()
			chip.text = r.name
			chip.add_theme_font_override("font", Tok.font(800))
			chip.add_theme_font_size_override("font_size", 15)
			chip.add_theme_color_override("font_color", color)
			chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var sb := Tok.box(Color.WHITE, 9, 1.5, color, 0, 0)
			sb.shadow_color = Color(0, 0, 0, 0.25)
			sb.shadow_offset = Vector2(0, 2)
			sb.shadow_size = 1
			chip.add_theme_stylebox_override("normal", sb)
			chip.position = Vector2(x, at.y - 3)
			chip.size = Vector2(w, 30)
			$Recipe.add_child(chip)
			if not have:  # .tok.el.need: a tap opens Convert with it on the To side
				var sym: String = r.name
				chip.set_meta("cmp", "need:" + sym)
				chip.mouse_filter = MOUSE_FILTER_STOP
				chip.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.open_convert(sym))
			if not have and convertible > 0:  # "Convert could cover this"
				var cv := TextureRect.new()
				cv.texture = load("res://assets/ui/btn_quark.webp")
				cv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				cv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				cv.position = Vector2(x + w - 12, at.y - 13)
				cv.size = Vector2(22, 22)
				cv.mouse_filter = MOUSE_FILTER_IGNORE  # a tap on it reaches the chip
				$Recipe.add_child(cv)
		else:
			have = Catalog.owns(s, r.name)
			w = 26
			var item_ic := Tok.icon(Data.t("ITEM_EMOJI").get(r.name, ""), 26)
			item_ic.position = Vector2(x, at.y)
			item_ic.material = Tok.outline(26.0 * 1.5 / 1.0)  # 1px black outline (.tok-icon)
			$Recipe.add_child(item_ic)
		if have and not plain:
			var t := Tok.tick(Color.WHITE, 15, Tok.OK, Tok.CARD)
			t.position = Vector2(x + w - 9, at.y - 6)
			$Recipe.add_child(t)
		x += w

