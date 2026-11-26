## Card playing at a Display Mat check (PLAN.md step 14, "the check
## reworked", the user 2026-11-23). The mat clears when the hand is dealt.
## The deck is every owned mat card: the cards crafted since the last check
## first (the fresh side deck), then the rest, each part shuffled. A hand of
## 7. A play is any number of picked hand cards, packed onto the mat
## automatically (Mat.pack; where a card sits never changes the score), as
## many plays as fit; "a card laid is a card played": nothing comes off the
## mat until the check ends, so a full mat ends it. Every card played or
## discarded is replaced 1 for 1 from the deck. HAND_DISCARDS discards of
## any number of cards, out for the rest of the check. Element
## draws grow the hand (up to HAND_MAX): 1 element draws a card with its
## suit's pip, 1 Unknown Element token any card. Each play's names go on
## s.matPlays: Mat.score counts what a play made by itself once more.
## `h` is {deck, hand, discards, fresh, tosses}; `s` the run state.
class_name Hand

static func start() -> int:
	return int(Data.t("HAND_START"))


static func most() -> int:  # the most a hand holds
	return int(Data.t("HAND_MAX"))


## A fresh check: the mat clears; the fresh side deck on top, the rest
## under it, each shuffled (Rng, so tests can feed it); deal 7.
static func deal(s: Dictionary) -> Dictionary:
	s.mat = []
	s.matPlays = []
	var ok := func(n): return Catalog.mat_card(n) != null and not Mat.is_capstone(Catalog.mat_card(n)) and s.items.has(n)  # capstones: always on
	var fresh: Array = []
	for v in Util.get_or(s, "visitLog", []).slice(maxi(0, int(s.visits) - int(Data.t("MAT_CHECK_EVERY"))), int(s.visits)):
		for n in v.items:
			if ok.call(n) and not fresh.has(n):
				fresh.append(n)
	var rest: Array = s.items.filter(func(n): return ok.call(n) and not fresh.has(n))
	var h := {"deck": _shuffled(fresh) + _shuffled(rest), "hand": [], "discards": [], "fresh": fresh,
		"tosses": int(Data.t("HAND_DISCARDS"))}
	draw(h, start())
	return h


static func _shuffled(a: Array) -> Array:
	var d := a.duplicate()
	for i in range(d.size() - 1, 0, -1):  # Fisher-Yates
		var j := int(floor(Rng.next() * (i + 1)))
		var t = d[i]
		d[i] = d[j]
		d[j] = t
	return d


## Up to n from the deck's top, never past the hand's most. Returns how many.
static func draw(h: Dictionary, n: int) -> int:
	var k := mini(n, mini(most() - h.hand.size(), h.deck.size()))
	for i in k:
		h.hand.append(h.deck.pop_front())
	return k


## How many fresh cards are still in the deck.
static func fresh_left(h: Dictionary) -> int:
	return h.deck.filter(func(n): return h.fresh.has(n)).size()


## The mat with `names` added, or why they don't fit.
static func _after(s: Dictionary, names: Array) -> Variant:
	var mat: Array = s.mat + names
	if Mat.fits(Mat.on_mat({"mat": mat, "items": s.items}), Mat.stage(s)):
		return mat
	return "There's no room for %s on the mat." % ("that" if names.size() == 1 else "all of those")


## Plays the picked hand cards onto the mat, then refills the hand 1 for 1.
## Returns "" or why not (nothing changes).
static func play(h: Dictionary, s: Dictionary, names: Array) -> String:
	if names.is_empty() or not names.all(func(n): return h.hand.has(n)):
		return "That card isn't in your hand."
	var mat = _after(s, names)
	if mat is String:
		return mat
	s.mat = mat
	s.matPlays = Util.get_or(s, "matPlays", []) + [names.duplicate()]
	for n in names:
		h.hand.erase(n)
	draw(h, names.size())
	return ""


## Do these cards fit on the mat now?
static func fits(s: Dictionary, names: Array) -> bool:
	return _after(s, names) is Array


## The mat's score (Mat.score()) once `names` are played, or null if they
## don't fit (the play preview's combos).
static func score_after(s: Dictionary, ctx: Dictionary, names: Array) -> Variant:
	var mat = _after(s, names)
	if mat is String:
		return null
	var after := s.duplicate()
	after.matPlays = Util.get_or(s, "matPlays", []) + [names]
	return Mat.score(Mat.on_mat({"mat": mat, "items": s.items}), after, ctx)


## What playing `names` would add to the mat's score, or null if they don't
## fit (the Play button's preview). `base`: the mat's score now, if known.
static func gain(s: Dictionary, ctx: Dictionary, names: Array, base := NAN) -> Variant:
	var sc = score_after(s, ctx, names)
	if sc == null:
		return null
	if is_nan(base):
		base = Mat.score(Mat.on_mat(s), s, ctx).total
	return sc.total - base


## Is the check over? Nothing in the hand or the deck fits on the mat.
static func mat_full(h: Dictionary, s: Dictionary) -> bool:
	return not (h.hand + h.deck).any(func(n): return fits(s, [n]))


## Discards any number of hand cards at once, for one discard.
static func discard(h: Dictionary, names: Array) -> String:
	if names.is_empty() or not names.all(func(n): return h.hand.has(n)):
		return "That card isn't in your hand."
	if h.tosses <= 0:
		return "No discards left this check."
	for n in names:
		h.hand.erase(n)
		h.discards.append(n)
	h.tosses -= 1
	draw(h, names.size())
	return ""


## How many element draws could be made now (the Draw button's badge): per
## suit, the elements held against the deck cards with its pip, plus the
## Unknown Elements; never more than the deck or the hand's room.
static func draws_left(h: Dictionary, s: Dictionary) -> int:
	var in_deck := {}
	for n in h.deck:
		var c = Catalog.mat_card(n)
		if c != null:
			for su in c.pips:
				in_deck[su] = in_deck.get(su, 0) + 1
	var held := {}
	for sym in Util.get_or(s, "elements", {}):
		var su: String = Data.t("ELEMENT_SUIT").get(sym, "")
		held[su] = held.get(su, 0) + int(s.elements[sym])
	var n := int(Util.get_or(s, "emptyElements", 0))
	for su in held:
		n += mini(held[su], in_deck.get(su, 0))
	return mini(n, mini(most() - h.hand.size(), h.deck.size()))


## A card with this element's suit pip from the deck, for 1 of it: `card`
## (the player's pick), or the deck's first.
static func suit_draw(h: Dictionary, s: Dictionary, sym: String, card := "") -> String:
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	if Catalog.count(s, sym) < 1:
		return "You have no %s." % sym
	if h.hand.size() >= most():
		return "Your hand is full."
	if card != "" and not suit_cards(h, sym).has(card):
		return "That card isn't in the deck."
	if card == "":
		card = suit_card(h, sym)
	if card == "":
		return "No %s cards left in the deck." % Data.t("ELEMENT_SUIT_LABEL").get(suit, suit)
	s.elements[sym] = Catalog.count(s, sym) - 1
	if s.elements[sym] <= 0:
		s.elements.erase(sym)
	h.deck.erase(card)
	h.hand.append(card)
	return ""


## The deck's first card with this element's suit pip ("" if none).
static func suit_card(h: Dictionary, sym: String) -> String:
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	for n in h.deck:
		var c = Catalog.mat_card(n)
		if c != null and c.pips.has(suit):
			return n
	return ""


## Every deck card with this element's suit pip (the draw's picker).
static func suit_cards(h: Dictionary, sym: String) -> Array:
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	return h.deck.filter(func(n): return Catalog.mat_card(n) != null and Catalog.mat_card(n).pips.has(suit))


## Any card from the deck, for 1 Unknown Element token.
static func pick_draw(h: Dictionary, s: Dictionary, name: String) -> String:
	if int(Util.get_or(s, "emptyElements", 0)) < 1:
		return "You have no Unknown Elements."
	if not h.deck.has(name):
		return "That card isn't in the deck."
	if h.hand.size() >= most():
		return "Your hand is full."
	s.emptyElements = int(s.emptyElements) - 1
	h.deck.erase(name)
	h.hand.append(name)
	return ""
