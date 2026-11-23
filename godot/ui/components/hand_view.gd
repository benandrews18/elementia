## The hand at a check (card playing, PLAN.md work queue 5): its cards
## fanned across the bottom like a card game's hand, each tilted along an
## arc. Each card overlaps the next one's left side, so every card's right
## side shows: its suit pips, its size badge (the user, 2026-11-22). A tap
## lifts a card out of the fan as the full card, components and all, on
## top; a tap on it again puts it back. The screen plays the lifted card
## (DisplayMatScreen).
class_name HandView
extends Control

signal lift(name: String)  # "" when the card is put back

@export var card_w := 96.0
@export var tilt_deg := 3.0  # per card from the middle
@export var arc := 1.5  # px each card drops from the middle, by its distance squared
@export var lifted_w := 150.0  # the lifted card's width (a capstone's landscape card: lifted_cap_w)
@export var lifted_cap_w := 260.0

var lifted := ""


func show_hand(names: Array, lifted_name: String) -> void:
	lifted = lifted_name
	for c in get_children():
		c.queue_free()
	var n := names.size()
	if n == 0:
		return
	var ch := card_w * 1.4
	var step := minf(card_w + 6, (size.x - 16 - card_w) / (n - 1)) if n > 1 else 0.0
	var x0 := (size.x - (card_w + step * (n - 1))) / 2
	var mid := (n - 1) / 2.0
	var lift_x := -1.0
	for i in range(n - 1, -1, -1):  # right to left: each card drawn over the one to its right
		var nm: String = names[i]
		var card := ItemCard.make(nm, {"size": true})
		card.size = Vector2(card_w, ch)
		card.pivot_offset = Vector2(card_w / 2, ch)  # tilts from its foot
		var d := i - mid
		card.position = Vector2(x0 + i * step, size.y - ch - 6 + (d * d - mid * mid) * arc)  # the outer cards sit at the foot
		card.rotation_degrees = d * tilt_deg
		card.mouse_filter = MOUSE_FILTER_STOP
		card.set_meta("hand", nm)
		if nm == lifted:
			card.modulate.a = 0.35  # its place in the fan; the full card is over it
		card.gui_input.connect(func(ev): if Tap.tap(ev): lift.emit("" if lifted == nm else nm))
		add_child(card)
		if nm == lifted:
			lift_x = card.position.x + card_w / 2
	if lift_x >= 0:
		_lifted_card(lifted, lift_x)  # last: over the whole fan


## The lifted card: the full card (CardPop's side card), raised out of the
## fan over its place, kept on screen; a tap puts it back.
func _lifted_card(nm: String, centre_x: float) -> void:
	var cap: bool = Data.t("ITEM_TIER").get(nm, "") == "CAPSTONE"
	var full := CardPop.side_card(nm, lifted_cap_w if cap else lifted_w)
	var sz: Vector2 = full.size * full.scale
	var holder := Control.new()  # takes the tap (the side card ignores the mouse)
	holder.size = sz
	holder.position = Vector2(clampf(centre_x - sz.x / 2, 4, size.x - 4 - sz.x), size.y - 4 - sz.y)
	holder.mouse_filter = MOUSE_FILTER_STOP
	holder.set_meta("hand", nm)
	holder.set_meta("cmp", "hand:lifted")
	holder.add_child(full)
	holder.gui_input.connect(func(ev): if Tap.tap(ev): lift.emit(""))
	add_child(holder)
