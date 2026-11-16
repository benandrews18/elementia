## The Market card (mat-scoring.js, bingo.js): rows of 4 (default) or the
## 5x5 BINGO card, drawing it, the centre capstone and finished lines.
class_name Market


static func _tier(n: String) -> String:
	return Data.t("ITEM_TIER")[n]


## JS arr[0]: null when empty.
static func _first(arr: Array) -> Variant:
	return null if arr.is_empty() else arr[0]


static func rows_mode(s: Dictionary) -> bool:
	return s.get("bingoLayout") == "rows"


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


## drawBingoCard(): the 5x5 card, a capstone in the centre.
static func draw_bingo_card(center: Variant) -> Array:
	var el := eligible()
	var cap_pool := shuffle(el.filter(func(n): return _tier(n) == "CAPSTONE"))
	if center == null:
		center = cap_pool[0]
	var unlocked: Dictionary = Data.t("UNLOCKED_BY")
	var used := {center: true}
	var picks := []
	for spread in Data.t("BINGO_TIER_SPREAD"):
		var tier: String = spread[0]
		var from_el := shuffle(el.filter(func(x): return _tier(x) == tier and not used.has(x)))
		var from_core := shuffle(Data.t("CORE_ITEM_NAMES").filter(func(x):
			return _tier(x) == tier and not used.has(x) and not unlocked.has(x) and not from_el.has(x)))
		for x in (from_el + from_core).slice(0, int(spread[1])):
			used[x] = true
			picks.append(x)
	var size := int(Data.t("BINGO_SIZE"))
	var need := size * size - 1
	if picks.size() < need:
		for x in shuffle(el.filter(func(x): return not used.has(x) and _tier(x) != "CAPSTONE" and _tier(x) != "MATERIAL")).slice(0, need - picks.size()):
			used[x] = true
			picks.append(x)
	var others := shuffle(picks)
	var c := int(Data.t("BINGO_CENTER_IDX"))
	return others.slice(0, c) + [center] + others.slice(c)


static func ensure_card(s: Dictionary) -> Array:
	var need := int(Data.t("MARKET_ROWS")) * int(Data.t("MARKET_ROW_LEN")) if rows_mode(s) else int(Data.t("BINGO_SIZE")) ** 2
	var core: Array = Data.t("CORE_ITEM_NAMES")
	var card = s.get("bingoCard")
	var stale: bool = card != null and card.any(func(n): return not core.has(n))
	if card == null or card.size() != need or stale:
		if card != null:
			s.bingoLinesCompleted = []
			s.pendingBingoClears = []
			s.bingoCenterChosen = false
		s.bingoCard = draw_row_card(null) if rows_mode(s) else draw_bingo_card(null)
	return s.bingoCard


## setBingoCenter(): the run's chosen capstone (or "__RANDOM__").
static func set_center(s: Dictionary, name: String) -> void:
	if name == Data.t("BINGO_RANDOM_CAPSTONE"):
		name = Rng.pick(capstone_choices())
	if rows_mode(s):
		if Util.get_or(s, "bingoLinesCompleted", []).is_empty():
			s.bingoCard = draw_row_card(name)
		else:
			ensure_card(s)
		s.bingoCenterChosen = true
		return
	var card := ensure_card(s).duplicate()
	var c := int(Data.t("BINGO_CENTER_IDX"))
	var dup := -1
	for i in card.size():
		if i != c and card[i] == name:
			dup = i
			break
	if dup != -1:
		var used := {}
		for n in card:
			used[n] = true
		used[name] = true
		var filler = _first(shuffle(eligible().filter(func(n): return _tier(n) == _tier(card[dup]) and not used.has(n))))
		if filler == null:
			filler = _first(shuffle(eligible().filter(func(n): return _tier(n) != "CAPSTONE" and _tier(n) != "MATERIAL" and not used.has(n))))
		if filler != null:
			card[dup] = filler
	card[c] = name
	s.bingoCard = card
	s.bingoCenterChosen = true


static func lines(s: Dictionary) -> Array:
	var out := []
	if rows_mode(s):
		var n := int(Data.t("MARKET_ROW_LEN"))
		for r in int(Data.t("MARKET_ROWS")):
			out.append(range(r * n, r * n + n))
		return out
	var n := int(Data.t("BINGO_SIZE"))
	for r in n:
		out.append(range(n).map(func(c): return r * n + c))
	for c in n:
		out.append(range(n).map(func(r): return r * n + c))
	out.append(range(n).map(func(i): return i * n + i))
	out.append(range(n).map(func(i): return i * n + n - 1 - i))
	return out


## checkBingoLines(): each newly finished line, once ever.
static func check_lines(s: Dictionary) -> void:
	if s.get("bingoCard") == null:
		return
	if s.get("pendingBingoClears") == null:
		s.pendingBingoClears = []
	var ls := lines(s)
	for i in ls.size():
		if s.bingoLinesCompleted.any(func(x): return int(x) == i):
			continue
		if not ls[i].all(func(idx): return Catalog.owns(s, s.bingoCard[idx])):
			continue
		s.bingoLinesCompleted.append(i)
		s.pendingBingoClears.append(i)
