## The hand at a check (card playing, PLAN.md work queue 5): its cards
## fanned like a card game's hand, in two rows of up to 5 (the user,
## 2026-11-23: portrait has the height, and fewer cards a row show more of
## each), each tilted along an arc. Each card overlaps the next one's left
## side, so every card's right side shows: its suit pips, its size badge
## (the user, 2026-11-22). A tap picks a card, another tap puts it back
## (lift(name): the screen keeps the picks, DisplayMatScreen). Picks sit
## raised in the fan (two or more with a tick); the last one tapped shows as
## the full card, components and all, big but in its place in the fan (the
## user, 2026-11-26). A ⭐ marks cards of a known collection the hand can
## finish. A tap on the hand's blank space: lift("") (let go of them all).
class_name HandView
extends Control

signal lift(name: String)  # a card tapped (pick or put back); "": a blank tap, let go of all

@export var card_w := 112.0  # at most: smaller when the two rows need it
@export var per_row := 5
@export var tilt_deg := 3.0  # per card from the row's middle
@export var arc := 1.5  # px each card drops from the middle, by its distance squared
@export var row_overlap := 0.12  # of a card's height: the back row tucked under the front one when short of room
@export var lifted_w := 150.0  # the lifted card's width (a capstone's landscape card: lifted_cap_w)
@export var lifted_cap_w := 260.0

@export var deal_stagger := 0.09  # entering a check: one card after another,
@export var deal_time := 0.32  # each flying up from below into its place

var lifted := ""
var picks: Array = []  # picked: raised (two or more: ticked)
var starred := {}  # card name -> its collection's id: its ⭐
## When the check's deal starts (Time ticks, ms; 0: none). The hand is
## rebuilt on every redraw, so each card works out how far along its own
## fly-in is from this, and a redraw mid-deal doesn't restart it.
static var deal_at := 0
## Cards new since the last redraw (a draw, the refill after a play or a
## discard) rise from below like the deal: name -> when (ms) its rise starts.
static var _arrive := {}
static var _last: Array = []  # the names shown last ([]: a fresh deal, nothing rises)


## Entering a check (the user, 2026-11-23): the hand is dealt in once the
## shutters have parted, `after` seconds from now.
static func deal(after: float) -> void:
	deal_at = 0 if Juice.calm() else Time.get_ticks_msec() + int(after * 1000 / Engine.time_scale)
	_last = []
	_arrive = {}


## The check's opening (the user, 2026-11-23): the hand waits below the
## screen until the challenge window is closed, then deal() brings it in.
static func hold() -> void:
	deal_at = -1
	_last = []
	_arrive = {}


func show_hand(names: Array, lifted_name: String, picked: Array = [], stars := {}) -> void:
	lifted = lifted_name
	picks = picked
	starred = stars
	set_meta("cmp", "hand")  # the tutorial points at the fan
	if not gui_input.is_connected(_blank):
		gui_input.connect(_blank)
	for c in get_children():
		c.queue_free()
	_note_arrivals(names)
	var n := names.size()
	if n == 0:
		return
	var rows: Array = [names] if n <= per_row else [names.slice(0, n - n / 2), names.slice(n - n / 2)]
	var cw := minf(card_w, (size.y - 8) / (rows.size() * (1.0 - row_overlap) + row_overlap) / 1.4)
	var ch := cw * 1.4
	var gap := minf(ch + 4, size.y - 8 - ch)  # foot to foot: apart when there's room, else tucked
	var lift_x := -1.0
	var lift_foot := size.y - 4
	for r in rows.size():  # the back row first: the front one over it
		var foot := size.y - 6 - (rows.size() - 1 - r) * gap
		var x = _fan(rows[r], cw, foot, 0 if r == 0 else rows[0].size())
		if x >= 0:
			lift_x = x
			lift_foot = foot - 18  # raised like the other picks
	if lift_x >= 0:
		_lifted_card(lifted, lift_x, lift_foot, ch * 1.3)  # last: over the whole hand


## One row, its cards' feet on `foot`. Returns the lifted card's centre x
## if it's in this row, else -1.
func _fan(names: Array, cw: float, foot: float, first := 0) -> float:
	var n := names.size()
	var ch := cw * 1.4
	var step := minf(cw + 6, (size.x - 16 - cw) / (n - 1)) if n > 1 else 0.0
	var x0 := (size.x - (cw + step * (n - 1))) / 2
	var mid := (n - 1) / 2.0
	var lift_x := -1.0
	for i in range(n - 1, -1, -1):  # right to left: each card drawn over the one to its right
		var nm: String = names[i]
		var card := ItemCard.make(nm, {"size": true, "star": starred.get(nm, "")})
		card.size = Vector2(cw, ch)
		card.pivot_offset = Vector2(cw / 2, ch)  # tilts from its foot
		var d := i - mid
		card.position = Vector2(x0 + i * step, foot - ch + (d * d - mid * mid) * arc)  # the outer cards sit lowest
		card.rotation_degrees = d * tilt_deg
		card.mouse_filter = MOUSE_FILTER_STOP
		card.set_meta("hand", nm)
		if nm == lifted:
			card.modulate.a = 0.35  # its place in the fan; the full card is over it
			lift_x = card.position.x + cw / 2
		card.gui_input.connect(func(ev): if Tap.tap(ev): lift.emit(nm))
		add_child(card)
		if picks.has(nm):  # picked: raised (two or more: ticked, for Discard)
			card.position.y -= 18
		if picks.has(nm):  # raised and ticked: every pick alike (the user, 2026-11-27)
			var tk := Tok.tick(Color.WHITE, 22, Tok.OK, Tok.CARD)
			tk.position = Vector2(cw - 16, -8)
			tk.mouse_filter = MOUSE_FILTER_IGNORE
			card.add_child(tk)
		_dealt_in(card, first + i)
	return lift_x


## The last card tapped: the full card (CardPop's side card), big, standing
## in its place in the fan (its foot with the raised picks), shrunk to fit
## the hand's area but never under least_h tall (then it rises over the
## buttons); a tap puts it back.
func _lifted_card(nm: String, centre_x: float, foot: float, least_h: float) -> void:
	var cap: bool = Data.t("ITEM_TIER").get(nm, "") == "CAPSTONE"
	var full := CardPop.side_card(nm, lifted_cap_w if cap else lifted_w, true)
	var sz: Vector2 = full.size * full.scale
	var room := maxf(foot + 4, least_h)
	if sz.y > room:  # taller than the room above its foot: smaller
		full.scale *= room / sz.y
		Tok.floor_text(full, full.scale.x)
		sz = full.size * full.scale
	var holder := Control.new()  # takes the tap (the side card ignores the mouse)
	holder.size = sz
	holder.position = Vector2(clampf(centre_x - sz.x / 2, 4, size.x - 4 - sz.x), foot - sz.y)
	holder.mouse_filter = MOUSE_FILTER_STOP
	holder.set_meta("hand", nm)
	holder.set_meta("cmp", "hand:lifted")
	holder.add_child(full)
	if starred.has(nm):  # on the picture's top right, 26 px on screen
		var pic: Control = full.get_node("Card/Icon")
		var star := ItemCard.star_button(26 / full.scale.x, starred[nm])
		star.position = Vector2(pic.size.x - star.size.x * 0.6, -star.size.x * 0.3)
		pic.add_child(star)
	holder.gui_input.connect(func(ev): if Tap.tap(ev): lift.emit(nm))
	add_child(holder)


## The names not shown last time start rising now, one after another.
func _note_arrivals(names: Array) -> void:
	var now := Time.get_ticks_msec()
	var k := 0
	for nm in names:
		if not _last.is_empty() and not _last.has(nm) and not _arrive.has(nm) and Juice.on():
			_arrive[nm] = now + int(k * deal_stagger * 1000 / Engine.time_scale)
			k += 1
	for nm in _arrive.keys():
		if not names.has(nm):
			_arrive.erase(nm)
	_last = names.duplicate()


## The deal: the k-th card flies up from below the screen into its place,
## from wherever it has got to (a redraw mid-deal picks it up there). A
## card new since the last redraw rises the same way.
func _dealt_in(card: Control, k: int) -> void:
	var nm: String = card.get_meta("hand")
	if _arrive.has(nm):
		_rise(card, _arrive[nm])
		return
	if deal_at == 0:
		return
	if deal_at < 0:  # held: out of sight below
		card.position.y = size.y + 40
		return
	_rise(card, deal_at + int(k * deal_stagger * 1000 / Engine.time_scale))


func _rise(card: Control, start: int) -> void:
	var ts := Engine.time_scale  # the clock is real time; tweens follow the game's speed
	var now := Time.get_ticks_msec()
	var p := clampf(float(now - start) * ts / (deal_time * 1000), 0.0, 1.0)
	if p >= 1.0:
		return
	var to := card.position
	var from := Vector2(to.x, size.y + 40)
	card.position = from.lerp(to, ease(p, 0.4))
	var tw := card.create_tween()
	if now < start:
		tw.tween_interval((start - now) * ts / 1000.0)
	tw.tween_property(card, "position", to, deal_time * (1.0 - p)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _blank(ev: InputEvent) -> void:
	if Tap.tap(ev):
		lift.emit("")
