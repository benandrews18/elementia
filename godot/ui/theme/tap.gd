## A tap: the left button (a finger, on phones) lifted near where it went
## down. A finger that moved further (a scroll) isn't a tap, so dragging a
## list by one of its rows doesn't open the row when the finger lifts.
## Every tappable checks Tap.tap(ev) on each gui_input event (presses too:
## that's how it knows where the finger went down).
class_name Tap

const SLOP := 10.0  # how far a finger may wander and still tap

static var _down: Variant = null  # where the last press was; null: none seen (tests send bare releases)
static var _scrolled := false  # a list scrolled since that press (DragScroll), or the press stopped a fling


static func tap(ev: InputEvent) -> bool:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		return false
	if ev.pressed:
		_down = ev.global_position
		_scrolled = DragScroll.caught
		return false
	return not _scrolled and (_down == null or ev.global_position.distance_to(_down) <= SLOP)
