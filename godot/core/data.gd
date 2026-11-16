## The HTML game's data and rule tables, exported by
## tools/export_from_game.mjs into data/game_data.json (never hand-edit it).
## Data.t("ITEM_POINTS") returns a table by its JS name.
extends Node

var tables: Dictionary
var icons: Dictionary  # icon key (emoji or __NAME__ or suit:x) -> res:// path

func _init() -> void:
	tables = _read_json("res://data/game_data.json")
	icons = _read_json("res://assets/icons/icons.json")

func t(name: String) -> Variant:
	assert(tables.has(name), "No table %s in game_data.json (re-run the export?)" % name)
	return tables[name]

## The texture for an icon key, or null if the game has no image for it.
func icon(key: String) -> Texture2D:
	return load(icons[key]) if icons.has(key) else null

static func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Missing %s: run node godot/tools/export_from_game.mjs" % path)
	return JSON.parse_string(text)
