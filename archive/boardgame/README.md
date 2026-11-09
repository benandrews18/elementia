# Elementia — Board Game (digital tabletop)

A playable, rules-enforcing digital version of the physical board game laid
out in `images/Board Game View 2.png`. Open `boardgame/index.html` in a
browser — no server, no build step, no dependencies.

Every component from the mockup is here: the Capstone row, the map board
with its eight stations and their dice pools, the Tier I/II/III decks and
the Item Display they feed, Held Elements, Crafted Items, and the BINGO
card.

## Running it

Just open the file. It works straight off disk (`file://`) — the only
external asset is the map art, loaded from `game/backdrops/`, so keep the
folder where it is relative to `game/`.

Progress auto-saves to `localStorage` and is restored on reload. A save
written against a different `CONTENT_VERSION` is discarded rather than
loaded, so a content change can never half-break an in-flight board.

## Rules

**A turn**

1. **Move** to a station connected to yours by a dashed line. You may not
   stay put. The Ocean ↔ Observatory shortcut opens once you have stood at
   the Observatory; owning a **Helicopter** lets you fly anywhere.
2. **Roll** 6 dice. Each die shows one of that station's six elements, and
   only the rolling player collects them. Elements carry over between turns
   and are uncapped.
3. **Build** as many cards as you like from the face-up rows or the Capstone
   row. Any card can be built from anywhere — you need only its elements and
   its item ingredients; where you are standing does not restrict what you
   can craft. Elements are spent; item cards are not, so each keeps working
   as an ingredient forever. Every card bought is replaced from its deck at
   once.
4. **Convert** 3 of any one element into 1 of any other, at any point on
   your turn, as often as you like.
5. **Craft cost** — every card also burns element tokens *of any kind* on
   top of the elements its recipe names: **1** for Tier I, **2** for Tier
   II, **3** for Tier III, **none** for Capstones. They come off your
   deepest stack first. See below for why this exists.

The game ends once every player has taken **20 turns**, or early if all
eight capstones are claimed. Score = item points, +15 for visiting all
eight stations, +20 per completed Bingo line.

### Tiering

Cards are banded by **point value**, not by `build_guide.py`'s
`MATERIAL`/`COMPONENT`/`CREATION` field. The two disagree — the tier field
describes what an item *is*, the bands describe what it is *worth*, so e.g.
Tools (a `CREATION` worth 3) banks into Tier I.

| Tier | Points | Items |
|---|---|---|
| I | 1–4 | 25 |
| II | 5–10 | 28 |
| III | 11–19 | 18 |
| Capstone | 20+ | 8 |

The bands partition the Classic catalogue exactly: no regular item reaches
20, and every capstone is 20 or above, so the capstone row needs no band of
its own and nothing falls through the gaps.

**Deck copies.** Exactly **one of each capstone** exists — first to build it
keeps it. Other cards have several copies, scaled to the table:

| Tier | Copies of each | 1p | 2p | 3p | 4p |
|---|---|---|---|---|---|
| I | `seats` | 1 | 2 | 3 | 4 |
| II | `seats - 1` | 1 | 1 | 2 | 3 |
| III | `seats - 2` | 1 | 1 | 1 | 2 |

Face-up row widths are the mockup's 7 / 5 / 3.

### Restock — the one rule not in the spec

Clicking a tier deck bottom-decks its whole face-up row and deals a fresh
one, once per tier per turn. It is how you dig for a particular card rather
than waiting on the shuffle. To remove it, delete `restock()` and the deck
button — nothing else depends on it.

## Why element tokens need a craft cost

Element tokens are spent when used and item cards are not — that part works
exactly as intended, and always did. The problem is that the **recipes stop
asking for elements** almost immediately:

| Tier | Items | Element tokens the recipes name | Items naming **none** |
|---|---|---|---|
| I (1–4 pts) | 25 | **46** | 4 |
| II (5–10) | 28 | 10 | 22 |
| III (11–19) | 18 | 2 | 16 |
| Capstone (20+) | 8 | **0** | **8** |

**50 of the 79 items name no element at all**, the entire catalogue names
**58 tokens**, and a 20-turn game deals **120**. Every capstone is a pure
item-on-item combination. Elements gate the bottom row and nothing above it,
so a solo player used to finish holding 62 unspent tokens.

Cutting the dice does not fix it. Measured:

| variant | gathered | spent | **left over** | items built |
|---|---|---|---|---|
| no craft cost, 6 dice | 115 | 52 | **62** | 59.5 |
| no craft cost, 3 dice | 60 | 33 | **27** | 25 |
| no craft cost, 2 dice | 40 | 21 | **19** | 13.4 |
| **craft cost 1/2/3/0, 6 dice** | 120 | 117 | **3** | 39.6 |

At 3 or 2 dice a player *still* ends holding 19–27 tokens while the game
starves — the leftovers are the **wrong** elements. It is a matching
problem, not a quantity one, and conversion already solves matching. Only a
flat per-craft cost actually drains the pool.

`CRAFT_COST` in `board.js` is therefore **invented**, like Restock, and
flagged as such in the source. Set every value to `0` to remove it.

### Balance as shipped

Batches of 10 complete games, bot converts toward what it needs:

| | items (of 79) | capstones | leftover tokens | median score |
|---|---|---|---|---|
| solo | 39.6 | 0.5 | 2.7 | 256 |
| 2 players | 37.5 | 0.4 | 5.3 | 217 |
| 4 players | 38.3 | 1.3 | 3.7 | 219 |

Of 120 tokens gathered per player, 96–98% get spent — elements are now the
binding resource at every table size, which is what the rules intend.

Two caveats worth knowing:

- **Capstones remain hard** (0.4–1.3 per game) and **Bingo lines still do
  not complete**. The bot does not plan a route toward a specific capstone,
  so a deliberate human should beat these; but if you want them to be
  reliable goals, the levers are lowering `CRAFT_COST.III`, raising
  `TURN_LIMIT`, or drawing Bingo squares from reachable items rather than
  from everything worth 5+.
- The fee is auto-paid from your deepest stack. A physical game would let
  the player choose which tokens to hand back; that choice is rarely
  interesting and would need a picker on every craft, so it is automatic
  here.

## Where the content comes from

The fork owns **no content of its own**. `build_board.py` reads the two
existing authoritative sources and writes two generated bundles:

| Generated | Contains | Read from |
|---|---|---|
| `data.js` | `DATA` (stations, dice, recipes, points, suits), `CORE_SET`, `MAP_EDGES`, `MAP_NODE_POS`, the element tables | `build_guide.py` + `elementia.html` |
| `icons.js` | `ICONS` — every emoji/token key the board game can display, resolved to the bundled Noto rasters and bespoke art | `elementia.html` |

Regenerate after any upstream content change:

```bash
python boardgame/build_board.py
```

`--check` verifies without writing (exit 1 if stale). Both bundles are
committed so the game runs from a fresh clone; they are outputs, not
sources — edit `build_guide.py` instead.

## Art and card styling

Card chrome reproduces the printed Classic deck (`build_cards_classic.py`)
one for one: thick suit border, station and points badges straddling the
top corners, dashed divider, `MADE FROM`, `+`-separated ingredient pills.
Capstones use the wide 5.1 × 3.57in shape; every other item uses the
regular 2.5 × 3.5in playing-card shape.

Every dimension in the print stylesheet is quoted against a fixed physical
card, so each is restated here as that same fraction of the card's own
width in `cqw` units — which is why each card sits inside a `.cardbox`
container (container-query units resolve against an ancestor container,
never the element itself). Scale the box and the whole card scales with it,
print-accurate at any size.

Item art is byte-identical to the digital game's: the `emoji` field is a
lookup key, never a glyph. That sidesteps the ⚠️/❌ column of the fork
handoff doc's §5 art table entirely — no icon needs re-sourcing, because
the live art travels with the data.

**Stations** follow `images/Board Game View 2` (refining `Station Style 1`
and `Station Style 2`): the node is a large dark disc ringed in the
station's colour carrying only its icon, and the name lives on the
station's own plate — icon, name, `ELEMENTS FOUND HERE`, then six white
tiles bordered in each element's own suit colour with that element's die
face alongside.

The two side plates are that same plate turned a quarter-turn, and they
turn *opposite* ways so each one's label lands on the outer edge: the
Ocean's anticlockwise, so its faces read 6 at the top down to 1 with its
label reading bottom-to-top; the Observatory's clockwise, so its faces read
1 at the top down to 6 with its label reading top-to-bottom. Pips sit
inboard on both. Only the name label rotates with the plate — the element
letters stay upright.

The map is `game/backdrops/diamond_map_full.webp` rotated a quarter-turn
clockwise, which is what the mockup shows (ocean left, space right). The
board frame is locked to the art's exact inverse aspect ratio (1981:794) so
`MAP_NODE_POS`'s percentages stay pixel-accurate through the rotation.

## Multiplayer

The engine is multi-seat throughout — `state.players[]` plus an `active`
index, with every rule reading through `me()`. New Game offers 1–4 seats.
Solo is simply `players.length === 1`, which hides the seat bar and the
scoreboard's comparison rows.

Shared: the board, the three decks, the Item Display, and the Capstone row.
Per player: position, elements, built items, Bingo card and pins. The turn
counter advances only after every seat has played, so each player gets the
same 20 turns.

## Layout

Follows `images/Board Game View 2` top to bottom: the tier decks and their
face-up rows first (III down to I), the capstone row beneath them, then the
board.

Everything personal to one player — Held Elements, Crafted Items, the Bingo
card — lives in a **slide-up tray** docked to the bottom of the window. Its
handle stays on screen and doubles as a summary ("16 elements · 12 built"),
and clicking it slides the tray in and out.

Station plates sit *outside* `.map-frame`: the frame has to clip, since it
holds the quarter-turned art, but the plates straddle the map's top and
bottom edges into the board's padding the way View 2 shows them. `.map-wrap`
is the same box as the frame and does not clip, so their percentage
positions are unchanged and each plate clears its node by ~5%.

## Files

```
boardgame/
├── index.html        -- markup shell
├── board.css         -- all styling
├── board.js          -- rules engine + renderer (hand-written)
├── build_board.py    -- regenerates the two bundles below
├── data.js           -- GENERATED
└── icons.js          -- GENERATED (~2.8 MB of bundled art)
```
