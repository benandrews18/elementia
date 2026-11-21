## Every screen and window in a fixed state, by name, for the before/after
## check of M5.5 (tools/shot_diff.py shoots the whole list in one Godot run,
## tests/shot_batch.gd). One state alone:
##   G --path godot res://tests/shot.tscn -- --screen res://tests/shot_states.gd --state market --save tests/fixtures/station_visit7.json --out x.png --wait 0.8
## Animations are left to settle (--wait); nothing random is shown.
extends Control

const STATES := ["map", "map_card", "station", "bench", "drawer", "drawer_elements", "drawer_selected",
	"convert", "picker", "unknown", "market", "market_craft", "row_reward", "todo", "confirm", "reward",
	"order", "end_over", "end_done", "howto0", "howto1", "howto2", "capstone", "capstone_confirm", "pin_tip",
	"suit_spend", "expand", "reward_open", "roll",
	"order_restrict", "order_grand", "station_fold",
	"card_pop", "card_pop_cap", "card_pop_back", "element_card"]


var state := ""  # set by tests/shot_batch.gd; else from --state


func _ready() -> void:
	if state == "":
		state = load("res://tests/shot.gd")._args().get("state", "map")
	Progress.prefs.pinnedItems = ["Metropolis", "Plastic"]
	Progress.prefs.hiddenTips = []
	var app := App.new()
	add_child(app)
	app.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	await get_tree().process_frame
	match state:
		"map", "station":
			pass
		"station_fold":  # crafted items folded into the header's bar
			Game.state.collapseCraftedItems = true
			Game.state_changed.emit()
		"map_card":
			Game.ctx.selectedMapStation = "The Ocean"
			Game.state_changed.emit()
		"bench":
			app.open_card("Glass")
		"drawer":
			app.open_panel("drawer")
		"drawer_elements":
			app.open_panel("drawer")
			app._panel_node.view = "elements"
			app._panel_node._redraw()
		"drawer_selected":
			app.open_panel("drawer")
			app._panel_node.selected = Game.state.items[0]
			app._panel_node._redraw()
		"convert":
			Game.state.emptyElements = 1
			app.open_panel("convert")
			app._panel_node.from = "S"
			app._panel_node.to = "Fe"
			app._panel_node._redraw()
		"picker":
			app.open_panel("convert")
			app._panel_node._pick("to")
		"unknown":
			Game.state.emptyElements = 1
			UnknownPick.open(app)
		"market":
			app._on_hub("market")
		"market_craft":
			app._on_hub("market")
			MarketCraft.open(app, "Plastic")
		"row_reward":
			app._on_hub("market")
			var r := RowReward.make(1, func(): pass)
			r.size = app.size
			app.add_child(r)
		"todo":
			TodoTray.hint_open = true
			TodoTray.expanded = {"refroot/Plastic": true}
			app._on_hub("jobs")
			app._panel_node._open_hint_paths()
			app._panel_node._redraw()
		"confirm":
			ConfirmDialog.ask(app, "Reset the Display Mat to your last locked-in layout?", func(): pass)
		"reward":
			app.open_panel("drawer")
			var d := LockInReward.make()
			d.dice = 3
			d.unknown = true
			d.quarks = 1234
			d.size = app.size
			d.on_done = func(): pass
			app.add_child(d)
		"order":
			OrderInfo.open(app)
		"order_restrict", "order_grand":  # a restriction that wraps (two suits), and the last round's
			var su: Array = Data.t("ELEMENT_SUIT_LABEL").keys()
			Game.state.order = {"id": "doubleDrought", "p": su[0] + "|" + su[1], "round": Game.state.visits} if state == "order_restrict" 				else {"id": "grand", "p": null, "round": Game.state.visits}
			OrderInfo.open(app)
		"end_over", "end_done":
			if state == "end_over":
				Game.state.ended = true
			else:
				Game.state.runComplete = true
				Game.state.starsEarned = 7
			Game.ctx.endShown = "ended" if state == "end_over" else "complete"  # no confetti
			var e := EndGame.make()
			e.size = app.size
			app.add_child(e)
		"howto0", "howto1", "howto2":
			var h := HowToPlay.make()
			h.on_done = func(): pass
			h.size = app.size
			app.add_child(h)
			for i in int(state.right(1)):
				h._next()
		"capstone", "capstone_confirm":
			var c := CapstoneChoice.make()
			c.size = app.size
			app.add_child(c)
			if state == "capstone_confirm":
				c._confirm("Robot")
		"pin_tip":
			TodoTray.expanded = {"refroot/Robot": true}
			Progress.prefs.pinnedItems = ["Robot"]
			app.open_panel("todo")
			PinTip.open(app, func(): pass)
		"suit_spend":
			app.craft_tap("Skyscraper", Rect2(240, 600, 60, 35))
		"expand":
			app.open_panel("drawer")
			var mx := MatExpand.new()
			mx.hole = Rect2(20, 200, 350, 120)
			mx.on_done = func(): pass
			mx.size = app.size
			app.add_child(mx)
		"reward_open":  # no dice, both "?" lines open
			var d := LockInReward.make()
			d.unknown = true
			d.quarks = 1234
			d.size = app.size
			d.on_done = func(): pass
			app.add_child(d)
			d.get_node("Window/Why").visible = true
			d.get_node("Window/Hint").visible = true
			d._layout()
		"roll":  # 4 dice, already revealed (the tweens run to their end)
			var pop := RollPopup.make()
			pop.roll = [{"face": 3, "sym": "C"}, {"face": 5, "sym": "O"}, {"face": 1, "sym": "Fe"}, {"face": 6, "sym": "Si"}]
			pop.size = app.size
			app.add_child(pop)
			for t in get_tree().get_processed_tweens():
				t.custom_step(10)
		"card_pop", "card_pop_cap":  # an item's card; a capstone's (landscape, with its rule)
			app.show_card("Bridge" if state == "card_pop" else "Robot")
		"card_pop_back":  # drilled into a component: Back shows where from
			app.show_card("Bridge")
			var pop: CardPop = app.get_children().back()
			pop._back.append(pop.entry)
			pop.show_item("Steel", true)
		"element_card":
			app.show_element_card("Fe")
