## Component gallery: item cards laid out like the HTML game's Inventory grid
## (renderMatResultsGrid(): tier 1 at half height, capstones 2 wide), for
## the side-by-side comparison (tools/compare.mjs builds the same page in
## the HTML game). Items come from --items <json file> ({tiers: [[names]]}).
extends Control

const PAD := 12.0
const GAP := 8.0
const SECTION_GAP := 14.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Tok.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var args := OS.get_cmdline_user_args()
	var i := args.find("--items")
	var tiers: Array = JSON.parse_string(FileAccess.get_file_as_string(args[i + 1])).tiers
	# .mat-results-grid: 4 columns, 8px gaps, rows 1.4x the column width.
	var w := 390.0 - 2 * PAD
	var col_w := (w - 3 * GAP) / 4
	var row_h := col_w * 1.4
	var y := PAD
	for names in tiers:
		var x := 0
		var t1: bool = Catalog.mat_card(names[0]).tier == "MATERIAL"
		var h := (row_h - 2) / 2 if t1 else row_h
		for n in names:
			var wide: bool = Catalog.mat_card(n).tier == "CAPSTONE"
			var span := 2 if wide else 1
			if x + span > 4:
				x = 0
				y += h + GAP
			var c := ItemCard.make(n, {"mini": t1, "wide": wide})
			c.position = Vector2(PAD + x * (col_w + GAP), y)
			c.size = Vector2(col_w * span + GAP * (span - 1), h)
			add_child(c)
			x += span
		y += h + SECTION_GAP
	# The Crafting Bench around an 80px-tall placeholder.
	var bench := BenchPanel.new()
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(0, 80)
	inner.set_meta("cmp", "bench:content")
	bench.add_child(inner)
	bench.position = Vector2(PAD, y)
	bench.size = Vector2(390 - 2 * PAD, 80 + 48)
	add_child(bench)
