## How to Play's second window (#tutElements, renderTutElementsGrid()): the
## 16 elements by atomic number, each a white card ringed in its suit's
## colour (ui/pieces/tut_el_card.tscn), scrolling past 52% of the screen.
## The layout is ui/overlays/tut_elements.tscn.
class_name TutElements
extends ParchDialog

const SCENE := "res://ui/overlays/tut_elements.tscn"
const CARD := "res://ui/pieces/tut_el_card.tscn"

@export var max_list := 0.52  # of the screen's height (.tut-el-grid max-height:52vh)
@export var min_card := 90.0  # repeat(auto-fill, minmax(90px, 1fr))


func _ready() -> void:
	var an: Dictionary = Data.t("ATOMIC_NUMBER")
	var syms: Array = Util.stable_sort(Data.t("CORE_ELEMENT_SYMS"), func(a, b): return an[a] - an[b])
	var grid: GridContainer = $Window/Content/Scroll/Grid
	for sym in syms:
		var c: PanelContainer = load(CARD).instantiate()
		var box: StyleBoxFlat = c.get_theme_stylebox("panel").duplicate()
		box.border_color = Color(Data.t("ELEMENT_COLOR").get(sym, "#4a4f5c"))
		c.add_theme_stylebox_override("panel", box)
		c.get_node("Box/Num").text = str(int(an[sym]))
		c.get_node("Box/Sym").text = sym
		c.get_node("Box/Name").text = Data.t("ELEMENT_NAMES").get(sym, sym)
		grid.add_child(c)
	super()


## As many columns as fit at min_card wide; the list at most max_list tall.
func _layout() -> void:
	var grid: GridContainer = $Window/Content/Scroll/Grid
	var w: float = minf(max_width, size.x - 40) - 76
	grid.columns = maxi(1, floori((w + 10) / (min_card + 10)))
	var scroll: ScrollContainer = $Window/Content/Scroll
	scroll.custom_minimum_size.y = minf(grid.get_combined_minimum_size().y, size.y * max_list)
	super()
