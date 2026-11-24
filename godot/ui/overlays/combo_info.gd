## A combo chip tapped on the mat (openComboInfo(); the user, 2026-11-23):
## the mat cards making that combo (icon, name, points), or, for the ⭐,
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
	var d: ComboInfo = load(SCENE).instantiate()
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
		$Window.title = "★ Named Collections (%d)" % cols.size()
		for c in cols:
			var r := CollectionRow.make()
			r.custom_minimum_size.y = r.fill(c, null, w)
			r.get_node("Toggle").visible = false  # a summary: no switching here
			box.add_child(r)
	else:
		var cards := cards_for(kind, key)
		var label: String = Data.t("ELEMENT_SUIT_LABEL").get(key, key) if kind == "suit" else key
		$Window.title = "%s ×%d" % [label, cards.size()]
		$Window.icon = Data.icon(Catalog.station(key).emoji if kind == "station" else "suit:" + key if kind == "suit" else Data.t("ITEM_EMOJI").get(key, ""))
		for c in cards:
			box.add_child(_row(c, w))
	super()


## matCardsForCombo(): the mat cards earning a combo.
static func cards_for(k: String, name: String) -> Array:
	var mat := Mat.on_mat(Game.state)
	match k:
		"station": return mat.filter(func(c): return c.stations.has(name))
		"suit": return mat.filter(func(c): return c.pips.has(name))
		"component": return mat.filter(func(c): return c.name == name or Mat.direct_items(c).has(name))
	return []


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
	var pts := Tok.label(str(int(c.points)), 15, Tok.CARD_INK, 800)
	pts.position = Vector2(w - 12 - pts.get_minimum_size().x, nm.position.y)
	row.add_child(pts)
	return row
