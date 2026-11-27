## One trophy, tapped in the Trophies grid (openTrophyDetail()): its icon
## (a silhouette when locked), then its name on the banner (or "Locked"),
## how to earn it, and when it was earned. The banner sits under the icon,
## as in the HTML. The layout is ui/overlays/trophy_detail.tscn.
class_name TrophyDetail
extends ParchDialog

const SCENE := "res://ui/overlays/trophy_detail.tscn"

var id := ""


static func show_on(on: Control, trophy: String) -> TrophyDetail:
	var d: TrophyDetail = Tok.make(SCENE)
	d.id = trophy
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	var t: Dictionary = Trophies.all().filter(func(x): return x.id == id)[0]
	var got = Progress.trophies.get(id)
	$Window.title = t.name if got != null else "Locked"
	var ic: TextureRect = $Window/Content/Icon
	ic.texture = Data.icon(t.icon)
	ic.material = null if got != null else Tok.tinted(Color(0, 0, 0, 0.4))
	$Window/Content/Hint.text = t.hint
	var n := int(got.get("n", 1)) if got != null else 0
	$Window/Content/At.text = "Not earned yet" if got == null else (
		"Earned %d times · first %s · latest %s" % [n, got.at, got.last] if n > 1 else "Earned %s" % got.at)
	super()
