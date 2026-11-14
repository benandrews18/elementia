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
// Official board checks (every MAT_CHECK_EVERY-th round): breakpoints x
// (1 + this), tuned in tools/quark_breakpoint_tuner.html.
const OFFICIAL_CHECK_BUMP = 0.25;
function lockInTiersForRound(round){
  const t = baseTiersForRound(round);
  if (round % MAT_CHECK_EVERY !== 0) return t;
  const up = v => Math.round(v * (1 + OFFICIAL_CHECK_BUMP) / 5) * 5;
  return { one: up(t.one), two: up(t.two), three: up(t.three), four: up(t.four) };
}
function baseTiersForRound(round){
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
/* Quiet check: every trip that isn't a board check. The mat's score now
   sets this trip's dice (state.tripDice), never below the last board
   check's (state.matBonusDice, the floor). No shutter, no "?", never ends
   the run, and check orders don't apply. */
function quietCheck(){
  if (!state.matChecked) return;
  const total = matScore(matOnMat()).total;
  const quiet = diceDeltaForReward(emptyElementsForScore(total, state.visits));
  const floor = state.matBonusDice || 0;
  state.tripDice = Math.max(floor, quiet);
}

/* Check orders ("challenges"): each board check STARTS one, revealed on its
   shutter (startCheckOrder()), and it lasts MAT_CHECK_EVERY rounds: that
   check plus the quiet checks until the next one (state.order = {id, p,
   round}, round = the check that started it). Requests (from checks up to
   ORDER_LAST_REQUEST) multiply the Quarks by ORDER_REQUEST_MULT when met;
   restrictions (later) by ORDER_RESTRICT_MULT when broken. Round
   RUN_COMPLETE_VISIT's final check is the Grand Exhibition: a high target
   (GRAND_EXHIBITION_TARGET), nothing else. Only orders the player's owned
   cards can satisfy are drawn, and none repeats. */
const ORDER_REQUEST_MULT = 1.5, ORDER_RESTRICT_MULT = 0.75, ORDER_LAST_REQUEST = 12;
const GRAND_EXHIBITION_TARGET = Math.round(lockInTiersForRound(RUN_COMPLETE_VISIT).two);
const ORDER_SUITS = Object.keys(ELEMENT_SUIT_LABEL);
const matStationCount = (mat, st) => matGroupsOf(mat).st[st] || 0;
const CHECK_ORDERS = {
  stationWeek: { kind: "request", name: "Station Week",
    icon: p => em(STATION_BY_NAME[p].emoji), text: p => `3+ ${em(STATION_BY_NAME[p].emoji)}`, desc: p => `3 ${p} cards`,
    params: owned => Object.keys(STATION_BY_NAME).filter(st => matStationCount(owned, st) >= 3),
    ok: (mat, p) => matStationCount(mat, p) >= 3 },
  rainbow: { kind: "request", name: "Rainbow",
    icon: () => "🌈", desc: () => "All 4 element colours", text: () => ORDER_SUITS.map(su => `<span class="ord-suit" style="--suit:${SUIT_COLOR[su]}">${SUIT_ICON[su]}</span>`).join(""),
    params: owned => ORDER_SUITS.every(su => owned.some(c => c.pips.includes(su))) ? [null] : [],
    ok: mat => ORDER_SUITS.every(su => mat.some(c => c.pips.includes(su))) },
  collector: { kind: "request", name: "Collector",
    icon: () => "★", text: () => "★ ✓", desc: () => "1 Named collection",
    params: owned => matCompletedIn(owned).length ? [null] : [],
    ok: mat => matCompletedIn(mat).length > 0 },
  freshFaces: { kind: "restriction", name: "Fresh Faces",
    icon: () => "🆕", text: () => "↺ ≤ ½", desc: () => "Half your cards or fewer from the last check",
    params: () => (state.lastCheckedMat || []).length ? [null] : [],
    ok: mat => { const last = state.lastCheckedMat || []; return mat.filter(c => last.includes(c.name)).length * 2 <= mat.length; } },
  drought: { kind: "restriction", name: "Drought",
    icon: p => SUIT_ICON[p], desc: p => `No ${ELEMENT_SUIT_LABEL[p][0]}${ELEMENT_SUIT_LABEL[p].slice(1).toLowerCase()} cards`, text: p => `🚫 <span class="ord-suit" style="--suit:${SUIT_COLOR[p]}">${SUIT_ICON[p]}</span>`,
    params: () => ORDER_SUITS, ok: (mat, p) => !mat.some(c => c.pips.includes(p)) },
  shortTable: { kind: "restriction", name: "Short Table",
    icon: () => "🪑", text: () => "⬜ 1+", desc: () => "1 empty slot",
    params: () => [null], ok: mat => matOccupancy(mat) < matLayout(mat).slots },
  trendShift: { kind: "restriction", name: "Trend Shift",
    icon: p => em(STATION_BY_NAME[p].emoji), text: p => `🚫 3+ ${em(STATION_BY_NAME[p].emoji)}`, desc: p => `No ${p} combo`,
    params: () => state.lastTopStation ? [state.lastTopStation] : [], ok: (mat, p) => matStationCount(mat, p) < 3 },
};
function drawOrder(round, avoid){
  if (round > RUN_COMPLETE_VISIT) return null;
  if (round === RUN_COMPLETE_VISIT) return { id: "grand", p: null, round };
  const kind = round <= ORDER_LAST_REQUEST ? "request" : "restriction";
  const owned = state.items.map(n => MAT_CARD_BY_NAME[n]).filter(Boolean);
  // Never avoid itself; and no exact repeat of any order this run
  // (state.usedOrders) while a fresh one is possible.
  const all = Object.keys(CHECK_ORDERS).filter(id => CHECK_ORDERS[id].kind === kind)
    .flatMap(id => CHECK_ORDERS[id].params(owned).map(p => ({ id, p, round })))
    .filter(o => !avoid || orderKey(o) !== orderKey(avoid));
  const used = new Set(state.usedOrders || []);
  const fresh = all.filter(o => !used.has(orderKey(o)));
  const pool = fresh.length ? fresh : all;
  return pool.length ? pool[Math.floor(Math.random() * pool.length)] : null;
}
const orderKey = o => o.id + ":" + o.p;
// Sets the upcoming order and remembers it so it isn't drawn again.
function setOrder(o){
  state.order = o;
  if (o) (state.usedOrders || (state.usedOrders = [])).push(orderKey(o));
}
// The challenge in force this round: from the check that started it until
// the next check's shutter. None before the first check, or (early on) when
// the player's cards can't satisfy any.
function currentOrder(){
  if (typeof comboLabActive !== "undefined" && comboLabActive) return null;
  const o = state.order;
  return o && state.visits >= o.round && state.visits < o.round + MAT_CHECK_EVERY ? o : null;
}
// A board check's shutter: draw this check's challenge (once -- backing out
// and travelling again keeps it), never the one it replaces.
function startCheckOrder(){
  if (state.order && state.order.round === state.visits) return;
  setOrder(drawOrder(state.visits, state.order));
}
// Is the mat meeting the order (requests), keeping to it (restrictions), or
// reaching the target (Grand Exhibition)?
function orderMet(o, mat, total){
  return o.id === "grand" ? total >= GRAND_EXHIBITION_TARGET : CHECK_ORDERS[o.id].ok(mat, o.p);
}
// The order's multiplier on matScore(), only while its board check is the
// one underway (never on quiet checks or saved-layout previews elsewhere).
function orderMultFor(mat){
  const o = currentOrder();
  if (!o || o.id === "grand") return 1;
  const ok = CHECK_ORDERS[o.id].ok(mat, o.p);
  return CHECK_ORDERS[o.id].kind === "request" ? (ok ? ORDER_REQUEST_MULT : 1) : (ok ? 1 : ORDER_RESTRICT_MULT);
}
function orderMultLabel(o){
  return o.id === "grand" ? GRAND_EXHIBITION_TARGET.toLocaleString()
    : CHECK_ORDERS[o.id].kind === "request" ? `×${ORDER_REQUEST_MULT}` : `×${ORDER_RESTRICT_MULT}`;
}
function orderIconHTML(o){ return o.id === "grand" ? "🏛️" : CHECK_ORDERS[o.id].icon(o.p); }
function orderName(o){ return o.id === "grand" ? "Grand Exhibition" : CHECK_ORDERS[o.id].name; }
// Combo-row chip (matComboChipsHTML(..., true)) for the challenge in force:
// lit when met, red when a restriction is broken. Tap: openOrderInfo().
function orderChipHTML(s){
  const o = currentOrder();
  if (!o) return "";
  const ok = orderMet(o, matOnMat(), s.total);
  const restr = o.id !== "grand" && CHECK_ORDERS[o.id].kind === "restriction";
  const cls = restr ? (ok ? "off" : "bad") : (ok ? "on" : "off");
  return `<button type="button" class="mm-combo order ${cls}" data-order title="${esc(orderName(o))} (rounds ${o.round}-${o.round + MAT_CHECK_EVERY - 1})"><span class="mm-cico order-ic">${orderIconHTML(o)}</span><b>${orderMultLabel(o)}</b></button>`;
}
function orderShutterLine(){
  const o = currentOrder();
  if (!o) return "";
  if (o.id === "grand") return `🏛️ Grand Exhibition: reach ${GRAND_EXHIBITION_TARGET.toLocaleString()} Quarks!`;
  const d = CHECK_ORDERS[o.id];
  return `${d.kind === "request" ? "Request" : "Restriction"}: ${d.name} (${orderMultLabel(o)})`;
}
// A small clock face: ticks round the inside edge, the round number in
// the middle (no clock numerals).
function roundClockSVG(n){
  const ticks = Array.from({ length: 12 }, (_, i) => {
    const a = i * Math.PI / 6, r1 = i % 3 ? 22 : 19, r2 = 25.5;
    const p = r => `${(30 + Math.sin(a) * r).toFixed(1)} ${(30 - Math.cos(a) * r).toFixed(1)}`;
    return `<path d="M${p(r1)} L${p(r2)}"/>`;
  }).join("");
  return `<svg viewBox="0 0 60 60" aria-hidden="true"><circle cx="30" cy="30" r="28" fill="#fff7e0" stroke="#a8730f" stroke-width="3"/>
    <g stroke="#5e4026" stroke-width="2" stroke-linecap="round">${ticks}</g>
    <text x="30" y="31" text-anchor="middle" dominant-baseline="central" font-size="21" font-weight="900" fill="#3b2412">${n}</text></svg>`;
}
function openOrderInfo(){
  const o = currentOrder();
  if (!o) return;
  // Round clock in the top-left corner, a short title on the banner, one
  // line of text, the rule in icons, and the swap button.
  const clock = `<div class="ord-clock" title="Started at the round ${o.round} board check">${roundClockSVG(o.round)}</div>`;
  const okBtn = `<button type="button" class="bigbtn" id="orderInfoOk">OK</button>`;
  let title, html;
  if (o.id === "grand"){
    title = "Grand Exhibition!";
    html = `${clock}<p class="ord-desc">Reach ${GRAND_EXHIBITION_TARGET.toLocaleString()} ⚛️ at the final check</p>
      <div class="ord-rule">⚛️ ${GRAND_EXHIBITION_TARGET.toLocaleString()}</div>
      <div class="btnrow ord-btns">${okBtn}</div>`;
  } else {
    const d = CHECK_ORDERS[o.id], req = d.kind === "request";
    title = `${o.id === "stationWeek" ? o.p : d.name} ${req ? "Request" : "Restriction"}!`;
    const canReroll = (state.emptyElements || 0) > 0 && !lockInCommitted && !!drawOrder(o.round, o);
    html = `${clock}<p class="ord-desc">${esc(d.desc(o.p))}: ×${req ? ORDER_REQUEST_MULT : ORDER_RESTRICT_MULT}⚛️${req ? "" : " if broken"}</p>
      <div class="ord-rule">${d.text(o.p)}</div>
      <div class="btnrow ord-btns"><button type="button" class="bigbtn sec order-reroll" id="orderReroll" ${canReroll ? "" : "disabled"} title="Swap for another challenge" aria-label="Swap for another challenge, costs 1 Unknown Element"><span class="ord-reroll-ic">↻</span>${emptyElSquareHTML(22)}</button>${okBtn}</div>`;
  }
  document.getElementById("comboInfoTitle").textContent = title;
  document.getElementById("comboInfoBody").innerHTML = html;
  openOverlay("comboInfoOverlay");
}
document.getElementById("comboInfoOverlay").addEventListener("click", ev => {
  if (ev.target.closest("#orderInfoOk")){ closeOverlay("comboInfoOverlay"); return; }
  if (!ev.target.closest("#orderReroll:not(:disabled)")) return;
  const o = currentOrder(), next = o && drawOrder(o.round, o);
  if (!next || !(state.emptyElements > 0)) return;
  state.emptyElements -= 1;
  setOrder(next);
  save(); render();
  if (drawer.classList.contains("open")) renderMatTop();
  openOrderInfo();
});
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
  document.body.classList.add("lockin-layers"); // kept until that modal has popped in (endLockInLayers())
  const mat = matOnMat();
  const s = matLastScore || matScore(mat);
  const beats = lockInScoreBeats(mat, s);

  // The live view never rendered chips for first-time collections, so rebuild
  // the row with revealAll=true (first-timers hidden until their beat).
  const combosEl = document.querySelector("#drawerTop .mat-combos");
  if (combosEl){
    combosEl.innerHTML = matComboChipsHTML(s, true, true) ||
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
    bouncePulse(document.querySelector("#drawerTop .mm-combo.order"));
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
  const order = state.order && state.order.round === state.visits ? state.order : null;
  const orderOk = order ? orderMet(order, matOnMat(), 0) : null;
  const logEntry = { v: state.visits, q: Math.round(matScore(matOnMat()).total) };
  if (order){ logEntry.o = order.id; logEntry.ok = orderOk; }
  (state.checkLog || (state.checkLog = [])).push(logEntry);
  // Trend Shift's station: the biggest station combo on this mat.
  const st = Object.entries(matGroupsOf(matOnMat()).st).filter(([, n]) => n >= 3).sort((a, b) => b[1] - a[1])[0];
  state.lastTopStation = st ? st[0] : null;
  state.lastCheckedMat = [...state.mat]; // the mat's "Last" button
  // Old Growth: board checks in a row with Ecosystem on the mat.
  state.ecoStreak = matHas(matOnMat(), "Ecosystem") ? (state.ecoStreak || 0) + 1 : 0;
  document.body.classList.remove("lockin-playing"); // never leave input blocked
  endLockInLayers();
  const delta = diceDeltaForReward(reward);
  state.matChecked = true;
  state.matBonusDice = delta; // the floor until the next board check
  state.tripDice = delta;
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
// The count's GPU layers (will-change) and paused background pulses stay
// until the reward window has finished popping in: dropping them at the
// same moment it opens repainted the whole drawer and hitched the hand-off.
function endLockInLayers(){
  setTimeout(() => document.body.classList.remove("lockin-layers"), 900);
}
function showLockInRewardModal(n, gotEmptyElement, onDone){
  document.body.classList.remove("lockin-playing");
  // "Bonus Dice", a "+" and the dice; the corner "?" says why.
  const reduced = lowMotion();
  document.getElementById("lockInRewardDice").innerHTML = n === 0
    ? '<span class="lre-none">No bonus dice this time</span>'
    : '<span class="lre-plus">+</span>' + Array.from({length: n}, (_, i) =>
      `<span class="lockin-reward-die"${reduced ? "" : ` style="animation-delay:${i * LOCKIN_DICE_POP_STAGGER_MS}ms"`}>🎲</span>`).join("");
  const quarks = Math.round(matScore(matOnMat()).total).toLocaleString();
  const why = document.getElementById("lockInRewardWhy");
  why.hidden = true;
  document.getElementById("lockInRewardWhyBtn").setAttribute("aria-expanded", "false");
  why.innerHTML = n === 0
    ? `⚛️ ${quarks}: below the first breakpoint<br>No bonus dice this time`
    : `⚛️ ${quarks} → 🎲 +${n} at every station<br>until the next board check`;
  // Top breakpoint's "?" (see finishLockIn()): its own line; tap the
  // square for what it does.
  const extra = document.getElementById("lockInRewardExtra");
  extra.hidden = !gotEmptyElement;
  extra.innerHTML = gotEmptyElement ? `
    <div class="lre-line"><span>+1 Unknown Element</span>
      <button type="button" class="lre-q" id="lockInRewardQ" aria-label="What's an Unknown Element?" aria-expanded="false">${emptyElSquareHTML(34)}</button></div>
    <p class="lre-hint" id="lockInRewardHint" hidden>Becomes any element at your station<br>Use it from the Convert menu</p>` : "";
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
  if (ev.target.closest("#lockInRewardWhyBtn")){
    const why = document.getElementById("lockInRewardWhy");
    why.hidden = !why.hidden;
    ev.target.closest("#lockInRewardWhyBtn").setAttribute("aria-expanded", String(!why.hidden));
    return;
  }
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
  startCheckOrder();
  playShutter("Final Score!", () => { openDrawer(); updateHub(); orderInfoPending = true; continueCheckIntro(); }, orderShutterLine());
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
  document.body.classList.remove("lockin-playing"); endLockInLayers();
  (state.checkLog || (state.checkLog = [])).push({ v: state.visits, q: Math.round(total), final: true });
  state.grandExhibition = total >= GRAND_EXHIBITION_TARGET;
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
function playShutter(line2, atClosed, line3 = ""){
  if (lowMotion()){ atClosed(); return; }
  const el = document.getElementById("shutter");
  el.querySelector(".sh-l1").textContent = `Round ${state.visits} / ${RUN_COMPLETE_VISIT}`;
  el.querySelector(".sh-l2").textContent = line2;
  el.querySelector(".sh-l3").textContent = line3;
  el.querySelector(".sh-l3").hidden = !line3;
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
  orderInfoPending = true;
  if (!prefs.sawMatCheckTutorial){
    prefs.sawMatCheckTutorial = true; savePrefs();
    orderTipAfterRules = true; // the challenge windows follow the rules
    openMatRules();
    return;
  }
  continueCheckIntro();
}
// Next window of a board check's opening: the challenge intro (once per
// run), then this check's challenge (openOrderInfo()).
let orderInfoPending = false;
function continueCheckIntro(){
  if (maybeShowOrderTip()) return;
  if (!orderInfoPending) return;
  orderInfoPending = false;
  const o = currentOrder();
  if (o && o.round === state.visits) openOrderInfo();
}
/* Display Mat Challenges (check orders): explained the first time a run
   reaches a board check that has one (state.sawOrderTip), unless hidden
   with its corner ✕. */
let orderTipAfterRules = false;
function maybeShowOrderTip(){
  const o = state.order;
  if (!o || o.round !== state.visits || state.sawOrderTip || tipHidden("orderTip")) return false;
  state.sawOrderTip = true; save();
  openOrderTip();
  return true;
}
function openOrderTip(){
  document.getElementById("orderTipBody").innerHTML = `
    <p class="mct-line">🎲 Your <b>Quark Score</b> earns <b>bonus dice</b></p>
    <p class="mct-line">✅ <b>Requests</b>: ×${ORDER_REQUEST_MULT} ⚛️<br>⛔ <b>Restrictions</b>: ×${ORDER_RESTRICT_MULT} ⚛️</p>`;
  openOverlay("orderTip");
}
document.getElementById("orderTip").addEventListener("click", ev => {
  if (ev.target.closest("#orderTipHide")) hideTipForever("orderTip");
  else if (!ev.target.closest("#orderTipOk") && ev.target.id !== "orderTip") return;
  closeOverlay("orderTip");
});
document.getElementById("matCheckTutorial").innerHTML = `
  <p class="mct-line">🕒 Display Mat <b>challenge</b> every 3 turns</p>
  <p class="mct-line">🎲 Your <b>Quark Score</b> earns <b>bonus dice</b></p>
  <p class="mct-line mct-warn">⚠️ A score below the first breakpoint <b>ends your run</b>.</p>`;

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
