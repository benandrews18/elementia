# Elementia

A chemistry crafting game for kids, played on phones and tablets in
portrait mode. **Classic Mode is the only mode.**

**The game is the Godot 4 project in `godot/`** (since the cutover,
2026-11-21). Before any work, read `godot/PLAN.md` (current milestone, next
task, decisions) and update its log when done. `godot/EDITING.md` says how
to change things in the Godot editor.

Frozen history, never a reference to sync with: `game/` (the HTML
prototype, replaced on the website by the Godot web build),
`print/` (the printed cards; a future board game would be its own
project) and `archive/`.

## Source of truth

- `godot/data/game_data.json`: `DATA` (each station's dice, shop rows
  `[emoji, name, tier, recipe, points]`, capstone and unlock rows) and the
  plain rule tables (suit costs, Display Mat collections, challenges'
  numbers, ...). Tables built from them are computed (`Data.derive()`),
  never stored or copied into code.
- Item icons: a new emoji needs `python godot/tools/fetch_icons.py` (Noto
  images). Hand-made art: `godot/assets/icons/` + `icons.json`.
- Rules are code in `godot/core/` and `godot/game/` (no nodes, no drawing).
- A rule or data change must still load older saves (`Progress`).

## Checks

- `python godot/tools/check.py fast` after a change (add `--only <section>`
  for the play-test part that changed); `full` at the end of a step and
  before a release. It must print `ALL PASSED`.
- The rules lock (`godot/tests/goldens`, in git): a rule changed on purpose
  makes it fail; re-record with `parity.tscn -- --accept` and say why in the
  commit.

## Releases

- **Phone (the user's, Android):** `python godot/tools/phone.py` builds the
  release-signed APK and installs it over Wi-Fi (setup: PLAN.md "Phone
  builds"). The user's own phone: no need to ask.
- **Web (testers, iPhones):** the Godot web export is the website:
  `python godot/tools/web.py "What changed"`. Pushing to the site is
  publishing: ask the user first. Never push `master` to the
  site repo's `main`.
- Add a `CHANGELOG.md` entry for changes players see.

## Conventions

- Commit on `master`, one commit per logical change.
