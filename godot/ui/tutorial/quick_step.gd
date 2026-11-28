## One step of Quick Rules (QuickRules): its words, where the card sits,
## what the step sets up on the screen, and what's spotlit. The steps are
## listed on ui/tutorial/quick_rules.tscn (edit them in the Inspector).
class_name QuickStep
extends Resource

## The card's words ([b]...[/b]: bold; {🌲}, {suit:organic}, {ui:market}:
## the game's picture of it, inline).
@export_multiline var say := ""
## Where the card sits: "middle", "high" (a little above the middle), "top"
## or "bottom" (just above the hub).
@export_enum("middle", "high", "top", "bottom") var place := "middle"
## What the step does as it starts, in order (QuickRules._act), e.g.
## "station:Old Growth Forest" (it bounces onto the map), "hub:home" (the
## hub, only its middle button), "slide:inv" (a side button rises in),
## "market" (the Market tray), "card:Ecosystem" (its big card).
@export var act: PackedStringArray
## What's spotlit (the rest dimmed), e.g. "market:stations", "cp:station".
@export var spot: PackedStringArray
## A picture under the words: "elements" (the 16 elements, by suit).
@export var extra := ""
