## The HTML game's data and rule tables, exported by
## tools/export_from_game.mjs into data/game_data.json (never hand-edit it).
## Data.t("ITEM_POINTS") returns a table by its JS name.
extends Node

var tables: Dictionary
var icons: Dictionary  # icon key (emoji or __NAME__ or suit:x) -> res:// path

func _init() -> void:
	tables = _read_json("res://data/game_data.json")
	tables.merge(derive(tables))
	icons = _read_json("res://assets/icons/icons.json")

func t(name: String) -> Variant:
	assert(tables.has(name), "No table %s in game_data.json (re-run the export?)" % name)
	return tables[name]

## The texture for an icon key (an item's emoji, __NAME__, suit:x), or one of
## the UI emoji in assets/emoji (Noto images: the web has no emoji font), or
## null.
func icon(key: String) -> Texture2D:
	if icons.has(key):
		return load(icons[key])
	if icons.has(key + char(0xfe0f)):  # the item tables write some emoji with the variation selector
		return load(icons[key + char(0xfe0f)])
	var cps := []
	for c in key:
		if c.unicode_at(0) != 0xfe0f:
			cps.append("%x" % c.unicode_at(0))
	var path := "res://assets/emoji/emoji_u%s.png" % "_".join(cps)
	return load(path) if ResourceLoader.exists(path) else null

## The tables worked out from DATA and the hand-written ones (model.js,
## mat-scoring.js, map-graph.js, lock-in.js, trophies.js), so editing an
## item, a station or a table in game_data.json is all a change needs.
static func derive(t: Dictionary) -> Dictionary:
	var stations: Array = t.DATA.stations
	var d := {"ENTRIES": [], "ITEM_EMOJI": {}, "ITEM_TIER": {}, "ITEM_POINTS": {}, "UNLOCKED_BY": {},
		"STATION_BY_NAME": {}, "CORE_ITEM_STATION": {}, "MAP_ADJ": {}, "STATION_SHOP": {}, "MAT_CARD_BY_NAME": {}}
	var dice := []
	for s in stations:
		for el in s.dice:
			if not dice.has(el):
				dice.append(el)
		var rows: Array = s.shop + [s.capstone]
		for row in rows + s.get("unlock", []):
			d.ENTRIES.append({"station": s.name, "emoji": row[0], "name": row[1], "tier": row[2], "recipe": row[3],
				"points": row[4], "reqs": parse_recipe(row[3])})
			d.ITEM_EMOJI[row[1]] = row[0]
			d.ITEM_TIER[row[1]] = row[2]
			d.ITEM_POINTS[row[1]] = row[4]
		for row in s.get("unlock", []):
			d.UNLOCKED_BY[row[1]] = s.capstone[1]
		d.STATION_BY_NAME[s.name] = s
		d.STATION_SHOP[s.name] = s.shop.map(func(r): return r[1])
	d.ELEMENTS = dice
	d.CLASSIC_ELEMENTS = dice.duplicate()
	d.CAPSTONES = stations.map(func(s): return s.capstone[1])
	d.CORE_ITEM_NAMES = []
	for e in d.ENTRIES:
		if not d.CORE_ITEM_STATION.has(e.name):
			d.CORE_ITEM_STATION[e.name] = e.station
			d.CORE_ITEM_NAMES.append(e.name)
	var suits: Array = t.ELEMENT_SUIT_LABEL.keys()
	d.ORDER_SUITS = suits
	d.MAT_PIPS_EXTRA = {"Planet": suits.duplicate()}
	d.SUIT_CORE_ELEMENTS = {}
	for suit in suits:
		d.SUIT_CORE_ELEMENTS[suit] = t.CORE_ELEMENT_SYMS.filter(func(sym): return t.ELEMENT_SUIT.get(sym) == suit)
	d.MAT_CARDS = []
	for name in d.CORE_ITEM_NAMES:
		var home: String = d.CORE_ITEM_STATION[name]
		var at := [home]
		var entry = null
		for e in d.ENTRIES:
			if e.name == name:
				if entry == null and e.station == home:
					entry = e
				if not at.has(e.station):
					at.append(e.station)
		var card := {"name": name, "points": d.ITEM_POINTS[name], "tier": d.ITEM_TIER[name], "emoji": d.ITEM_EMOJI[name],
			"station": home, "stations": at, "pips": d.MAT_PIPS_EXTRA.get(name, t.ITEM_SUIT_COST_TABLE.get(name, [])),
			"components": entry.reqs if entry else []}
		d.MAT_CARDS.append(card)
		d.MAT_CARD_BY_NAME[name] = card
	for edge in t.MAP_EDGES:
		for i in 2:
			var adj: Array = d.MAP_ADJ.get_or_add(edge[i], [])
			if not adj.has(edge[1 - i]):
				adj.append(edge[1 - i])
	d.MAT_SLOTS_TOTAL = t.MAT_SLOTS_COLS * t.MAT_SLOTS_ROWS
	var half := int(t.BINGO_SIZE) / 2
	d.BINGO_CENTER_IDX = half * t.BINGO_SIZE + half
	d.MAX_VISITS = t.DEFAULT_MAX_VISITS
	return d


## parseRecipe(): "Fe + C* + 💧 Water" -> [{name, kind, emoji, catalyst}].
static func parse_recipe(recipe: String) -> Array:
	var out := []
	for tok in recipe.split("+"):
		tok = tok.strip_edges()
		if tok == "":
			continue
		var catalyst := tok.ends_with("*")
		tok = tok.replace("*", "").strip_edges()
		if RegEx.create_from_string("^[A-Z][a-z]?$").search(tok):
			out.append({"name": tok, "kind": "element", "emoji": "", "catalyst": catalyst})
			continue
		var sp := tok.find(" ")
		out.append({"name": tok.substr(sp + 1).strip_edges() if sp >= 0 else tok, "kind": "item",
			"emoji": tok.substr(0, sp) if sp >= 0 else "", "catalyst": catalyst})
	return out


static func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Missing %s: run node godot/tools/export_from_game.mjs" % path)
	return JSON.parse_string(text)
