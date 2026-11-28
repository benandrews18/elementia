## One of the later plays' hints (Hints): a 💡 on its target while its
## moment holds; a tap on it and Professor Mouse says it. Listed on
## ui/tutorial/hints.tscn (edit them in the Inspector).
class_name Hint
extends Resource

## Saved in prefs.hiddenTips by "Don't show again"; state.hintsSeen once a run.
@export var id := ""
## What Mouse says ([b]...[/b]: bold; {🔍}: an emoji's image).
@export_multiline var say := ""
## His pose (assets/mouse_qr/<name>.webp: the new poses, the user 2026-11-28).
@export var pose := "pointing_call_out"
## Where the 💡 goes: as a TutorialStep's target ("hub:<id>", a cmp tag,
## "x*" a prefix), or "tip:<tag>" for the meta "tip" (a craftable card).
@export var target := ""
## When it's out: Tutorial.met's tests, "&" all of, "|" either, "!" not.
@export var when := ""
