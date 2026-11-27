## One item on the Items screen (.refrow): its icon with its suit costs
## under it, the name (✓ when owned), its points, the stations that make it,
## "▸ Full breakdown", and 📌. A tap on the row opens or closes its
## breakdown (RefTree, dark) under it. The look is ui/pieces/ref_row.tscn.
class_name RefRow
extends Panel

const SCENE := "res://ui/pieces/ref_row.tscn"

@export var owned_style: StyleBox
@export var pin_on: StyleBox
@export var pin_off: StyleBox

var item := ""


static func make() -> RefRow:
	return Tok.make(SCENE)


## Fills the row for entry e at width w (open: its breakdown shows, built by
## tree); returns its height.
func fill(e: Dictionary, w: float, open: bool, tree: RefTree) -> float:
	item = e.name
	size.x = w
	var owned := Catalog.owns(Game.state, e.name)
	if owned:
		add_theme_stylebox_override("panel", owned_style)
	$Icon.texture = Data.icon(e.emoji)
	for su in Data.t("ITEM_SUIT_COST_TABLE").get(e.name, []):  # bare glyphs in their suit's colour
		var g := Tok.icon("suit:" + su, 12)
		g.material = Tok.tinted(Tok.suit_color(su))
		$Suits.add_child(g)
	var name_l: Label = $Name
	name_l.text = e.name
	if owned:  # .reftop .tick: a green ✓ after the name
		var nw := name_l.get_theme_font("font").get_string_size(e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_l.get_theme_font_size("font_size")).x
		var t := Tok.tick(Tok.OK, 14)
		t.position = Vector2(name_l.position.x + nw + 9, name_l.position.y + 4.5)
		add_child(t)
	$Pts/Row/Num.text = str(int(e.points))
	for st in _homes(e.name):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.mouse_filter = MOUSE_FILTER_IGNORE
		var ic := Tok.icon(Catalog.station(st).emoji, 13)
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
		h.add_child(Tok.label(st, 13, Tok.INK2, 600))
		$Where.add_child(h)
	$Expand/Label.text = "Hide full breakdown" if open else "Full breakdown"
	var arrow := RefTree.arrow(open, Tok.GOLD)
	arrow.scale = Vector2(0.7, 0.7)
	arrow.position = Vector2(0, 6.5)
	$Expand/Arrow.add_child(arrow)
	var pinned := Progress.is_pinned(e.name)
	$Pin.add_theme_stylebox_override("panel", pin_on if pinned else pin_off)
	$Pin.modulate.a = 1.0 if pinned else 0.5
	$Pin/Icon.material = null if pinned else Tok.grey()
	$Pin.gui_input.connect(func(ev): if Tap.tap(ev):
		App.pin(e.name))
	var h := 103.7
	if open:  # .ref-tree: the full row's width, under the body
		var tr: Control = $Tree
		tr.size.x = w - 32
		var bottom := tree.nodes(tr, RefTree.components(e), "ref/" + e.name, {e.name: true}, Vector2.ZERO, tr.size.x)
		h = tr.position.y + bottom + 14
	size.y = h
	return h


## Names its parts (meta cmp: k, k:icon, k:name...) for the tests.
func tag(k: String) -> void:
	set_meta("cmp", k)
	for n in [["Icon", "icon"], ["Name", "name"], ["Pts", "pts"], ["Where", "where"], ["Expand", "expand"], ["Pin", "pin"], ["Suits", "suits"]]:
		get_node(n[0]).set_meta("cmp", k + ":" + n[1])


## The stations that make it (an item can be made at more than one).
static func _homes(name: String) -> Array:
	var out := []
	for x in Data.t("ENTRIES"):
		if x.name == name and not out.has(x.station):
			out.append(x.station)
	return out


## What the search matches: name, tier, stations, recipe (data-ref).
static func search_text(e: Dictionary) -> String:
	return ("%s %s %s %s" % [e.name, e.tier, " ".join(_homes(e.name)), e.get("recipe", "")]).to_lower()
