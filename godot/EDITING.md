# Editing Elementia in Godot

How to change how the game looks in the Godot editor, without code.

## Before you start

1. Commit or tell Claude about any earlier edits (`git status` should be
   clean). Claude checks `git status` at the start of every session, so the
   two of you never overwrite each other.
2. Open the editor:
   ```
   "C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/benan/Documents/Elementia-v2/godot" -e
   ```

**Keys:**
- **F5** plays the whole game.
- **F6** plays only the scene you have open.
- **F8** stops.
- **Ctrl+S** saves; **Ctrl+Z** undoes.
- **W** is the move tool; **Q** goes back to selecting.

## Which file is which

**Screens** (`ui/screens/`):

| What you see | Scene |
|---|---|
| The map, and where each station sits | `map.tscn` |
| A station: the art, header, labels and shop heading | `station.tscn` |
| The Display Mat drawer and the item list | `display_mat.tscn` |

**Shell and trays:**

| What you see | Scene |
|---|---|
| The bottom bar: its buttons, the Home circle's faces | `ui/components/hub_bar.tscn` |
| The Quark bar along the top | `ui/components/quark_top_bar.tscn` |
| The To-Do List | `ui/overlays/todo_tray.tscn` |
| The Market | `ui/overlays/market_tray.tscn` |
| Convert | `ui/overlays/convert_tray.tscn` |

**Windows** (`ui/overlays/`):

| What you see | Scene |
|---|---|
| "Are you sure?" | `confirm.tscn` |
| End of the run | `end_game.tscn` |
| Bonus Dice | `lock_in_reward.tscn` |
| The challenge | `order_info.tscn` |
| The opening slides | `how_to_play.tscn` |
| Choose a capstone | `capstone_choice.tscn` |
| The pinning tip | `pin_tip.tscn` |
| Row complete | `row_reward.tscn` |
| "?" pick | `unknown_pick.tscn` |
| Element picker | `element_picker.tscn` |
| The roll | `roll_popup.tscn` |
| Suit-cost balloon | `suit_spend.tscn` |
| Craft from the Market | `market_craft.tscn` |

**Pieces.** An edit to one of these changes every copy in the game:

| Piece | Scene |
|---|---|
| Every item card | `ui/components/item_card.tscn` |
| The Crafting Bench's row | `ui/components/shop_row.tscn` |
| An element chip | `ui/pieces/element_chip.tscn` |
| A map station (its disc and ring colours on the top node) | `ui/pieces/map_node.tscn` |
| Every window's frame and title banner | `ui/pieces/parchment_window.tscn` |
| Green button | `ui/pieces/pill_button.tscn` |
| Tan button | `ui/pieces/parch_button.tscn` |

**Colours and fonts:**
- **A colour in one place:** select the node and change it in the Inspector (a label's Theme Overrides, a panel's style).
- **The dim behind every window**, and the lighter one behind the trays: `ui/pieces/dim.tscn` and `ui/pieces/scrim.tscn`. One edit changes them all.
- **A colour everywhere at once** (every scene and the code), e.g. the gold:
  ```
  python godot/tools/recolour.py "#e2b25a" "#f0c060" --dry-run
  ```
  This lists every file that uses it. Run it again without `--dry-run` to change them. Each copy keeps its own transparency. Re-open scenes in the editor afterwards.
- `ui/theme/tokens.tres`: the base colours the code draws with (rings, ticks, chips). They apply when the game starts, so press F5. To change one of them in the scenes too, use `recolour.py`.
- **Fonts:** `ui/theme/fonts/` has the Nunito weights.

## What's safe to change

- **Texts:** a label's Text in the Inspector. Words that depend on the game (a station's name, a count) are filled in by the game. Their wording sits on the scene's top node in the Inspector, like `start_text` "Start at %s" (keep the `%s` and `%d`).
- **Colours, fonts, font sizes:** a label's Theme Overrides.
- **Styles:** a panel's or button's Theme Overrides → Styles. Some looks change with the game's state, such as "can craft" against "owned", or pinned against not. Those are on the top node, e.g. `can_style` and `pin_on`.
- **Images:** a TextureRect's Texture. Drag one in from FileSystem.
- **Layout numbers:** on a screen's top node, e.g. the shop's `columns`, `gap` and `card_ratio`, or the mat's `side` and `cols_gap`.
- **Positions:** fixed things (map stations, labels, icons). Drag them with **W**.

## What the game overrides

- **Window position and width:** windows are centred and fitted to the phone. Their height comes from their content.
- **Button widths:** buttons fit their text.
- **Anything built from the data:** which cards, chips, squares and rows appear, and in what order.
- **Holders:** nodes named `Grid`, `Chips`, `Rows`, `Shop`, `Content` or `Items` start empty in the editor. The game fills them.
- **Still drawn in code:** the Quark Meter, combo chips, To-Do trees, Market squares, the shutter and the animations. Animations move to the editor in M8.

## What lives in the data instead

Items, recipes, points, stations' elements and shop items come from the HTML game (`game/js/data.js`) and are exported into Godot. Change them there, never in Godot.

## After a session

- **To keep your changes:** save, then `git -C "C:/Users/benan/Documents/Elementia-v2" commit -am "My edits in the Godot editor"`. The editor also adds `.uid` and `.import` files and may rewrite scenes; commit those too.
- **To throw everything away:** `git -C "C:/Users/benan/Documents/Elementia-v2" checkout -- godot`
- **If something you changed doesn't take,** tell Claude which node and setting: the code is probably overriding it.
