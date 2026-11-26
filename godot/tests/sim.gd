## The simulator (PLAN.md step 16 part 2): whole runs played headless with
## the game's own rules by a player who knows the game, for the breakpoint
## tuner (tools/sim.py reads what this writes).
##   Godot_console.exe --headless --path godot res://tests/sim.tscn -- --runs 200 --seed 1 --out <file.json>
## Ported from the HTML game's simulator (game/tools/sim/sim_agent.js):
## capstone first (the start station's, then the one whose tree it owns
## most of), route planning a few moves ahead, an opening book and craft
## habits from the user's runs (tests/sim_guide/*.json, History exports).
## New here: it plays the check's hand (Hand: plays, discards, draws).
extends Node

const OPENING_TURNS := 6
const ROUTE_DECAY := 0.55
const PLAY_BAR := 0.7  # a play is worth it at this share of an average deck card's value per slot

var s: Dictionary  # Game.state of the run being played
var item_freq := {}  # item -> share of the user's runs that crafted it
var trans := {}  # station -> {next station: times}
var openings := {}  # start station -> [the user's routes]
var cap_tree := {}  # capstone -> its whole recipe tree (and itself)
var dist := {}  # station -> {station: moves}
var want := {}
var goal = null
var route = null
var verbose := false


func _ready() -> void:
	Progress.autosave = false
	Progress.prefs.devMode = false  # the Dev Panel's dice never reach the sim
	var args := OS.get_cmdline_user_args()
	var runs := int(_arg(args, "--runs", "100"))
	verbose = args.has("--verbose")
	seed(int(_arg(args, "--seed", "1")))
	var out_path := _arg(args, "--out", ProjectSettings.globalize_path("res://build/sim_runs.json"))
	_learn()
	var t0 := Time.get_ticks_msec()
	var out := []
	for i in runs:
		out.append(_play_run())
		if (i + 1) % 25 == 0:
			print("sim: %d/%d runs" % [i + 1, runs])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("sim: %d runs in %.1fs -> %s" % [runs, (Time.get_ticks_msec() - t0) / 1000.0, out_path])
	get_tree().quit(0)


func _arg(args: PackedStringArray, k: String, d: String) -> String:
	var i := args.find(k)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else d


# ---- what the user's runs and the data tell us

func _learn() -> void:
	var runs := []
	for f in DirAccess.get_files_at("res://tests/sim_guide"):
		if f.ends_with(".json"):
			var r = JSON.parse_string(FileAccess.get_file_as_string("res://tests/sim_guide/" + f))
			runs += r if r is Array else [r]
	for r in runs:
		var log: Array = r.visitLog
		var made := {}
		for t in log:
			for n in t.items:
				made[n] = true
		for n in made:
			item_freq[n] = item_freq.get(n, 0.0) + 1.0 / runs.size()
		for i in range(1, log.size()):
			var row: Dictionary = trans.get_or_add(log[i - 1].station, {})
			row[log[i].station] = row.get(log[i].station, 0) + 1
		if not log.is_empty():
			openings.get_or_add(log[0].station, []).append(log.map(func(t): return t.station))
	for c in Data.t("CAPSTONES"):
		cap_tree[c] = Catalog.component_closure(c) + [c]
	for st in _stations():
		var d := {st: 0}
		var queue := [st]
		while not queue.is_empty():
			var n = queue.pop_front()
			for m in Data.t("MAP_ADJ").get(n, []):
				if not d.has(m):
					d[m] = d[n] + 1
					queue.append(m)
		dist[st] = d


func _stations() -> Array:
	return Data.t("DATA").stations.map(func(x): return x.name)


func _trans_p(a: String, b: String) -> float:
	var row: Dictionary = trans.get(a, {})
	var tot := 0
	for k in row:
		tot += row[k]
	return float(row.get(b, 0)) / tot if tot else 0.0


# ---- goals

## The capstone's tree: itself 8, its direct parts 5, deeper parts 3.
func _set_wants() -> void:
	want = {}
	if goal == null:
		return
	var depth := {goal: 0}
	var queue := [goal]
	while not queue.is_empty():
		var n = queue.pop_front()
		var e = Catalog.entry(n)
		if e != null:
			for i in Catalog.needs_of(e.reqs).items:
				if not depth.has(i.name):
					depth[i.name] = depth[n] + 1
					queue.append(i.name)
	for n in depth:
		want[n] = 8.0 if depth[n] == 0 else 5.0 if depth[n] == 1 else 3.0


## Next capstone: the one whose tree is most owned already.
func _choose_goal() -> void:
	goal = null
	var best := -1.0
	for c in Data.t("CAPSTONES"):
		if Catalog.owns(s, c):
			continue
		var f: float = float(cap_tree[c].filter(func(n): return Catalog.owns(s, n)).size()) / cap_tree[c].size()
		if f > best:
			best = f
			goal = c
	_set_wants()


func _weight(n: String) -> float:
	return want.get(n, 0.0) + item_freq.get(n, 0.0)


func _in_some_cap_tree(n: String) -> bool:
	return Data.t("CAPSTONES").any(func(c): return not Catalog.owns(s, c) and cap_tree[c].has(n))


# ---- elements and crafting

func _shop_at(st: String) -> Array:
	return Data.t("ENTRIES").filter(func(e): return e.station == st and Catalog.item_open(s, e.name) and not Catalog.owns(s, e.name))


func _parts_owned(e: Dictionary) -> bool:
	return Catalog.needs_of(e.reqs).items.all(func(i): return Catalog.owns(s, i.name))


## Elements held back for the top wanted items whose parts are owned.
func _reserve() -> Dictionary:
	var r := {}
	var es := want.keys().filter(func(n): return not Catalog.owns(s, n) and Catalog.item_open(s, n)) \
		.map(func(n): return Catalog.entry(n)).filter(func(e): return e != null and _parts_owned(e))
	es.sort_custom(func(a, b): return _weight(a.name) > _weight(b.name))
	for e in es.slice(0, 4):
		var els: Dictionary = Catalog.needs_of(e.reqs).els
		for sym in els:
			r[sym] = r.get(sym, 0) + els[sym]
	return r


## What e still lacks: recipe elements, then suit costs from what's left.
func _shortfall(e: Dictionary, have: Dictionary) -> Dictionary:
	var els: Dictionary = Catalog.needs_of(e.reqs).els
	var miss := {}
	var total := 0.0
	for sym in els:
		if have.get(sym, 0) < els[sym]:
			miss[sym] = els[sym] - have.get(sym, 0)
			total += miss[sym]
	var suit_miss := {}
	var need := Game.suit_cost_need(e.name)
	for su in need:
		var surplus := 0.0
		for sym in Data.t("SUIT_CORE_ELEMENTS").get(su, []):
			surplus += maxf(0, have.get(sym, 0) - els.get(sym, 0))
		if surplus < need[su]:
			suit_miss[su] = need[su] - surplus
			total += suit_miss[su]
	return {"miss": miss, "suit_miss": suit_miss, "total": total}


func _craft(e: Dictionary) -> bool:
	if not Catalog.can_craft(s, e) or not Game.suit_cost_payable(e.name):
		return false
	if not Game.craft(e.name, Game.suggest_suit_picks(e.name)):
		return false
	Game.collect_market_rewards()
	if goal != null and Catalog.owns(s, goal):
		_choose_goal()
	return true


## Fills e's shortfall (at most 3) by converting 3:1 and spending "?" on
## this station's elements. False if it can't be done (nothing changes).
func _enable(e: Dictionary) -> bool:
	var sf := _shortfall(e, s.elements)
	if sf.total == 0:
		return true
	if sf.total > 3:
		return false
	var els: Dictionary = Catalog.needs_of(e.reqs).els
	var keep := _reserve()
	var dice: Array = Catalog.station(Game.ctx.current).dice
	var rate := int(Data.t("CONVERT_RATE"))
	var todo := []
	for sym in sf.miss:
		for i in int(sf.miss[sym]):
			todo.append(sym)
	for su in sf.suit_miss:
		var core: Array = Data.t("SUIT_CORE_ELEMENTS")[su]
		var at_hand := core.filter(func(x): return dice.has(x))
		for i in int(sf.suit_miss[su]):
			todo.append(at_hand[0] if not at_hand.is_empty() else core[0])
	var spare := {}
	for sym in s.elements:
		spare[sym] = Catalog.count(s, sym) - els.get(sym, 0) - keep.get(sym, 0)
	var q := int(Util.get_or(s, "emptyElements", 0))
	var steps := []
	for target in todo:
		if q > 0 and dice.has(target):
			q -= 1
			steps.append(["?", target])
			continue
		var from = null
		for sym in spare:
			if sym != target and spare[sym] >= rate and (from == null or spare[sym] > spare[from]):
				from = sym
		if from == null:
			return false
		spare[from] -= rate
		steps.append([from, target])
	var after: Dictionary = s.elements.duplicate()
	for st in steps:
		if st[0] != "?":
			after[st[0]] = after.get(st[0], 0) - rate
		after[st[1]] = after.get(st[1], 0) + 1
	if _shortfall(e, after).total > 0:
		return false
	for st in steps:
		if st[0] == "?":
			Game.spend_unknown(st[1])
		else:
			Game.convert_elements(st[0], st[1])
	return true


## One station visit's shopping.
func _shop() -> void:
	var here: String = Game.ctx.current
	var last: bool = int(s.visits) >= int(Data.t("RUN_COMPLETE_VISIT"))
	for guard in 40:
		var items := _shop_at(here).filter(_parts_owned)
		var ready := items.filter(func(e): return Catalog.can_craft(s, e) and Game.suit_cost_payable(e.name))
		var wanted := ready.filter(func(e): return want.has(e.name))
		wanted.sort_custom(func(a, b): return _weight(a.name) > _weight(b.name))
		if not wanted.is_empty() and _craft(wanted[0]):
			continue
		# A wanted item a convert or "?" away (on the last turn, anything).
		var near := items.filter(func(e): return (want.has(e.name) or last) and not ready.has(e))
		near.sort_custom(func(a, b): return _weight(a.name) > _weight(b.name) if _weight(a.name) != _weight(b.name) else a.points > b.points)
		var done := false
		for e in near:
			if _enable(e) and _craft(e):
				done = true
				break
		if done:
			continue
		# Side crafts that serve something, if they spare the reserve. Any mat
		# card counts: the deck is the check's hand.
		var keep := _reserve()
		var extra := ready.filter(func(e):
			var els: Dictionary = Catalog.needs_of(e.reqs).els
			var spares: bool = els.keys().all(func(sym): return Catalog.count(s, sym) - els[sym] >= keep.get(sym, 0))
			return spares and (_in_some_cap_tree(e.name) or e.points >= 8 or item_freq.get(e.name, 0.0) >= 0.4 or last
				or Catalog.mat_card(e.name) != null))
		extra.sort_custom(func(a, b): return a.points > b.points)
		if not extra.is_empty() and _craft(extra[0]):
			continue
		break


# ---- where next

func _moves(a: String, b: String) -> int:
	return 0 if a == b else 1 if Catalog.owns(s, "Helicopter") else int(dist[a].get(b, 9))


## What a visit to station n is worth now: wanted items it sells whose parts
## are owned (or sold there too), by how close the elements are.
func _station_value(n: String, dice: float) -> float:
	var have: Dictionary = s.elements.duplicate()
	for sym in Catalog.station(n).dice:
		have[sym] = have.get(sym, 0) + dice / 6.0
	var v := 0.0
	for e in _shop_at(n):
		var w: float = _weight(e.name) if want.has(e.name) else 0.25 * item_freq.get(e.name, 0.0)
		if w == 0:
			continue
		var missing: Array = Catalog.needs_of(e.reqs).items.filter(func(i): return not Catalog.owns(s, i.name))
		if not missing.all(func(i): return Data.t("ENTRIES").any(func(x): return x.name == i.name and x.station == n)):
			continue
		var d: float = _shortfall(e, have).total + (1.5 if not missing.is_empty() else 0.0)
		v += w / pow(1 + d, 1.5)
	return v


func _choose_next() -> String:
	var here: String = s.lastStation
	var opts := _stations().filter(func(n): return n != here and (Catalog.owns(s, "Helicopter") or Catalog.is_map_connected(here, n)))
	var t := int(s.visits)  # the next visit is turn t+1
	if route != null and t < OPENING_TURNS and t < route.size() and opts.has(route[t]):
		return route[t]
	var dice: float = Data.t("TAKE") + (float(Util.get_or(s, "tripDice", Util.get_or(s, "matBonusDice", 0))) if s.get("matChecked") else 1.0)
	var val := {}
	for n in _stations():
		val[n] = 0.0 if n == here else _station_value(n, dice)
	var scored := []
	for n in opts:
		var ahead := 0.0
		for m in _stations():
			if m != n and m != here:
				ahead = maxf(ahead, val[m] * pow(ROUTE_DECAY, _moves(n, m)))
		var v: float = val[n] + ahead + (0.6 if not s.visitedStations.has(n) else 0.0) + 0.8 * _trans_p(here, n)
		scored.append([n, v])
	scored.sort_custom(func(a, b): return a[1] > b[1])
	return scored[0][0] if randf() < 0.85 or scored.size() < 2 else scored[1][0]


# ---- the check's hand

## Mat space a card takes (tier 1 cards stack two to a slot).
static func _slots(n: String) -> float:
	var c = Catalog.mat_card(n)
	return 2.0 if Mat.is_capstone(c) else 0.5 if Mat.is_tier1(c) else 1.0


## Greedy: add the hand card that raises the score most per slot, while it
## beats `bar` per slot (up to HAND_PLAY_MAX). [names, gain]
func _best_play(h: Dictionary, base: float, bar: float) -> Array:
	var cur := []
	var total := base
	for k in int(Data.t("HAND_PLAY_MAX")):
		var best = null
		var best_t := 0.0
		var best_d := bar
		for n in h.hand:
			if cur.has(n):
				continue
			var sc = Hand.score_after(s, Game.ctx, cur + [n])
			if sc == null:
				continue
			var d: float = (sc.total - total) / _slots(n)
			if d > best_d:
				best = n
				best_t = sc.total
				best_d = d
		if best == null:
			break
		cur.append(best)
		total = best_t
	return [cur, total - base]


## Elements the bot will spend on draws: on the final check anything, else
## what's held beyond the wanted items' reserve.
func _draw_syms(h: Dictionary, final: bool) -> Array:
	var keep := {} if final else _reserve()
	return s.elements.keys().filter(func(sym): return Catalog.count(s, sym) - keep.get(sym, 0) >= 1 and Hand.suit_card(h, sym) != "")


## Plays the dealt hand like a player: plays worth their mat space, discards
## the weak cards while discards last, draws with spare elements, until
## nothing more fits.
func _play_hand(final: bool) -> void:
	Game.deal_hand()
	var h: Dictionary = s.hand
	for guard in 80:
		if Hand.mat_full(h, s):
			break
		var now: Dictionary = Game.mat_score()
		var cards: Array = h.hand + h.deck
		var dens := 0.0
		for n in cards:
			dens += Catalog.mat_card(n).points / _slots(n)
		var bar: float = PLAY_BAR * dens / maxf(1, cards.size()) * now.mult
		var can_improve: bool = (h.tosses > 0 and not h.deck.is_empty()) or (h.hand.size() < Hand.most() and not _draw_syms(h, final).is_empty())
		var play: Array = _best_play(h, now.total, bar if can_improve else 0.0)
		if not play[0].is_empty():
			Hand.play(h, s, play[0])
			continue
		if h.tosses > 0 and not h.deck.is_empty():
			# The weakest cards out: those that don't fit, then the lowest per slot.
			var ranked: Array = h.hand.map(func(n):
				var g = Hand.gain(s, Game.ctx, [n], now.total)
				return [n, -1e9 if g == null else g / _slots(n)])
			ranked.sort_custom(func(a, b): return a[1] < b[1])
			var out := ranked.filter(func(r): return r[1] < bar).slice(0, int(Data.t("HAND_DISCARD_MAX"))).map(func(r): return r[0])
			if not out.is_empty() and Hand.discard(h, out) == "":
				continue
		var syms := _draw_syms(h, final)
		if h.hand.size() < Hand.most() and not syms.is_empty():
			syms.sort_custom(func(a, b): return Catalog.count(s, a) > Catalog.count(s, b))
			if Hand.suit_draw(h, s, syms[0]) == "":
				continue
		# Nothing better coming: whatever still fits goes on.
		var rest: Array = _best_play(h, now.total, -1e9)
		if rest[0].is_empty() or Hand.play(h, s, rest[0]) != "":
			break


# ---- one run

func _play_run() -> Dictionary:
	var stations := _stations()
	var yours := openings.keys()
	var start: String = yours[randi() % yours.size()] if not yours.is_empty() and randf() < 0.6 else stations[randi() % stations.size()]
	var book: Array = openings.get(start, [])
	route = book[randi() % book.size()] if not book.is_empty() else null
	Game.start_run(Catalog.station(start).capstone[1])
	s = Game.state
	goal = Catalog.station(start).capstone[1]
	_set_wants()
	var dice := []
	var tiers := []
	for guard in 60:
		if s.ended or s.get("runComplete"):
			break
		dice.append(Game.do_roll().size())
		var t0 := Time.get_ticks_msec()
		_shop()
		if verbose:
			print("visit %d shop %dms" % [s.visits, Time.get_ticks_msec() - t0])
		Game.go_map()
		if s.get("finalCheckPending"):
			_play_hand(true)
			Game.confirm_final_lock_in()
			break
		var dest := _choose_next()
		Game.ctx.selectedMapStation = dest
		if Catalog.is_mat_check_visit(s):
			Game.ctx.travelPromptFor = dest
			Game.start_check_order()
			var t1 := Time.get_ticks_msec()
			_play_hand(false)
			if verbose:
				print("check %d hand %dms score %d" % [s.visits, Time.get_ticks_msec() - t1, Game.mat_score().total])
			tiers.append(Orders.reward_for(Game.mat_score().total, Orders.check_round(s)))
			Game.confirm_lock_in()
		else:
			Game.quiet_check()
			Game.go_station(dest)
	return {"start": start, "capstones": Data.t("CAPSTONES").filter(func(c): return Catalog.owns(s, c)),
		"checks": s.checkLog.duplicate(true), "tiers": tiers, "dice": dice, "items": s.items.size(),
		"leftover": s.elements.duplicate(), "qLeft": int(Util.get_or(s, "emptyElements", 0))}
