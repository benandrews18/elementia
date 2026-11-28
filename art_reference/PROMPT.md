# Re-drawing Elementia's art as a crafting card game

Two reference sheets, made from the game's own images (`python godot/tools/art_sheet.py` rebuilds them):

- `items.png`: all 100 items, by tier (27 materials, 34 components, 31 creations, 8 capstones).
- `icons.png`: the icons on and around the cards (suits, stations, the card game's buttons, points, Quarks, dice, the Unknown Element, pin, track, the hub).

Generate in batches of about 10 to 16 items, attaching `items.png` (or a crop of the row you want) and `icons.png` as references every time, with the same style paragraph. Keep one finished image from the first batch and attach it to every later batch as the style anchor.

## Style paragraph (the same every time)

```
Redraw each item from the attached reference sheet as a single game icon for a cozy, kid-friendly crafting card game about chemistry and exploration. Keep each item instantly recognisable as the same object shown in the reference (same silhouette, same main colours, same viewing angle), but render it in one consistent card-game illustration style: chunky, slightly rounded shapes; a confident dark outline (about 3% of the icon's width) all around the silhouette; flat base colours with one soft cel-shaded shadow tone and one small highlight; a gentle warm light from the top left; no background, no ground shadow, no text, no frames. Each object is centred, fills about 85% of a square canvas, and reads clearly at 48 pixels. Materials (tier 1) are simple single objects; components (tier 2) a little more detailed; creations (tier 3) richer; capstones (the 8 biggest items) the most detailed and celebratory, with a subtle golden glow. Output each item as its own square image on a transparent background, named exactly as labelled in the reference.
```

## Batch request (change the list each time)

```
This batch: Aluminum Alloy, Battery, Bone, Brass, Clay, Concrete, DNA, Fabric, Fertilizer, Fireworks, Furnace, Glass, Limestone, Magnet, Natural Gas, Plant Fiber.
```

Suggested batches, following the sheet's order:

1. Tier 1, first 16 (above).
2. Tier 1, the rest: Rubber, Sand, Seaweed, Soil, Stainless Steel, Steel, Sugar, Tools, Water, Wire, Yeast.
3. Tier 2: Apple to Farm (Apple, Banana, Biofuel, Book, Bridge, Building, Canoe, Chicken, Chocolate, Clock, Cloud, Compass, Cow, Deer, Dough, Egg, Engine, Farm).
4. Tier 2: Fiberglass to Wheel (Fiberglass, Flour, Fossil, Grain, Light Bulb, Log Cabin, Microchip, Milk, Plastic, Sailboat, Salmon, Solar Panel, Star, Tree, Trumpet, Wheel).
5. Tier 3: Apple Pie to Museum.
6. Tier 3: Orca to Éclair.
7. Capstones: Coral Reef, Ecosystem, Fruit Cake, Homestead, Maglev Train, Metropolis, Robot, Space Station.

## The card icons (a separate request)

```
Using the attached icons sheet, redraw every icon in the same card-game style as the items (same outline weight, same shading, same light), keeping each one's colour and meaning. The four element suit icons stay white-on-colour inside their coloured circles (green ORGANIC leaf, red REACTIVE flame, gold EARTH mountain, blue METAL anvil) with a thin dark rim. The station icons, the card game's buttons (Discard, Goal, Pass, Deck, Draw, Hand), Points, Quarks, Dice, the Unknown Element, Pin, Track and the five hub icons each as their own square transparent image, named as labelled.
```

## Before they go into the game

- Square PNGs on transparent backgrounds, at least 256 px (the game shows them from 18 px up to about 110 px).
- Keep the names exactly as on the sheet, so they can be mapped by name in `godot/assets/icons/icons.json` (no code changes needed).
- The game already draws a thin dark outline around every item picture. If the new art has its own outline, that one can be turned off in one place (`Tok.icon`).
