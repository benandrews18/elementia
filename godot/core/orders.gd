## Board checks (lock-in.js): breakpoints, the reward tiers, and check
## orders ("challenges"). CHECK_ORDERS holds code in the JS, so its rules
## are ported here; the multipliers and rounds come from the data.
class_name Orders

## id -> [kind, level] in the JS definition order (drawing depends on it).
const KINDS := {
	"stationWeek": ["request", null], "collector": ["request", null], "fullRecipe": ["request", null],
	"suitSet": ["request", null], "commonThread": ["request", null],
	"drought": ["restriction", "easy"], "closedStation": ["restriction", "easy"], "freshFaces": ["restriction", "easy"],
	"shortTable": ["restriction", "hard"], "thinStock": ["restriction", "hard"], "trendShift": ["restriction", "hard"],
	"doubleDrought": ["restriction", "hard"], "spreadOut": ["restriction", "hard"],
}


static func _suits() -> Array:
	return Data.t("ELEMENT_SUIT_LABEL").keys()


static func _station_count(cards: Array, st: String) -> int:
	return int(Mat.groups(cards).st.get(st, 0))


static func _suit_cards(cards: Array, su: String) -> int:
	return cards.filter(func(c): return c.pips.has(su)).size()


## CHECK_ORDERS[id].params(owned): the choices of p for this order.
static func params(id: String, owned: Array, s: Dictionary) -> Array:
	var stations: Array = Data.t("STATION_BY_NAME").keys()
	match id:
		"stationWeek": return stations.filter(func(st): return _station_count(owned, st) >= 3)
		"collector": return [null] if not Mat.completed_in(owned).is_empty() else []
		"fullRecipe": return [null] if owned.any(func(c): return Mat.is_complete(c, owned)) else []
		"suitSet": return _suits().filter(func(su): return _suit_cards(owned, su) >= 3)
		"commonThread": return [null] if Mat.groups(owned).cp.values().any(func(n): return n >= 3) else []
		"drought": return _suits()
		"closedStation": return stations.filter(func(st): return _station_count(owned, st) >= 1)
		"freshFaces": return [null] if not Util.get_or(s, "lastCheckedMat", []).is_empty() else []
		"shortTable", "thinStock", "spreadOut": return [null]
		"trendShift": return [s.lastTopStation] if s.get("lastTopStation") else []
		"doubleDrought":
			var out := []
			var su := _suits()
			for i in su.size():
				for j in range(i + 1, su.size()):
					out.append(su[i] + "|" + su[j])
			return out
	push_error("Unknown order " + id)
	return []


## CHECK_ORDERS[id].ok(mat, p)
static func ok(id: String, cards: Array, p: Variant, s: Dictionary) -> bool:
	match id:
		"stationWeek": return _station_count(cards, p) >= 3
		"collector": return not Mat.completed_in(cards).is_empty()
		"fullRecipe": return cards.any(func(c): return Mat.is_complete(c, cards))
		"suitSet": return _suit_cards(cards, p) >= 3
		"commonThread": return Mat.groups(cards).cp.values().any(func(n): return n >= 3)
		"drought": return not cards.any(func(c): return c.pips.has(p))
		"closedStation": return _station_count(cards, p) == 0
		"freshFaces":
			var last: Array = Util.get_or(s, "lastCheckedMat", [])
			return cards.filter(func(c): return last.has(c.name)).size() * 2 <= cards.size()
		"shortTable": return Mat.has_empty_slot(cards, Mat.stage(s))
		"thinStock": return cards.filter(Mat.is_tier1).size() <= 3
		"trendShift": return _station_count(cards, p) < 3
		"doubleDrought":
			var two: PackedStringArray = p.split("|")
			return not cards.any(func(c): return Array(two).any(func(su): return c.pips.has(su)))
		"spreadOut": return Mat.groups(cards).st.values().all(func(n): return n < 4)
	push_error("Unknown order " + id)
	return false


static func key(o: Dictionary) -> String:
	return o.id + ":" + Util.js_str(o.p)


## drawOrder(round, avoid): a random order the owned cards can satisfy,
## preferring ones not used this run. null when none.
static func draw(s: Dictionary, round: int, avoid: Variant) -> Variant:
	var last := int(Data.t("RUN_COMPLETE_VISIT"))
	if round > last:
		return null
	if round == last:
		return {"id": "grand", "p": null, "round": round}
	var kind := "request" if round <= int(Data.t("ORDER_LAST_REQUEST")) else "restriction"
	var level = null if kind == "request" else "hard" if round >= int(Data.t("ORDER_HARD_FROM")) else "easy"
	var owned: Array = s.items.map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
	var all := []
	for id in KINDS:
		if KINDS[id][0] == kind and KINDS[id][1] == level:
			for p in params(id, owned, s):
				var o := {"id": id, "p": p, "round": round}
				if avoid == null or key(o) != key(avoid):
					all.append(o)
	var used: Array = Util.get_or(s, "usedOrders", [])
	var fresh := all.filter(func(o): return not used.has(key(o)))
	return Rng.pick(fresh if not fresh.is_empty() else all)


static func set_order(s: Dictionary, o: Variant) -> void:
	s.order = o
	if o != null:
		if s.get("usedOrders") == null:
			s.usedOrders = []
		s.usedOrders.append(key(o))


## currentOrder(): the challenge in force this round.
static func current(s: Dictionary) -> Variant:
	var o = s.get("order")
	var v := int(s.visits)
	return o if o != null and v >= int(o.round) and v < int(o.round) + int(Data.t("MAT_CHECK_EVERY")) else null


static func met(o: Dictionary, cards: Array, total: float, s: Dictionary) -> bool:
	return total >= Data.t("GRAND_EXHIBITION_TARGET") if o.id == "grand" else ok(o.id, cards, o.p, s)


## orderMultFor(): the challenge's multiplier on the score while in force.
static func mult_for(cards: Array, s: Dictionary) -> float:
	var o = current(s)
	if o == null or o.id == "grand":
		return 1.0
	var good := ok(o.id, cards, o.p, s)
	if KINDS[o.id][0] == "request":
		return Data.t("ORDER_REQUEST_MULT") if good else 1.0
	return 1.0 if good else Data.t("ORDER_RESTRICT_MULT")


# ---- breakpoints

static func base_tiers(round: int) -> Dictionary:
	var a: Array = Data.t("LOCKIN_ROUND_ANCHORS")
	var row := func(r: Array) -> Dictionary: return {"one": r[1], "two": r[2], "three": r[3], "four": r[4]}
	if round <= a[0][0]:
		return row.call(a[0])
	if round >= a[-1][0]:
		return row.call(a[-1])
	for i in a.size() - 1:
		var lo: Array = a[i]
		var hi: Array = a[i + 1]
		if round >= lo[0] and round <= hi[0]:
			var f: float = float(round - lo[0]) / (hi[0] - lo[0])
			return {"one": lo[1] + (hi[1] - lo[1]) * f, "two": lo[2] + (hi[2] - lo[2]) * f,
				"three": lo[3] + (hi[3] - lo[3]) * f, "four": lo[4] + (hi[4] - lo[4]) * f}
	return {}


## lockInTiersForRound(): board-check rounds get the (rounded) bump.
static func tiers(round: int) -> Dictionary:
	var t := base_tiers(round)
	if round % int(Data.t("MAT_CHECK_EVERY")) != 0:
		return t
	var bump: float = Data.t("OFFICIAL_CHECK_BUMP")
	var up := func(v: float) -> float: return Util.js_round(v * (1 + bump) / 5) * 5
	return {"one": up.call(t.one), "two": up.call(t.two), "three": up.call(t.three), "four": up.call(t.four)}


## emptyElementsForScore(): 0-4, the breakpoints the score reached.
static func reward_for(total: float, round: int) -> int:
	var t := tiers(round)
	if total >= t.four: return 4
	if total >= t.three: return 3
	if total >= t.two: return 2
	if total >= t.one: return 1
	return 0


## nextCheckRound(): never earlier than the first check on visit 3.
static func next_check_round(s: Dictionary) -> int:
	var every := int(Data.t("MAT_CHECK_EVERY"))
	return maxi(every, ceili(float(int(s.visits)) / every) * every)


## matCheckRound(): whose breakpoints apply on leaving now.
static func check_round(s: Dictionary) -> int:
	return int(s.visits) if s.get("matChecked") and not Catalog.is_sunset_visit(s) else next_check_round(s)
