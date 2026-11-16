## The Display Mat (mat-scoring.js): its shape as it grows, packing cards
## into slots, combos, collections and the score. `cards` are MAT_CARD rows.
class_name Mat

static var _collections: Array  # MAT_COLLECTIONS: the raw list minus any with a missing card


static func on_mat(s: Dictionary) -> Array:
	return s.mat.map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)


static func has(cards: Array, name: String) -> bool:
	return cards.any(func(c): return c.name == name)


static func is_capstone(c: Dictionary) -> bool:
	return c.tier == "CAPSTONE"


static func is_tier1(c: Dictionary) -> bool:
	return c.tier == "MATERIAL"


## matStage(): 0..3, how far the mat has grown (MAT_GROW_ROUNDS).
static func stage(s: Dictionary) -> int:
	var v := int(s.get("visits", 0))
	var n := 0
	for r in Data.t("MAT_GROW_ROUNDS"):
		if v > r or (v == r and s.get("checkRound") != null and int(s.checkRound) == r):
			n += 1
	return n


static func layout(cards: Array, st: int) -> Dictionary:
	var extra := 1 if has(cards, "Metropolis") else 0
	var cols := int(Data.t("MAT_SLOTS_COLS")) + extra
	var kinds := []
	for r in int(Data.t("MAT_SLOTS_ROWS")):
		for c in cols:
			if r == 0:
				kinds.append("locked" if st == 0 and c >= 3 + extra else "full")
			else:
				kinds.append("full" if st >= 3 else "top" if st == 2 else "locked")
	var per_slot := 3 if has(cards, "Maglev Train") else int(Data.t("MAT_TIER1_PER_SLOT"))
	return {"cols": cols, "kinds": kinds, "perSlot": per_slot, "stage": st}


## matPack(): bigger cards first into open slots (a capstone takes two side
## by side), then tier 1 cards stacked. Returns {slot, overflow}.
static func pack(cards: Array, st: int) -> Dictionary:
	var L := layout(cards, st)
	var cols: int = L.cols
	var slot: Array = L.kinds.map(func(k): return {"kind": k})
	var free := func(x) -> bool:
		return x.kind == "full" and not x.has("card") and not x.has("stack") and not x.has("cover")
	var overflow := []
	for idx in cards.size():
		var c: Dictionary = cards[idx]
		if is_tier1(c):
			continue
		var w := 2 if is_capstone(c) else 1
		var at := -1
		for i in slot.size():
			if i % cols + w <= cols and i + w <= slot.size() and slot.slice(i, i + w).all(free):
				at = i
				break
		if at < 0:
			overflow.append(c)
			continue
		slot[at].card = c
		slot[at].idx = idx
		slot[at].w = w
		for k in range(1, w):
			slot[at + k].cover = true
	for idx in cards.size():
		var c: Dictionary = cards[idx]
		if not is_tier1(c):
			continue
		var target = null
		for x in slot:
			if x.has("stack") and x.stack.size() < (1 if x.kind == "top" else L.perSlot):
				target = x
				break
		if target == null:
			for x in slot:
				if x.kind == "top" and not x.has("stack"):
					target = x
					break
		if target == null:
			for x in slot:
				if free.call(x):
					target = x
					break
		if target == null:
			overflow.append(c)
			continue
		if not target.has("stack"):
			target.stack = []
		target.stack.append({"card": c, "idx": idx})
	return {"L": L, "slot": slot, "overflow": overflow}


static func fits(cards: Array, st: int) -> bool:
	return pack(cards, st).overflow.is_empty()


static func has_empty_slot(cards: Array, st: int) -> bool:
	return pack(cards, st).slot.any(func(x): return x.kind != "locked" and not x.has("card") and not x.has("stack") and not x.has("cover"))


static func direct_items(c: Dictionary) -> Array:
	var out := []
	for x in c.components:
		if x.kind == "item" and not out.has(x.name):
			out.append(x.name)
	return out


## matGroupsOf(): counts per station, suit pip and shared component.
static func groups(cards: Array) -> Dictionary:
	var st := {}
	var su := {}
	var cp := {}
	for c in cards:
		for x in c.stations:
			st[x] = st.get(x, 0) + 1
		for x in c.pips:
			su[x] = su.get(x, 0) + 1
		cp[c.name] = cp.get(c.name, 0) + 1
		for x in direct_items(c):
			cp[x] = cp.get(x, 0) + 1
	return {"st": st, "su": su, "cp": cp}


static func combo_tier(k: int) -> int:
	var b := 0
	for t in Data.t("MAT_COMBO_TIERS"):
		if k >= t.k:
			b = int(t.b)
	return b


static func combo_bonus(counts: Dictionary) -> int:
	var n := 0
	for k in counts:
		n += combo_tier(int(counts[k]))
	return n


## matIsComplete(): the card's whole direct recipe is on the mat too.
static func is_complete(c: Dictionary, cards: Array) -> bool:
	var need := direct_items(c)
	return not need.is_empty() and need.all(func(n): return has(cards, n))


static func collections() -> Array:
	if _collections.is_empty():
		for col in Data.t("MAT_COLLECTIONS_RAW"):
			if col.items.all(func(i): return Catalog.mat_card(i) != null):
				var pts := 0.0
				for i in col.items:
					pts += Catalog.mat_card(i).points
				var c: Dictionary = col.duplicate()
				c.bonus = Util.js_round(pts * 0.3)
				_collections.append(c)
	return _collections


static func completed_in(cards: Array) -> Array:
	return collections().filter(func(col): return col.items.all(func(i): return has(cards, i)))


## matDestination(): where a Lock-In travels to (Space Station's Orbit).
static func destination(s: Dictionary, ctx: Dictionary) -> Variant:
	if ctx.get("travelPromptFor"):
		return ctx.travelPromptFor
	var sel = ctx.get("selectedMapStation")
	return sel if ctx.get("screen") == "map" and sel and sel != s.get("lastStation") else null


## matScore(): (points + collection bonuses) x combo multiplier, with the
## capstone signature rules and the challenge in force.
static func score(cards: Array, s: Dictionary, ctx: Dictionary) -> Dictionary:
	var dest = destination(s, ctx) if has(cards, "Space Station") else null
	var maglev := has(cards, "Maglev Train")
	var robot := has(cards, "Robot")
	var homestead := has(cards, "Homestead")
	var base := 0.0
	for c in cards:
		var p: float = c.points + (2 if maglev and is_tier1(c) else 0) + (5 if robot else 0)
		if is_complete(c, cards):
			p *= 3 if homestead else 2
		if dest != null and c.stations.has(dest):
			p *= 2
		base += p
	var g := groups(cards)
	var combo := combo_bonus(g.st) + combo_bonus(g.su) + combo_bonus(g.cp)
	var col_bonus := 0.0
	for col in completed_in(cards):
		col_bonus += col.bonus
	var stations_on := {}
	for c in cards:
		for x in c.stations:
			stations_on[x] = true
	var coral := stations_on.size() if has(cards, "Coral Reef") else 0
	var eco := int(s.get("ecoStreak", 0)) + 1 if has(cards, "Ecosystem") else 0
	var mult := 1 + combo + coral + eco
	var layered: bool = has(cards, "Fruit Cake") and Data.t("ELEMENT_SUIT_LABEL").keys().all(
		func(su): return cards.any(func(c): return c.pips.has(su)))
	var pre := (base + col_bonus) * mult
	var order_mult := Orders.mult_for(cards, s)
	return {"base": base, "colBonus": col_bonus, "mult": mult, "layered": layered, "orderMult": order_mult,
		"total": Util.js_round((pre * 2 if layered else pre) * order_mult)}
