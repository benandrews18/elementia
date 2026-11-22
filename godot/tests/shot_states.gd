## Every screen and window in a fixed state, by name, for the before/after
## check of M5.5 (tools/shot_diff.py shoots the whole list in one Godot run,
## tests/shot_batch.gd). One state alone:
##   G --path godot res://tests/shot.tscn -- --screen res://tests/shot_states.gd --state market --save tests/fixtures/station_visit7.json --out x.png --wait 0.8
## Animations are left to settle (--wait); nothing random is shown.
extends Control

const STATES := ["map", "map_card", "station", "bench", "drawer", "drawer_elements", "drawer_selected", "drawer_list",
	"convert", "picker", "unknown", "market", "market_craft", "row_reward", "todo", "confirm", "reward",
	"order", "end_over", "end_done", "howto0", "howto1", "howto2", "capstone", "capstone_confirm", "pin_tip",
	"suit_spend", "expand", "reward_open", "roll",
	"order_restrict", "order_grand", "station_fold",
	"card_pop", "card_pop_cap", "card_pop_back", "element_card", "items", "items_open", "items_search",
	"settings", "game_rules", "tutorial_messages", "mat_rules", "mat_rules2", "order_tip", "unknown_tip",
	"welcome", "classic_mode", "trophies", "trophy_detail", "history", "history_open",
	"pins", "tracked_card", "tracked_map", "tracked_station", "map_ocean", "station_early", "clock_info",
	"mouse_bl", "mouse_tl", "mouse_c", "mouse_br", "tut_intro", "tut_elements", "coach1",
	"layouts", "coll_run", "coll_menu", "coll_found", "clue_box", "clue_card", "combo_lab",
	"dev_tools", "dev_jump", "dev_inv", "dev_snaps", "history_dev"]


var state := ""  # set by tests/shot_batch.gd; else from --state


func _ready() -> void:
	if state == "":
		state = load("res://tests/shot.gd")._args().get("state", "map")
	Progress.prefs.pinnedItems = ["Metropolis", "Plastic"]
	Progress.prefs.hiddenTips = []
	Progress.prefs.guidedTutorialEnabled = false  # no Professor Mouse popping up on his own (the mouse_* states show him)
	Progress.prefs.sawEmptyElTip = true
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
		"drawer_list":  # the 📋 view: the compact list, the selected card on the right
			DisplayMatScreen.list_mode = true
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
		"roll":  # 5 dice, already revealed (the tweens run to their end); the last 2 the check's bonus
			var pop := RollPopup.make()
			pop.roll = [{"face": 3, "sym": "C"}, {"face": 5, "sym": "O"}, {"face": 1, "sym": "Fe"}, {"face": 6, "sym": "Si"}, {"face": 2, "sym": "Mg"}]
			pop.bonus = 2
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
		"items", "items_open", "items_search":  # the Items screen; Bridge's breakdown open; searching "steel"
			ItemsScreen.query = "steel" if state == "items_search" else ""
			app.open_items("Bridge" if state == "items_open" else "")
		"settings", "game_rules", "tutorial_messages":
			Progress.prefs.guidedTutorialEnabled = true  # Game Rules' Tutorial tips switch shows on (a window is open: no tip pops up)
			app.open_settings({"settings": "", "game_rules": "rules", "tutorial_messages": "tuts"}[state])
		"trophies", "trophy_detail", "history", "history_open":  # with tests/fixtures/trophies_history.json
			var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/trophies_history.json"))
			Progress.trophies = fx.trophies
			Progress.history = fx.history
			if state.begins_with("trophies") or state == "trophy_detail":
				TrophiesWindow.show_on(app)
				if state == "trophy_detail":
					TrophyDetail.show_on(app, "first-run")
			else:
				var hw := HistoryWindow.show_on(app)
				if state == "history_open":
					hw._open[0] = true
					hw._build()
		"dev_tools":  # Settings' Dev Tools, Developer mode on
			Progress.prefs.devMode = true
			app.sync_dev()
			ParchDialog.open(app, DevTools.SCENE)
		"dev_jump", "dev_inv", "dev_snaps":  # the Dev Panel's tabs (no snapshots kept)
			Dev.snap_path = "user://_shot_no_snaps.json"
			Progress.prefs.devMode = true
			app.sync_dev()
			var dp: DevPanel = app.get_node("Dev").get_child(1)
			dp.tab = {"dev_jump": "jump", "dev_inv": "inv", "dev_snaps": "snaps"}[state]
			dp.visible = true
			dp.place(app.size)
		"history_dev":  # Developer mode: History's Runs / Dev runs tabs, Dev runs open (none yet)
			Progress.prefs.devMode = true
			HistoryWindow.dev_tab = true
			HistoryWindow.show_on(app)
			HistoryWindow.dev_tab = false
		"tracked_map", "tracked_station":  # Metropolis tracked: the map's badges and card (The City), the shop's badges
			Game.ctx.tracked = "Metropolis"
			if state == "tracked_map":
				Game.ctx.selectedMapStation = "The City"
			Game.state_changed.emit()
		"clock_info":  # the turn clock's window
			ClockInfo.show_on(app)
		"station_early":  # before the first mat check: no Quark bar, the header from the very top
			Game.state.matChecked = false
			Game.state_changed.emit()
		"map_ocean":  # at the Ocean (YOU ARE HERE off to its right, clear of the hub), Metropolis tracked (its badges over the stations)
			Game.state.lastStation = "The Ocean"
			Game.ctx.tracked = "Metropolis"
			Game.ctx.selectedMapStation = null
			Game.state_changed.emit()
		"mouse_bl", "mouse_tl", "mouse_c", "mouse_br":  # Professor Mouse in each corner (the HTML's tips)
			await get_tree().process_frame
			match state:
				"mouse_bl": app.mouse.show_tip(3, "Tap [b]Roll[/b] to get elements!", "bottom-left", app._hub.button("home"), 14)
				"mouse_tl": app.mouse.show_tip(7, "Tap [b]Craft[/b]!", "top-left", app._screen.find_tagged("st:craft:"))
				"mouse_c": app.mouse.show_tip(5, "Convert Elements! [b]3:1[/b]", "center", app._hub.button("home"))
				"mouse_br": app.mouse.show_tip(7, "Your tracked item needs this one!", "bottom-right")
		"tut_intro", "tut_elements", "coach1":  # How to Play: its two windows; the walkthrough's first step
			app.start_coach()
			if state != "tut_intro":
				app.get_children().filter(func(c): return c is ParchDialog)[0].pressed.emit("Next")
				await get_tree().process_frame
			if state == "coach1":
				app.get_children().filter(func(c): return c is TutElements)[0].pressed.emit("Next")
		"layouts", "coll_run", "coll_menu", "coll_found", "clue_box", "clue_card":  # from tests/fixtures/collections_prefs.json
			Progress.prefs.merge(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/collections_prefs.json")), true)
			match state:
				"layouts":
					app.open_panel("drawer")
					LayoutsWindow.show_on(app)
				"coll_run":
					app.open_panel("drawer")
					CollectionsWindow.show_on(app)
				"coll_menu":
					CollectionsWindow.show_on(app, true)
				"coll_found":  # Alloys complete on the mat, never found
					Progress.prefs.everUnlockedMatCollections = ["bedrock", "fruits"]
					Game.state_changed.emit()
				"clue_box", "clue_card":  # a gift (a clue to People Power: Canoe known, Bicycle new)
					var c: Dictionary = Mat.collections().filter(func(x): return x.id == "people-power")[0]
					var co := ClueOpen.show_on(app, [{"c": c, "item": "Bicycle", "known": ["Canoe", "Bicycle"], "discovered": true}])
					if state == "clue_card":
						co._card()
		"pins", "tracked_card":  # Metropolis tracked: the pins tray open; its card from the pill
			Game.ctx.tracked = "Metropolis"
			if state == "pins":
				app.open_panel("pins")
			else:
				app.show_card("Metropolis")
				(app.get_children().filter(func(c): return c is CardPop)[0] as CardPop).show_tracking()
		"combo_lab":  # the sandbox mat over the real run
			app.open_combo_lab()
		"welcome", "classic_mode":  # the title screen; Play's Classic window over it
			app.show_welcome()
			if state == "classic_mode":
				ClassicMode.show_on(app)
		"mat_rules", "mat_rules2", "order_tip", "unknown_tip":
			app.show_tip({"mat_rules": "mat_rules", "mat_rules2": "mat_rules2", "order_tip": "order", "unknown_tip": "unknown"}[state])
