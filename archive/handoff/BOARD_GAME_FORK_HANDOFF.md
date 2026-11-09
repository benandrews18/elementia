# Elementia — Board Game Fork Handoff

*Written for a fresh Claude Code chat starting the physical-board-game fork
described by `images/board game view.png`. Verified against the actual repo
state on 2026-09-03 — every claim below was checked against real files in
this session, not carried over from older docs (see §2, which explains why
that distinction matters here).*

## 1. What you're forking from

Elementia is currently a single-file digital browser game
(`game/elementia.html`) with three modes (Classic, Adventure/Hard, Zen),
built from one underlying content model: 8 stations, each selling a set of
items craftable from raw elements and other items, plus one capstone per
station. That underlying model — not the digital game's UI — is what a
board game needs, and it lives entirely in one file:

**`Elementia_Handoff/handoff/pdf_generation/build_guide.py`**

For each of the 8 stations it lists: name, theme color (`SUITS`, an 8-color
wheel — this is exactly the "station colour" already used for borders on
the digital game's Bingo card), its 6-element dice pool, and every item it
sells as `(emoji, name, tier, recipe_string, points)`. Tiers are
`MATERIAL` / `COMPONENT` / `CREATION` / `CAPSTONE` — this already matches
your mockup's "Tier I / II / III" decks plus a separate capstone row almost
exactly; CAPSTONE is tier IV in effect, just always exactly one per
station rather than a shuffled deck.

A `CONTENT_VERSION` string at the top (currently `"2026.08.16"`) is stamped
on every PDF, the digital game's Settings screen, and the Artifact link, so
any output in hand can be matched back to a point in time. `CHANGELOG.md`
at the repo root logs what changed at each version — worth skimming for
recent recipe/point tuning history.

**This file is still fully current and authoritative.** Nothing about the
digital game's growth has replaced or shadowed it — recipes, points, and
station rosters are edited here once and propagate everywhere (see §4).

## 2. Two docs in this folder are STALE — do not treat them as current

`HANDOFF.md` and `CURRENT_GAME_STATE.md`, sitting right next to this file,
are both leftovers from an early phase of the project (pre-Classic/Adventure
split). I checked them against the live `build_guide.py` while writing this
and they've drifted hard: `CURRENT_GAME_STATE.md` still shows a station
called "The Quarry" (now "The City," with a different recipe set) and a
different Robot/capstone lineup than what's live today; `HANDOFF.md`
references `TAKE=5` and a "Full Card Deck" pipeline that later got
superseded by a Classic-only convention (see §4). Neither is wrong to read
for historical design reasoning, but don't pull specific numbers, recipes,
or station names from either — read `build_guide.py` itself for anything
current.

## 3. Folder orientation

```
Elementia-v2/
├── build_all.py                  -- see §4, has a real gap right now
├── CHANGELOG.md                  -- content history, keyed to CONTENT_VERSION
├── game/
│   ├── elementia.html            -- the digital game (not what you're forking)
│   ├── build_game.py             -- syncs build_guide.py -> elementia.html
│   └── build_artifact.py         -- builds the Artifact-publish copy
├── images/                       -- see §5
└── Elementia_Handoff/
    ├── BOARD_GAME_FORK_HANDOFF.md -- this file
    ├── handoff/HANDOFF.md         -- STALE, see §2
    ├── handoff/CURRENT_GAME_STATE.md -- STALE, see §2
    ├── handoff/pdf_generation/
    │   ├── build_guide.py         -- THE source of truth, see §1
    │   ├── build_guide_classic.py / build_cards_classic.py
    │   ├── render_guide_classic.py / render_cards_classic.py
    │   │     -- the CURRENT, safe PDF pipeline (see §4)
    │   ├── build_cards_full.py, build_print_run.py, build_element_cards.py,
    │   │   build_item_reference.py, render.py, render_cards_full.py, ...
    │   │     -- older/parallel pipelines, unverified this session (see §4)
    │   └── build/                 -- generated HTML (gitignored working files)
    └── handoff/simulation/        -- reachability/completion-rate simulators,
                                       also read build_guide.py directly
```

## 4. Regenerating PDFs — what's actually safe to run

**Only run the Classic pipeline.** This project settled on Classic Mode's
item catalog (`CORE_SET` in `game/elementia.html`) as the one that should
ever get rendered to a physical guide or card deck — the full/non-Classic
catalog pipeline is legacy and should not be regenerated. If you change a
recipe or point value in `build_guide.py`, run exactly this, from the repo
root:

```bash
cd Elementia_Handoff/handoff/pdf_generation
python build_guide_classic.py     # -> build/guide_classic.html
python build_cards_classic.py     # -> build/classic_cards_*.html
python render_guide_classic.py    # -> Elementia_Classic_Station_Guide.pdf
python render_cards_classic.py    # -> Elementia_Classic_Card_Deck.pdf
```

Both PDFs land at the repo root. If the digital game also needs to reflect
the change, additionally run `python game/build_game.py` from the repo
root (add `--check` first to verify without writing).

**`build_all.py`, at the repo root, does NOT call the Classic scripts at
all** — its `PDF_STEPS` list only runs the old full-catalog pipeline
(`build_guide.py` → `render.py`, `build_cards_full.py`,
`build_print_run.py`, `build_element_cards.py`, `build_item_reference.py`
and their renders/checks). That's a real inconsistency I found while
writing this doc, not something I fixed — it means `build_all.py` is out of
sync with the Classic-only convention above. **Don't run it expecting it to
produce what you actually want; use the four-command block above instead.**
Whether those other scripts (full card deck, print-run, element cards, item
reference) are still useful for THIS fork is genuinely unverified this
session — sanity-check their output before relying on any of it, especially
for element cards, which could be directly relevant to your mockup's "Held
Elements" component.

## 5. Art: how images actually work in this game

This is the part you were right to be suspicious of. The `emoji` field in
`build_guide.py` is a **lookup key**, not literal art — nothing in the
digital game renders a raw Unicode emoji glyph from the system font. Every
icon, plain-emoji or custom, goes through one function (`em()` in
`elementia.html`) that resolves the key to an embedded image:

- Plain emoji characters (the vast majority, e.g. `"💧"`, `"🍞"`) resolve
  through `NOTO_ICONS`, a big lookup table mapping ~130 emoji characters to
  bundled Noto-style raster images, for consistent cross-platform
  rendering. These are a generic, reusable icon set — not bespoke to any
  one item.
- A smaller set of items use a `__TOKEN__` placeholder instead of an emoji
  (e.g. `__WHEEL__`, `__CONCRETE__`, `__GOLEM__`) and resolve through
  `CUSTOM_ICONS`, which maps each token to **bespoke art** — some inline
  base64 PNGs, some hand-drawn inline SVGs. These are the ones that matter
  most for card art, since they represent a deliberate custom-illustration
  choice, not a generic emoji substitution.

I cross-referenced every `CUSTOM_ICONS` token against the `images/` folder.
Columns: token → item name → art format in the live game → status in
`images/`.

| Token | Item | Format in-game | `images/` file |
|---|---|---|---|
| `__WHEEL__` | Wheel | PNG | `wheel.png` ✅ |
| `__FURNACE__` | Furnace | PNG | `furnace-2.png` ✅ |
| `__OVEN__` | Oven | PNG | `oven-2.png` ✅ |
| `__BANANABREAD__` | Banana Bread | PNG | `banana bread.png` ✅ |
| `__TURBINEBLADE__` | Turbine Blade | PNG | `turbine.png` ✅ |
| `__STEEL__` | Steel | PNG | `steel.png` ✅ |
| `__FOSSIL__` | Fossil | PNG | `fossil.png` ✅ |
| `__CONCRETE__` | Concrete | PNG | `concrete.png` ✅ |
| `__FIBERGLASS__` | Fiberglass | PNG | `fiberglass.png` ✅ |
| `__LOGCABIN__` | Log Cabin | PNG | `log cabin.png` ✅ |
| `__GOLEM__` | Golem | PNG | `Golem.png` ✅ |
| `__MICROCHIP__` | Microchip | PNG | `microchip.png` ✅ |
| `__LIFE__` | Life | PNG | `Life.png` ✅ |
| `__ECOSYSTEM__` | Ecosystem | PNG | `Ecosystem.png` / `Ecosystem (1).png` ✅ |
| `__GEMCOLLECTION__` | Gemstone Collection | PNG | `Gemstone Collection.png` / `(1)` ✅ |
| `__PEARL__` | Pearl | PNG | `Pearl (1).png` ✅ |
| `__RUBY__` | Ruby | PNG | `Ruby (1).png` ✅ |
| `__OPAL__` | Opal | PNG | `Opal (1).png` ✅ |
| `__TURQUOISE__` | Turquoise | PNG | `Turquoise (1).png` ✅ |
| `__AMBER__` | Amber | PNG | `Amber (1).png` ✅ |
| `__DIAMOND__` | Diamond | PNG | `Diamond (1).png` ✅ |
| `🔘` (literal key) | Rubber Tire | PNG | `Rubber Tire.png` ✅ |
| `__RUBBER__` | Rubber | inline SVG | `rubber.png` exists but **unverified match** — the live render is a drawn SVG, not this file; compare before using ⚠️ |
| `__DYEYELLOW__` / `__DYERED__` / `__DYEBLUE__` / `__DYEBLACK__` | 4 dye colors | PNG | all 4 share **one sprite sheet**, `vials of dye-1.png` — no per-color file; the digital game slices it with CSS `background-position` ⚠️ |
| `__ORCA__` | Orca | inline SVG | `Orca.png` exists — **unverified match**, likely separate reference art ⚠️ |
| `__CORAL__` | Coral Reef | inline SVG | `Coral Reef.png` exists — **unverified match** ⚠️ |
| `__FLOUR__` | Flour | inline SVG | `Flour.png` exists — **unverified match** ⚠️ |
| `__LIGHTHOUSE__` | Lighthouse | inline SVG | no file found ❌ |
| `__TUNNEL__` | (tunnel, no single item name) | inline SVG | no file found ❌ |
| `__ALCAN__` | (aluminum can) | inline SVG | no file found ❌ |
| `__BRASSBAR__` | Brass | inline SVG | no file found ❌ |
| `__MARKETPLACE__` | (UI icon, not an item) | PNG | not relevant to cards |

**Practical guidance:** for anything marked ✅, the `images/` file is a
real, standalone asset you can likely use directly for card art. For ⚠️
items, a similarly-named file exists but I haven't visually diffed it
against what the live game actually renders — open the Artifact link (or
run `game/elementia.html` locally) and eyeball the item next to the file
before trusting it's the same art. For ❌ items, there's no standalone
file at all — the only rendering is inline SVG source inside
`elementia.html` itself (search for the token's paired `_SVG` constant,
e.g. `LIGHTHOUSE_SVG`), which would need to be exported to an image file
first if you want it as print-ready card art.

One more honest caveat: `images/` itself isn't guaranteed clean — it has
duplicate-looking numbered files (`Diamond (1).png` alongside implied
originals) and at least one file for a station name that no longer exists
(`The Quarry.png` — see §2, that station is now "The City"). Don't assume
every file in there is current or singular; check before use.

## 6. The mockup

`images/board game view.png` is the layout target. Notably, several of its
sections already map to existing systems rather than needing new ones:

- **Capstone Cards row** ↔ one card per station's `CAPSTONE`-tier entry in
  `build_guide.py`.
- **Tier Decks I/II/III** ↔ `MATERIAL` / `COMPONENT` / `CREATION` tiers.
- **Held Elements** ↔ the element set already covered by
  `build_element_cards.py`'s pipeline (unverified currency, see §4).
- **BINGO Card** ↔ the digital game's own Classic-Mode Bingo card
  (`bingoCardHTML()` in `elementia.html`) — same underlying idea
  (5×5 of core items ≥5 points each), already tuned and playtested there.
  Worth looking at directly for a starting point rather than designing a
  physical Bingo card's rules from scratch.
- **Board layout** (8 stations + connections) ↔ `MAP_ADJ` / `MAP_NODE_POS`
  in `elementia.html` already encode which stations connect to which and
  roughly where they sit.

## 7. Suggested first steps for a new chat

1. Read this file, then read `build_guide.py` directly (it's not long) to
   get the real, current 8-station catalog rather than trusting a summary.
2. Open `images/board game view.png` and this repo's `elementia.html`
   Bingo card side by side — decide how much of the digital Bingo
   mechanic (scoring, tier eligibility) should just be reused vs. reworked
   for physical play.
3. Before touching any art, resolve the ⚠️/❌ rows in §5's table — decide
   per-item whether to export the inline SVGs, re-source new art, or
   accept the existing PNGs after a visual check.
4. If any recipe/point/station change is needed for the physical version,
   decide up front whether it should also change `build_guide.py` (and
   thus flow back into the digital game) or stay fork-only — that's a real
   fork-vs-shared-source decision this doc deliberately leaves to you.
