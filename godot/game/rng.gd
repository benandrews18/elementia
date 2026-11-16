## Every random number the rules use comes from here (PLAN.md,
## "Randomness"). Tests feed recorded numbers with feed(); otherwise it's
## Godot's own random. Visual effects use randf() directly, never this.
extends Node

var _fed: Array = []

func feed(numbers: Array) -> void:
	_fed = numbers.duplicate()

## Numbers fed but not used: a sign the port draws fewer than the JS does.
func leftover() -> int:
	return _fed.size()

## Like JS Math.random(): 0 <= r < 1.
func next() -> float:
	return _fed.pop_front() if not _fed.is_empty() else randf()

## Like JS pool[Math.floor(Math.random() * pool.length)].
func pick(pool: Array) -> Variant:
	return pool[int(floor(next() * pool.size()))] if not pool.is_empty() else null
