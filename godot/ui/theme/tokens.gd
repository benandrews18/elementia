## The game's colours (the HTML game's game/css/base.css :root), as one
## resource: open ui/theme/tokens.tres in the Godot editor and every colour
## is a colour picker in the Inspector. Tok reads these at startup, so a
## change shows everywhere the next time the game runs.
class_name Tokens
extends Resource

@export_group("Text")
@export var ink := Color("#e8edf4")  ## main text on the dark screens
@export var ink2 := Color("#b3becd")  ## secondary text
@export var mute := Color("#7d8899")  ## faint text
@export var card_ink := Color("#181614")  ## text on cream cards

@export_group("Surfaces")
@export var bg := Color("#0f2733")  ## the screen behind everything
@export var bg_soft := Color("#122e3c")
@export var card := Color("#163544")  ## drawers, trays, panels
@export var sunken := Color("#1c4257")  ## inset boxes
@export var parchment := Color("#f2e6cc")  ## item card faces
@export var line := Color("#2a5a72")  ## borders
@export var line2 := Color("#1c4257")
@export var shadow := Color(0, 0, 0, 0.45)

@export_group("Accents")
@export var ok := Color("#3fb46c")  ## green: owned, can do
@export var bad := Color("#f0674c")  ## red: missing, remove
@export var gold := Color("#e2b25a")  ## gold: highlights, edges
@export var gold_soft := Color("#3a2e14")  ## dark gold fill
