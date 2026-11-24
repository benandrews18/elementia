## Card playing at a Display Mat check (PLAN.md, work queue 5; decisions
## 2026-11-22/23). The deck is every owned mat card not on the mat: the
## cards crafted since the last check first (the fresh side deck), then the
## rest, each part shuffled. A hand of 7; Draw adds 2, up to 10 held. A
## check has a budget: HAND_PLAYS plays and HAND_DISCARDS discards, and
## neither refills the hand (Draw does), so the deck can't be cycled
## through. A card played onto a mat card replaces it (the old one to the
## discards); mat cards leave no other way. Discards are out for the rest
## of the check. `h` is {deck, hand, discards, fresh, plays, tosses}
## (names, then the plays and discards left); `s` the run state (its mat).
## Taking control (2026-11-23): a Discard throws out up to
## HAND_DISCARD_MAX hand cards for one of the check's discards; a mat card
## can be discarded for free, any number of times; Take back (a mat card
## back into the hand) has its own budget, HAND_TAKEBACKS a check; draws
## paid from stock: 1 element draws a card with its suit's pip, 1 Unknown
## Element token draws any card the player picks. (Rehang and Frame are
## gone: the user, 2026-11-23, to feel out the base game first.)
class_name Hand

static func start() -> int:
	return int(Data.t("HAND_START"))


static func most() -> int:  # the most a hand holds
	return int(Data.t("HAND_MAX"))


## A fresh check: the fresh side deck on top, the rest under it, each
## shuffled (Rng, so tests can feed it); deal 7.
static func deal(s: Dictionary) -> Dictionary:
	var ok := func(n): return Catalog.mat_card(n) != null and not s.mat.has(n) and s.items.has(n)
	var fresh: Array = []
	for v in Util.get_or(s, "visitLog", []).slice(maxi(0, int(s.visits) - int(Data.t("MAT_CHECK_EVERY"))), int(s.visits)):
		for n in v.items:
			if ok.call(n) and not fresh.has(n):
				fresh.append(n)
	var rest: Array = s.items.filter(func(n): return ok.call(n) and not fresh.has(n))
	var h := {"deck": _shuffled(fresh) + _shuffled(rest), "hand": [], "discards": [], "fresh": fresh,
		"plays": int(Data.t("HAND_PLAYS")), "tosses": int(Data.t("HAND_DISCARDS")), "takebacks": int(Data.t("HAND_TAKEBACKS"))}
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


static func can_draw(h: Dictionary) -> bool:
	return h.hand.size() < most() and not h.deck.is_empty()


## Up to n (Draw's 2 by default) from the deck's top, never past the hand's
## most. Returns how many.
static func draw(h: Dictionary, n := -1) -> int:
	var k := mini(int(Data.t("HAND_DRAW")) if n < 0 else n, mini(most() - h.hand.size(), h.deck.size()))
	for i in k:
		h.hand.append(h.deck.pop_front())
	return k


## How many fresh cards are still in the deck.
static func fresh_left(h: Dictionary) -> int:
	return h.deck.filter(func(n): return h.fresh.has(n)).size()


## The mat after `name` goes onto a free slot (over == "") or over the mat
## card `over` (taking its place in the mat's order, so a same-size card
## lands in the same slot); or why it can't.
static func _after(s: Dictionary, name: String, over: String) -> Variant:
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
	return mat


## Plays `name` from the hand (see _after). Returns "" or why not.
static func play(h: Dictionary, s: Dictionary, name: String, over := "") -> String:
	if not h.hand.has(name):
		return "That card isn't in your hand."
	if h.plays <= 0:
		return "No plays left this check."
	var mat = _after(s, name, over)
	if mat is String:
		return mat
	s.mat = mat
	h.hand.erase(name)
	h.plays -= 1
	if over != "":
		h.discards.append(over)
	return ""


## What playing `name` there would do to the mat's score, or null if it
## can't go there (the lifted card's preview). `base`: the mat's score now,
## if the caller has it (one preview per place: scored once, not each time).
static func gain(s: Dictionary, ctx: Dictionary, name: String, over := "", base := NAN) -> Variant:
	var mat = _after(s, name, over)
	if mat is String:
		return null
	var cards := func(m: Array): return m.map(func(n): return Catalog.mat_card(n)).filter(func(c): return c != null)
	if is_nan(base):
		base = Mat.score(cards.call(s.mat), s, ctx).total
	return Mat.score(cards.call(mat), s, ctx).total - base


## Discards up to HAND_DISCARD_MAX hand cards at once, for one discard.
static func discard(h: Dictionary, names: Array) -> String:
	if names.is_empty() or not names.all(func(n): return h.hand.has(n)):
		return "That card isn't in your hand."
	if names.size() > int(Data.t("HAND_DISCARD_MAX")):
		return "Discard up to %d cards at a time." % int(Data.t("HAND_DISCARD_MAX"))
	if h.tosses <= 0:
		return "No discards left this check."
	for n in names:
		h.hand.erase(n)
		h.discards.append(n)
	h.tosses -= 1
	return ""


## A mat card discarded: free, as often as you like (out for the check).
static func mat_discard(h: Dictionary, s: Dictionary, name: String) -> String:
	if not s.mat.has(name):
		return "That card isn't on the mat."
	s.mat.erase(name)
	h.discards.append(name)
	return ""


static func takebacks_left(h: Dictionary) -> int:
	return int(h.get("takebacks", Data.t("HAND_TAKEBACKS")))  # a check saved before they had their own budget


## Take back: a mat card into the hand (its own budget, HAND_TAKEBACKS).
static func take_back(h: Dictionary, s: Dictionary, name: String) -> String:
	if not s.mat.has(name):
		return "That card isn't on the mat."
	if takebacks_left(h) <= 0:
		return "No Take Backs left this check."
	if h.hand.size() >= most():
		return "Your hand is full."
	s.mat.erase(name)
	h.hand.append(name)
	h.takebacks = takebacks_left(h) - 1
	return ""


## The first card in the deck with this element's suit pip, for 1 of it.
static func suit_draw(h: Dictionary, s: Dictionary, sym: String) -> String:
	var suit: String = Data.t("ELEMENT_SUIT").get(sym, "")
	if Catalog.count(s, sym) < 1:
		return "You have no %s." % sym
	if h.hand.size() >= most():
		return "Your hand is full."
	var card := suit_card(h, sym)
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
