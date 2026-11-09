# Elementia

A chemistry crafting game for kids, played on phones and tablets in
portrait mode. **Classic Mode is the only mode.** Plain HTML/CSS/JS, no
framework, no build step to play. See `game/README.md` for how the code
is laid out.

## Source of truth

The game is the source of truth for all content. Edit these, nothing else:

- `game/js/data.js`: dice per roll (`take`), content version, each
  station's dice, shop items and capstone (`[emoji, name, tier, recipe, points]`).
  The block between the `__GAME_DATA_*__` markers must stay plain JSON.
- `game/js/model.js`: Classic item set (`CORE_SET`), suit costs
  (`ITEM_SUIT_COST_TABLE`), element suits, visit limits and dice rules.
- `game/js/mat-scoring.js`: Display Mat collections, combos, BINGO rules.

Nothing else holds a copy of game data. The print pipeline reads the game.
`archive/` is old experiments and stale data. Never use it as a reference
for current rules.

## Checks

- `node game/tools/run_smoke.mjs`: plays a short run in headless Chrome.
  Run it after any game change. It must print `PASS`.
- `node --check game/js/<file>.js` for a quick syntax check.
- `python print/build_pdfs.py --html-only` after content changes, to
  confirm the print pipeline still reads the game data.

## Publishing (only when asked)

1. `python game/build_artifact.py` → `game/build/elementia_artifact.html`
2. Shared link: publish that file to https://claude.ai/artifact/KCo6nrTYdJ6cRXPhJqu2ZV
3. Website (https://benandrews18.github.io/elementia/): copy it over
   `../elementia-site/index.html` (a separate clone), commit there,
   `git push origin main`. This repo has no remote.
4. Add a `CHANGELOG.md` entry. Bump `"version"` in `data.js` when content changed.

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
