## Spending an Unknown Element in a check with cards (card playing,
## 2026-11-23): every card left in the deck; a tap takes it into the hand
## (Hand.pick_draw). Opened from the "?" on the mat's Elements tab. The layout is ui/overlays/card_pick.tscn.
class_name CardPick
extends ParchDialog

const SCENE := "res://ui/overlays/card_pick.tscn"
@export var card_w := 94.0


static func show_on(on: Control) -> CardPick:
	var d: CardPick = load(SCENE).instantiate()
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	var h = Game.ctx.get("hand")
	var grid: GridContainer = $Window/Content/Scroll/Cards
	for n in (h.deck if h != null else []):
		var card := ItemCard.make(n, {"size": true})
		card.custom_minimum_size = Vector2(card_w, card_w * 1.4)
		card.mouse_filter = MOUSE_FILTER_STOP
		card.set_meta("cmp", "pick:" + n)
		var nm: String = n
		card.gui_input.connect(func(ev): if Tap.tap(ev): _take(nm))
		grid.add_child(card)
	super()


func _take(name: String) -> void:
	if Hand.pick_draw(Game.ctx.hand, Game.state, name) != "":
		return
	close()
	Game._changed()
