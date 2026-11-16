## The Market (mat-scoring.js, bingo.js): 3 rows of 4 items, drawn once per
## run around the chosen capstone; each finished row pays a "?". (The HTML
## game's old 5x5 BINGO card setting isn't ported: retired.)
class_name Market


static func _tier(n: String) -> String:
	return Data.t("ITEM_TIER")[n]


## JS shuffle(): Fisher-Yates in place, drawing from Rng.
static func shuffle(arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := int(floor(Rng.next() * (i + 1)))
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
	return arr


static func eligible() -> Array:
	var pts: Dictionary = Data.t("ITEM_POINTS")
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	return Data.t("CORE_ITEM_NAMES").filter(func(n): return pts.get(n, 0) >= Data.t("BINGO_MIN_POINTS") and not unlocked.has(n))


static func capstone_choices() -> Array:
	return eligible().filter(func(n): return _tier(n) == "CAPSTONE")


## drawRowCard(): 3 rows of three tier 3 + one tier 2; given a capstone, the
## first row is it plus three of its station's items (feeding it first).
static func draw_row_card(capstone: Variant) -> Array:
	var el := eligible().filter(func(n): return _tier(n) != "CAPSTONE")
	var home: Dictionary = Data.t("CORE_ITEM_STATION")
	var row_len := int(Data.t("MARKET_ROW_LEN"))
	var used := {}
	var rows := []
	if capstone != null:
		var feeds := Catalog.component_closure(capstone)
		var rank := func(n): return (0 if feeds.has(n) else 2) + (0 if _tier(n) == "CREATION" else 1)
		var mates := Util.stable_sort(shuffle(el.filter(func(n): return home[n] == home[capstone])),
			func(a, b): return rank.call(a) - rank.call(b)).slice(0, row_len - 1)
		for n in [capstone] + mates:
			used[n] = true
		rows.append(shuffle([capstone] + mates))
	var t3 := shuffle(el.filter(func(n): return _tier(n) == "CREATION" and not used.has(n)))
	var t2 := shuffle(el.filter(func(n): return _tier(n) == "COMPONENT" and not used.has(n)))
	while rows.size() < int(Data.t("MARKET_ROWS")):
		var row := t3.slice(0, 3) + t2.slice(0, 1)
		t3 = t3.slice(3)
		t2 = t2.slice(1)
		rows.append(shuffle(row))
	var flat := []
	for r in rows:
		flat += r
	return flat


static func ensure_card(s: Dictionary) -> Array:
	var need := int(Data.t("MARKET_ROWS")) * int(Data.t("MARKET_ROW_LEN"))
	var core: Array = Data.t("CORE_ITEM_NAMES")
	var card = s.get("bingoCard")
	var stale: bool = card != null and card.any(func(n): return not core.has(n))
	if card == null or card.size() != need or stale:
		if card != null:
			s.bingoLinesCompleted = []
			s.pendingBingoClears = []
			s.bingoCenterChosen = false
		s.bingoCard = draw_row_card(null)
	return s.bingoCard


## setBingoCenter(): the run's chosen capstone (or "__RANDOM__") gets its own
## row, if no row has paid out yet.
static func set_center(s: Dictionary, name: String) -> void:
	if name == Data.t("BINGO_RANDOM_CAPSTONE"):
		name = Rng.pick(capstone_choices())
	if Util.get_or(s, "bingoLinesCompleted", []).is_empty():
		s.bingoCard = draw_row_card(name)
	else:
		ensure_card(s)
	s.bingoCenterChosen = true


static func lines() -> Array:
	var n := int(Data.t("MARKET_ROW_LEN"))
	return range(int(Data.t("MARKET_ROWS"))).map(func(r): return range(r * n, r * n + n))


## checkBingoLines(): each newly finished row, once ever.
static func check_lines(s: Dictionary) -> void:
	if s.get("bingoCard") == null:
		return
	if s.get("pendingBingoClears") == null:
		s.pendingBingoClears = []
	var ls := lines()
	for i in ls.size():
		if s.bingoLinesCompleted.any(func(x): return int(x) == i):
			continue
		if not ls[i].all(func(idx): return Catalog.owns(s, s.bingoCard[idx])):
			continue
		s.bingoLinesCompleted.append(i)
		s.pendingBingoClears.append(i)
