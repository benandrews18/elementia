/* =====================================================================
   travel.js -- Travel: goStation() (arriving at a station) and goMap().
   ===================================================================== */
function goStation(name){
  lockInCommitted = false;
  if (state.ended){ showEndGame(); return; }
  // Classic: auto-pin the first station's capstone (state.visits is still 0
  // here) so there's a goal from the first tap.
  if (state.visits === 0 && STATION_BY_NAME[name]){
    const capName = STATION_BY_NAME[name].capstone[1];
    if (!isPinned(capName)) togglePin(capName);
  }
  current = name; screen = "station";
  state.visits++; state.rolledHere = false;
  state.pendingRoll = null; state.lastRoll = null;
  // One turn-log entry per real visit, before any crafting or rolling can
  // add to it.
  if (!state.visitLog) state.visitLog = [];
  state.visitLog.push({station: name, items: [], elements: {}});
  // Defensive reset: leaving mid-roll can tear the dice cards out before
  // their finish event fires, which would leave this stuck true and freeze
  // .stationhead everywhere.
  rollAnimationInProgress = false;
  state.visitedStations[name] = true;
  if (MAT_GROW_ROUNDS.includes(state.visits))
    queueEventToast("stations", "🖼️", "Your Display Mat grew!", state.visits === MAT_GROW_ROUNDS[2] ? "It's full size now" : "More room for cards");
  // Every station visited: one "?" element, once per run.
  if (!state.allStationsPaid && DATA.stations.every(s => state.visitedStations[s.name])){
    state.allStationsPaid = true;
    state.emptyElements = (state.emptyElements || 0) + 1;
    queueEventToast("stations", emptyElSquareHTML(30), "All 8 stations visited!", "+1 ? element");
  }

  save(); render(true);
  // The mini-game launches immediately on arrival, covering the screen
  // (#mgOverlay) until its score has become a roll (launchMinigame()/
  // doRoll()).
  launchMinigame();
}
function goMap(){
  if (current){ state.priorStation = state.lastStation; state.lastStation = current; }
  screen = "map"; current = null; state.lastRoll = null; selectedMapStation = null;
  save(); render(false);
  // Land on the player's own position, not the top of the page -- on a
  // tall map, scrolling back up to hunt for yourself every single visit
  // would get old fast.
  const hereNode = document.querySelector(".map-node.here");
  if (hereNode) hereNode.scrollIntoView({block:"center", behavior:"instant"});
  else window.scrollTo({top:0, behavior:"instant"});
  // The congratulatory ending at MAX_VISITS.
  if (state.visits >= MAX_VISITS && !state.ended){
    state.ended = true; state.reachedHardLimit = true; save(); showEndGame();
  }
  // The run is complete at RUN_COMPLETE_VISIT: keep playing (Overtime) or
  // start a new game. Older saves already past it get this on their next
  // return to the map.
  else if (state.visits >= RUN_COMPLETE_VISIT && !state.runComplete && !state.ended){
    startFinalCheck();
  }
  // One-time tip: back on the map after the first visit without ever opening
  // the Marketplace, point at the hub's Market button.
  if (state.visits >= 1 && !state.marketVisited){
    tryWalkthroughTip("checkmarket", 1, `<span style="font-size:16px">Check out the Market!</span>`, "bottom-right", "#hubMarket");
  }
}
