## Rules parity (PLAN.md): replays every golden step recorded from the HTML
## game (tools/record_golden.mjs) through the Godot rules and compares.
##   Godot_console.exe --headless --path godot res://tests/parity.tscn
## Exit code 0 only when every step is ported and matches.
extends Node

const GOLDENS := "res://tests/goldens"
const SHOW_FAILS := 8

func _ready() -> void:
	Game.autosave = false
	var files := DirAccess.get_files_at(GOLDENS)
	if files.is_empty():
		print("No goldens: run node godot/tools/record_golden.mjs")
		get_tree().quit(1)
		return
	var passed := 0
	var failed := 0
	var not_ported := {}
	for f in files:
		var steps: Array = JSON.parse_string(FileAccess.get_file_as_string(GOLDENS + "/" + f))
		for i in steps.size():
			var step: Dictionary = steps[i]
			if step.fn == "__trophies":  # the trophies the HTML game awarded this run
				var got := Trophies.earned(step.before.state, step.before.prefs)
				var ids: Array = Trophies.all().map(func(t): return t.id)
				var d := "" if ids == step.allIds else "trophy ids differ: %s" % str(ids.filter(func(x): return not step.allIds.has(x)) + step.allIds.filter(func(x): return not ids.has(x)))
				if d == "" and got != step.earned:
					d = "earned %s, HTML game %s" % [got.filter(func(x): return not step.earned.has(x)), step.earned.filter(func(x): return not got.has(x))]
				if d == "":
					passed += 1
				else:
					failed += 1
					print("FAIL %s trophies: %s" % [f, d])
				continue
			var method: String = step.fn.to_snake_case()
			if not Game.has_method(method):
				not_ported[step.fn] = not_ported.get(step.fn, 0) + 1
				continue
			Game.load_snapshot(step.before)
			Rng.feed(step.rand)
			# craft(entry) was recorded as {entry: name}; Godot takes the name.
			Game.callv(method, step.args.map(func(a): return a.entry if a is Dictionary and a.has("entry") else a))
			var d := diff(Game.snapshot(), step.after, "")
			if d == "" and Rng.leftover() > 0:
				d = "%d random numbers left unused" % Rng.leftover()
			if d == "":
				passed += 1
			else:
				failed += 1
				if failed <= SHOW_FAILS:
					print("FAIL %s step %d %s(%s): %s" % [f, i, step.fn, JSON.stringify(step.args), d])
	var total: int = passed + failed + not_ported.values().reduce(func(a, b): return a + b, 0)
	print("parity: %d/%d steps match, %d differ" % [passed, total, failed])
	if not not_ported.is_empty():
		print("not ported yet: " + ", ".join(not_ported.keys().map(func(k): return "%s %d" % [k, not_ported[k]])))
	get_tree().quit(0 if passed == total else 1)

## First difference between two JSON values as "path: a != b", or "".
## 3 and 3.0 are equal (Godot's JSON makes every number a float).
static func diff(a: Variant, b: Variant, path: String) -> String:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return "" if absf(float(a) - float(b)) < 1e-9 else "%s: %s != %s" % [path, a, b]
	if typeof(a) != typeof(b):
		return "%s: %s != %s" % [path, JSON.stringify(a).left(80), JSON.stringify(b).left(80)]
	if a is Dictionary:
		for k in a:
			if not b.has(k):
				return "%s.%s: only in Godot" % [path, k]
			var d := diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		for k in b:
			if not a.has(k):
				return "%s.%s: missing in Godot" % [path, k]
		return ""
	if a is Array:
		if a.size() != b.size():
			return "%s: length %d != %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	return "" if a == b else "%s: %s != %s" % [path, a, b]
