/* =====================================================================
   map.js -- Map screen: station nodes, paths, the station card and renderMap().
   ===================================================================== */
/* Every item this station sells, icon-only. Owned items are full colour
   (greyscale otherwise). */
function stationItemIconsHTML(stationName){
  // The tracked item and what's still needed for it get the gold ring
  // (.station-item-icon.job-highlight) -- only that. stillNeededClosure() so
  // spent intermediates stop lighting up.
  const jobTree = selectedJobItem ? new Set([selectedJobItem, ...stillNeededClosure(selectedJobItem)]) : null;
  const icons = entriesAt(stationName)
    .filter(e => e.tier !== "CAPSTONE")
    .map(e => {
      markSeen(e.name);
      const cls = ["station-item-icon"];
      if (owns(e.name)) cls.push("owned");
      if (jobTree && jobTree.has(e.name)) cls.push("job-highlight");
      return `<span class="${cls.join(" ")}" title="${esc(e.name)}" data-item-card="${ENTRIES.indexOf(e)}">${em(e.emoji)}</span>`;
    });
  // A flex-basis:100% spacer forces a new row every 10 icons (see
  // .station-items-break).
  return icons.reduce((html, icon, i) =>
    html + (i > 0 && i % 10 === 0 ? '<span class="station-items-break"></span>' : "") + icon, "");
}

/* Map path lines, drawn from MAP_EDGES/MAP_NODE_POS (the art has none).
   One SVG with viewBox 0-100 and preserveAspectRatio="none" so it lines up
   with the nodes' percentages; vector-effect:non-scaling-stroke (see
   .map-path-line) keeps dashes the same size whatever the edge's angle. */
/* `here` = state.lastStation: only its edges are .active (bright gold).
   here === null (choosing a start): every edge is active. */
function mapPathsHTML(here){
  const lines = MAP_EDGES.filter(([a, b]) => edgeUnlocked(a, b)).map(([a, b]) => {
    const [x1, y1] = MAP_NODE_POS[a], [x2, y2] = MAP_NODE_POS[b];
    const active = here === null || a === here || b === here;
    // data-a/data-b let syncMapPaths() find each line's endpoints later and add
    // the per-station mm nudge (MAP_NODE_MM_SHIFT), which needs the rendered
    // canvas height.
    return `<line data-a="${esc(a)}" data-b="${esc(b)}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" class="map-path-line${active ? " active" : ""}"/>`;
  }).join("");
  return `<svg class="map-paths" viewBox="0 0 100 100" preserveAspectRatio="none">${lines}</svg>`;
}
// CSS mm -> px is fixed (96px per inch, 25.4mm per inch).
const MM_TO_PX = 96 / 25.4;
/* Node icons sit MAP_NODE_MM_SHIFT below their MAP_NODE_POS percentage, a
   physical offset the 0-100 viewBox can't express ahead of time. After the
   map renders, measure the canvas height and nudge each line's y1/y2 by the
   matching percent so lines end on the icons. Called from render() and on
   resize. */
function syncMapPaths(){
  const canvas = document.querySelector(".map-canvas");
  const svg = document.querySelector(".map-paths");
  if (!canvas || !svg) return;
  const h = canvas.getBoundingClientRect().height;
  if (!h) return;
  svg.querySelectorAll("line[data-a]").forEach(line => {
    const a = line.dataset.a, b = line.dataset.b;
    const y1 = MAP_NODE_POS[a][1] + (MAP_NODE_MM_SHIFT[a] * MM_TO_PX / h) * 100;
    const y2 = MAP_NODE_POS[b][1] + (MAP_NODE_MM_SHIFT[b] * MM_TO_PX / h) * 100;
    line.setAttribute("y1", y1);
    line.setAttribute("y2", y2);
  });
}

/* Map station card, shown when a node is tapped (renderMap()). Read-only;
   travel goes through the hub's Travel face. */
function mapCardHTML(name){
  const s = STATION_BY_NAME[name];
  const su = DATA.suits[s.suit];
  const capName = s.capstone[1], done = owns(capName);
  const over = state.ended;
  const here = name === state.lastStation;
  const connected = canReachStation(state.lastStation, name);
  // Travel happens via the hub's Travel face (hubHomeFace()/canTravelTo());
  // the card only explains why a node can't be travelled to.
  const statusNote = here ? "You are here"
    : over ? "Session complete"
    : !connected ? "Not connected to your location"
    : "";
  // Tracked item, top-right, ringed like the highlighted icons below so it
  // labels them.
  const trackedEntry = selectedJobItem && ENTRIES.find(e => e.name === selectedJobItem);
  const trackedPill = trackedEntry
    ? `<span class="mc-tracked" title="Tracking ${esc(trackedEntry.name)}"><span class="mct-glass">🔍</span><span class="mct-em">${em(trackedEntry.emoji)}</span><span class="mct-name">${esc(trackedEntry.name)}</span></span>`
    : "";
  const itemsHTML = `<div class="station-items">${stationItemIconsHTML(name)}</div>
    <div class="capline ${done ? "done" : ""}" data-item-card="${ENTRIES.findIndex(e => e.name === capName)}" title="${esc(capName)}">
      <span class="cap-em">${em(s.capstone[0])}</span>
      <span class="cap-name">${esc(capName)}</span>
      ${done ? "<span>✓</span>" : ""}
    </div>`;
  // Atomic number + element name, like the station pool (.pnum/.pname mirror
  // .gnum/.gname).
  const poolHTML =
    `<div class="pool">${sortedDice(s).map(d => `<div class="pcol"><button type="button" class="pchip" data-elem="${esc(d)}" title="${esc(d)} — tap for its card" style="--suit:${ELEMENT_COLOR[d] || "#8a94a6"}"><span class="pnum">${ATOMIC_NUMBER[d]}</span><span class="psym">${esc(d)}</span>${elSuitBadgeHTML(d)}</button><span class="pname">${esc(ELEMENT_NAMES[d] || d)}</span></div>`).join("")}</div>`;
  return `<div class="map-card" style="--suit:${su.color}">
    <div class="row1"><span class="em">${em(s.emoji)}</span><h2>${esc(name)}</h2>${trackedPill}</div>
    ${poolHTML}
    ${itemsHTML}
    ${statusNote ? `<p class="map-status-note">${esc(statusNote)}</p>` : ""}
  </div>`;
}

function renderMap(){
  const over = state.ended;
  const here = state.lastStation;
  // This map badge marks only the station where the tracked item itself is
  // crafted -- one breadcrumb, not every station selling a component.
  const trackedEntry = selectedJobItem && ENTRIES.find(e => e.name === selectedJobItem);

  const nodesHTML = Object.keys(MAP_NODE_POS).map(name => {
    const [x] = MAP_NODE_POS[name];
    const topStyle = mapNodeTopStyle(name);
    const s = STATION_BY_NAME[name];
    const isHere = name === here;
    const reachable = !isHere && !over && canReachStation(here, name);
    const cls = ["map-node", isHere ? "here" : reachable ? "reachable" : "unreachable"];
    if (selectedMapStation === name) cls.push("selected");
    // Tracked-item badge on the station where it's crafted (visited stations
    // only). Unlike the station card's icon row,
    // capstones count here -- when the tracked item IS a capstone, this is the
    // only pointer to its station.
    const hasTracked = trackedEntry && trackedEntry.station === name;
    // Initial station pick (lastStation === null): each node shows its capstone
    // in the tracked badge's slot (syncInitialPickCapstoneTracking() tracks the
    // open card's one); it wins over the tracked badge. Both badges are
    // SIBLINGS of the node button so z-index can put them behind its circle (a
    // negative-z child can't go behind its parent's own fill).
    const capstoneBadge = state.lastStation === null && !classicIntroHideCapstones
      ? `<span class="map-node-capstone-badge" style="left:${x}%;top:${topStyle}" title="Capstone: ${esc(s.capstone[1])}">${em(s.capstone[0])}</span>` : "";
    const trackedBadge = (hasTracked && !capstoneBadge)
      ? `<span class="map-node-tracked-badge" style="left:${x}%;top:${topStyle}" title="Feeds ${esc(selectedJobItem)}">${em(trackedEntry.emoji)}<span class="map-node-tracked-glass">🔍</span></span>` : "";
    return `${trackedBadge}${capstoneBadge}<button type="button" class="${cls.join(" ")}" style="left:${x}%;top:${topStyle};--suit:${DATA.suits[s.suit].color}" data-map-node="${esc(name)}" aria-label="${esc(name)}">
      <span class="mn-em">${em(s.emoji)}</span>
      ${isHere ? '<span class="mn-here-label">You are here</span>' : ""}
    </button>`;
  }).join("");

  const banner = over
    ? `<p class="map-sub" style="color:var(--bad);font-weight:700">
         This run has ended.
         <button type="button" class="tbtn" id="showEndBtn" style="margin-left:8px">See results</button></p>`
    : "";

  // Hidden during Classic's opening sequence (body[data-intro-sequence]).
  // Rendered inside .map-canvas, centred.
  const hint = state.lastStation === null && !document.body.hasAttribute("data-intro-sequence")
    ? `<p class="map-sub map-pick-note">Choose a<br>station to<br>start!</p>`
    : "";

  const cardHTML = selectedMapStation ? `<div class="map-card-wrap">${mapCardHTML(selectedMapStation)}</div>` : "";

  // No starting station yet: skip the web entirely -- every edge would be
  // "active" and the whole map would light up.
  const pathsHTML = state.lastStation === null ? "" : mapPathsHTML(state.lastStation);

  return `${cardHTML}
    ${banner}
    <div class="map-canvas" data-map-bg>${pathsHTML}<div class="map-nodes">${nodesHTML}</div>${hint}</div>`;
}
