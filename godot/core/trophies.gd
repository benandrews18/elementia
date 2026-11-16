## Trophies (trophies.js): each {id, icon, name, hint, test(st, prefs)}.
## Tested against the HTML game's own verdicts at the end of every golden
## run (tests/parity.gd, the "__trophies" step).
class_name Trophies

static var _list: Array


static func _slug(s: String) -> String:
	var re := RegEx.create_from_string("[^a-z]+")
	return re.sub(s.to_lower(), "-", true)


static func run_caps(st: Dictionary) -> Array:
	return Data.t("CAPSTONES").filter(func(c): return st.items.has(c))


## The turn (1-based) an item was crafted, or 0.
static func craft_turn(st: Dictionary, name: String) -> int:
	var log: Array = Util.get_or(st, "visitLog", [])
	for i in log.size():
		if log[i].items.has(name):
			return i + 1
	return 0


static func board_checks(st: Dictionary) -> Array:
	return Util.get_or(st, "checkLog", []).filter(func(c): return not c.get("final") and c.get("q") != null)


static func check_tier(c: Dictionary) -> int:
	return Orders.reward_for(c.q, int(c.v))


static func order_kind(c: Dictionary) -> Variant:
	return Orders.KINDS[c.o][0] if c.get("o") and Orders.KINDS.has(c.o) else null


static func final_q(st: Dictionary) -> float:
	for c in Util.get_or(st, "checkLog", []):
		if c.get("final"):
			return Util.get_or(c, "q", 0)
	return 0


## Local date n days ago, YYYY-MM-DD.
static func local_day(days_ago: int) -> String:
	var bias: int = Time.get_time_zone_from_system().bias
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + bias * 60 - days_ago * 86400)


static func play_streak(prefs: Dictionary) -> int:
	var days: Array = Util.get_or(prefs, "playDays", [])
	var n := 0
	while days.has(local_day(n)):
		n += 1
	return n


## prefs.lifetime[key] (totals across completed runs), or default.
static func _life(prefs: Dictionary, key: String, default: Variant) -> Variant:
	var L = prefs.get("lifetime")
	return Util.get_or(L, key, default) if L is Dictionary else default


static func all() -> Array:
	if not _list.is_empty():
		return _list
	var L := []
	var add := func(id, icon, name, hint, test: Callable): L.append({"id": id, "icon": icon, "name": name, "hint": hint, "test": test})
	var caps: Array = Data.t("CAPSTONES")
	var emoji: Dictionary = Data.t("ITEM_EMOJI")
	add.call("first-run", "🏁", "First Run", "Complete a run (reach turn 24)", func(_st, _p): return true)
	for cap in caps:
		add.call("cap-" + _slug(cap), emoji[cap], cap + " Run", "Complete a run that crafts the " + cap,
			func(st, _p): return st.items.has(cap))
	add.call("caps-2", "🥈", "Double Feature", "Craft 2 capstones in one run", func(st, _p): return run_caps(st).size() >= 2)
	add.call("caps-3", "🥇", "Triple Crown", "Craft 3 capstones in one run", func(st, _p): return run_caps(st).size() >= 3)
	add.call("cap-early", "⚡", "Early Riser", "Craft a capstone by turn 15",
		func(st, _p): return run_caps(st).any(func(c): return craft_turn(st, c) <= 15))
	add.call("caps-all", "👑", "Grand Collection", "Craft all 8 capstones (across runs)",
		func(_st, p): return _life(p, "caps", []).size() >= caps.size())
	add.call("items-40", "🧰", "Busy Builder", "Craft 40 items in one run", func(st, _p): return st.items.size() >= 40)
	add.call("items-50", "🏗️", "Master Builder", "Craft 50 items in one run", func(st, _p): return st.items.size() >= 50)
	add.call("items-all", "🌍", "Every Item", "Craft every item in one run", func(st, _p): return st.get("craftedEverything") == true)
	var shop: Dictionary = Data.t("STATION_SHOP")
	for s in Data.t("DATA").stations:
		var short: String = s.name.trim_prefix("The ")
		add.call("station-" + _slug(s.name.to_lower().trim_prefix("the ")), s.emoji, short + " Complete",
			"Craft every item in the %s shop in one run" % s.name,
			func(st, _p): return shop[s.name].all(func(n): return st.items.has(n)))
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	add.call("unlocked", "🔓", "Unlocked!", "Craft an item a capstone unlocks", func(st, _p): return st.items.any(func(n): return unlocked.has(n)))
	add.call("way-out", "🪐", "Way Out There", "Craft Planet, Solar System, University, Library or Trumpet",
		func(st, _p): return Data.t("WAY_OUT_THERE").any(func(n): return st.items.has(n)))
	var q_icons := ["⚛️", "💫", "🌟"]
	var qs := [1000, 2500, 4000]
	for i in 3:
		var q: int = qs[i]
		add.call("quarks-%d" % q, q_icons[i], "%s Quarks" % Util.thousands(q), "Lock In a Display Mat worth %s Quarks" % Util.thousands(q),
			func(st, _p): return Util.get_or(st, "bestMatScore", 0) >= q)
	var grand: int = Data.t("GRAND_EXHIBITION_TARGET")
	add.call("grand", "🏛️", "Grand Exhibition", "Reach %s Quarks at the final check" % Util.thousands(grand), func(st, _p): return final_q(st) >= grand)
	add.call("grand-gala", "🎆", "Grand Gala", "Reach 6,000 Quarks at the final check", func(st, _p): return final_q(st) >= 6000)
	add.call("top-shelf", "❓", "Top Shelf", "Reach the top breakpoint at a board check (its \"?\")",
		func(st, _p): return board_checks(st).any(func(c): return check_tier(c) >= 4))
	add.call("never-zero", "🎲", "Never Zero", "Earn at least 1 bonus die at every board check",
		func(st, _p): return board_checks(st).size() >= 7 and board_checks(st).all(func(c): return check_tier(c) >= 1))
	add.call("steady", "🎯", "Steady Hand", "Earn 2+ bonus dice at every board check",
		func(st, _p): return board_checks(st).size() >= 7 and board_checks(st).all(func(c): return check_tier(c) >= 2))
	add.call("request", "📜", "By Request", "Meet a Display Mat request",
		func(st, _p): return board_checks(st).any(func(c): return order_kind(c) == "request" and c.get("ok")))
	add.call("requests-all", "🧾", "Every Request", "Meet the requests at turns 3, 6 and 9",
		func(st, _p): return [3, 6, 9].all(func(v): return board_checks(st).any(func(c): return int(c.v) == v and order_kind(c) == "request" and c.get("ok"))))
	add.call("rule-keeper", "⚖️", "Rule Keeper", "Keep every restriction in a run (turns 12-21)",
		func(st, _p):
			var r := board_checks(st).filter(func(c): return order_kind(c) == "restriction")
			return r.size() >= 4 and r.all(func(c): return c.get("ok")))
	add.call("short-table", "🪑", "Short Table", "Keep the Short Table restriction",
		func(st, _p): return board_checks(st).any(func(c): return c.get("o") == "shortTable" and c.get("ok")))
	for f in [["full", "🖼️", "Full House", "Fill the whole 4×2 Display Mat"], ["combo5", "✖️", "Big Combo", "Reach a ×5 combo multiplier"],
			["recipe", "🧩", "Full Recipe", "Lock In a card with its whole recipe on the mat"], ["suits4", "🌈", "Four Suits", "Lock In all four suits on the mat"],
			["metro10", "🌆", "Metropolis Mat", "Fill all 10 slots of a Metropolis mat"], ["freight9", "🚄", "Freight Line", "Lock In Maglev Train with 9+ tier 1 cards"],
			["layered", "🎂", "Layered", "Lock In Fruit Cake with its ×2 active"]]:
		var feat: String = f[0]
		add.call("mat-" + feat, f[1], f[2], f[3], func(st, _p): return Util.get_or(st, "matFeats", []).has(feat))
	for c in [[5, "🔍", "Collector"], [20, "🗂️", "Curator"], [0, "🏛️", "Every Collection"]]:
		var n: int = c[0]
		add.call("collections-%d" % n if n else "collections-all", c[1], c[2],
			"Discover %d collections on your Display Mat (across runs)" % n if n else "Discover every collection (across runs)",
			func(_st, p): return Util.get_or(p, "everUnlockedMatCollections", []).size() >= (n if n else Mat.collections().size()))
	add.call("explorer", "🧭", "Explorer", "Visit all 8 stations by turn 8",
		func(st, _p):
			var seen := {}
			for t in Util.get_or(st, "visitLog", []).slice(0, 8):
				seen[t.station] = true
			return seen.size() >= 8)
	add.call("heli", "🚁", "Fast Travel", "Fly the Helicopter to a station off your path", func(st, _p): return Util.get_or(st, "heliTrips", 0) >= 1)
	add.call("regular", "🏠", "Regular", "Visit one station 6 times in a run",
		func(st, _p):
			var n := {}
			for t in Util.get_or(st, "visitLog", []):
				n[t.station] = n.get(t.station, 0) + 1
			return n.values().any(func(x): return x >= 6))
	add.call("bingo-1", "🎯", "Market Row", "Complete a Market row", func(st, _p): return Util.get_or(st, "bingoLinesCompleted", []).size() >= 1)
	add.call("bingo-3", "🎰", "Market Sweep", "Complete all 3 Market rows in one run", func(st, _p): return Util.get_or(st, "bingoLinesCompleted", []).size() >= 3)
	add.call("waste-not", "♻️", "Waste Not", "Finish a run with no elements left over",
		func(st, _p): return not Util.get_or(st, "elements", {}).values().any(func(n): return n > 0))
	add.call("alchemist", "⚗️", "Alchemist", "Convert elements 10 times in one run", func(st, _p): return Util.get_or(st, "converts", 0) >= 10)
	add.call("unknowns", "🔮", "Into the Unknown", "Spend 5 \"?\" elements in one run", func(st, _p): return Util.get_or(st, "qSpent", 0) >= 5)
	for m in [[5, "🎮", "Regular Player"], [25, "🕹️", "Devoted"], [100, "💯", "Centurion"]]:
		var n: int = m[0]
		add.call("runs-%d" % n, m[1], m[2], "Complete %d runs" % n, func(_st, p): return _life(p, "runs", 0) >= n)
	for m in [[500, "📦", "Stockpile"], [2000, "🏭", "Factory"]]:
		var n: int = m[0]
		add.call("crafted-%d" % n, m[1], m[2], "Craft %s items in total" % Util.thousands(n), func(_st, p): return _life(p, "items", 0) >= n)
	add.call("capstones-10", "🏆", "Capstone Veteran", "Craft 10 capstones in total", func(_st, p): return _life(p, "capCount", 0) >= 10)
	for m in [[3, "📅", "Three in a Row"], [7, "🗓️", "Week Streak"], [30, "🔥", "Month Streak"]]:
		var n: int = m[0]
		add.call("streak-%d" % n, m[1], m[2], "Play %d days in a row" % n, func(_st, p): return play_streak(p) >= n)
	add.call("ot-30", "⏱️", "Overtime", "Reach visit 30 in Overtime", func(st, _p): return int(st.visits) >= 30)
	add.call("ot-36", "🔥", "Iron Will", "Reach visit 36 in Overtime", func(st, _p): return int(st.visits) >= 36)
	_list = L
	return L


## The ids this run qualifies for.
static func earned(st: Dictionary, prefs: Dictionary) -> Array:
	return all().filter(func(t): return t.test.call(st, prefs)).map(func(t): return t.id)
