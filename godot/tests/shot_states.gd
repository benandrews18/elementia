## Every screen and window in a fixed state, by name, for the before/after
## check of M5.5 (tools/shot_diff.py shoots the whole list in one Godot run,
## tests/shot_batch.gd). One state alone:
##   G --path godot res://tests/shot.tscn -- --screen res://tests/shot_states.gd --state market --save tests/fixtures/station_visit7.json --out x.png --wait 0.8
## Animations are left to settle (--wait); nothing random is shown.
extends Control

const STATES := ["map", "map_card", "station", "bench", "drawer", "drawer_elements", "drawer_selected", "drawer_list", "drawer_mini", "station_list",
	"convert", "picker", "unknown", "market", "market_craft", "row_reward", "todo", "confirm", "reward",
	"order", "end_over", "end_done", "howto0", "howto1", "howto2", "capstone", "capstone_confirm", "celebrate", "unlock", "pin_tip",
	"suit_spend", "expand", "reward_open", "roll",
	"order_restrict", "order_grand", "station_fold",
	"card_pop", "card_pop_cap", "card_pop_back", "element_card", "items", "items_open", "items_search",
	"settings", "game_rules", "tutorial_messages", "mat_rules", "mat_rules2", "order_tip", "unknown_tip",
	"welcome", "classic_mode", "trophies", "trophy_detail", "history", "history_open",
	"pins", "tracked_card", "tracked_map", "tracked_say", "tracked_station", "map_ocean", "station_early", "station_mine", "clock_info",
	"mouse_bl", "mouse_tl", "mouse_c", "mouse_br", "hint_badge", "hint_open", "tut_intro", "tut_elements", "tut_coach",
	"layouts", "coll_run", "coll_menu", "coll_found", "clue_box", "clue_card", "combo_lab", "challenge_pick", "challenge_hand", "hand_picks", "challenge_elements", "combo_info", "play_together", "hand_preview", "hand_inventory", "convert_bench", "keep_fan",
	"dev_tools", "dev_jump", "dev_inv", "dev_snaps", "history_dev"]


var state := ""  # set by tests/shot_batch.gd; else from --state


func _ready() -> void:
	if state == "":
		state = load("res://tests/shot.gd")._args().get("state", "map")
	Progress.prefs.pinnedItems = ["Metropolis", "Plastic"]
	Progress.prefs.hiddenTips = []
	Progress.prefs.hints = false  # no 💡 hints (the hint_* states show one)
	var app := App.new()
	add_child(app)
	app.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	await get_tree().process_frame
	if Game.ctx.get("travelPromptFor") != null:  # a fixture saved mid-check: its hand dealt the same every time
		Rng.feed(range(60).map(func(i): return fmod(i * 0.37, 1.0)))
		Game.deal_hand()
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
		"station_list":  # the station shop's 📋 view: the list, Glass on the side card with Pin / Craft
			StationScreen.list_mode = true
			app._screen.open_card = "Glass"
			app._screen._redraw()
		"drawer_mini":  # the mat minimised (the fold button): its icons in a row, how full it is
			DisplayMatScreen.collapsed = true
			app.open_panel("drawer")
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
		"celebrate":  # a capstone just crafted (no confetti: nothing random)
			Game.state.items.append("Metropolis")
			CardPop.open(app, "Metropolis").show_celebration(1, 8)
		"unlock":  # the items a capstone opened up, all popped in
			var by: Dictionary = Data.t("UNLOCKED_BY")
			UnlockReveal.show_on(app, "Metropolis", by.keys().filter(func(n): return by[n] == "Metropolis"))
		"craft_peek":  # the small card after a craft, before it flies (--wait under 0.7)
			app._craft_peek("Glass")
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
		"suit_spend":  # Craft on the bench: the picker points at the row's suit badges
			app.open_card("Skyscraper")
			await get_tree().process_frame
			var row := (app._screen as StationScreen).find_tagged("row:Skyscraper") as ShopRow
			app.craft_tap("Skyscraper", row._tax_anchor(row.get_node("Craft")) if row else Rect2(240, 600, 60, 35))
		"expand":  # the mat grown from 1.5 rows to 2 (the reveal as played)
			app.open_panel("drawer")
			await get_tree().process_frame
			var mat: DisplayMatScreen = app._panel_node
			mat.show_stage(2)
			var mx := MatExpand.new()
			mx.pages = mat.grow(MatExpand.GROW)
			var cols: int = Mat.layout(Mat.on_mat(Game.state), 3).cols
			for i in mat.slot_rects:
				if i >= cols:
					mx.hole = mat.slot_rects[i] if mx.hole.size == Vector2.ZERO else mx.hole.merge(mat.slot_rects[i])
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
			Progress.prefs.hints = true  # Game Rules' Tutorial tips switch shows on
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
		"tracked_say":  # Metropolis tracked: a tapped 🔍 on the map says what it means
			Game.ctx.tracked = "Metropolis"
			Game.ctx.screen = "map"
			Game.ctx.selectedMapStation = null
			Game.state_changed.emit()
			await get_tree().process_frame
			var gs: Array = app._screen.get_node("Area/Badges").get_children().filter(func(c): return c is TextureRect)
			if not gs.is_empty():
				app._screen._say(gs[-1], "Components for {%s} are here!" % Catalog.entry("Metropolis").emoji)
			await get_tree().create_timer(0.4).timeout
		"clock_info":  # the turn clock's window
			ClockInfo.show_on(app)
		"station_mine":  # Deep Mine's shop: Aluminum Alloy and Stainless Steel's names on two lines
			Game.ctx.current = "Deep Mine"
			Game.ctx.screen = "station"
			Game.state_changed.emit()
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
				"mouse_tl": app.mouse.show_tip(7, "Tap a green card, then [b]Craft[/b]!", "top-left", app._screen.find_tagged("st:craft:"))
				"mouse_c": app.mouse.show_tip(5, "Convert Elements! [b]3:1[/b]", "center", app._hub.button("home"))
				"mouse_br": app.mouse.show_tip(7, "Your tracked item needs this one!", "bottom-right")
		"hint_badge", "hint_open":  # a 💡 hint (Hints) out; tapped: Mouse says it, Don't show again
			Progress.prefs.hints = true
			for i in 60:
				if app.hints._badge != null:
					break
				await get_tree().process_frame
			await get_tree().create_timer(0.6).timeout  # its fade-in
			if state == "hint_open" and app.hints._badge != null:
				app.hints._open()
		"tut_intro", "tut_elements":  # Tutorial Messages' The 16 Elements: its two windows
			app.show_elements()
			if state != "tut_intro":
				app.get_children().filter(func(c): return c is ParchDialog)[0].pressed.emit("Next")
		"tut_coach":  # the first-play tutorial's Roll step: Mouse docked away from it, Skip under him
			await get_tree().process_frame
			app.mouse.coach(3, "Every visit you roll the station's dice. Tap [b]Roll[/b]!", app._hub.button("home"), false, false)
		"layouts", "coll_run", "coll_menu", "coll_found", "clue_box", "clue_card":  # from tests/fixtures/collections_prefs.json
			Progress.prefs.merge(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/collections_prefs.json")), true)
			match state:
				"layouts":  # the Combo Lab's (the run's mat is locked in)
					Game.ctx.travelPromptFor = null
					app.open_combo_lab(true)
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
		"challenge_pick":  # the lab's Challenge Test: pick a check round
			app.open_combo_lab()
			app._challenge_pick()
		"challenge_hand":  # the test at round 12: the hand fanned, a card lifted (Rng fed: the same every time)
			app.open_combo_lab()
			Rng.feed(range(60).map(func(i): return fmod(i * 0.37, 1.0)))
			app.start_challenge_test(12)
			for c in app.get_children():
				if c is OrderInfo:
					c.queue_free()
			Hand.play(Game.state.hand, Game.state, Game.state.hand.hand.slice(0, 2))  # something on the cleared mat
			var mat := app._panel_node as DisplayMatScreen
			mat.picks = [Game.state.hand.hand[2]]
			mat._redraw()
		"combo_info":  # the test's mat: a combo chip tapped lists the cards making it
			app.open_combo_lab()
			Rng.feed(range(60).map(func(i): return fmod(i * 0.37, 1.0)))
			app.start_challenge_test(12)
			for c in app.get_children():
				if c is OrderInfo:
					c.queue_free()
			var by := {}  # the mat clears at a check: a station's three cards, laid in one play
			for n in Game.state.items:
				var mc = Catalog.mat_card(n)
				if mc != null and not Mat.is_capstone(mc):
					for st in mc.stations:
						by[st] = by.get(st, []) + [n]
			for st in by:
				if by[st].size() >= 3:
					Game.state.mat = by[st].slice(0, 3)
					Game.state.matPlays = [by[st].slice(0, 3)]
					for k in ["hand", "deck"]:
						Game.state.hand[k] = Game.state.hand[k].filter(func(n): return not Game.state.mat.has(n))
					break
			Game._changed()
			var mat2 := app._panel_node as DisplayMatScreen
			var combos: Array = mat2._chip_nodes.keys().filter(func(k): return k != "order")
			if not combos.is_empty():
				ComboInfo.open_for(app, combos[0])
		"play_together", "hand_preview":  # a station's three cards picked: the preview's combo and score (hand_preview); Play: their own combo shows before they fly
			app.open_combo_lab()
			Rng.feed(range(60).map(func(i): return fmod(i * 0.37, 1.0)))
			app.start_challenge_test(12)
			for c in app.get_children():
				if c is OrderInfo:
					c.queue_free()
			var by2 := {}
			for n in Game.state.items:
				var mc = Catalog.mat_card(n)
				if mc != null and not Mat.is_capstone(mc):
					for st in mc.stations:
						by2[st] = by2.get(st, []) + [n]
			for st in by2:
				if by2[st].size() >= 3:
					Game.state.hand.hand = by2[st].slice(0, 3) + Game.state.hand.hand.filter(func(n): return not by2[st].slice(0, 3).has(n)).slice(0, 4)
					break
			var mat4 := app._panel_node as DisplayMatScreen
			mat4.picks = Game.state.hand.hand.slice(0, 3)
			mat4._redraw()
			if state == "play_together":
				mat4.hand_play()
				await get_tree().create_timer(0.5).timeout
		"hand_inventory":  # a check: the deck's count tapped, the whole Inventory to plan with
			app.open_combo_lab()
			Rng.feed(range(60).map(func(i): return fmod(i * 0.37, 1.0)))
			app.start_challenge_test(12)
			for c in app.get_children():
				if c is OrderInfo:
					c.queue_free()
			var mat5 := app._panel_node as DisplayMatScreen
			mat5.browsing = true
			mat5._redraw()
		"convert_bench":  # a card's missing element tapped: Convert, the card's Crafting Bench on top
			var withel = StationScreen.shop_entries(Game.ctx.current).filter(func(e): return not Catalog.owns(Game.state, e.name) and e.reqs.any(func(r): return r.kind == "element"))
			if not withel.is_empty():
				var sym: String = withel[0].reqs.filter(func(r): return r.kind == "element")[0].name
				Game.state.elements.erase(sym)  # short of one element
				Game.state.elements["C" if sym != "C" else "O"] = 4  # something to convert from
				Game.state_changed.emit()
				app.open_convert(sym, withel[0].name)
			await get_tree().create_timer(0.5).timeout
		"keep_fan":  # a craft's kept component cards peeking up from behind the hub, fanned
			Juice.craft_keep(app, ["Water", "Steel", "Glass", "Clay"], app._hub, 2.0)
			await get_tree().create_timer(0.75).timeout
		"hand_picks":  # two hand cards picked: raised and ticked, Play in full colour
			app.open_combo_lab()
			Rng.feed(range(60).map(func(i): return fmod(i * 0.37, 1.0)))
			app.start_challenge_test(12)
			for c in app.get_children():
				if c is OrderInfo:
					c.queue_free()
			var mat3 := app._panel_node as DisplayMatScreen
			Game.state.hand.hand = ["Soil", "Rubber", "Tree", "Cloud", "Plastic"]  # a fixed hand (the lab's run here can be thin)
			mat3.picks = ["Rubber", "Cloud"]
			mat3._redraw()
		"challenge_elements":  # the test's Elements tab: a tap spends one on a card of its suit
			app.open_combo_lab()
			Rng.feed(range(60).map(func(i): return fmod(i * 0.37, 1.0)))
			app.start_challenge_test(12)
			for c in app.get_children():
				if c is OrderInfo:
					c.queue_free()
			Game.state.elements = {"H": 2, "O": 4, "Fe": 1}
			Game.state.emptyElements = 1
			var mat := app._panel_node as DisplayMatScreen
			mat.view = "elements"
			Game._changed()
		"welcome", "classic_mode":  # the title screen; Play's Classic window over it
			app.show_welcome()
			if state == "classic_mode":
				ClassicMode.show_on(app)
		"mat_rules", "mat_rules2", "order_tip", "unknown_tip":
			app.show_tip({"mat_rules": "mat_rules", "mat_rules2": "mat_rules2", "order_tip": "order", "unknown_tip": "unknown"}[state])
