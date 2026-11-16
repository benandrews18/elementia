## Small helpers that make GDScript behave like the JS it's ported from
## (PLAN.md, "JS -> GDScript pitfalls").
class_name Util


## JS Math.round: halves round up (Godot's round() rounds them away from 0).
static func js_round(x: float) -> float:
	return floor(x + 0.5)


## JS Array.sort(cmp) is stable (ties keep their order); Godot's
## sort_custom isn't. cmp(a, b) returns a number like a JS comparator.
## Sorts a copy.
static func stable_sort(arr: Array, cmp: Callable) -> Array:
	var idx := range(arr.size())
	idx.sort_custom(func(i, j):
		var c: float = cmp.call(arr[i], arr[j])
		return c < 0 or (c == 0 and i < j))
	return idx.map(func(i): return arr[i])


## JS String(x) for the values orders use as keys ("collector:null").
static func js_str(x: Variant) -> String:
	return "null" if x == null else str(x)


## Value at key, or default when the key is missing or null (JS `x || d`
## for objects and `x ?? d`).
static func get_or(d: Dictionary, key: String, default: Variant) -> Variant:
	var v = d.get(key)
	return default if v == null else v


## JS n.toLocaleString() for whole numbers: 4000 -> "4,000".
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
