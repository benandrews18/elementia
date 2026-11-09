/* =====================================================================
   state.js -- Run and player state: storage keys, the `state` object (freshState()),
   `prefs`, UI selection globals, and save()/loadAll().
   ===================================================================== */
const lsGet = k => { try { return localStorage.getItem(k); } catch(e){ return null; } };
const lsSet = (k,v) => { try { localStorage.setItem(k,v); } catch(e){} };
const lsDel = k => { try { localStorage.removeItem(k); } catch(e){} };

function savePrefs(){ lsSet(PREFS_KEY, JSON.stringify(prefs)); }
// The run's localStorage key (only "classic" is used).
function saveKeyFor(mode){ return SAVE_KEY_PREFIX + mode; }
// Skipped while state.mode is null (between a reset and choosing a mode)
// -- it would write a stray "null" save.
// Skipped in Combo Lab: its sandbox state says "classic", so a save
// would overwrite the real Classic save (see openComboLab()).
function save(){ if (comboLabActive) return; if (state.mode) lsSet(saveKeyFor(state.mode), JSON.stringify(state)); }
function readModeSave(mode){
  try {
    const raw = lsGet(saveKeyFor(mode));
    return raw ? JSON.parse(raw) : null;
  } catch(e){ return null; }
}
function modeHasSave(mode){ return readModeSave(mode) !== null; }

/* Whether this is a genuinely new session (no save at all), so a mid-run
   reload doesn't show the welcome slide. */
function loadAll(){
  try { prefs = Object.assign(prefs, JSON.parse(lsGet(PREFS_KEY) || "{}")); } catch(e){}
  delete prefs.theme; // theme choice no longer exists -- drop it from any older save
  loadHistory();

  const raw = lsGet(saveKeyFor("classic"));
  let isNewSession = !raw;
  try {
    state = raw ? Object.assign(freshState(), JSON.parse(raw)) : freshState();
  } catch(e){ state = freshState(); isNewSession = true; }
  state.mode = "classic";
  // Saves from before bingoCenterChosen existed: a drawn card means a centre
  // was already chosen.
  if (state.bingoCard && !state.bingoCenterChosen) state.bingoCenterChosen = true;
  // Saves from before the 3-visit mat check -- a run already past its first
  // "day" counts as checked, so it keeps rolling TAKE rather than jumping to 6.
  if (state.matChecked === false && state.visits > MAT_CHECK_EVERY) state.matChecked = true;
  savePrefs();
  return isNewSession;
}

/* The run's save lives at saveKeyFor("classic") (see loadAll()). */
const SAVE_KEY_PREFIX = "elementia-save-v4-";
const PREFS_KEY   = "elementia-prefs-v1";
const HISTORY_KEY = "elementia-history-v1";
const HISTORY_MAX = 50;

let state, screen = "map", current = null;
let selectedMapStation = null; // ephemeral: which node's card is showing on the map
// The station whose Lock-In prompt has been shown (the "travel" face's
// click handler). Compared against selectedMapStation, so picking a
// different station shows the mat again.
let travelPromptFor = null;
// The capstone the initial station-pick preview auto-tracked
// (syncInitialPickCapstoneTracking()), so exactly that one can be undone.
// Ephemeral, like selectedMapStation.
let initialPickPinnedCapstone = null;
// Screen to return to when Item Reference closes, set only when coming from
// the Marketplace (see closePanelByName()). null = current station or map.
let codexReturnScreen = null;
// The drawer's state when Item Reference opened, restored on close
// (closePanelByName()). Item Reference is a full screen below #drawer, so
// the drawer must close. null: closed; true: peeked; false: expanded.
let codexReturnDrawerPeeked = null;
// Shop items unlocked by the latest craft, held out of the shop grid until
// the card popup closes (flushPendingReveal()).
let pendingRevealNames = null, pendingRevealStation = null;
let itemRevealTimer = null, itemRevealShown = false, itemRevealDismissable = false, itemRevealDismissTimer = null;
// guidedTutorialEnabled/tutorialHintsSeen: Professor Mouse's feature tips
// (showTutorialHintOnce()) fire the first time each situation comes up in
// play. Kept in prefs (per player, survives resets) so no tip repeats.
// arcadeHighScores: {[stationName]: {raw, label, score, dice}} -- best
// Mini-Games run per station (launchArcadeGame()), keyed on the raw score
// so results stay comparable if difficulty is retuned.
let prefs = {maxVisits:DEFAULT_MAX_VISITS, diceCount:3, pinnedItems:[], minigamesEnabled:false,
  // Saved Display Mat layouts {name, items}, account-level, so a combo from
  // Combo Lab or a run can be recalled later (openMatLayoutsOverlay()).
  savedMatLayouts:[],
  // [collectionId, ...] every named collection ever revealed in a Lock-In
  // (playLockInSequence()). Account-level so discoveries survive a reset. A
  // collection on the mat that has never been locked in shows no chip
  // (renderMatTop()).
  everUnlockedMatCollections:[],
  guidedTutorialEnabled:false, tutorialHintsSeen:[], arcadeHighScores:{},
  // On: full inspection popup after a craft. Off: just settle the item into
  // the shop (showCardPop()/autoCardPop()).
  autoCardInspection:true,
  // Low motion (see lowMotion()/html.low-motion): null = follow the
  // device's own "reduce motion" setting, true/false = player's override.
  lowMotion:null};
/* The tracked item (ephemeral UI state, not saved): highlights its
   ingredient closure on station cards (componentClosure()/
   stationItemIconsHTML()/renderMap()). */
let selectedJobItem = null;
/* Item Reference search text, kept here because renderCodex() rebuilds the
   input every render (see applyRefFilter()). */
let refFilterQuery = "";
// Same "outlives a full renderCodex() rebuild" reasoning as refFilterQuery
// above -- the <select> itself gets torn down and rebuilt on every render.
let refSortMode = "az"; // "az" (default) | "points_asc" | "points_desc"

function freshState(){
  return {
    elements: {},      // symbol -> count (consumed)
    items: [],         // crafted item names (permanent)
    visitLog: [],       // [{station, items, elements}] one per goStation(); items appended by
                        // craft(), elements by doRoll(). Feeds History (recordHistory()).
    visits: 0,
    lastStation: null,   // where the player is standing right now (map screen's anchor)
    priorStation: null,  // where they were BEFORE lastStation -- the "no repeat" rule now
                          // blocks A->B->A oscillation on the path map, not same-station-twice
    rolledHere: false, // one PLAY per visit
    pendingRoll: null, // dice count earned from the minigame, waiting on a manual Roll tap
    lastRoll: null,
    noRepeat: true,    // default on: blocks immediately backtracking to priorStation
    ended: false,      // session summary already shown for this run
    mode: null,        // always "classic" once a run starts
    visitedStations: {}, // {stationName: true} -- every station ever entered, for the
                          // "visited every station" bonus and the Market's progress row.
    stationLastSeen: {}, // {station: [items]} revealed non-capstone shop items as of the last
                         // visit, so goStation() can spot "new since last time".
    seenItems: {},     // {item: true} every item shown to the player this run.
    collapseCraftedItems: true, // global "Collapse crafted" toggle for every station shop -- on by default
    convertRevealed: false, // true forever once the floating Convert button has appeared once
    marketVisited: false, // true once the Marketplace tray has been opened (openJobSelectTray()).
    arrangement: { bg: null, stickers: [] }, // Arrange Items scene -- see openArrangeScreen()
    mat: [], // Display Mat (Classic): item names in display order (matScore()).
             // Collection discovery lives in prefs.everUnlockedMatCollections,
             // which survives resets.
    bingoCard: null,  // [item x25] Classic BINGO card, drawn once per run by ensureBingoCard();
                      // null gives a fresh run a new draw.
    bingoLinesCompleted: [], // [lineIndex] completed lines (checkBingoLines()); never un-completes.
    pendingBingoClears: [], // [lineIndex] completed but not yet played (runBingoSequence(), which
                            // runs once the craft's own effects finish).
    // The "?" elements held (Empty Elements): earned at the top Quark
    // breakpoint and from BINGO lines; spent via openEmptyElPicker().
    emptyElements: 0,
    // Non-Classic Lock-In reward: a dice delta (-1..+2) applied by the next
    // doRoll() at the destination, then reset. Classic uses
    // state.matBonusDice instead.
    matChecked: false, // Classic: has a Display Mat check (Lock-In) happened yet this run? See MAT_CHECK_EVERY.
    matBonusDice: 0,   // Classic: bonus dice from the latest check, added to the rolls after it.
    bingoCenterChosen: false, // Whether the BINGO centre has been chosen (setBingoCenter()); false
                              // shows "Add Capstone". See the migration after freshState() for older
                              // saves.
    sawBreakpointGateNotice: false, // One-shot: whether the turn-10 "breakpoints now matter"
                       // notice has fired yet this run (see BREAKPOINT_GATE_VISIT).
    finalGameOver: false, // True once a sunset Lock-In from BREAKPOINT_GATE_VISIT on missed the
                          // first breakpoint and the player confirmed ending (confirmLockIn()).
    craftedEverything: false, // Classic: every CORE_ITEM_NAMES item owned -- see checkCraftedEverything().
    reachedHardLimit: false, // True once state.visits hits MAX_VISITS (goMap()): the
                             // congratulatory ending.
    bestMatScore: 0,   // Best matScore().total across this run's Lock-Ins, shown on the End
                       // screen.
  };
}
