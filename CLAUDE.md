# Elementia

A chemistry crafting game for kids, played on phones and tablets in
portrait mode. **Classic Mode is the only mode.** Plain HTML/CSS/JS, no
framework, no build step to play. See `game/README.md` for how the code
is laid out.

## Source of truth

The game is the source of truth for all content. Edit these, nothing else:

- `game/js/data.js`: dice per roll (`take`), content version, each
  station's dice, shop items and capstone (`[emoji, name, tier, recipe, points]`).
  Every row is in the game; to add or remove an item, add or remove its
  row. The block between the `__GAME_DATA_*__` markers must stay plain JSON.
- `game/js/model.js`: suit costs (`ITEM_SUIT_COST_TABLE`), element suits,
  visit limits and dice rules.
- Item icons: an emoji renders as a Noto image. After adding an item with a
  new emoji, run `python game/tools/fetch_noto_icons.py`. Hand-made art uses
  a `__NAME__` marker mapped in `CUSTOM_ICONS` (`js/render-helpers.js`).
- `game/js/mat-scoring.js`: Display Mat collections, combos, BINGO rules.

Nothing else holds a copy of game data. The print pipeline reads the game.
`archive/` is old experiments and stale data. Never use it as a reference
for current rules.

## Checks

- `node game/tools/run_smoke.mjs`: plays a short run in headless Chrome,
  then checks icons, recipes and key rules (suit costs, convert, BINGO
  redraw, loading an old save). Run it after any game change. It must
  print `PASS`. Add a rule check to `game/tools/smoke_classic.js` when you
  fix a rule bug.
- A project hook (`.claude/settings.json`) syntax-checks every .js/.mjs
  file right after Claude edits it.
- `python print/build_pdfs.py --html-only` after content changes, to
  confirm the print pipeline still reads the game data.

## Publishing (standard for every game update)

Every change to the game (anything under `game/` that players see) is
published as part of finishing the work, without waiting to be asked: once
it's committed and the smoke test passes, do all three steps below. Changes
to tooling, docs, `print/` or `archive/` alone don't need a publish. If the
smoke test or the push fails, stop and report it; don't publish a broken
build.

1. Website (https://benandrews18.github.io/elementia/):
   `python game/deploy.py "What changed"`. It runs the smoke test, builds
   `game/build/elementia_artifact.html`, copies it into `../elementia-site/`
   (a separate clone; this repo has no remote), commits there and pushes.
2. Shared link: publish that same build file with the Artifact tool to
   https://claude.ai/artifact/KCo6nrTYdJ6cRXPhJqu2ZV
3. Add a `CHANGELOG.md` entry. Bump `"version"` in `data.js` when content changed.

## Printing

`python print/build_pdfs.py` builds the Classic Station Guide, Card Deck
and Element Cards into `print/pdf/`. Only run it when asked to update the
PDFs. Classic only; there is no full/non-Classic guide anymore.

## Conventions

- `js/` files are classic scripts sharing one global scope, loaded in the
  order `elementia.html` lists them (see `game/README.md`).
- Saves live in localStorage under `elementia-save-v4-classic`. A rule or
  data change must still load older saves (see `loadAll()` in `js/state.js`).
- Commit on `master`. One commit per logical change.
