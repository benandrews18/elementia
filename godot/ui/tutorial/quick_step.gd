## One step of Quick Rules (QuickRules): its words, where the card sits,
## what the step sets up on the screen, and what's spotlit. The steps are
## listed on ui/tutorial/quick_rules.tscn (edit them in the Inspector).
class_name QuickStep
extends Resource

## The card's words ([b]...[/b]: bold; {🌲}, {suit:organic}, {ui:market}:
## the game's picture of it, inline).
@export_multiline var say := ""
## Professor Mouse's pose (a file in assets/mouse_qr, e.g. "props_hold_die");
## "": he points at the step's first spot (or calls out when there's none).
@export var mouse := ""
## A title over the words, its picture to the left (hub buttons' cards:
## e.g. title "Inventory", title_icon "ui:inventory").
@export var title := ""
## A badge on the card's top-left corner: "clock" (the turn clock at 24),
## "discard" (the mat's Discard button), or
## an icon key in a round badge (e.g. 🎯 for the challenges).
@export var corner := ""
@export var title_icon := ""
## Where the card sits: "middle", "high" (a little above the middle), "top",
## "bottom" (just above the hub; over it when the step spots nothing there),
## "hub" (just above the hub's bar), "above:<spot>" or "below:<spot>" (just
## above or under that spot, e.g. "above:map:The Ocean", "below:bench"),
## or "over:<spot>" (its foot resting on that spot's top edge).
@export var place := "middle"
## What the step does as it starts, in order (QuickRules._act), e.g.
## "station:Old Growth Forest" (it bounces onto the map), "hub:home" (the
## hub, only its middle button), "slide:inv" (a side button rises in),
## "market" (the Market tray), "card:Ecosystem" (its big card).
@export var act: PackedStringArray
## What's spotlit (the rest dimmed), e.g. "market:stations", "cp:station".
@export var spot: PackedStringArray
## A picture under the words: "elements" (the 16 elements, by suit),
## "meter" (a Quark Meter, partly filled), "pool" (the station's elements),
## "suits" (the four suits).
@export var extra := ""
## The card waits until ("": it shows at once): "mat" (the Display Mat's play or deal has
## finished), "reward" (the Lock In's Bonus Dice window is up), "arrive" (a
## station's cards are in), "roll" (the dice have landed), "gathered" (the
## roll's elements are in the Inventory), "crafted" (the craft has played),
## "reveal" (the map's new stations are in).
@export var wait := ""
## Spots where a real tap does what Next does (the user, 2026-11-27: at key
## moments, sparingly), e.g. "hub:home" (Roll, Gather), "craft:Sand".
@export var tap: PackedStringArray
