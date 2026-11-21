## History (renderHistory(); the Classic window's History row): this
## device's finished runs, newest first, one HistEntry each (a tap opens its
## turn-by-turn log), scrolling past half the screen's height; ⧉ Export
## copies them all as JSON (a run's own ⧉ copies just that run). The title
## banner sits at the left, Export at the right (.hist-header). The layout
## is ui/overlays/history.tscn. In Developer mode, Runs / Dev runs tabs
## (runs changed with the Dev Panel are kept apart; dev.js).
class_name HistoryWindow
extends ParchDialog

const SCENE := "res://ui/overlays/history.tscn"

@export var max_list := 0.5  # of the screen's height (.histrows max-height:50vh)
@export var banner_x := 46.5  # the banner's left edge in the window
@export var tab_off: StyleBox  # .hist-tab
@export var tab_on: StyleBox  # .hist-tab.on

static var dev_tab := false  # Dev runs shown (kept while the game runs, like the HTML's histTab)

var _empty_text := ""  # the scene's (real runs)
var _open := {}  # run index -> its log shown


static func show_on(on: Control) -> HistoryWindow:
	return ParchDialog.open(on, SCENE) as HistoryWindow


func _ready() -> void:
	$Window.icon = Data.icon("🕓")  # left out if the game has no image for it
	var ex: Control = $Window/Export
	var glyph := Tok.copy_glyph(HistEntry.MUTE, 12)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.get_node("Row").add_child(glyph)
	ex.get_node("Row").move_child(glyph, 0)
	ex.gui_input.connect(func(ev): if Tap.tap(ev): _export())
	_empty_text = $Window/Content/Empty.text
	$Window/Content/Tabs.visible = Progress.prefs.get("devMode") == true
	for t in ["Runs", "Dev"]:
		var b: Button = get_node("Window/Content/Tabs/" + t)
		b.pressed.connect(func():
			dev_tab = t == "Dev"
			_open = {}
			_build())
	_build()
	super()


func _build() -> void:
	var rows: VBoxContainer = $Window/Content/Scroll/Rows
	for c in rows.get_children():
		c.queue_free()
	var runs := _runs()
	for t in ["Runs", "Dev"]:
		var b: Button = get_node("Window/Content/Tabs/" + t)
		var on: bool = (t == "Dev") == _dev()
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, tab_on if on else tab_off)
		b.add_theme_color_override("font_color", Color("#241d10") if on else Color("#5e4026"))
	var empty: Label = $Window/Content/Empty
	empty.text = "No dev runs yet — runs you change with the Dev Panel land here when they end." if _dev() else _empty_text
	empty.visible = runs.is_empty()
	$Window/Content/Scroll.visible = not runs.is_empty()
	for i in runs.size():
		var e := HistEntry.make()
		e.fill(runs[i], _open.has(i))
		var at := i
		e.toggled.connect(func():
			if _open.has(at):
				_open.erase(at)
			else:
				_open[at] = true
			_build())
		e.copied.connect(func(json):
			DisplayServer.clipboard_set(json)
			e.show_copied())
		rows.add_child(e)


func _dev() -> bool:
	return dev_tab and Progress.prefs.get("devMode") == true


func _runs() -> Array:
	return Progress.dev_history if _dev() else Progress.history


## ⧉ Export: every run as JSON, then "✓ Copied!" for a moment.
func _export() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_runs(), "  "))
	var l: Label = $Window/Export/Row/Text
	l.text = "Copied!"
	get_tree().create_timer(1.8).timeout.connect(func(): if is_instance_valid(l): l.text = "Export")


func _layout() -> void:
	var scroll: ScrollContainer = $Window/Content/Scroll
	scroll.custom_minimum_size.y = minf($Window/Content/Scroll/Rows.get_combined_minimum_size().y, size.y * max_list)
	super()
	$Window/Banner.position.x = banner_x
	var ex: Control = $Window/Export
	ex.size = ex.get_combined_minimum_size()
	ex.position.x = $Window.size.x - 38 - ex.size.x
