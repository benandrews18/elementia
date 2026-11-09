/* =====================================================================
   map-graph.js -- Station web: MAP_EDGES, adjacency, node positions on the map art.

   Station web: travel follows these edges only. The graph was developed in
   the old reachability simulator (archive/simulation/): Ocean,
   Old Growth Forest, Greenhouse, The Bakery and The Observatory are hubs
   with 3-4 links each. Positions are percentages within
   backdrops/diamond_map_full.webp; lines are drawn from this list
   (mapPathsHTML()), so the graph can change without new art. */
const MAP_EDGES = [
  ["The Ocean","Old Growth Forest"], ["The Ocean","Deep Mine"], ["The Ocean","The Observatory"],
  ["Old Growth Forest","Deep Mine"], ["Old Growth Forest","The Power Plant"], ["Old Growth Forest","Greenhouse"],
  ["Greenhouse","Deep Mine"], ["Greenhouse","The Power Plant"], ["Greenhouse","The City"], ["Greenhouse","The Bakery"],
  ["The Bakery","The Observatory"], ["The Bakery","The City"], ["The Bakery","The Power Plant"],
  ["The Observatory","The City"],
  ["The City","The Power Plant"], ["The Power Plant","Deep Mine"],
];
const MAP_ADJ = {};
MAP_EDGES.forEach(([a,b]) => {
  if (!MAP_ADJ[a]) MAP_ADJ[a] = new Set();
  if (!MAP_ADJ[b]) MAP_ADJ[b] = new Set();
  MAP_ADJ[a].add(b); MAP_ADJ[b].add(a);
});
/* Every edge is open from the start, including Ocean <-> Observatory. */
function edgeUnlocked(a, b){
  return true;
}
/* a === null: no position yet (choosing a start), so every station is
   reachable. */
const isMapConnected = (a,b) => a === null ? !!b :
  !!(a && b && MAP_ADJ[a] && MAP_ADJ[a].has(b) && edgeUnlocked(a,b));
/* Owning a Helicopter makes every station reachable. */
const canReachStation = (a, b) => owns("Helicopter") || isMapConnected(a, b);

/* Node coordinates on the original tall map art (see .map-canvas). */
const MAP_NODE_POS = {
  "The Observatory":    [49.7,  9.1],
  "The Bakery":         [20.4, 26.5],
  "The City":            [79.5, 26.6],
  "Greenhouse":         [20.4, 45.3],
  "The Power Plant":    [79.8, 45.3],
  "Old Growth Forest":  [20.4, 67.2],
  "Deep Mine":          [79.3, 66.6],
  "The Ocean":          [49.9, 89.2],
};
/* Per-station nudge in mm (device-independent), added via CSS calc() on
   top of MAP_NODE_POS. The Ocean isn't moved; Greenhouse and The Power
   Plant get 1.5mm extra. Only the real map uses it (renderArcadeMap()
   doesn't). */
const MAP_NODE_MM_SHIFT = Object.fromEntries(Object.keys(MAP_NODE_POS).map(name => [
  name,
  name === "The Ocean" ? 0 : (name === "Greenhouse" || name === "The Power Plant") ? 6.5 : 5,
]));
const mapNodeTopStyle = name => {
  const mm = MAP_NODE_MM_SHIFT[name];
  const y = MAP_NODE_POS[name][1];
  return mm ? `calc(${y}% + ${mm}mm)` : `${y}%`;
};
