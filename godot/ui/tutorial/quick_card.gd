## Quick Rules' card (QuickRules): a parchment window of words, a picture
## under them, Next, and a ✕ to leave. One card for every step: its words
## change and it glides to the step's place (middle, high, top, bottom).
## The layout is ui/tutorial/quick_card.tscn.
class_name QuickCard
extends ParchDialog

const PX := 17  # the words' size (their {🌲} pictures too)

var place := "middle"
var target := Rect2()  # where the window is going (its glide's end)
var anchor := Rect2()  # place "above:<spot>": the spot (this node's coordinates)
var low := false  # nothing on the hub is spotlit: "bottom" sits over the hub (the user, 2026-11-27)
var _glide: Tween


func show_step(say: String, where: String, extra: Control, next: String, above := Rect2(), title := "", title_icon := "") -> void:
	place = where
	anchor = above
	_title(title, title_icon)
	var text: RichTextLabel = $Window/Content/Text
	text.text = "[center]%s[/center]" % emojify(keep_together(say), PX + 6)
	var holder: Control = $Window/Content/Extra
	for c in holder.get_children():
		c.queue_free()
	holder.visible = extra != null
	if extra:
		holder.add_child(extra)
	($Window/Content/Buttons/Next/Text as Label).text = next
	_layout.call_deferred()


## No word or picture alone on a line (the user, 2026-11-27): a {picture}
## holds on to the word before it (or after it, starting a line), and each
## line's last two words (or recipe parts) wrap together. Non-breaking
## spaces: the text server keeps inline images on them too.
static func keep_together(say: String) -> String:
	const NB := " "
	var before := RegEx.create_from_string("(?<=[^ ]) (?=[{])")  # one space: the recipe's wide gaps between parts stay
	var after := RegEx.create_from_string("^([{][^}]*[}]) (?! )")
	var last := RegEx.create_from_string(" +(?=[^ ]*$)")
	var lines := say.replace("-", "-⁠").split("\n")  # a word joiner: To-Do doesn't break at its hyphen (invisible: HarfBuzz hides it)
	for k in lines.size():
		var l: String = after.sub(lines[k], "$1" + NB)
		l = before.sub(l, NB, true)
		var m := last.search(l)
		if m:
			l = l.substr(0, m.get_start()) + NB.repeat(m.get_string().length()) + l.substr(m.get_end())
		lines[k] = l
	return "\n".join(lines)


## The title row over the words: the picture (about a hub button's size)
## left of the name; none without a title.
func _title(title: String, icon: String) -> void:
	var old := $Window/Content.get_node_or_null("Head")
	if old:
		old.free()
	if title == "":
		return
	var head := MarginContainer.new()  # the row, a little room under it
	head.name = "Head"
	head.add_theme_constant_override("margin_bottom", 8)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	if icon != "":
		var ic := Tok.icon(icon, 52)
		ic.custom_minimum_size = Vector2(52, 52)
		ic.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var l := Tok.label(title, 24, Color("#5e4026"), 900)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	head.add_child(row)
	$Window/Content.add_child(head)
	$Window/Content.move_child(head, 0)


## A picture on the window's top-left corner (the Display Mat notices'
## clock), or none.
func set_corner(c: Control) -> void:
	var old := $Window.get_node_or_null("Corner")
	if old:
		old.free()
	if c:
		c.name = "Corner"
		c.position = Vector2(-22, -22)
		c.mouse_filter = MOUSE_FILTER_IGNORE
		$Window.add_child(c)


## The words' width inside the window.
func content_width() -> float:
	return minf(max_width, size.x - side_margin * 2) - 2 * $Window/Content.position.x


func _layout() -> void:
	var win: Control = $Window
	var was := win.position.y
	super()
	var hub_top := size.y - HubBar.H - 16.2 - 18  # clear of the side buttons that rise above the bar
	var y: float = {"middle": win.position.y, "high": win.position.y - 120,
		"top": 24.0, "bottom": (size.y - 12 if low else hub_top) - win.size.y,
		"hub": size.y - HubBar.H - 14 - win.size.y}.get(place, win.position.y)
	if place.begins_with("over:") and anchor.has_area():  # its foot on the spot's top edge
		y = anchor.position.y + 6 - win.size.y
	elif place.begins_with("above:") and anchor.has_area():
		y = anchor.position.y - 14 - win.size.y
	elif place.begins_with("below:") and anchor.has_area():
		y = anchor.end.y + 10
	y = clampf(y, 20, maxf(20, size.y - win.size.y - 10))
	target = Rect2(win.position.x, y, win.size.x, win.size.y)
	if _glide and _glide.is_valid():
		_glide.kill()
	if was == 0 or not Juice.on() or absf(was - y) < 1:
		win.position.y = y
		return
	win.position.y = was
	_glide = win.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_glide.tween_property(win, "position:y", y, 0.35)
