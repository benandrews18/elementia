## One trophy in the Trophies grid (.trophy-mini): its icon, in colour on
## gold when earned, a dark silhouette when not; ×n when earned on more than
## one day. The look is ui/pieces/trophy_tile.tscn.
class_name TrophyTile
extends Panel

const SCENE := "res://ui/pieces/trophy_tile.tscn"

@export var earned_style: StyleBox
@export var locked_style: StyleBox
@export var locked_tint := Color(0, 0, 0, 0.4)  # brightness(0) opacity(.4)

var id := ""


static func make() -> TrophyTile:
	return load(SCENE).instantiate()


## t: a Trophies.all() entry; got: its {at, last, n}, or null.
func fill(t: Dictionary, got: Variant) -> void:
	id = t.id
	add_theme_stylebox_override("panel", earned_style if got != null else locked_style)
	$Icon.texture = Data.icon(t.icon)
	$Icon.material = null if got != null else Tok.tinted(locked_tint)
	var n: int = int(got.get("n", 1)) if got != null else 0
	$Count.visible = n > 1
	$Count/Text.text = "×%d" % n
