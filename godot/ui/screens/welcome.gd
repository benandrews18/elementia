## The title screen (showWelcomeSlide(), tutorial/0.webp): at every launch,
## from Settings' Home and the end screen's Main Menu. The run underneath is
## untouched; Play opens the Classic window (ClassicMode: Continue / New
## Game), Trophies its window. The layout is ui/screens/welcome.tscn: the
## buttons stack at the bottom over a dark fade; Mini-Games, Combo Lab and
## Collections stay hidden until their features exist (M7, M6 step 8).
class_name WelcomeScreen
extends Control

const SCENE := "res://ui/screens/welcome.tscn"

@export var side := 20.0  # the buttons' inset (.tour-welcome-actions padding)
@export var pad := 24.0  # under the buttons, and the fade above them
@export var max_width := 400.0


static func show_on(on: Control) -> WelcomeScreen:
	var w: WelcomeScreen = load(SCENE).instantiate()
	w.size = on.size
	on.add_child(w)
	return w


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	$Actions/Play.gui_input.connect(func(ev): if Tap.tap(ev): ClassicMode.show_on(get_parent(), self))
	$Actions/Row2/Trophies.gui_input.connect(func(ev): if Tap.tap(ev): TrophiesWindow.show_on(get_parent()))
	$Actions/Settings.gui_input.connect(func(ev): if Tap.tap(ev) and App.current: App.current.open_settings())
	resized.connect(_layout)
	_layout()


## The buttons centred at the bottom (at most max_width wide), the fade
## behind them.
func _layout() -> void:
	var outer := minf(size.x, max_width)
	var acts: VBoxContainer = $Actions
	acts.size = Vector2(outer - side * 2, acts.get_combined_minimum_size().y)
	acts.position = Vector2((size.x - acts.size.x) / 2, size.y - pad - acts.size.y)
	$Shade.position = Vector2((size.x - outer) / 2, acts.position.y - pad)
	$Shade.size = Vector2(outer, size.y - $Shade.position.y)
