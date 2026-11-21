## The clue gifts (openClueBoxes(); bought in Collections): "Gift 1 of N",
## a 🎁 that wobbles until tapped, then shakes open (0.65s) and its clue
## card shows (ClueCard: the collection, what's known, the new item ringed;
## its last item discovers it). Next brings the next gift; Done closes.
## The layout is ui/overlays/clue_open.tscn.
class_name ClueOpen
extends ParchDialog

const SCENE := "res://ui/overlays/clue_open.tscn"

@export var open_time := 0.65  # the shake before the card

var clues: Array = []  # Progress.buy_clues(): [{c, item, known, discovered}]
var _i := 0
var _wobble: Tween


static func show_on(on: Control, got: Array) -> ClueOpen:
	var d: ClueOpen = load(SCENE).instantiate()
	d.clues = got
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	var box: TextureRect = $Window/Content/Gift/Box
	box.texture = Data.icon("🎁")
	box.gui_input.connect(func(ev): if Tap.tap(ev): _reveal())
	$Window/Content/Next.gui_input.connect(func(ev): if Tap.tap(ev): _next())
	_show_box()
	super()


## showClueBox(): this gift, wrapped.
func _show_box() -> void:
	var c := $Window/Content
	c.get_node("Count").text = "Gift %d of %d" % [_i + 1, clues.size()]
	c.get_node("Count").visible = true
	c.get_node("Gift").visible = true
	c.get_node("Tap").visible = true
	c.get_node("Next").visible = false
	for n in c.get_node("CardHolder").get_children():
		n.queue_free()
	c.get_node("CardHolder").visible = false
	var box: TextureRect = c.get_node("Gift/Box")
	box.scale = Vector2.ONE
	box.rotation = 0
	box.modulate.a = 1
	box.pivot_offset = box.size / 2
	if _wobble:
		_wobble.kill()
	_wobble = box.create_tween().set_loops()  # clueWobble: 1.4s, over and over
	_wobble.tween_property(box, "rotation_degrees", -6.0, 0.28)
	_wobble.parallel().tween_property(box, "scale", Vector2(1.04, 1.04), 0.28)
	_wobble.tween_property(box, "rotation_degrees", 5.0, 0.28)
	_wobble.tween_property(box, "rotation_degrees", 0.0, 0.28)
	_wobble.parallel().tween_property(box, "scale", Vector2.ONE, 0.28)
	_wobble.tween_interval(0.56)


## revealClue(): the box shakes, swells and fades, then the card.
func _reveal() -> void:
	var box: TextureRect = $Window/Content/Gift/Box
	if not $Window/Content/Gift.visible or box.has_meta("opening"):
		return
	box.set_meta("opening", true)
	if _wobble:
		_wobble.kill()
	var tw := box.create_tween()
	var step := open_time / 6
	for r in [[-12, 1.1], [12, 1.15], [-14, 1.2], [14, 1.25], [0, 1.5]]:
		tw.tween_property(box, "rotation_degrees", r[0], step)
		tw.parallel().tween_property(box, "scale", Vector2(r[1], r[1]), step)
	tw.tween_property(box, "scale", Vector2(2.2, 2.2), step)
	tw.parallel().tween_property(box, "modulate:a", 0.0, step)
	tw.tween_callback(func():
		box.remove_meta("opening")
		_card())


func _card() -> void:
	var clue: Dictionary = clues[_i]
	var c := $Window/Content
	c.get_node("Count").visible = false
	c.get_node("Gift").visible = false
	c.get_node("Tap").visible = false
	var card := ClueCard.make()
	var col: Dictionary = clue.c
	card.fill(col, clue.known, clue.item, clue.discovered, "Collection discovered!" if clue.discovered else "New clue",
		"+%d on your mat when it's all there" % int(col.bonus) if clue.discovered else "%s is in this collection" % clue.item)
	c.get_node("CardHolder").add_child(card)
	c.get_node("CardHolder").visible = true
	var last := _i >= clues.size() - 1
	var nl: Label = c.get_node("Next/Text")
	nl.text = "Done" if last else "Next gift (%d left)" % (clues.size() - _i - 1)
	c.get_node("Next").custom_minimum_size.x = nl.get_theme_font("font").get_string_size(nl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nl.get_theme_font_size("font_size")).x + 48
	c.get_node("Next").visible = true


func _next() -> void:
	_i += 1
	if _i >= clues.size():
		close()
	else:
		_show_box()
