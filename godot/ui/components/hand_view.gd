## The hand at a check (card playing, PLAN.md work queue 5): its cards
## fanned across the bottom like a card game's hand, each tilted along an
## arc, overlapping when there are many. A tap lifts a card (it rises,
## straightens and grows, over the others); a tap on it again puts it back.
## The screen plays the lifted card (DisplayMatScreen).
class_name HandView
extends Control

signal lift(name: String)  # "" when the card is put back

@export var card_w := 96.0
@export var tilt_deg := 3.0  # per card from the middle
@export var arc := 1.5  # px each card drops from the middle, by its distance squared
@export var lift_px := 34.0
@export var lift_scale := 1.2

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
	var up: Control = null
	for i in n:
		var nm: String = names[i]
		var card := ItemCard.make(nm)
		card.size = Vector2(card_w, ch)
		card.pivot_offset = Vector2(card_w / 2, ch)  # tilts and grows from its foot
		var d := i - mid
		card.position = Vector2(x0 + i * step, size.y - ch - 6 + (d * d - mid * mid) * arc)  # the outer cards sit at the foot
		card.rotation_degrees = d * tilt_deg
		if nm == lifted:
			card.position.y -= lift_px
			card.rotation_degrees = 0
			card.scale = Vector2.ONE * lift_scale
			up = card
		card.mouse_filter = MOUSE_FILTER_STOP
		card.set_meta("hand", nm)
		card.gui_input.connect(func(ev): if Tap.tap(ev): lift.emit("" if lifted == nm else nm))
		add_child(card)
	if up:
		move_child(up, -1)
