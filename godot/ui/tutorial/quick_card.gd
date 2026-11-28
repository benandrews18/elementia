## Quick Rules' card (QuickRules): a parchment window of words, a picture
## under them, Next, and a ✕ to leave. One card for every step: its words
## change and it glides to the step's place (middle, high, top, bottom).
## The layout is ui/tutorial/quick_card.tscn.
class_name QuickCard
extends ParchDialog

const PX := 17  # the words' size (their {🌲} pictures too)

var place := "middle"
var target := Rect2()  # where the window is going (its glide's end)
var _glide: Tween


func show_step(say: String, where: String, extra: Control, next: String) -> void:
	place = where
	var text: RichTextLabel = $Window/Content/Text
	text.text = "[center]%s[/center]" % emojify(say, PX + 3)
	var holder: Control = $Window/Content/Extra
	for c in holder.get_children():
		c.queue_free()
	holder.visible = extra != null
	if extra:
		holder.add_child(extra)
	($Window/Content/Buttons/Next/Text as Label).text = next
	_layout.call_deferred()


## The words' width inside the window.
func content_width() -> float:
	return minf(max_width, size.x - side_margin * 2) - 2 * $Window/Content.position.x


func _layout() -> void:
	var win: Control = $Window
	var was := win.position.y
	super()
	var hub_top := size.y - HubBar.H - 16.2 - 18  # clear of the side buttons that rise above the bar
	var y: float = {"middle": win.position.y, "high": win.position.y - 120,
		"top": 24.0, "bottom": hub_top - win.size.y}.get(place, win.position.y)
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
