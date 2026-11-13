/* =====================================================================
   lock-in.js -- Lock-In: Quark breakpoints per round, the scoring sequence, rewards
   (bonus dice, "?" elements), and the Lock-In banner.

   Lock In (Classic). Tapping Travel on a newly selected station opens the
   Display Mat instead of leaving, and only then does Home become "lockin"
   (gated on travelPromptFor, see hubHomeFace()). Locking in scores the mat
   and travels straight to the station (finishLockIn()); the reward is bonus
   dice for the next station's roll, plus a "?" element at the top tier. A
   zero reward only matters at sunset from BREAKPOINT_GATE_VISIT on (see
   confirmLockIn()).
   ===================================================================== */
/* History of this table: the 2026-09-17 version came from a hill-climb for
   the best possible mat (MAT_ABSOLUTE_CEILING) plus ~65 simulated 40-visit
   runs, with the breakpoints at each round's 15th/40th/70th/90th
   percentile. The table below has since been hand-tuned in the Quark
   Breakpoint Tuner. There is no deliberately impossible last row: reaching
   MAX_VISITS while clearing breakpoints is meant to succeed. */
// 4,784 since 2026-11-02 (capstones now count their own station twice) --
// the best mat a hill-climb finds with every Classic item owned.
const MAT_ABSOLUTE_CEILING = 4784;
// Hand-tuned in the Quark Breakpoint Tuner, one row per visit
// (lockInTiersForRound() would blend between rows if any were skipped).
// The top two breakpoints were retuned (2026-11-03) for big boards arriving
// around visit 10. Rows past MAT_ABSOLUTE_CEILING can't be reached. The
// previous table is kept in game/tools/quark_breakpoints_2026-11-03.html.
const LOCKIN_ROUND_ANCHORS = [
  // [visit, oneDieMin, twoDiceMin, threeDiceMin, emptyElementMin] -- one row per visit
  [1,   0,     5,     5,     5],
  [2,   5,     15,    20,    35],
  [3,   10,    35,    55,    100],
  [4,   25,    75,    115,   205],
  [5,   45,    125,   200,   355],
  [6,   75,    190,   320,   545],
  [7,   110,   270,   470,   770],
  [8,   150,   365,   645,   1030],
  [9,   205,   475,   850,   1315],
  [10,  265,   600,   1075,  1615],
  [11,  340,   740,   1315,  1925],
  [12,  420,   890,   1565,  2230],
  [13,  510,   1050,  1825,  2530],
  [14,  610,   1220,  2085,  2820],
  [15,  720,   1395,  2345,  3095],
  [16,  840,   1580,  2595,  3350],
  [17,  970,   1765,  2835,  3590],
  [18,  1105,  1955,  3070,  3815],
  [19,  1250,  2150,  3285,  4015],
  [20,  1405,  2340,  3490,  4200],
  [21,  1560,  2530,  3685,  4370],
  [22,  1725,  2720,  3865,  4525],
  [23,  1895,  2905,  4030,  4665],
  [24,  2065,  3090,  4180,  4795],
  [25,  2245,  3265,  4320,  4910],
  [26,  2425,  3440,  4450,  5015],
  [27,  2605,  3605,  4570,  5110],
  [28,  2790,  3770,  4680,  5195],
  [29,  2975,  3925,  4780,  5275],
  [30,  3155,  4075,  4870,  5345],
  [31,  3340,  4220,  4955,  5410],
  [32,  3525,  4360,  5035,  5470],
  [33,  3705,  4495,  5105,  5525],
  [34,  3885,  4620,  5170,  5575],
  [35,  4060,  4745,  5230,  5620],
  [36,  4235,  4860,  5290,  5660],
  [37,  4405,  4970,  5340,  5700],
  [38,  4570,  5075,  5385,  5735],
  [39,  4735,  5175,  5430,  5770],
  [40,  4895,  5270,  5470,  5800],
];
function lockInTiersForRound(round){
  const a = LOCKIN_ROUND_ANCHORS;
  if (round <= a[0][0]) return { one: a[0][1], two: a[0][2], three: a[0][3], four: a[0][4] };
  if (round >= a[a.length - 1][0]){
    const last = a[a.length - 1];
    return { one: last[1], two: last[2], three: last[3], four: last[4] };
  }
  for (let i = 0; i < a.length - 1; i++){
    const [r0, o0, t0, h0, e0] = a[i], [r1, o1, t1, h1, e1] = a[i + 1];
    if (round >= r0 && round <= r1){
      const f = (round - r0) / (r1 - r0);
      return { one: o0 + (o1 - o0) * f, two: t0 + (t1 - t0) * f, three: h0 + (h1 - h0) * f, four: e0 + (e1 - e0) * f };
    }
  }
}
function emptyElementsForScore(total, round){
  const t = lockInTiersForRound(round);
  if (total >= t.four) return 4;
  if (total >= t.three) return 3;
  if (total >= t.two) return 2;
  if (total >= t.one) return 1;
  return 0;
}
// Tier -> bonus dice for the trip: +0/+1/+2/+3 for tiers 0-3 (no penalty
// for tier 0). Tier 4 adds a "?" element on top of +3 (see finishLockIn()).
function diceDeltaForReward(reward){ return Math.min(reward, 3); }
/* Scores the mat as it stands now (not matLastScore, which could be stale).
   A zero reward only ends the run at sunset from BREAKPOINT_GATE_VISIT on,
   via askConfirm(); Cancel leaves the mat and drawer as they were so the
   player can rearrange and try again. Otherwise it proceeds. */
/* Set when a Lock-In commits: Home stays untappable until it becomes Roll
   at the station (cleared in goStation()), so the scoring can't run twice. */
var lockInCommitted = false; // var: updateHub() can read it before this line runs
// Does missing the first breakpoint end the run on this Lock-In? Only at a
// checkpoint from BREAKPOINT_GATE_VISIT on; in Overtime, every Lock-In.
const lockInGated = () => state.runComplete || (state.visits >= BREAKPOINT_GATE_VISIT && isSunsetVisit());
function confirmLockIn(){
  if (lockInCommitted) return;
  const s = matScore(matOnMat());
  state.bestMatScore = Math.max(state.bestMatScore || 0, s.total);
  const reward = emptyElementsForScore(s.total, matCheckRound());
  if (reward === 0){
    if (!lockInGated()){ lockInCommitted = true; updateHub(); finishLockIn(0); return; }
    askConfirm(state.runComplete
      ? `Your Display Mat only scored ${s.total.toLocaleString()} Quarks, not enough to clear the first Quark breakpoint. In Overtime, every Lock-In must clear it. End your run here?`
      : `Your Display Mat only scored ${s.total.toLocaleString()} Quarks at a checkpoint -- not enough to clear the first Quark breakpoint. From turn ${BREAKPOINT_GATE_VISIT} on, missing it at a checkpoint ends your run here. End it now?`,
      () => {
        lockInCommitted = true;
        state.finalGameOver = true;
        state.ended = true;
        save();
        closeDrawer();
        travelPromptFor = null;
        showEndGame();
      }
    );
    return;
  }
  lockInCommitted = true;
  updateHub();
  playLockInSequence(reward);
}
/* Which mat cards earned a given combo chip -- the same grouping as
   matGroupsOf(), re-run to recover membership so playLockInSequence() can
   bounce the right cards. */
function matCardsForCombo(kind, name){
  const mat = matOnMat();
  if (kind === "station") return mat.filter(c => c.stations.includes(name));
  if (kind === "suit") return mat.filter(c => c.pips.includes(name));
  if (kind === "component") return mat.filter(c => c.name === name || matDirectItems(c).has(name));
  if (kind === "collection"){
    const col = MAT_COLLECTIONS.find(c => c.id === name);
    return col ? mat.filter(c => col.items.includes(c.name)) : [];
  }
  return [];
}
// A quick in-place scale punch for something already on screen (unlike
// bounceCardAppear(), which pops in from invisible).
function bouncePulse(el){
  if (!el || lowMotion()) return;
  el.animate([
    { transform: "scale(1)" },
    { transform: "scale(1.35)", offset: .5 },
    { transform: "scale(1)" },
  ], { duration: LOCKIN_BOUNCE_DURATION_MS, easing: "cubic-bezier(.3,1.4,.4,1)" });
}
const LOCKIN_BOUNCE_STAGGER_MS = 220;
const LOCKIN_BOUNCE_DURATION_MS = 380;
/* The ordered scoring beats for the Lock-In reveal:
     1. every mat card, its plain points;
     2. every card whose full recipe is also on the mat (matIsComplete),
        bouncing with its ingredients, for its doubling bonus;
     3. every completed named collection, its members bouncing, for its
        bonus;
     4. every station/suit/component combo, in the combo row's order.
   Steps 1-3 add points (pointsDelta); step 4 adds multiplier (multDelta),
   matching matScore()'s (base + colBonus) * mult. chipKind/chipName let a
   beat bounce its combo chip. */
function lockInScoreBeats(mat, s){
  const beats = [];
  mat.forEach(c => beats.push({ cardNames: [c.name], pointsDelta: c.points, multDelta: 0 }));
  mat.forEach(c => {
    if (!matIsComplete(c, mat)) return;
    const need = matDirectItems(c);
    const groupNames = [c.name, ...mat.filter(m => need.has(m.name)).map(m => m.name)];
    beats.push({ cardNames: groupNames, pointsDelta: c.points, multDelta: 0 });
  });
  s.cols.forEach(col => beats.push({
    cardNames: matCardsForCombo("collection", col.id).map(c => c.name),
    pointsDelta: col.bonus, multDelta: 0,
    chipKind: "collection", chipName: COLLECTIONS_CHIP, colId: col.id,
  }));
  [...s.combos.station.map(g => ({ ...g, kind: "station" })),
   ...s.combos.suit.map(g => ({ ...g, kind: "suit" })),
   ...s.combos.component.map(g => ({ ...g, kind: "component" }))]
    .forEach(g => beats.push({
      cardNames: matCardsForCombo(g.kind, g.name).map(c => c.name),
      pointsDelta: 0, multDelta: g.bonus,
      chipKind: g.kind, chipName: g.name,
    }));
  // Capstone signatures: whatever the rules add beyond the beats above, as
  // one points beat and one multiplier beat, each bouncing its capstone.
  const sigCards = names => mat.filter(c => names.includes(c.name)).map(c => c.name);
  const ptsSoFar = beats.reduce((n, b) => n + b.pointsDelta, 0);
  const ptsSig = (s.base + s.colBonus) - ptsSoFar;
  if (ptsSig) beats.push({ cardNames: sigCards(["Robot", "Homestead", "Maglev Train", "Space Station"]), pointsDelta: ptsSig, multDelta: 0 });
  const multSig = s.mult - 1 - beats.reduce((n, b) => n + b.multDelta, 0);
  if (multSig) beats.push({ cardNames: sigCards(["Coral Reef", "Ecosystem"]), pointsDelta: 0, multDelta: multSig });
  return beats;
}
// Write the headline numbers directly -- a renderMatTop() mid-sequence would
// cancel bounces in flight. Same order as .mat-score-stats.
function setMatScoreNumbers(points, mult, total){
  // Only the Quark total is on screen now (see renderMatTop()'s own
  // compact meter line); points/mult are still passed in for its tooltip.
  const totalEl = document.querySelector("#drawerTop .qm-total");
  if (totalEl) totalEl.textContent = Math.round(total).toLocaleString();
}
// Same live write for the Quark Meter, using renderMatTop()'s fill math on
// the reveal's running total.
function setQuarkMeterProgress(total){
  const qmTiers = lockInTiersForRound(matCheckRound());
  const bounds = [0, qmTiers.one, qmTiers.two, qmTiers.three, qmTiers.four];
  const ranges = bounds.slice(1).map((hi, i) => [bounds[i], hi]);
  const segs = document.querySelectorAll("#drawerTop .qm-seg");
  ranges.forEach(([lo, hi], i) => {
    const seg = segs[i];
    if (!seg) return;
    const pct = hi > lo ? Math.max(0, Math.min(100, ((total - lo) / (hi - lo)) * 100)) : (total >= lo ? 100 : 0);
    const fill = seg.querySelector(".qm-seg-fill");
    if (fill) fill.style.transform = `scaleX(${pct / 100})`;
    seg.classList.toggle("lit", pct >= 100);
  });
  const passed = emptyElementsForScore(total, matCheckRound());
  document.querySelectorAll("#drawerTop .qm-break").forEach((b, i) => b.classList.toggle("lit", passed >= i + 1));
}
/* Lock-In reveal: the live numbers reset and then build back up one
   scoring beat at a time (lockInScoreBeats()) -- points and multiplier
   climb separately, while Quarks and the meter are recomputed after every
   beat. At the end the numbers snap to the real totals (a mat with no
   combos would otherwise never leave 0), Quarks bounce once more, and
   finishLockIn() runs (its modal is the one place the reward is shown).
   The timing is fixed; bouncePulse() itself handles reduced motion. */
function playLockInSequence(reward, onDone = finishLockIn){
  document.body.classList.add("lockin-playing"); // cleared when the reward modal opens
  const mat = matOnMat();
  const s = matLastScore || matScore(mat);
  const beats = lockInScoreBeats(mat, s);

  // The live view never rendered chips for first-time collections, so rebuild
  // the row with revealAll=true (first-timers hidden until their beat).
  const combosEl = document.querySelector("#drawerTop .mat-combos");
  if (combosEl){
    combosEl.innerHTML = matComboChipsHTML(s, true) ||
      `<span class="mm-combo-none">Three cards alike start a combo</span>`;
  }

  // Start the multiplier at 1 (matScore()'s mult = 1 + comboBonus), so each
  // combo beat lands exactly on the real value and Quarks are right from the
  // first beat.
  setMatScoreNumbers(0, 1, 0);
  setQuarkMeterProgress(0);

  let runningPoints = 0, runningMult = 1;
  beats.forEach((beat, i) => {
    setTimeout(() => {
      beat.cardNames.forEach(name => {
        bouncePulse(document.querySelector(`#matGrid [data-mat-card="${cssEsc(name)}"]`));
      });
      if (beat.chipKind && beat.chipName){
        const chipEl = document.querySelector(
          `#drawerTop .mat-combos .mm-combo[data-combo-kind="${beat.chipKind}"][data-combo-name="${cssEsc(beat.chipName)}"]`);
        // Discovery: a collection never locked in before is revealed on its beat
        // and saved to prefs straight away, so it shows on the live mat from now on.
        if (beat.chipKind === "collection" && chipEl){
          chipEl.classList.remove("discovering");
          if (!prefs.everUnlockedMatCollections.includes(beat.colId)){
            prefs.everUnlockedMatCollections.push(beat.colId);
            if (prefs.collectionClues) delete prefs.collectionClues[beat.colId];
            savePrefs();
            grantStars(STARS_DISCOVERY);
          }
          const countEl = chipEl.querySelector(".mm-ccount");
          if (countEl) countEl.textContent =
            s.cols.filter(c => prefs.everUnlockedMatCollections.includes(c.id)).length;
        }
        bouncePulse(chipEl);
      }
      runningPoints += beat.pointsDelta;
      runningMult += beat.multDelta;
      const runningTotal = runningPoints * runningMult;
      setMatScoreNumbers(runningPoints, runningMult, runningTotal);
      setQuarkMeterProgress(runningTotal);
    }, i * LOCKIN_BOUNCE_STAGGER_MS);
  });

  const afterBeats = beats.length * LOCKIN_BOUNCE_STAGGER_MS + LOCKIN_BOUNCE_DURATION_MS + 150;
  setTimeout(() => {
    setMatScoreNumbers(s.base + s.colBonus, s.mult, s.total);
    setQuarkMeterProgress(s.total);
    bouncePulse(document.querySelector("#drawerTop .qm-total"));
  }, afterBeats);
  const afterQuarks = afterBeats + LOCKIN_BOUNCE_DURATION_MS + 300;
  setTimeout(() => onDone(reward), afterQuarks);
}
// Apply the Lock-In reward and travel. Classic: the dice bonus lasts until
// the next check (state.matBonusDice); other modes: a one-trip delta
// (state.bonusDiceNextVisit) spent by the next doRoll(). The reward modal
// (showLockInRewardModal()) always shows, even for +0, and travel happens
// when it's dismissed. dest is captured up front.
function finishLockIn(reward, opts = {}){
  (state.checkLog || (state.checkLog = [])).push({ v: state.visits, q: Math.round(matScore(matOnMat()).total) });
  state.lastCheckedMat = [...state.mat]; // the mat's "Last" button
  // Old Growth: board checks in a row with Ecosystem on the mat.
  state.ecoStreak = matHas(matOnMat(), "Ecosystem") ? (state.ecoStreak || 0) + 1 : 0;
  document.body.classList.remove("lockin-playing"); // never leave input blocked
  const delta = diceDeltaForReward(reward);
  state.matChecked = true;
  state.matBonusDice = delta;
  // Tier 4 (the top breakpoint) also banks one "?" element.
  if (reward >= 4) state.emptyElements = (state.emptyElements || 0) + 1;
  save();
  const dest = selectedMapStation;
  // Fade to black (.5s), load the station behind it, fade back in on the
  // shop.
  const proceed = () => fadeThroughBlack(() => {
    // Snap the drawer shut under the black rather than letting its .3s
    // slide still be running when the station fades back in.
    drawer.style.transition = "none";
    closeDrawer();
    drawer.offsetHeight;
    drawer.style.transition = "";
    travelPromptFor = null;
    goStation(dest);
  });
  // skipToast: for a caller that skips playLockInSequence() and travels
  // directly.
  if (opts.skipToast){ proceed(); return; }
  showLockInRewardModal(delta, reward >= 4, proceed);
}
// Delay between each die's pop-in, via inline animation-delay (not a
// setTimeout chain, which a re-render could interrupt).
const LOCKIN_DICE_POP_STAGGER_MS = 150;
// Runs once when the modal is dismissed (Nice, backdrop tap or Escape),
// then cleared so it can't run twice.
let lockInRewardOnDone = null;
/* Lock-In reward modal: dice pop in left to right
   (LOCKIN_DICE_POP_STAGGER_MS); onDone continues finishLockIn() (close the
   drawer, travel) after the tap. Shown for every Lock-In -- n === 0 gets its
   own title and no dice. */
// Fade #fadeCurtain to black, run midpoint() while covered, fade back. Kept
// in low motion (a fade isn't movement).
const FADE_MS = 500;
function fadeThroughBlack(midpoint){
  const c = document.getElementById("fadeCurtain");
  c.classList.add("on");
  setTimeout(() => {
    midpoint();
    // A beat for the new screen to lay out before revealing it (a timer,
    // not requestAnimationFrame -- rAF pauses while the tab is hidden and
    // could leave the screen stuck on black).
    setTimeout(() => c.classList.remove("on"), 40);
  }, FADE_MS);
}
function showLockInRewardModal(n, gotEmptyElement, onDone){
  document.body.classList.remove("lockin-playing");
  // The title says it all: how many dice, for how long.
  document.getElementById("lockInRewardTitle").textContent = n === 0
    ? "No bonus dice this time"
    : `+${n} ${n === 1 ? "die" : "dice"} on your rolls for the next 3 turns`;
  const reduced = lowMotion();
  document.getElementById("lockInRewardDice").innerHTML = Array.from({length: n}, (_, i) =>
    `<span class="lockin-reward-die"${reduced ? "" : ` style="animation-delay:${i * LOCKIN_DICE_POP_STAGGER_MS}ms"`}>🎲</span>`).join("");
  // Top breakpoint's "?" (see finishLockIn()): its own line; tap the
  // square for what it does.
  const extra = document.getElementById("lockInRewardExtra");
  extra.hidden = !gotEmptyElement;
  extra.innerHTML = gotEmptyElement ? `
    <div class="lre-line"><span>+1 Unknown Element</span>
      <button type="button" class="lre-q" id="lockInRewardQ" aria-label="What's an Unknown Element?" aria-expanded="false">${emptyElSquareHTML(34)}</button></div>
    <p class="lre-hint" id="lockInRewardHint" hidden>Use it to gather any element from the station you're at -- open it from the Convert menu.</p>` : "";
  lockInRewardOnDone = onDone;
  openOverlay("lockInRewardOverlay");
}
function dismissLockInRewardModal(){
  closeOverlay("lockInRewardOverlay");
  const onDone = lockInRewardOnDone;
  lockInRewardOnDone = null;
  if (onDone) onDone();
}
document.getElementById("lockInRewardNice").addEventListener("click", dismissLockInRewardModal);
// A backdrop tap dismisses like Nice, so the pending travel still runs. The
// "?" square toggles its hint.
document.getElementById("lockInRewardOverlay").addEventListener("click", ev => {
  if (ev.target === ev.currentTarget){ dismissLockInRewardModal(); return; }
  const q = ev.target.closest("#lockInRewardQ");
  if (q){
    const hint = document.getElementById("lockInRewardHint");
    hint.hidden = !hint.hidden;
    q.setAttribute("aria-expanded", String(!hint.hidden));
  }
});

/* The final score: back on the map after turn 24's shopping, the mat
   opens for one last Lock-In (Home's "Final Score" face). Its Quarks count
   toward the run's score (state.bestMatScore, the top Quark score); then
   Run Complete. No travel and no reward dice. */
function startFinalCheck(){
  state.finalCheckPending = true;
  save();
  matDrawerView = "mat";
  playShutter("Final Score!", () => { openDrawer(); updateHub(); });
}
function confirmFinalLockIn(){
  if (lockInCommitted) return;
  lockInCommitted = true;
  const s = matScore(matOnMat());
  state.bestMatScore = Math.max(state.bestMatScore || 0, s.total);
  updateHub();
  playLockInSequence(0, () => finishFinalCheck(s.total));
}
function finishFinalCheck(total){
  document.body.classList.remove("lockin-playing");
  (state.checkLog || (state.checkLog = [])).push({ v: state.visits, q: Math.round(total), final: true });
  state.finalCheckPending = false;
  lockInCommitted = false;
  closeDrawer();
  state.runComplete = true;
  grantStars(STARS_RUN);
  save();
  fireConfetti();
  showEndGame();
}
/* Scene change into a board check: two panels slide in from the top and
   bottom, meet in the middle with the round and line2, and part again.
   atClosed runs while the screen is covered (open the mat there). Low
   motion: atClosed straight away. Input is blocked while it plays. */
const SHUTTER_CLOSE_MS = 480, SHUTTER_HOLD_MS = 1100;
function playShutter(line2, atClosed){
  if (lowMotion()){ atClosed(); return; }
  const el = document.getElementById("shutter");
  el.querySelector(".sh-l1").textContent = `Round ${state.visits} / ${RUN_COMPLETE_VISIT}`;
  el.querySelector(".sh-l2").textContent = line2;
  el.classList.add("on");
  el.offsetHeight; // start from open, so the panels slide in
  el.classList.add("closed");
  setTimeout(atClosed, SHUTTER_CLOSE_MS);
  setTimeout(() => el.classList.remove("closed"), SHUTTER_CLOSE_MS + SHUTTER_HOLD_MS);
  setTimeout(() => el.classList.remove("on"), SHUTTER_CLOSE_MS * 2 + SHUTTER_HOLD_MS);
}
/* A board check opening (hub's Travel on a checkpoint turn): the shutter
   scene change, with the mat opening behind it; the very first check ever
   also opens the Display Mat rules (prefs.sawMatCheckTutorial). */
function announceMatCheck(){
  if (!prefs.sawMatCheckTutorial){
    prefs.sawMatCheckTutorial = true; savePrefs();
    openMatRules();
  }
}
document.getElementById("matCheckTutorial").innerHTML = `
  <p class="mct-line">🕒 Your Display Mat is scored <b>every 3 turns</b> -- the big numbers on the clock.</p>
  <p class="mct-line">🎲 Your <b>Quark Score</b> earns <b>bonus dice</b> for each of the next 3 stations. Reach the top breakpoint for a <b>"?"</b> element too.</p>
  <p class="mct-line mct-warn">⚠️ From turn ${BREAKPOINT_GATE_VISIT}, a score below the first breakpoint <b>ends your run</b>.</p>`;

// Fill-in for the mat rules popup's two summary lines.
document.getElementById("lockInBannerSub").innerHTML =
  `<span>⚛️ Generate Quarks from your Card Display.</span>` +
  `<span>🎲 More Quarks = More Elements at the next Station</span>`;
// Fill-in for the Quark Score explainer, reusing buildMatFilterBar()'s icon
// markup as plain spans (no click wiring).
document.getElementById("lockInQuarkTutorial").innerHTML = `
  <div>Quark Score = Display Score × Combo Multiplier</div>
  <div>Complete item recipes DOUBLE the points for that item!</div>
  <div>Build Combo Multiplier by matching 3+ icons</div>
  <div class="liqt-icons">${Object.keys(MAP_NODE_POS).map(s => {
    const m = STATION_BY_NAME[s];
    return `<span class="liqt-ic" style="--st:${DATA.suits[m.suit].color}" title="${esc(s)}">${em(m.emoji)}</span>`;
  }).join("")}</div>
  <div class="liqt-icons">${Object.keys(ELEMENT_SUIT_LABEL).map(s =>
    `<span class="liqt-ic" style="--suit:${SUIT_COLOR[s]}" title="${esc(ELEMENT_SUIT_LABEL[s])}">${SUIT_ICON[s]}</span>`).join("")}</div>
  <div>Ingredient items count toward Combo Multiplier too!</div>
  <div class="liqt-icons">${["Water","Sand","Tree","Wheel"].map(n =>
    `<span class="liqt-ic" title="${esc(n)}">${ITEM_EMOJI[n] ? em(ITEM_EMOJI[n]) : esc(n)}</span>`).join("")}</div>`;
