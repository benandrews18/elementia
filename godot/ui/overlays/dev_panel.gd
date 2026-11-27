## The Dev Panel (dev.js renderDevPanel()), from the 🛠 button (Developer
## mode on): Jump (turn, station, checks and end screens), Inventory
## (elements, "?", items) and Snapshots (named saves of the run, to load,
## copy or paste, and ready-made scenarios). Built from Godot's own
## controls in one dark theme (a developer tool: no parity with the HTML's
## look). The actions are in game/dev.gd. The frame is
## ui/overlays/dev_panel.tscn; the tabs' rows are made here.
class_name DevPanel
extends PanelContainer

const SCENE := "res://ui/overlays/dev_panel.tscn"
const TABS := [["jump", "Jump"], ["inv", "Inventory"], ["snaps", "Snapshots"]]

@export var tab_on: StyleBox  # the open tab (gold)
@export var mute := Color("#7d8899")
@export var ok := Color("#3fb46c")
@export var bad := Color("#f0674c")

var tab := "jump"
var _cap := 0  # the scenarios' capstone


static func make() -> DevPanel:
	return Tok.make(SCENE)


var _base_bottom: Variant = null  # offset_bottom before the phone keyboard lifted the panel


func _ready() -> void:
	$V/Head/X.pressed.connect(hide)
	get_viewport().gui_focus_changed.connect(_on_focus)
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(func():
			tab = t[0]
			render())
		$V/Tabs.add_child(b)
	visibility_changed.connect(func(): if visible: render())
	render()


## Above the hub, at most 62% of the screen's height (.dev-panel).
func place(screen: Vector2) -> void:
	size = Vector2(minf(screen.x - 16, 520), screen.y * 0.62)
	position = Vector2((screen.x - size.x) / 2, screen.y - HubBar.H - 8 - size.y)


func render() -> void:
	if not visible:
		return
	var dev: bool = Game.state.get("dev") == true
	var flag: Label = $V/Head/Flag
	flag.text = "dev run" if dev else "real run"
	flag.add_theme_color_override("font_color", bad if dev else ok)
	for i in TABS.size():
		var b: Button = $V/Tabs.get_child(i)
		var on: bool = TABS[i][0] == tab
		b.add_theme_color_override("font_color", Color("#241d10") if on else Color("#b3becd"))
		if on:
			b.add_theme_stylebox_override("normal", tab_on)
		else:
			b.remove_theme_stylebox_override("normal")
	var body: VBoxContainer = $V/Scroll/Body
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	match tab:
		"jump": _jump(body)
		"inv": _inv(body)
		_: _snaps(body)


# ---- pieces

func _row(body: Control, kids: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	for k in kids:
		r.add_child(k)
	body.add_child(r)
	return r


func _grid(body: Control, kids: Array, cols := 2) -> void:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for k in kids:
		k.size_flags_horizontal = SIZE_EXPAND_FILL
		g.add_child(k)
	body.add_child(g)


func _btn(text: String, then_do: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		then_do.call()
		render())
	return b


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", mute)
	l.add_theme_font_size_override("font_size", 12)
	return l


func _field(hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.size_flags_horizontal = SIZE_EXPAND_FILL
	return e


func _pick(options: Array, selected: String) -> OptionButton:
	var o := OptionButton.new()
	o.size_flags_horizontal = SIZE_EXPAND_FILL
	o.clip_text = true
	for i in options.size():
		o.add_item(options[i])
		if options[i] == selected:
			o.select(i)
	return o


# ---- Jump

func _jump(body: Control) -> void:
	var s := Game.state
	var turn := SpinBox.new()
	turn.min_value = 1
	turn.max_value = int(Data.t("MAX_VISITS"))
	turn.value = int(s.visits)
	var at = Game.ctx.get("current")
	_row(body, [_note("Turn"), turn, _btn("Set", func(): Dev.set_turn(int(turn.value))),
		_note("now %d / %d%s" % [int(s.visits), int(Data.t("RUN_COMPLETE_VISIT")), " · at " + at if at else ""])])
	var names: Array = Data.t("DATA").stations.map(func(st): return st.name)
	var st := _pick(names, at if at else str(s.get("lastStation", "")))
	_row(body, [st, _btn("Go there (no turn)", func(): Dev.teleport(names[st.selected]))])
	_grid(body, [_btn("Next board check", Dev.next_check),
		_btn("Final check (%d)" % int(Data.t("RUN_COMPLETE_VISIT")), func():
			Dev.set_turn(int(Data.t("RUN_COMPLETE_VISIT")))
			hide()
			App.current.go_map()),  # the "Final Score!" shutter and the mat
		_btn("Run Complete screen", func():
			hide()
			Dev.end_screen(true)),
		_btn("Game Over screen", func():
			hide()
			Dev.end_screen(false))])
	# Testing options (prefs: they last across runs; a run they change becomes a dev run).
	var keep := CheckBox.new()
	keep.text = "No game over at breakpoints"
	keep.button_pressed = Progress.prefs.get("devNoGameOver") == true
	keep.toggled.connect(func(on):
		Progress.prefs.devNoGameOver = on
		Progress.save_all())
	body.add_child(keep)
	var now := 0
	if Progress.prefs.get("devDiceUnknown") == true:
		now = DICE.size() - 1
	elif int(Progress.prefs.get("devDice", 0)) > 0:
		now = DICE.find(int(Progress.prefs.devDice))
	var dice := _pick(DICE_LABELS, DICE_LABELS[maxi(0, now)])
	dice.item_selected.connect(func(i):
		Progress.prefs.devDice = DICE[i]
		Progress.prefs.devDiceUnknown = i == DICE.size() - 1
		Progress.save_all())
	_row(body, [_note("Dice per roll"), dice])


const DICE := [0, 3, 4, 5, 6, 6]  # the last: 6 and an Unknown Element
const DICE_LABELS := ["Normal", "At least 3", "At least 4", "At least 5", "At least 6", "6 + Unknown Element"]


# ---- Inventory

func _inv(body: Control) -> void:
	var s := Game.state
	var cells := []
	var colors: Dictionary = Data.t("ELEMENT_COLOR")
	for sym in Data.t("CORE_ELEMENT_SYMS"):
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var edge := ColorRect.new()  # the suit's colour (.dev-el's left border)
		edge.color = Color(colors.get(sym, "#888888"))
		edge.custom_minimum_size = Vector2(4, 0)
		var sy := Label.new()
		sy.text = sym
		sy.custom_minimum_size.x = 22
		sy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var n := Label.new()
		n.text = str(int(Catalog.count(s, sym)))
		n.size_flags_horizontal = SIZE_EXPAND_FILL
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for k in [edge, _btn("−", Dev.element.bind(sym, -1)), sy, n, _btn("+", Dev.element.bind(sym, 1))]:
			cell.add_child(k)
		cells.append(cell)
	_grid(body, cells, 2)
	_row(body, [_btn("All to 5", Dev.all_elements.bind(5)), _btn("Clear", Dev.all_elements.bind(0)),
		_note("\"?\" %d" % int(Util.get_or(s, "emptyElements", 0))), _btn("−", Dev.unknown.bind(-1)), _btn("+", Dev.unknown.bind(1))])
	var item := _field("Item name…")
	_row(body, [item])
	var name_of := func() -> String: return _item_named(item.text)
	_row(body, [_btn("Grant", func(): Dev.grant([name_of.call()])), _btn("With its tree", func(): Dev.grant_tree(name_of.call())),
		_btn("Remove", func(): Dev.remove(name_of.call()))])
	_row(body, [_btn("Grant every item", func(): Dev.grant(Data.t("CORE_ITEM_NAMES"))), _note("%d owned" % s.items.size())])


## The item a typed name means: exact (any case), else the first that starts
## with it (the HTML's datalist suggests names; here a prefix is enough).
static func _item_named(text: String) -> String:
	var t := text.strip_edges().to_lower()
	if t == "":
		return ""
	var core: Array = Data.t("CORE_ITEM_NAMES")
	for n in core:
		if n.to_lower() == t:
			return n
	for n in core:
		if n.to_lower().begins_with(t):
			return n
	return ""


# ---- Snapshots

func _snaps(body: Control) -> void:
	var nm := _field("Name this snapshot…")
	nm.max_length = 50
	_row(body, [nm, _btn("Save", func(): Dev.snap_save(nm.text.strip_edges()))])
	var list := Dev.snaps()
	if list.is_empty():
		body.add_child(_note("No snapshots yet."))
	for i in list.size():
		var sn: Dictionary = list[i]
		var info := VBoxContainer.new()
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var title := Label.new()
		title.text = str(sn.get("name", ""))
		title.clip_text = true
		info.add_child(title)
		info.add_child(_note("turn %d · %s" % [int(sn.state.get("visits", 0)), sn.get("at", "")]))
		var copy := Button.new()
		copy.text = "Copy"
		copy.pressed.connect(func():
			DisplayServer.clipboard_set(JSON.stringify(sn))
			copy.text = "Copied")
		_row(body, [info, _btn("Load", Dev.snap_load.bind(i)), copy, _btn("Delete", Dev.snap_delete.bind(i))])
	var paste := TextEdit.new()
	paste.placeholder_text = "Paste a snapshot here…"
	paste.custom_minimum_size.y = 44
	paste.size_flags_horizontal = SIZE_EXPAND_FILL
	var imp := Button.new()
	imp.text = "Import"
	imp.pressed.connect(func():
		if Dev.snap_import(paste.text):
			render()
		else:
			imp.text = "Not a snapshot")
	_row(body, [paste, imp])
	var sub := Label.new()
	sub.text = "Ready-made scenarios"
	sub.add_theme_font_override("font", Tok.font(800))
	body.add_child(sub)
	body.add_child(_note("Each starts a new dev run."))
	var caps: Array = Data.t("CAPSTONES")
	var cap := _pick(caps, caps[_cap])
	cap.item_selected.connect(func(i): _cap = i)
	_row(body, [_note("Capstone"), cap])
	var buttons := []
	for sc in Dev.SCENARIOS:
		buttons.append(_btn(sc[1], func(): Dev.scenario(sc[0], caps[_cap])))
	_grid(body, buttons)


## A text field focused on a phone (review M6-9): the panel's foot rises
## above the on-screen keyboard and the field scrolls into view; back down
## when focus leaves the fields.
func _on_focus(c: Control) -> void:
	if visible and (c is LineEdit or c is TextEdit) and is_ancestor_of(c):
		await get_tree().create_timer(0.35).timeout  # the keyboard is up by then
		var kb := DisplayServer.virtual_keyboard_get_height() / get_viewport().get_final_transform().get_scale().y
		if kb <= 0 or not is_instance_valid(c):
			return
		if _base_bottom == null:
			_base_bottom = offset_bottom
		offset_bottom = _base_bottom - kb
		await get_tree().process_frame
		if is_instance_valid(c):
			$V/Scroll.ensure_control_visible(c)
	elif _base_bottom != null:
		offset_bottom = _base_bottom
		_base_bottom = null
