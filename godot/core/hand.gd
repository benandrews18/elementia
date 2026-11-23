## Card playing at a Display Mat check (PLAN.md, work queue 5; decisions
## 2026-11-22). The deck is every owned mat card not on the mat, shuffled
## at the check's start; a hand of 7; "Draw cards" adds 2, up to 10 held.
## A card played or discarded is replaced 1 for 1 from the deck. A card
## played onto a mat card replaces it (the old one to the discards); mat
## cards leave no other way. Discards are out for the rest of the check.
## `h` is {deck, hand, discards} (names); `s` the run state (its mat).
class_name Hand

static func start() -> int:
	return int(Data.t("HAND_START"))


static func most() -> int:  # the most a hand holds
	return int(Data.t("HAND_MAX"))


## A fresh check: shuffle the deck (Rng, so tests can feed it), deal 7.
static func deal(s: Dictionary) -> Dictionary:
	var deck: Array = s.items.filter(func(n): return Catalog.mat_card(n) != null and not s.mat.has(n))
	for i in range(deck.size() - 1, 0, -1):  # Fisher-Yates
		var j := int(floor(Rng.next() * (i + 1)))
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	var h := {"deck": deck, "hand": [], "discards": []}
	draw(h, start())
	return h


static func can_draw(h: Dictionary) -> bool:
	return h.hand.size() < most() and not h.deck.is_empty()


## Up to n (the "Draw cards" 2 by default) from the deck's top, never past
## the hand's most. Returns how many.
static func draw(h: Dictionary, n := -1) -> int:
	var k := mini(int(Data.t("HAND_DRAW")) if n < 0 else n, mini(most() - h.hand.size(), h.deck.size()))
	for i in k:
		h.hand.append(h.deck.pop_front())
	return k


## Plays `name` from the hand: onto a free slot (over == "") or over the mat
## card `over`, which takes its place in the mat's order (so a same-size
## card lands in the same slot). Returns "" or why not.
static func play(h: Dictionary, s: Dictionary, name: String, over := "") -> String:
	if not h.hand.has(name):
		return "That card isn't in your hand."
	var mat: Array = s.mat.duplicate()
	if over == "":
		mat.append(name)
	elif mat.has(over):
		mat[mat.find(over)] = name
	else:
		return "That card isn't on the mat."
	var card = Catalog.mat_card(name)
	if not Mat.fits(mat.map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null), Mat.stage(s)):
		return "A capstone needs two free slots." if card != null and Mat.is_capstone(card) else "There's no room for it there."
	s.mat = mat
	h.hand.erase(name)
	if over != "":
		h.discards.append(over)
	draw(h, 1)
	return ""


static func discard(h: Dictionary, name: String) -> bool:
	if not h.hand.has(name):
		return false
	h.hand.erase(name)
	h.discards.append(name)
	draw(h, 1)
	return true
