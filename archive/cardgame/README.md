# Elementia — Solitaire

A solo card game prototype built on the Elementia item deck. Open
`cardgame/index.html` in a browser. No server, no build step.

It reuses the board game's art bundle rather than duplicating 2.8 MB, so
run `python boardgame/build_board.py` at least once first.

## The shape of a round

Gwent-style, not Balatro-style: your **element store** is your mana, and
every element in it is in play and untapped from the moment the round
begins. No ramp, no land drops — you have it all up front, and how you
spend it is the game.

1. **Play** item cards from your hand by tapping store elements matching
   the **suit pips** printed on the card. Elements of a suit are
   interchangeable, so payment is automatic — the only real decision is
   which card to play.
2. **25 of the 79 items cost nothing** and are always free to play. They
   score points without touching your store, and they pay no pips, so
   they never contribute to a flush.
3. Your hand holds at most **10 cards and never refills** as you play.
   What you were dealt is the round's resource.
4. **Mulligans**: one *opening* mulligan, usable only before you play your
   first card and lost if you don't take it, plus **2 more** to spend
   whenever. Either swaps any number of cards, one for one.
5. The round **ends when nothing in hand can be paid for** and no
   mulligans remain — or whenever you call it.
6. Only then are **flushes** counted and the total multiplied.

During play the running number is simply the points on the table. Flushes
are not folded in until the round is scored.

Final score = `points played × (1 + every flush bonus)`.

### Flushes

Every pip you actually paid is counted by suit at end of round. Each suit
that stacks high enough adds to one shared multiplier, so one deep flush
and three shallow ones are worth the same:

| Pips of one suit | Mult |
|---|---|
| 3+ | +1 |
| 5+ | +2 |
| 7+ | +3 |
| 10+ | +5 |

Repeated pips count once each — Coral Reef is three organic on its own.

## The loop

The store is **the element pool you bring in from the board game** — the
elements you rolled at stations are the mana you spend here — and the
**Station Points** you win go back the other way, spendable at a station
in place of rolling dice.

That seam is already in the code: `storeFromElements(counts)` takes a
plain `{symbol: count}` map, which is exactly the shape the board game
keeps its held elements in (`player.elements`). Wiring the two together is
a matter of handing that object across. Standalone play seeds one at
random via `randomElementCounts()`.

## Run mode — playing the recorded 20-round run

`New Run` offers two modes.

**Recorded run** plays the 20-round run in `run_reconstruction.md`, one
round at a time. Each round hands you:

- the **element store** that run actually held at that point, and
- a **deck of exactly the cards crafted by then** — nothing you hadn't
  built yet.

The deck grows 0 → 1 → 4 → … → 69 cards across the run, and the store
swings from 6 tokens (round 1, Deep Mine) to 33 (round 11). The station
that supplied the mana is shown next to the round number.

Missing a target **records the round and carries on** rather than ending
the run, so all 20 rounds can actually be played and replayed. A summary
table at the end lists every round's deck size, mana, cards played, base
points, multiplier, score and target.

**Free play** shuffles the whole 79-card deck against a random store and
ends when you miss a target, as before.

### Targets in run mode come from par

The free-play ante curve is meaningless against a run whose deck starts
empty and whose mana is whatever that round happened to hold — measured, it
clears **0 of 20**. So a run round sets its own target: the game plays the
round itself with a greedy pass over that same hand, store and deck, and
the target is **70% of that par**. Par is shown next to the target.

That makes every round a fair fight regardless of what the run brought, and
gives you something concrete to beat — mostly by holding out for a flush
where the greedy line just takes points as they come. Targets land between
0 (round 1, no deck) and 105.

Two knobs at the top of `cards.js`:

- `RUN_POOL_FIELD` — `"pool"` (default) uses the pool held once that
  round's dice were in; `"carried"` uses the pool as the round opened,
  before rolling.
- `DECK_THROUGH_CURRENT` — include the current round's own crafts in the
  deck (default), or draw only from what existed before it.

Regenerate `run.js` after editing the log in `reconstruct_run.py`:

```bash
python cardgame/reconstruct_run.py --emit-js
```

Delete `run.js` (or its `<script>` tag) and the game falls back to free
play only.

## Where the suits come from

`cardgame/classic set suits 0904.csv` is the authority: a per-slot suit
list, 0–3 suits per item with repeats allowed. It is cross-checked against
`elementia.html`'s `ITEM_SUIT_COST_TABLE` on every build, which prints a
warning if the two drift — the CSV wins.

The older one-suit-per-item CSV is still emitted as `suit` on every card
but is **not used for play**. Worth keeping in mind why: the pip model is
far better balanced.

| model | organic | reactive | earth | metal |
|---|---|---|---|---|
| single suit | 28 | **6** | 15 | 30 |
| suit pips | 26 | **21** | 20 | 27 |

Neither is `elementia.html`'s `itemSuitOf()`, which derives a suit
algorithmically from a recipe — 32 of the 79 disagree with that.

## Specified vs invented

**From the brief:** the store as always-in-play mana; tapping by suit to
pay a card's printed cost; no-pip cards free; pips as set size; the
10-card hand cap; one opening mulligan plus two in-round; flushes totalled
after all cards are played; Station Points as the payout; black card
frames.

**Invented, every one a constant at the top of `cards.js`:** store size
and its growth, the flush thresholds and multipliers, the target curve,
and the Station Point formula. Plus one structural call worth arguing
with — **the hand does not refill after you play**. The brief says the
round ends when you can make no more moves; with a refill that is nearly
unreachable, because the 25 free cards are always playable. A bot just
kept drawing and playing **26 of the 79 cards every round**.

## Balance

40 complete runs, greedy bot that chases points-per-pip and stacks suits:

| round | target | store | median score | cleared | mana left |
|---|---|---|---|---|---|
| 1 | 110 | 12 | 156 | 83% | 4.0 |
| 2 | 125 | 13 | 201 | 91% | 4.4 |
| 4 | 165 | 15 | 282 | 72% | 5.4 |
| 6 | 220 | 17 | 249 | 64% | 6.9 |
| 8 | 295 | 19 | 450 | 71% | 7.9 |
| 10 | 385 | 21 | 380 | 33% | 10.0 |

Runs reach a median of round 4 (max 12) and bank a median of 13 Station
Points.

**The 10-card cap sets a ceiling.** Score is bounded by how many cards you
can hold, so the target curve is deliberately shallow (×1.15 a round). An
earlier ×1.3 curve, tuned when the hand still grew, killed runs at median
round 3 while leftover mana climbed to 11.7 — the store was growing into a
hand that could not spend it. For the same reason store growth is now only
+1 a round, and leftover mana still drifts up to ~10 by round 10. If you
want the store to matter more later, the hand cap is what has to move.

## Open questions

1. **Should free cards be quite this good?** 25 cards that cost nothing
   and score 2–4 points each are a reliable floor with no decision
   attached. They pay no pips (as specified), so they are pure points.
2. **Nothing carries between rounds** except Station Points and the
   slowly growing store. No upgrades, no deck-building — the biggest
   missing lever if you want a run to develop a character.
3. **The curated single-suit CSV is unused.** If the real-world suit
   should mean something — flavour, a bonus, a second flush axis — it is
   already on every card as `suit`.

## UI

Portrait-first, built for a Pixel 9a held upright (414 x 875 CSS px). The
whole game is one phone-shaped column that never scrolls -- hand, element
store and score are all on screen together, because the only question the
game asks is "can I pay for this?" and that needs both halves visible. On
a desktop the column sits centred so it can be clicked with a mouse at
true size; short laptop windows trim the store, the most compressible zone.

Zone order is thumb-first, so the **hand is at the bottom**: payment is
automatic, an element is never tapped, and the store is a readout.

- **Element store** (`images/Card Game UI Reference.png`) -- one stack per
  suit, cards overlapping so the pool reads by depth. The number on an
  element card is its **atomic** number, never a quantity. Spent elements
  ride above the live ones, drained. The overlap step shrinks as a stack
  deepens, so the worst case in the recorded run (13 of one suit) still
  fits its zone.
- **Card face** (`images/Card Design Reference.png`) -- black frame, suit
  cost as a column down the **left edge**, points in a star top-right,
  art, name, then `Components` as icons only. The left-edge cost is
  load-bearing: the hand is fanned, so that strip is the only part of a
  buried card you can see, and cost is what decides playability.
- **The fan** doubles into **two rows above five cards**. One row of ten
  on a 414px screen leaves ~26px of each card showing -- enough for the
  cost column, not enough to tell which card it is, so nine of ten read as
  blank slabs. Two rows roughly double the visible slice and cost vertical
  space the hand zone had spare. Cards rotate about their own base;
  rotating about a point far below (the obvious way to draw a fan) swings
  the end cards ~50px sideways and off the screen.

Hovering a card lifts it clear of the fan to read in full.

## Display Mat prototype (mat.html)

A second, Bazaar-shaped take that removes the double-spend rather than
patching it: elements are spent once in the shop, and the item then earns
by sitting on an 8-slot **display mat** (2 rows of 4; a capstone takes 2).
No card is bought twice, and the solitaire half has no mana at all.

Score is `(points + collection bonuses) x combo multiplier`. Combos come
from cards sharing a **station**, a **suit**, or a **direct component**
(the card's own recipe, nothing further up the tree -- exactly the icon
strip printed along its bottom edge), counting
only the LARGEST group of each kind and only from three cards up.
Measured: summing every group from two up reaches x32 by round 14, since
eight cards carrying 2-5 components each throw off huge numbers of
incidental pairs. Largest-of-each-from-three gives x1 -> x17 over the run,
on a base that ramps 3 -> 100.

The mat confirms one thing outright: **no-suit cards leave the mat on
their own**. On the solver's best mat they go 8 (round 5) -> 5 (round 7)
-> 2 (rounds 8-11) -> **0 from round 13**. No rule needed.

### Collections

Hand-authored named sets of specific cards, not rules -- "five from one
station" is already what the combo multiplier pays for, so naming it too
would pay twice for the same arrangement. Nineteen of them, tuned so they
take most of a run: **8 cannot be completed before round 15**, 4 land in
rounds 10-14, and **7 cannot be finished in the recorded run at all**
(it never crafted Diamond, Rainbow or Ecosystem) -- which is where a run
gets its identity, the job the Bingo card used to do.

Completion requires every member **on the mat at once**, so a collection
competes for slots against raw points. Bonus is 30% of the set's own
points, the same rule `elementia.html` uses.

Note the digital game's own `COLLECTIONS` table is written against the
full catalogue: only 1 of its 10 (Alloys) is buildable from the Classic
79, which is exactly why that game hides collections from Classic Mode.
These are the Classic-legal rewrite.

### Screen

Portrait, one screen. Top to bottom: HUD, score, mat, collection, Travel.

**The canvas is a fixed 414 x 875** -- the Pixel 9a, in CSS px -- and the
whole phone is scaled to fit the window as one piece (`transform:scale`,
driven by `--fit` from `fitToWindow()`). Nothing reflows and nothing
stretches: every proportion is locked to every other, and resizing only
changes how big the phone is on your desk. Proportions authored against
`images/Mat Proportions UI 0906.png`; cards are **1.71** high by wide, and
a card is 0.227 of the screen width (the reference measures 0.228).

Measured at 412x870, 900x600, 1400x1000 and 500x400 -- a 3.5x range of
scale -- the mat card ratio, collection card ratio, card-to-screen and
mat-to-screen ratios are identical to four decimal places, and the phone
fits the window in every case.

Two things this replaced, both of which caused the stretching:

* **Card heights came from `100cqw`.** A container query unit in the
  container's *own* rule does not resolve against that container -- an
  element is never its own query container -- so it fell through to the
  small-viewport width. Card height was silently tracking the browser
  window rather than the mat. Sizes now come from `--canvas-w` in plain
  px, so they cannot depend on the viewport at all.
* **`.phone` sized itself to the viewport** (`min(100vw,414px)` /
  `min(100dvh,875px)`), letting width and height move independently, so
  the mat kept its width-derived card size while the height shrank
  underneath it.

The scale is driven by a `ResizeObserver` on the root element, not just
the `resize` event: that event does not fire for every way a viewport can
change (devtools docking, zoom, an embedded preview pane re-laying out),
and a missed one leaves the phone scaled for the previous window. The
collection's scrollbar is hidden rather than thin, because a visible bar
eats column width and would pull the collection cards off the mat's
proportions.

* **Score first.** It is the readout the rest of the screen serves, so it
  sits under the HUD where the eye lands, on one row: bonus icons packed
  left, the arithmetic right, flat on the felt rather than in a panel.
  Bonuses are icons -- the station's own art, the suit's own art, the
  shared component's own art -- so three live combos plus a collection
  still fit that one line.
* **Mat.** Always 2 rows of 4, drawn in full whether filled or not.
  **Drag a card** to re-arrange; the others shuffle aside as you go, and
  a placement that would force a capstone onto a third row is refused.
  Tap a mat card to take it off.
* **Cards** carry the point circle (top right), suit pips down the left
  edge so they survive any overlap, the station as **its own icon**
  rather than a colour dot, and the direct recipe as component art joined
  by `+`. Recipes of 4-5 parts step their art down to stay inside a
  single-width card; capstones are double-width and have the room.
* **Live bonuses.** Whichever station, suit and component are currently
  paying out are ringed in gold wherever their icon appears. On the mat
  that shows what the multiplier is actually made of; in the collection
  the same ring reads as "this card would join that group", which is the
  question you are answering every time you swap a card in. Ring only,
  never padding -- lighting a recipe up cannot re-flow a strip that was
  measured to fit.
* **Collection.** A 4-column grid -- capstones double-width there too, so
  their shape matches what they will cost. Filters for all 8 stations and
  4 suits (icon toggles, ORed within a group and ANDed across), a text
  search, and sorts by points / A-Z / station / suit.
* **Auto-fill.** While the collection is smaller than the mat there is no
  arrangement decision to make, so the mat fills itself. It stops on its
  own at round 6 of the recorded run, when the 10th card arrives.
* **Round 1 is the opening station.** The recorded run crafts nothing at
  Deep Mine -- you shop there, and the first card (Sand) is credited to
  round 2. So round 1 names itself: the button reads *Begin at Deep Mine*
  and the empty collection explains why it is empty, rather than showing
  eight empty slots under a *Travel* button as though the game had failed
  to start. A round with no craftable mat also pays the **full** roll (6
  dice), since par of 0 is trivially met.

If the page ever fails to start it now says so on the page, naming what
is missing, instead of leaving a blank screen with the reason in a
console nobody has open. The usual cause is a stale cache from opening
the file off disk -- `Ctrl+Shift+R`.

### Why the Travel button is pinned

Two independent bugs used to push it off the bottom, both looking
identical from the outside: the button flashes on first paint, then the
scripts fill the mat and collection and it is gone, with
`body{overflow:hidden}` making it unreachable.

1. **`dvh` with no fallback.** `height:min(100dvh,875px)` is dropped
   *entirely* by a browser that does not know `dvh` -- not just the unit,
   the whole declaration -- leaving `height:auto`, so `.phone` grew to
   696px inside a 554px window. Now `min(100vh,...)` is declared first
   and `min(100dvh,...)` second, so the cascade covers both.
2. **Short windows.** HUD + score + mat + foot are all fixed-height and
   together exceed a short viewport, so `.phone` clipped the foot.
   Everything between the HUD and the button now lives in `.stage`, the
   one band allowed to run out of room: it scrolls, and the button --
   a `flex:none` sibling of it -- cannot be displaced by any amount of
   content or any window height.

Measured after the fix at phone heights of 330, 420, 554 and 600px, and
at round 20 with all 69 cards: the button stays hit-testable in every
case. On a full-height phone nothing overflows and the collection still
scrolls inside itself, exactly as before.

Row heights are set explicitly rather than with `aspect-ratio`: a
two-wide capstone also swallows the 6px gap between its columns, so
`aspect-ratio` would stand it ~4px taller than the cards beside it. The
grids use `minmax(0,1fr)` because a card's min-content -- its recipe
strip and name -- is wider than a quarter of the screen.

### Dice

3 base at every station, +1/+2/+3 for reaching 45/70/90% of par. Early
rounds hand out the maximum for free and that is intended -- with 8 cards
and 8 slots you simply display everything, so par is trivially met. It
gets harder on its own as the collection grows: choosing 8 of 69 is a real
arrangement problem, so late rounds are where the dice are earned.

## Files

```
cardgame/
├── index.html        -- markup shell
├── cards.css         -- all styling
├── cards.js          -- rules engine + renderer (hand-written)
├── build_cards.py    -- regenerates data.js
├── reconstruct_run.py -- rebuilds the run log + run.js
├── classic set suits 0904.csv  -- suit authority (hand-maintained)
├── run_reconstruction.md -- GENERATED, the run written up
├── run.js            -- GENERATED, the run as game data
└── data.js           -- GENERATED
```

`build_cards.py` reads `build_guide.py` (names, points, tiers), the two
suit CSVs, and `elementia.html` (suit palette, suit symbol art, element
tables, plus the pip table it cross-checks against). Re-run it after any
content change:

```bash
python cardgame/build_cards.py
```
