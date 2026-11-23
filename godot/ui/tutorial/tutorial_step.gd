## One step of the first-play tutorial (Tutorial): what Professor Mouse
## says, what he points at, and what finishes the step. The steps are
## listed on ui/tutorial/tutorial.tscn (edit them in the Inspector).
class_name TutorialStep
extends Resource

## What Mouse says ([b]...[/b]: bold).
@export_multiline var say := ""
## His pose (assets/mouse/1-12.webp).
@export_range(1, 12) var pose := 2
## What's spotlit and tappable: "hub:<id>" (home, inv, jobs, market,
## codex), a cmp tag (exact, or a prefix ending in "*"), or "" (nothing).
@export var target := ""
## What moves on: "tap" (a tap on the target), "next" (Mouse's Next) or
## "wait" (only done_if: for a tap that takes a moment, like Travel's fade;
## moving on at the tap would feed the next step's dice too early).
@export_enum("tap", "next", "wait") var until := "tap"
## The game state this step leads to; once it holds, the step is done (and
## a resumed tutorial skips it). Tests, "|" between alternatives: rolled,
## collected, started, owns:<item>, has:<element>, from:<element>,
## panel:<name>, nopanel, screen:<map|station>, at:<station>,
## selected:<station>, check, settled, lifted, played, visit:<n>.
@export var done_if := ""
## The next roll's faces (element symbols), fed to the dice.
@export var dice: PackedStringArray
## Nothing locked: the player plays freely until done_if.
@export var free := false
