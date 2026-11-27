## A short explanation by a tapped icon (step 27, the user 2026-11-26:
## every icon tells you something): a dark balloon above it (below when
## there's no room), gone on the next press anywhere or after 3.5 s. One at
## a time.
class_name Explain
extends Label

static var _shown: Explain


## Makes icon c answer a tap with text() (a Callable: worked out when tapped).
static func on_tap(c: Control, text: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev): if Tap.tap(ev): show_at(c, text.call()))


static func show_at(target: Control, msg: String) -> void:
	var app := App.current
	if app == null or msg == "":
		return
	if is_instance_valid(_shown):
		_shown.queue_free()
	var e := Explain.new()
	e.text = msg
	e.add_theme_font_override("font", Tok.font(800))
	e.add_theme_font_size_override("font_size", 13)
	e.add_theme_color_override("font_color", Color.WHITE)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sb := Tok.box(Color("#0e2430"), 12, 1.5, Tok.GOLD, 6, 3, Color(0, 0, 0, 0.45))
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 12)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 8)
	e.add_theme_stylebox_override("normal", sb)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.set_meta("cmp", "explain")
	var w := minf(260, app.size.x - 24)
	var tw := Tok.font(800).get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24
	w = minf(w, tw + 2)
	e.custom_minimum_size = Vector2(w, 0)
	app.add_child(e)
	e.size = Vector2(w, 0)
	e.size = Vector2(w, e.get_minimum_size().y)
	var r := target.get_global_rect()
	var x := clampf(r.get_center().x - w / 2, 12, app.size.x - 12 - w)
	var y := r.position.y - e.size.y - 8
	if y < 12:
		y = r.end.y + 8
	e.position = Vector2(x, y) - app.global_position
	_shown = e
	Juice.pop_in(e)
	e.get_tree().create_timer(3.5).timeout.connect(func(): if is_instance_valid(e): e.queue_free())


func _input(ev: InputEvent) -> void:  # the next press anywhere puts it away (the press still lands)
	if ev is InputEventMouseButton and ev.pressed and Engine.get_process_frames() > _born + 1:
		queue_free()


var _born := 0

func _ready() -> void:
	_born = Engine.get_process_frames()


## A suit's line: what its icon on a card means.
static func suit(su: String) -> String:
	var label: String = str(Data.t("ELEMENT_SUIT_LABEL").get(su, su)).capitalize()
	var els: Array = Data.t("ELEMENT_SUIT").keys().filter(func(s): return Data.t("ELEMENT_SUIT")[s] == su)
	return "%s suit (%s). On an item: crafting it also costs one %s element." % [label, ", ".join(els.slice(0, 6)), label]


## A station's line.
static func station(name: String, extra := "") -> String:
	return name + (": " + extra if extra != "" else "")
