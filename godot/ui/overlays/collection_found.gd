## "New collection!" (maybeShowCollectionFound()): a named collection just
## completed on the mat (in a run, not Combo Lab): its card, and "🏆 Add to
## Collections" discovers it for good (a Star). The app opens it once nothing
## else is on screen, one at a time. The layout is
## ui/overlays/collection_found.tscn.
class_name CollectionFound
extends ParchDialog

const SCENE := "res://ui/overlays/collection_found.tscn"

var collection: Dictionary


static func show_on(on: Control, c: Dictionary) -> CollectionFound:
	var d: CollectionFound = load(SCENE).instantiate()
	d.collection = c
	d.size = on.size
	on.add_child(d)
	return d


func _ready() -> void:
	var card := ClueCard.make()
	card.fill(collection, collection.items, "", true, "New collection!", "+%d on your mat whenever it's all there" % int(collection.bonus))
	$Window/Content/CardHolder.add_child(card)
	$Window/Content/Add/Row/Icon.texture = Data.icon("🏆")
	$Window/Content/Add.gui_input.connect(func(ev): if Tap.tap(ev):
		close()
		Progress.discover_collection(collection.id))  # saves; the app then looks for the next one
	super()
