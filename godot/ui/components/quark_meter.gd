## The Quark Meter line (quarkMeterLineHTML(), display-mat.css .qm-*): the
## Quark icon, four pill segments filling toward this round's breakpoints
## with a die (or the "?") at each, the breakpoint numbers above, and the
## running total in a gold bubble. Set it with show_score().
class_name QuarkMeter
extends Control

const LABELS_H := 12.0
const ROW_GAP := 3.0
const SEG_H := 14.0
const SEG_GAP := 6.0
const LINE_GAP := 8.0

var _icon: TextureRect
var _total: Label
var _segs: Array[Panel] = []
var _fills: Array[Panel] = []
var _breaks: Array[Control] = []
var _labels: Array[Label] = []
var _pct := [0.0, 0.0, 0.0, 0.0]
var _passed := 0


func _init() -> void:
	custom_minimum_size = Vector2(0, LABELS_H + ROW_GAP + SEG_H)
	mouse_filter = MOUSE_FILTER_PASS
	gui_input.connect(_on_tap)  # the Display Mat rules: what Quarks and the dice mean (step 27)
	_icon = Tok.icon("⚛️", 22)
	_icon.custom_minimum_size = Vector2(30, 22)  # the HTML glyph box is ~30px wide
	add_child(_icon)
	for i in 4:
		var seg := Panel.new()
		seg.add_theme_stylebox_override("panel", Tok.box(Tok.LINE, 6))
		seg.clip_contents = true
		seg.mouse_filter = MOUSE_FILTER_IGNORE
		seg.set_meta("cmp", "qm:seg%d" % i)
		var fill := Panel.new()
		fill.mouse_filter = MOUSE_FILTER_IGNORE
		seg.add_child(fill)
		add_child(seg)
		_segs.append(seg)
		_fills.append(fill)
	for i in 4:
		var lab := Tok.label("", 10, Tok.GOLD if i == 3 else Tok.INK2, 800)
		lab.set_meta("cmp", "qm:label%d" % i)
		add_child(lab)
		_labels.append(lab)
	for i in 4:
		var b := Panel.new()
		b.mouse_filter = MOUSE_FILTER_IGNORE
		b.size = Vector2(20, 20)
		if i < 3:
			var die := Tok.icon("🎲", 12)
			die.position = Vector2(4, 4)
			b.add_child(die)
		else:
			var q := Tok.label("?", 11, Tok.CARD_INK, 800)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			b.add_child(q)
		b.set_meta("cmp", "qm:break%d" % i)
		add_child(b)
		_breaks.append(b)
	_total = Tok.label("0", 15, Tok.GOLD, 900)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_total.add_theme_stylebox_override("normal", Tok.box(Tok.GOLD_SOFT, 999, 1.5, Tok.GOLD))
	_total.set_meta("cmp", "qm:total")
	add_child(_total)
	resized.connect(_layout)


## total: the mat's Quarks; tiers: {one, two, three, four} for this round.
func show_score(total: float, tiers: Dictionary) -> void:
	var bounds := [0.0, tiers.one, tiers.two, tiers.three, tiers.four]
	_passed = _reached(total, bounds)
	for i in 4:
		var lo: float = bounds[i]
		var hi: float = bounds[i + 1]
		_pct[i] = clampf((total - lo) / (hi - lo), 0, 1) if hi > lo else (1.0 if total >= lo else 0.0)
		var lit: bool = _pct[i] >= 1
		_fills[i].add_theme_stylebox_override("panel", Tok.box(Color(Tok.GOLD, 1.0 if lit else 0.55), 6, 0, Color.BLACK,
			4 if lit else 0, 0, Color(Tok.GOLD, 0.7)))
		_labels[i].text = Util.thousands(int(round(bounds[i + 1])))
		var on := _passed >= i + 1
		_breaks[i].add_theme_stylebox_override("panel", Tok.box(Tok.GOLD if on else Color.WHITE, 7, 3, Color.BLACK,
			4 if on else 2, 0 if on else 2, Color(Tok.GOLD, 0.85) if on else Color(0, 0, 0, 0.4)))
	_total.text = Util.thousands(int(total))
	_layout()


func total_label() -> Control:
	return _total


static func _reached(total: float, bounds: Array) -> int:
	var n := 0
	for i in range(1, 5):
		if total >= bounds[i]:
			n = i
	return n


## .qm-line: icon | meter (labels over segments) | total, bottoms aligned.
func _layout() -> void:
	var h := size.y
	var icon_sz := _icon.custom_minimum_size
	_icon.size = icon_sz
	_icon.position = Vector2(0, h - icon_sz.y + 3)  # margin-bottom:-3px
	# min-width 56px; padding 4px 10px; border 1.5px; line-height 1.1
	var tw := Tok.font(900).get_string_size(_total.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var tsz := Vector2(maxf(56, tw + 23), 15 * 1.1 + 8 + 3)
	_total.size = tsz
	_total.position = Vector2(size.x - tsz.x, h - tsz.y + 4)  # margin-bottom:-4px
	var x0 := icon_sz.x + LINE_GAP
	var w := size.x - x0 - tsz.x - LINE_GAP
	var seg_y := h - SEG_H
	var seg_w := (w - 3 * SEG_GAP) / 4
	for i in 4:
		_segs[i].position = Vector2(x0 + i * (seg_w + SEG_GAP), seg_y)
		_segs[i].size = Vector2(seg_w, SEG_H)
		_fills[i].position = Vector2.ZERO
		_fills[i].size = Vector2(seg_w * _pct[i], SEG_H)
	# Breakpoint icons at 25/50/75% and the "?" capping the right end.
	for i in 4:
		var cx := x0 + w * (i + 1) * 0.25
		_breaks[i].position = Vector2(cx - 10 if i < 3 else x0 + w - 15, seg_y + SEG_H / 2 - 10)
	for i in 4:
		var lsz := _labels[i].get_minimum_size()
		_labels[i].size = lsz
		var lx := x0 + w * (i + 1) * 0.25 - lsz.x / 2 if i < 3 else x0 + w - lsz.x
		_labels[i].position = Vector2(lx, seg_y - ROW_GAP - LABELS_H + (LABELS_H - lsz.y) / 2)
	# Long numbers on a narrow meter: the 75% one steps left of the end's.
	_labels[2].position.x = minf(_labels[2].position.x, _labels[3].position.x - 6 - _labels[2].size.x)


func _on_tap(ev: InputEvent) -> void:
	if not Tap.tap(ev) or App.current == null:
		return
	var p := get_parent()
	while p != null:  # in a window (the Bonus Dice), it's part of the story: no rules over it
		if p is ParchDialog or p is LockInReward:
			return
		p = p.get_parent()
	MatRules.show_on(App.current)
