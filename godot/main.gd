## Startup: the app with the player's saved run under the title screen
## (every launch opens on it, like the HTML game; Play -> Continue / New
## Game). On a phone the app sits inside the safe area (clear of the notch
## and the gesture bar), the strips around it in dark wood.
extends Control

var _app: App


func _ready() -> void:
	Progress.load_all()
	var strip := ColorRect.new()
	strip.color = Color("#1a120b")
	strip.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(strip)
	_app = App.new()
	add_child(_app)
	_fit_safe_area()
	get_viewport().size_changed.connect(_fit_safe_area)
	_app.show_welcome.call_deferred()  # after the app's own deferred end screen, so it's on top


func _fit_safe_area() -> void:
	var w := get_window()
	var inset := safe_insets(DisplayServer.get_display_safe_area(), w.position, w.size, get_viewport_rect().size)
	_app.offset_top = inset.x
	_app.offset_bottom = -inset.y


## How far the top and bottom bars must move in (design pixels): the parts
## of the window outside the screen's safe area (a notch, a gesture bar).
## Desktop and web: the whole window is safe, so (0, 0).
static func safe_insets(safe: Rect2i, win_pos: Vector2i, win_size: Vector2i, view: Vector2) -> Vector2:
	if safe.size.y <= 0 or win_size.y <= 0:
		return Vector2.ZERO
	var k := view.y / win_size.y  # window pixels -> design pixels
	var top := maxi(0, safe.position.y - win_pos.y)
	var bottom := maxi(0, (win_pos.y + win_size.y) - safe.end.y)
	return Vector2(top, bottom) * k
