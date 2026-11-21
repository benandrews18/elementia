## The roll (playRollAnimation(), #rollPopup in station.css): the screen dims,
## a card shows the rolled elements as big chips, each first covered by a
## die that tumbles, then fades to reveal the element; Collect sends them
## flying into the Inventory button. The roll itself has already happened
## (Game.do_roll()); this only shows it. Emits done.
class_name RollPopup
extends Control

signal done

const CHIP := 84.0
const STAGGER := 0.09
const TUMBLE := 0.5
const PAUSE := 0.35
const PIP := Color("#c9d3e0")
const PIPS := {1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8]}

## The layout is ui/overlays/roll_popup.tscn (the card, its title, Collect);
## this lays out the rolled chips and plays the reveal.
const SCENE := "res://ui/overlays/roll_popup.tscn"

var roll: Array  # [{face, sym}]
var fly_to := Vector2.ZERO  # the Inventory button's centre
var _chips: Array[Control] = []
@onready var _collect: Control = $Box/Collect
@onready var _box: Panel = $Box


static func make() -> RollPopup:
	return load(SCENE).instantiate()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var cols := mini(3, roll.size())
	var rows := ceili(roll.size() / 3.0)
	var row_w := cols * CHIP + (cols - 1) * 16
	var row_h := rows * (CHIP + 6 + 11) + (rows - 1) * 14
	var bw := minf(440, size.x - 32)
	var bh := 18 + 19 + 16 + row_h + 16 + 46 + 16
	_box.size = Vector2(bw, bh)
	_box.position = (size - _box.size) / 2
	var title: Control = $Box/Title
	title.size = title.get_combined_minimum_size()
	title.position.x = (bw - title.size.x) / 2
	for i in roll.size():
		var c := _chip(roll[i])
		c.position = Vector2((bw - row_w) / 2 + (i % 3) * (CHIP + 16), 18 + 19 + 16 + (i / 3) * (CHIP + 17 + 14))
		$Box/Chips.add_child(c)
		_chips.append(c)
	_collect.size = Vector2(maxf(bw * 0.6, 120), 46)
	_collect.position = Vector2((bw - _collect.size.x) / 2, bh - 16 - 46)
	_collect.gui_input.connect(_on_collect)
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	# Each die tumbles, holds on its face, then fades off the element.
	for i in _chips.size():
		var die: Control = _chips[i].get_meta("die")
		var t0 := i * STAGGER
		var tw := create_tween()
		tw.tween_interval(t0)
		for k in [[-18.0, 1.12], [14.0, 0.94], [-8.0, 1.06], [0.0, 1.0]]:
			tw.tween_property(die, "rotation_degrees", k[0], TUMBLE / 4).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(die, "scale", Vector2(k[1], k[1]), TUMBLE / 4).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(PAUSE)
		tw.tween_property(die, "modulate:a", 0.0, 0.18)
		tw.parallel().tween_property(_chips[i].get_meta("face"), "modulate:a", 1.0, 0.18)
	var last := (_chips.size() - 1) * STAGGER + TUMBLE + PAUSE + 0.3
	var show := create_tween()
	show.tween_interval(last)
	show.tween_callback(func(): _collect.visible = true)
	show.tween_property(_collect, "modulate:a", 1.0, 0.2)


## A rolled element: the white chip (suit border, number, badge, name),
## with the die face over it until the reveal.
func _chip(r: Dictionary) -> Control:
	var sym: String = r.sym
	var color := Color(Data.t("ELEMENT_COLOR").get(sym, "#8a94a6"))
	var c := Control.new()
	c.size = Vector2(CHIP, CHIP + 17)
	var face := Control.new()  # everything revealed (faded in)
	face.size = c.size
	face.modulate.a = 0
	var sq := Panel.new()
	sq.add_theme_stylebox_override("panel", Tok.box(Color.WHITE, 12, 6, color))
	sq.size = Vector2(CHIP, CHIP)
	c.add_child(sq)
	var s := Tok.label(sym, 32, Color("#221f1a"), 800)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0, 18)
	s.size = Vector2(CHIP, 36)
	face.add_child(s)
	var num := Tok.label(str(int(Data.t("ATOMIC_NUMBER").get(sym, 0))), 12, color, 800)
	num.position = Vector2(12, 8)
	face.add_child(num)
	var nm := Tok.label(Data.t("ELEMENT_NAMES").get(sym, sym), 10.5, Color.BLACK, 700)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(6, 56)
	nm.size = Vector2(CHIP - 12, 14)
	face.add_child(nm)
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	if suit != "":
		var b := Panel.new()
		b.add_theme_stylebox_override("panel", Tok.box(Tok.suit_color(suit), 10, 0, Color.BLACK, 2, 1, Color(0, 0, 0, 0.45)))
		b.position = Vector2(CHIP - 6 + 7 - 20, -7 + 6)
		b.size = Vector2(20, 20)
		var g := Tok.icon("suit:" + suit, 14)
		g.position = Vector2(3, 3)
		g.material = Tok.white()
		b.add_child(g)
		face.add_child(b)
	c.add_child(face)
	var die := Control.new()  # .rc-die: the face's pips on a dark square
	die.size = Vector2(CHIP, CHIP)
	die.pivot_offset = die.size / 2
	var pips: Array = PIPS[int(r.face)]
	die.draw.connect(func():
		die.draw_style_box(Tok.box(Tok.SUNKEN, 12, 2, Tok.LINE), Rect2(Vector2.ZERO, die.size))
		for p in pips:
			var at := Vector2([0.2, 0.5, 0.8][p % 3], [0.2, 0.5, 0.8][p / 3]) * CHIP
			die.draw_circle(at, CHIP * 0.3 * 0.45 / 2 * 1.6, PIP))
	c.add_child(die)
	c.set_meta("die", die)
	c.set_meta("face", face)
	return c


## The green pill button (.bigbtn on pill_long.webp, 46 / 14px).
static func _pill_button(text: String, sz: Vector2) -> Control:
	var b: Control = load("res://ui/pieces/pill_button.tscn").instantiate()  # its Label is child 0
	b.size = sz
	b.get_node("Text").text = text
	return b


## Collect: each chip flies to the Inventory button, shrinking into it; the
## card fades away underneath.
func _on_collect(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) or not _collect.visible:
		return
	_collect.visible = false
	var fade := create_tween()
	fade.tween_property(_box, "modulate:a", 0.0, 0.22)
	fade.parallel().tween_property(get_child(0), "modulate:a", 0.0, 0.22)
	for i in _chips.size():
		var c := _chips[i]
		var at := c.global_position
		c.reparent(self)
		c.global_position = at
		c.pivot_offset = c.size / 2
		var target := fly_to - c.size / 2
		var tw := create_tween()
		tw.tween_interval(i * 0.045)
		tw.tween_property(c, "global_position", target, 0.48 * 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(c, "scale", Vector2(0.55, 0.55), 0.48 * 0.72)
		tw.tween_property(c, "scale", Vector2(0.15, 0.15), 0.48 * 0.28)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.48 * 0.28)
	var end := create_tween()
	end.tween_interval((_chips.size() - 1) * 0.045 + 0.5)
	end.tween_callback(func():
		done.emit()
		queue_free())
