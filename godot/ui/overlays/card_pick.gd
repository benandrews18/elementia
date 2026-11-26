## Spending an element in a check with cards (card playing, 2026-11-23):
## an Unknown Element shows every card left in the deck (Hand.pick_draw),
## an element the deck's cards of its suit (Hand.suit_draw; the user,
## 2026-11-26: the player chooses). A tap takes the card into the hand.
## Opened from the mat's Elements tab. The layout is ui/overlays/card_pick.tscn.
class_name CardPick
extends ParchDialog

const SCENE := "res://ui/overlays/card_pick.tscn"
@export var card_w := 94.0


var sym := ""  # the element spent; "": an Unknown Element


static func show_on(on: Control, element := "") -> CardPick:
	var d: CardPick = load(SCENE).instantiate()
	d.sym = element
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	var h = Game.check_hand()
	var grid: GridContainer = $Window/Content/Scroll/Cards
	if sym != "":
		var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
		$Window/Content/Message.text = "Spend 1 %s to take a %s card from your deck into your hand." % [
			Data.t("ELEMENT_NAMES").get(sym, sym), String(Data.t("ELEMENT_SUIT_LABEL").get(suit, suit)).capitalize()]
	for n in ([] if h == null else Hand.suit_cards(h, sym) if sym != "" else h.deck):
		var card := ItemCard.make(n, {"size": true})
		card.custom_minimum_size = Vector2(card_w, card_w * 1.4)
		card.mouse_filter = MOUSE_FILTER_PASS  # a tap takes it (Tap: never a drag; DragScroll scrolls the list)
		card.set_meta("cmp", "pick:" + n)
		var nm: String = n
		card.gui_input.connect(func(ev): if Tap.tap(ev): _take(nm))
		grid.add_child(card)
	super()


func _take(name: String) -> void:
	var h: Dictionary = Game.state.hand
	if (Hand.suit_draw(h, Game.state, sym, name) if sym != "" else Hand.pick_draw(h, Game.state, name)) != "":
		return
	close()
	Game._changed()
