## Item and station lookups over the exported tables (model.js,
## crafting.js). Pure functions of the data; `s` is the run state where a
## rule needs it.
class_name Catalog

static var _first_entry: Dictionary  # item name -> its first ENTRIES row (JS ENTRIES.find)


static func entry(name: String) -> Variant:
	if _first_entry.is_empty():
		for e in Data.t("ENTRIES"):
			if not _first_entry.has(e.name):
				_first_entry[e.name] = e
	return _first_entry.get(name)


static func station(name: String) -> Dictionary:
	return Data.t("STATION_BY_NAME")[name]


static func mat_card(name: String) -> Variant:
	return Data.t("MAT_CARD_BY_NAME").get(name)


## sortedDice(): a station's dice by atomic number.
static func sorted_dice(st: Dictionary) -> Array:
	var an: Dictionary = Data.t("ATOMIC_NUMBER")
	return Util.stable_sort(st.dice, func(a, b): return an.get(a, 999) - an.get(b, 999))


## needsOf(): elements needed (summed) and unique item ingredients.
static func needs_of(reqs: Array) -> Dictionary:
	var els := {}
	var items := []
	for r in reqs:
		if r.kind == "element":
			els[r.name] = els.get(r.name, 0) + 1
		elif not items.any(func(i): return i.name == r.name):
			items.append(r)
	return {"els": els, "items": items}


static func owns(s: Dictionary, name: String) -> bool:
	return s.items.has(name)


static func count(s: Dictionary, sym: String) -> float:
	return s.elements.get(sym, 0)


static func can_craft(s: Dictionary, e: Dictionary) -> bool:
	var n := needs_of(e.reqs)
	for sym in n.els:
		if count(s, sym) < n.els[sym]:
			return false
	return n.items.all(func(it): return owns(s, it.name))


## componentClosure(): every item in name's recipe tree, excluding name.
static func component_closure(name: String) -> Array:
	var seen := {}
	var walk := func(n: String, self_ref: Callable) -> void:
		if seen.has(n):
			return
		seen[n] = true
		var e = entry(n)
		if e != null:
			for i in needs_of(e.reqs).items:
				self_ref.call(i.name, self_ref)
	var root = entry(name)
	if root == null:
		return []
	for i in needs_of(root.reqs).items:
		walk.call(i.name, walk)
	return seen.keys()


static func is_map_connected(a: Variant, b: Variant) -> bool:
	if a == null:
		return b != null and b != ""
	var adj: Dictionary = Data.t("MAP_ADJ")
	return a != "" and b != null and b != "" and adj.has(a) and adj[a].has(b)


## isMatCheckVisit() / isSunsetVisit()
static func is_mat_check_visit(s: Dictionary) -> bool:
	var v := int(s.visits)
	return v >= int(Data.t("MAT_CHECK_EVERY")) and v % int(Data.t("MAT_CHECK_EVERY")) == 0


static func is_sunset_visit(s: Dictionary) -> bool:
	var v := int(s.visits)
	return v > 0 and v % int(Data.t("MAT_CHECK_EVERY")) == 0
