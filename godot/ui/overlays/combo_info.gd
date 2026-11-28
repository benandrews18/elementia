## A combo chip tapped on the mat (openComboInfo(); the user, 2026-11-23):
## the mat cards making that combo (icon, name and the icon being counted)
## and the plays that made it together (counted again), or, for the ⭐,
## the found collections the mat completes (CollectionRow). The window is
## ui/overlays/combo_info.tscn; the rows are built here.
class_name ComboInfo
extends ParchDialog

const SCENE := "res://ui/overlays/combo_info.tscn"

@export var row_px := 30.0  # a card row's icon

var kind := ""  # "station", "suit", "component" or "collection"
var key := ""


## combo: a chip's meta "combo" ("station:<name>", "suit:<suit>",
## "component:<item>" or "collection").
static func open_for(on: Control, combo: String) -> ComboInfo:
	var d: ComboInfo = Tok.make(SCENE)
	d.kind = combo.get_slice(":", 0)
	d.key = combo.substr(combo.find(":") + 1) if combo.contains(":") else ""
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	var box: VBoxContainer = $Window/Content
	var w: float = box.size.x
	if kind == "collection":
		var sc: Dictionary = Game.mat_score()
		var found: Array = Util.get_or(Progress.prefs, "everUnlockedMatCollections", [])
		var cols: Array = sc.cols.filter(func(c): return found.has(c.id))
		$Window.title = "Named Collections (%d)" % cols.size()
		# the banner's icon spot holds a drawn ★ (not in Nunito; a text ★ differs per device)
		$Window.icon = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
		$Window/Banner/Icon.add_child(Tok.star(Tok.GOLD, 24))
		for c in cols:
			var r := CollectionRow.make()
			r.custom_minimum_size.y = r.fill(c, null, w)
			r.get_node("Toggle").visible = false  # a summary: no switching here
			box.add_child(r)
	else:
		var cards := cards_for(kind, key)
		var label: String = Data.t("ELEMENT_SUIT_LABEL").get(key, key) if kind == "suit" else key
		var plays := together_plays(kind, key)
		var extra := 0
		for p in plays:
			extra += p.size()
		$Window.title = "%s ×%d" % [label, cards.size() + extra]
		$Window.icon = Data.icon(Catalog.station(key).emoji if kind == "station" else "suitdisc:" + key if kind == "suit" else Data.t("ITEM_EMOJI").get(key, ""))
		for c in cards:
			box.add_child(_row(c, w))
		for p in plays:
			box.add_child(_together_row(p, w))
	super()


## matCardsForCombo(): the mat cards earning a combo.
static func cards_for(k: String, name: String) -> Array:
	var mat := Mat.on_mat(Game.state)
	match k:
		"station": return mat.filter(func(c): return c.stations.has(name))
		"suit": return mat.filter(func(c): return c.pips.has(name))
		"component": return mat.filter(func(c): return c.name == name or Mat.direct_items(c).has(name))
	return []


## The plays (their mat cards making this combo) that made it by
## themselves: each counts again (Mat.together).
static func together_plays(k: String, name: String) -> Array:
	var mat := Mat.on_mat(Game.state)
	var making := cards_for(k, name).map(func(c): return c.name)
	var out := []
	for names in Util.get_or(Game.state, "matPlays", []):
		if names.size() < 2 or not names.all(func(n): return Mat.has(mat, n)):
			continue
		var in_it: Array = names.filter(func(n): return making.has(n))
		if Mat.combo_tier(in_it.size()) > 0:
			out.append(in_it)
	return out


## A mat card: its icon, its name, and next to the name the icon this
## combo counts on it (its station, suit or ingredient).
func _row(c: Dictionary, w: float) -> Control:
	var row := Panel.new()
	row.add_theme_stylebox_override("panel", Tok.box(Color(1, 1, 1, 0.35), 10, 1.5, Color("#c9a571")))
	row.custom_minimum_size = Vector2(w, row_px + 12)
	var ic := Tok.icon(Data.t("ITEM_EMOJI").get(c.name, ""), row_px)
	ic.position = Vector2(8, 6)
	row.add_child(ic)
	var nm := Tok.label(c.name, 15, Tok.CARD_INK, 800)
	nm.position = Vector2(row_px + 18, 6 + (row_px - nm.get_minimum_size().y) / 2)
	row.add_child(nm)
	var cx := nm.position.x + nm.get_minimum_size().x + 8
	var cy := 6 + (row_px - 22) / 2
	if kind == "suit":
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		dot.position = Vector2(cx, cy)
		dot.size = Vector2(22, 22)
		dot.add_child(Tok.icon("suitdisc:" + key, 22))
		row.add_child(dot)
	else:
		var counted := Tok.icon(Catalog.station(key).emoji if kind == "station" else Data.t("ITEM_EMOJI").get(key, ""), 22)
		counted.position = Vector2(cx, cy)
		row.add_child(counted)
	return row


## "Played together": the cards of one play that made this combo by
## themselves, and what they add to its count.
func _together_row(names: Array, w: float) -> Control:
	var row := Panel.new()
	row.add_theme_stylebox_override("panel", Tok.box(Color(Tok.OK, 0.18), 10, 1.5, Tok.OK))
	row.custom_minimum_size = Vector2(w, row_px + 12)
	row.set_meta("cmp", "combo:together")
	var nm := Tok.label("Played together", 14, Tok.CARD_INK, 900)
	nm.position = Vector2(10, 6 + (row_px - nm.get_minimum_size().y) / 2)
	row.add_child(nm)
	var x := nm.position.x + nm.get_minimum_size().x + 8
	for n in names:
		var ic := Tok.icon(Data.t("ITEM_EMOJI").get(n, ""), 24)
		ic.position = Vector2(x, 6 + (row_px - 24) / 2)
		row.add_child(ic)
		x += 26
	var add := Tok.label("+%d" % names.size(), 15, Tok.OK, 900)
	add.position = Vector2(w - 12 - add.get_minimum_size().x, nm.position.y)
	row.add_child(add)
	return row
