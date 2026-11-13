/* =====================================================================
   hub.js -- Bottom hub: the Home button's face (Roll / Market / Lock-In / Map,
   setHubHomeFace()), hub badges, travel checks, and the hub buttons that
   open panels (openPanelName()/closePanelByName()).
   ===================================================================== */
/* ------------------------------------------------------- bottom hub --- */
/* Home from Item Reference skips goMap()'s visit bookkeeping only when no
   station visit is underneath (keyed off `current`, like mapLocked()) --
   otherwise the map would forget the station just left. */
function goHome(){
  cancelPendingFullscreenEvents();
  if (current === null && screen === "codex"){ screen = "map"; render(true); return; }
  goMap();
}
/* Every hub button first deals with whatever panel is open: its own button
   closes it, and a DIFFERENT button also just closes it (a second press
   opens the new one). Item Reference and Convert count as panels, so Home's
   back arrow has one place to ask "what's open?". */
function openPanelName(){
  // Checked top-down by z-index: Jobs (69) and Settings (65) can be open on
  // top of the drawer (60), and Home must close the top layer first.
  if (jobSheet.classList.contains("open")) return "jobs";
  if (anySettingsOpen()) return "settings";
  if (drawer.classList.contains("open")) return "drawer";
  if (pinsTray.classList.contains("open")) return "pins";
  if (document.getElementById("convert").classList.contains("open")) return "convert";
  if (screen === "codex") return "codex";
  return null;
}
function closePanelByName(name){
  if (name === "drawer") closeDrawer();
  else if (name === "jobs") closeJobBoard();
  else if (name === "pins") closePinsTray();
  else if (name === "settings"){
    const openId = SETTINGS_OVERLAY_IDS.find(id => document.getElementById(id).classList.contains("open"));
    if (openId) closeOverlay(openId);
  }
  else if (name === "convert") closeOverlay("convert");
  else if (name === "codex"){
    // Return where Item Reference was opened from: a station name when
    // goToRefItem() came from a shop (it has to null `current`). Other entry
    // points leave `current` alone, so the fallback below covers them.
    if (codexReturnScreen){
      current = codexReturnScreen;
      screen = "station";
    } else {
      screen = current ? "station" : "map";
    }
    codexReturnScreen = null;
    render(true);
    // Restore the drawer as it was before Item Reference opened
    // (codexReturnDrawerPeeked).
    if (codexReturnDrawerPeeked !== null){
      openDrawer({ peeked: codexReturnDrawerPeeked });
      codexReturnDrawerPeeked = null;
    }
  }
}
/* A button whose panel is open just closes it; any OTHER button closes
   what's open AND opens its own target in the same tap. Item Reference is a
   screen, not an overlay, so it isn't closed first. */
function hubPanelClick(name, openFn){
  const open = openPanelName();
  if (open === name){ closePanelByName(name); return; }
  // Jobs/Settings stack above #drawer (69/65 vs 60), so the drawer stays open
  // beneath them; closing it would strand the player on the map afterward.
  // Item Reference/Pins/Convert sit below it and still close it (Item
  // Reference restores it, see codexReturnDrawerPeeked).
  if (open === "drawer" && (name === "jobs" || name === "settings")){ openFn(); return; }
  if (open && open !== "codex") closePanelByName(open);
  openFn();
}
/* Rolls this visit's dice (or launches the mini-game that hands off to a
   roll), via Home's Roll face. */
function triggerRoll(){
  if (state.pendingRoll){
    const n = state.pendingRoll;
    state.pendingRoll = null;
    doRoll(n);
  } else {
    launchMinigame();
  }
}
/* Home's action always matches whichever face it's currently showing (see
   hubHomeFace()) -- the two can never drift apart since both read the
   same function. */
document.getElementById("hubHome").addEventListener("click", ev => {
  if (startingGiftInProgress) return; // see playStartingGift()
  const face = hubHomeFace();
  if (face === "close"){
    closePanelByName(openPanelName());
    return;
  }
  if (face === "roll"){ triggerRoll(); return; }
  // The full Marketplace tray (openJobSelectTray()); the hub's To-Do List
  // button is openJobBoard().
  // Free re-entry into the current station: no goStation() (that spends a
  // visit), just point current/screen back at it.
  if (face === "shop"){ current = state.lastStation; screen = "station"; render(); return; }
  // The first tap on a newly selected travel target opens the Display Mat
  // (Home becomes "lockin"); locking in then travels on its own
  // (finishLockIn()). This branch handles backing out of the mat and tapping
  // Travel again -- travelPromptFor still matches, so it goes straight to
  // goStation().
  if (face === "travel"){
    // Nothing owned yet: skip the Lock-In doorway (an empty mat would look
    // broken) and travel straight away.
    if (isClassicFirstPick()){ playStartingGift(selectedMapStation); return; }
    // The mat is only checked when leaving a checkpoint turn (every 3rd,
    // isMatCheckVisit()); other trips travel straight away.
    if (!isMatCheckVisit()){ goStation(selectedMapStation); return; }
    if (travelPromptFor !== selectedMapStation){
      travelPromptFor = selectedMapStation;
      matDrawerView = "mat";
      // The shutter scene change, then the full inventory; the first check
      // ever also explains it (announceMatCheck()).
      playShutter("Display Board Check!", () => { openDrawer(); announceMatCheck(); });
      return;
    }
    goStation(selectedMapStation);
    return;
  }
  // The mat is already open when this face shows -- just score it
  // (confirmLockIn()).
  if (face === "lockin"){ if (!lockInCommitted) confirmLockIn(); return; }
  // Final Score: opens the mat if it's closed, else scores it.
  if (face === "final"){
    if (!drawer.classList.contains("open")){ matDrawerView = "mat"; openDrawer(); return; }
    confirmFinalLockIn(); return;
  }
  // The Marketplace tray reads "Map" but still has to be closed; the map is
  // already underneath.
  if (face === "map" && openPanelName() === "jobs"){ closeJobBoard(); return; }
  // Already on the map: Home just reads "Map" there.
  if (screen === "map") return;
  goHome(); // face === "map"
});
document.getElementById("hubInv").addEventListener("click", () => {
  // The peeked view means "mid Lock-In", not "Inventory open", so tapping
  // Inventory expands it instead of closing it.
  if (expandDrawerToFull()) return;
  // Mid Lock-In, tapping Inventory from the full view collapses back to the
  // peeked view instead of closing (closing the drawer still backs out). Home
  // stays "lockin" in both views.
  if (travelPromptFor !== null && travelPromptFor === selectedMapStation
      && drawer.classList.contains("open") && drawer.classList.contains("expanded")){
    collapseDrawerToPeeked();
    return;
  }
  hubPanelClick("drawer", openDrawer);
});
document.getElementById("hubCodex").addEventListener("click", () => {
  // Captured before hubPanelClick()'s own closePanelByName("drawer") call
  // (triggered when openPanelName() reports "drawer") can close it -- see
  // codexReturnDrawerPeeked's own comment.
  const drawerPeeked = drawer.classList.contains("open") ? !drawer.classList.contains("expanded") : null;
  hubPanelClick("codex", () => {
    codexReturnScreen = null;
    codexReturnDrawerPeeked = drawerPeeked;
    screen = "codex"; render(true);
  });
});
document.getElementById("settingsBtn").addEventListener("click", () => hubPanelClick("settings", openSettings));
// Marketplace: the full BINGO/Capstones tray (openJobSelectTray()) from
// anywhere. Shares #jobSheet with the To-Do List, so it toggles on the
// variant, not hubPanelClick()'s panel name.
document.getElementById("hubMarket").querySelector(".hi").innerHTML = em("__MARKETPLACE__");
document.getElementById("hubMarket").addEventListener("click", () => {
  const open = openPanelName();
  if (open === "jobs" && jobSheetVariant === "full"){ closeJobBoard(); return; }
  if (open === "jobs"){ closeJobBoard(); openJobSelectTray(); return; }
  if (open && open !== "codex" && open !== "drawer") closePanelByName(open);
  openJobSelectTray();
});
document.getElementById("hubJobs").addEventListener("click", () => hubPanelClick("jobs", openJobBoard));

/* Hub button states: job board progress, active screen, and Home's own
   rotation through its five faces. */
/* Tracks Home's current face so the coin-flip only plays between the
   "progress" faces (Roll/Market/Travel/Map), not to or from Close, which
   changes too often to animate. */
let hubHomeState = null;
function setHubHomeFace(face){
  const home = document.getElementById("hubHome");
  // Travel icon: the boot by default, the helicopter when the selection is
  // only reachable by fast travel (see canReachStation()).
  const viaAir = selectedMapStation && !isMapConnected(state.lastStation, selectedMapStation);
  const FACES = {
    roll:   { hi: "🎲", hl: "Roll" },
    // The same Market icon/label in every mode, even though Classic's tap opens
    // the BINGO tray. Custom art (__MARKETPLACE__) via em(), which returns an
    // <img> -- hence innerHTML below.
    // Free re-entry into the current station (hubHomeFace()): a shopping cart,
    // distinct from Market's stall art.
    shop:   { hi: "🛒", hl: "Shop" },
    travel: { hi: viaAir ? "🚁" : "🥾", hl: "Travel" },
    // Classic's Lock-In face (hubHomeFace()); other modes keep plain "travel".
    lockin: { hi: "🔒", hl: "Lock In" },
    final:  { hi: "🏁", hl: "Final Score" },
    map:    { hi: "🗺️", hl: "Map" },
    close:  { hi: "⬅️", hl: "Close" },
  };
  const target = FACES[face];
  const isCoinPair = hubHomeState !== null && hubHomeState !== face &&
    hubHomeState !== "close" && face !== "close";
  const apply = () => {
    // innerHTML: the market face's icon is an <img> (see FACES.market).
    home.querySelector(".hi").innerHTML = target.hi;
    home.querySelector(".hl").textContent = target.hl;
    home.classList.remove("face-final", "face-roll", "face-shop", "face-travel", "face-lockin", "face-map", "face-close");
    home.classList.add("face-" + face);
  };
  if (isCoinPair && !lowMotion()){
    home.classList.add("coinflip");
    setTimeout(apply, 200); // midpoint of the .4s hubCoinFlip animation, edge-on and invisible
    setTimeout(() => home.classList.remove("coinflip"), 400);
  } else {
    apply();
  }
  hubHomeState = face;
}
function updateHub(){
  // Never badged, green or red -- the To-Do state is
  // already visible the moment the panel opens; a bubble here read as
  // one more thing competing for attention on the hub.
  setHubBadge("hubJobs", null);

  const home = document.getElementById("hubHome");
  const anyOpen = !!openPanelName();
  home.classList.toggle("active", screen === "map" && !anyOpen);

  document.getElementById("hubCodex").classList.toggle("active", screen === "codex");
  // Lit for the full inventory only; the half-height Lock-In view doesn't
  // count.
  document.getElementById("hubInv").classList.toggle("active",
    drawer.classList.contains("open") && drawer.classList.contains("expanded"));
  // Only the "compact" variant is the To-Do List (openJobBoard()); #jobSheet
  // is also the Marketplace/BINGO tray ("full"), which shouldn't light this
  // button.
  document.getElementById("hubJobs").classList.toggle("active",
    jobSheet.classList.contains("open") && jobSheetVariant === "compact");
  document.getElementById("settingsBtn").classList.toggle("active", anySettingsOpen());
  document.getElementById("hubMarket").classList.toggle("active",
    jobSheet.classList.contains("open") && jobSheetVariant === "full");
  const pinsOpen = pinsTray.classList.contains("open");
  const convertOpen = document.getElementById("convert").classList.contains("open");
  document.getElementById("pinsBtn").classList.toggle("active", pinsOpen);
  document.getElementById("quickConvertBtn").classList.toggle("active", convertOpen);
  // Each floating trigger (and the tracked pill) hides while the OTHER
  // tray is open, so the two trays don't fight over controls.
  document.getElementById("quickConvertBtn").classList.toggle("cross-hide", pinsOpen);
  document.getElementById("pinsBtn").classList.toggle("cross-hide", convertOpen);
  document.getElementById("trackedPill").classList.toggle("cross-hide", convertOpen);

  // Attention badges ("!"): Pins when items are pinned but none is tracked;
  // Convert when something can be converted.
  const hasUnselectedPin = prefs.pinnedItems.length > 0 && !selectedJobItem;
  setHubBadge("pinsBtn", hasUnselectedPin ? "!" : null);
  // Conversions possible right now across all elements (floor(count/rate)
  // each), not just "you have enough of something".
  const totalConvertible = totalConvertibleCount();
  const canConvert = totalConvertible > 0;
  setHubBadge("quickConvertBtn", canConvert ? String(totalConvertible) : null);
  document.getElementById("quickConvertBtn").innerHTML = em("__CONVERT__");
  // Once revealed, Convert stays on screen for good (a persisted flag, since
  // holdings can drop again). Revealed as soon as the player holds any element
  // (right after the starting gift).
  const holdsElements = Object.values(state.elements).some(v => v > 0);
  if (holdsElements && !state.convertRevealed){
    // Its tip comes later, with the walkthrough (maybeShowWalkthroughTip()),
    // once a conversion is actually possible.
    state.convertRevealed = true;
  }

  // Floating buttons stay off-screen until useful: Pins once an item is
  // pinned; Convert once revealed.
  const everTakenSomething = prefs.pinnedItems.length > 0;
  document.getElementById("pinsBtn").classList.toggle("offscreen", !everTakenSomething);
  document.getElementById("quickConvertBtn").classList.toggle("offscreen", !state.convertRevealed);

  const face = hubHomeFace();
  setHubHomeFace(face);
  home.setAttribute("aria-disabled", face === "lockin" && lockInCommitted ? "true" : "false");
  home.title = face === "close" ? "Close"
    : face === "roll" ? "Roll the dice"
    : face === "shop" ? `Re-enter ${selectedMapStation} (free)`
    : face === "travel" ? `Travel to ${selectedMapStation}`
    : face === "lockin" ? "Lock in your Display Mat"
    : face === "final" ? "Lock in your mat for your final score"
    : "Back to the station map";
  // The Market button gets a "!" until the Marketplace is first opened
  // (state.marketVisited, set by openJobSelectTray()).
  // ...and again whenever a Market square was finished out of sight
  // (state.marketUnseen, see runBingoSequence()).
  setHubBadge("hubMarket", state.marketVisited && !state.marketUnseen ? null : "!");
}

/* Whether the player can travel to the selected map station right now
   (not here, reachable, run not over) -- gates Home's Travel face. */
function canTravelTo(name){
  return !!name && name !== state.lastStation && canReachStation(state.lastStation, name) && !state.ended;
}
/* Which of Home's faces is showing. updateHub() (styling, via
   setHubHomeFace()) and the hubHome click handler (behaviour) both read
   this, so they never disagree.
     close  -- a panel is open; tap closes it.
     roll   -- at a station, this visit's dice not yet rolled.
     shop   -- on the map with the CURRENT station selected; tap re-enters it
               for free (no visit spent, shop as left).
     travel -- on the map with another reachable station selected (see
               canTravelTo()).
     lockin -- Classic: the drawer is open on the Display Mat because the
               player tapped Travel (see confirmLockIn()). Checked before the
               generic "panel open -> close" rule.
     map    -- rolled, off the map screen -- time to leave. Also the
               Marketplace screen's resting face (tap continues to the map);
               an expanded Marketplace section or a sheet on top still reads
               "close". */
function hubHomeFace(){
  const panel = openPanelName();
  // The full Marketplace tray (jobSheetVariant === "full", opened by Home)
  // reads "Map" -- leaving it is just returning to the map. The hub's compact
  // To-Do tray falls through to "close".
  // Turn 24 is over: the only way on is the final score (no travel).
  if (state.finalCheckPending && (!panel || panel === "drawer")) return "final";
  if (panel === "jobs" && jobSheetVariant === "full") return "map";
  // Lock In only through the travel doorway: travelPromptFor ===
  // selectedMapStation is set only by tapping Travel, so opening the mat any
  // other way never shows Lock In.
  if (panel === "drawer" && matDrawerView === "mat"
      && screen === "map" && selectedMapStation && canTravelTo(selectedMapStation)
      && travelPromptFor === selectedMapStation) return "lockin";
  if (panel) return "close";
  if (mapLocked()) return "roll";
  // Selecting the station you're standing at: "shop" -- a free re-entry
  // (canTravelTo() refuses the current station).
  if (screen === "map" && selectedMapStation && selectedMapStation === state.lastStation) return "shop";
  if (screen === "map" && selectedMapStation && canTravelTo(selectedMapStation)) return "travel";
  return "map";
}

/* At a station, leaving is blocked until the dice are rolled (the visit is
   already spent). Keyed off `current` so Item Reference isn't a side door
   out. */
function mapLocked(){ return current !== null && !state.rolledHere; }
function setHubBadge(id, text, ok){
  const btn = document.getElementById(id);
  const old = btn.querySelector(".hub-badge");
  if (old) old.remove();
  if (text === null) return;
  const b = document.createElement("span");
  b.className = "hub-badge" + (ok ? " ok" : "");
  b.textContent = text;
  btn.appendChild(b);
}
