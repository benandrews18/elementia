/* Elementia simulator player. Injected into the real game page by
   run_sim.mjs: it plays whole runs through the game's own rule code
   (goStation, doRoll, craft, startCheckOrder, confirmLockIn, quietCheck,
   matScore, ...) with the screen-only parts (animations, windows,
   rendering) switched off.

   The player is goal-directed, guided by real play (window.SIM_GUIDE):
   - layouts: saved Display Mat layouts. Each run picks one as its plan,
     starts at its capstone's station, and chases the plan's items and
     their components; a finished plan gives way to the next.
   - runs: History exports. How often players crafted each item (crafting
     outside the plan) and where they went next (station choice).
   Things a player can do by hand that the rules code doesn't (convert 3:1,
   spend a "?", pay suit costs, collect a Market row's "?") are done here
   with the game's own rates and helpers.

   simPlay(n, opts) -> [run], each in the History export format plus
   `sim` (plan names, game over). */
(() => {
  // ---- deterministic dice: one seeded generator for the whole page
  let seed = 1;
  Math.random = () => {
    seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
  const rnd = () => Math.random();
  const pickWeighted = pairs => {
    const tot = pairs.reduce((s, [, w]) => s + Math.max(0, w), 0);
    let r = rnd() * tot;
    for (const [x, w] of pairs){ r -= Math.max(0, w); if (r <= 0) return x; }
    return pairs.length ? pairs[pairs.length - 1][0] : null;
  };

  // ---- screen-only code off
  const noop = () => {};
  ["render", "updateHub", "renderMatTop", "openOverlay", "closeOverlay", "openDrawer", "closeDrawer",
   "queueEventToast", "launchMinigame", "playRollAnimation", "scheduleBingoSequence", "tryWalkthroughTip",
   "showEndGame", "fireConfetti", "playShutter", "save", "savePrefs", "renderTrackedPill",
   "showTutorialHintOnce", "scheduleCraftedEverythingEnd", "flushPendingMouseTip", "endLockInLayers",
   "queueUnlockReveal", "maybeShowMatExpansion"].forEach(n => { if (typeof window[n] === "function") window[n] = noop; });
  window.playLockInSequence = (reward, onDone = finishLockIn) => onDone(reward);
  window.showLockInRewardModal = (n, gotEmpty, onDone) => onDone();
  window.fadeThroughBlack = midpoint => midpoint();
  window.askConfirm = (msg, yes) => yes(); // a missed gate: end the run, as a player must

  // ---- what real play tells us
  const G = window.SIM_GUIDE || { runs: [], layouts: [] };
  const itemFreq = {}, trans = {};
  G.runs.forEach(r => {
    const crafted = new Set(r.visitLog.flatMap(t => t.items));
    crafted.forEach(n => itemFreq[n] = (itemFreq[n] || 0) + 1 / G.runs.length);
    r.visitLog.forEach((t, i) => {
      const prev = r.visitLog[i - 1];
      if (!prev) return;
      (trans[prev.station] || (trans[prev.station] = {}))[t.station] = ((trans[prev.station] || {})[t.station] || 0) + 1;
    });
  });
  const transP = (a, b) => {
    const row = trans[a]; if (!row) return 0;
    const tot = Object.values(row).reduce((s, x) => s + x, 0);
    return (row[b] || 0) / tot;
  };
  const layouts = G.layouts.filter(l => l.items.every(n => MAT_CARD_BY_NAME[n]));
  const layoutValue = l => +(l.name.match(/^\d+/) || [1500])[0];

  // ---- recipes
  const entryAt = (name, st) => ENTRIES.find(e => e.name === name && (!st || e.station === st));
  const shopAt = st => ENTRIES.filter(e => e.station === st && itemOpen(e.name) && !owns(e.name));
  const stationsSelling = name => [...new Set(ENTRIES.filter(e => e.name === name).map(e => e.station))];

  // ---- per-run tallies for the report (reset by playRun())
  let T = null;
  const tally = (o, k, n = 1) => { o[k] = (o[k] || 0) + n; };

  // ---- the plan: a layout's items and everything under them
  let plan = null, want = {};
  function closureOf(names){
    const out = new Set();
    const walk = n => { if (out.has(n)) return; out.add(n); const e = entryAt(n); if (e) needsOf(e.reqs).items.forEach(i => walk(i.name)); };
    names.forEach(walk);
    return out;
  }
  function choosePlan(){
    const open = layouts.filter(l => !l.items.every(owns) && l !== plan);
    if (!open.length){ plan = null; want = {}; return; }
    setPlan(pickWeighted(open.map(l => [l, (l.items.filter(owns).length / l.items.length + 0.25) * layoutValue(l)])));
  }
  function setPlan(l){
    plan = l;
    want = {};
    closureOf(plan.items).forEach(n => { want[n] = 2; });
    plan.items.forEach(n => { want[n] = ITEM_TIER[n] === "CAPSTONE" ? 6 : 3; });
  }
  const weightOf = n => (want[n] || 0) + (itemFreq[n] || 0);

  // ---- elements
  const take = (sym, n = 1) => { state.elements[sym] = count(sym) - n; if (state.elements[sym] <= 0) delete state.elements[sym]; };
  const give = sym => { state.elements[sym] = count(sym) + 1; };
  // Elements held back for the top wanted items whose parts are owned.
  function reserve(){
    const r = {};
    Object.keys(want).filter(n => !owns(n) && itemOpen(n)).map(n => entryAt(n)).filter(e => e && itemReqsMet(e))
      .sort((a, b) => weightOf(b.name) - weightOf(a.name)).slice(0, 3)
      .forEach(e => Object.entries(needsOf(e.reqs).els).forEach(([s, k]) => r[s] = (r[s] || 0) + k));
    return r;
  }
  // What e still lacks: recipe elements, then suit costs paid from what's left.
  function shortfall(e, have = state.elements){
    const c = s => have[s] || 0;
    const { els } = needsOf(e.reqs);
    const miss = {};
    Object.entries(els).forEach(([s, k]) => { if (c(s) < k) miss[s] = k - c(s); });
    const suitMiss = {};
    Object.entries(suitCostNeed(e)).forEach(([su, k]) => {
      const surplus = (SUIT_CORE_ELEMENTS[su] || []).reduce((n, s) => n + Math.max(0, c(s) - (els[s] || 0)), 0);
      if (surplus < k) suitMiss[su] = k - surplus;
    });
    return { miss, suitMiss, total: Object.values(miss).reduce((a, b) => a + b, 0) + Object.values(suitMiss).reduce((a, b) => a + b, 0) };
  }
  // Pay e's suit cost (largest surplus first, sparing the reserve), then craft.
  function payAndCraft(e){
    if (!canCraft(e) || !suitCostPayable(e)) return false;
    const { els } = needsOf(e.reqs), keep = reserve();
    for (const [su, k] of Object.entries(suitCostNeed(e))){
      for (let i = 0; i < k; i++){
        const sym = (SUIT_CORE_ELEMENTS[su] || []).filter(s => count(s) > (els[s] || 0))
          .sort((a, b) => (count(b) - (els[b] || 0) - (keep[b] || 0)) - (count(a) - (els[a] || 0) - (keep[a] || 0)))[0];
        if (!sym) return false;
        take(sym);
      }
    }
    if (!craft(e)) return false;
    // A finished Market row pays one "?" (runBingoSequence(), screen-only here).
    const lines = state.pendingBingoClears || [];
    state.emptyElements = (state.emptyElements || 0) + lines.length;
    state.pendingBingoClears = [];
    if (plan && plan.items.every(owns)) choosePlan();
    return true;
  }
  // Fill e's shortfall by converting 3:1 (elements e doesn't need) and
  // spending "?" (this station's dice only). False if it can't be done.
  function enable(e){
    const { miss, suitMiss, total } = shortfall(e);
    if (!total || total > 3) return !total;
    const { els } = needsOf(e.reqs), keep = reserve();
    const dice = sortedDice(STATION_BY_NAME[current]);
    const todo = [...Object.entries(miss).flatMap(([s, k]) => Array(k).fill(s)),
      ...Object.entries(suitMiss).flatMap(([su, k]) => Array(k).fill("suit:" + su))];
    const plan_ = [];
    const spare = {};
    Object.keys(state.elements).forEach(s => spare[s] = count(s) - (els[s] || 0) - (keep[s] || 0));
    let q = state.emptyElements || 0;
    for (const need of todo){
      const target = need.startsWith("suit:") ? SUIT_CORE_ELEMENTS[need.slice(5)].find(s => dice.includes(s)) || SUIT_CORE_ELEMENTS[need.slice(5)][0] : need;
      if (q > 0 && dice.includes(target)){ q--; plan_.push(["?", target]); continue; }
      const from = Object.keys(spare).filter(s => spare[s] >= CONVERT_RATE && s !== target).sort((a, b) => spare[b] - spare[a])[0];
      if (!from) return false;
      spare[from] -= CONVERT_RATE;
      plan_.push([from, target]);
    }
    // Try it on a copy first: a conversion can eat what the suit cost needed.
    const after = { ...state.elements };
    plan_.forEach(([from, to]) => { if (from !== "?") after[from] -= CONVERT_RATE; after[to] = (after[to] || 0) + 1; });
    if (shortfall(e, after).total) return false;
    plan_.forEach(([from, to]) => {
      if (from === "?"){ state.emptyElements -= 1; T.qSpent++; } else { take(from, CONVERT_RATE); tally(T.convFrom, from); tally(T.convTo, to); }
      give(to);
    });
    return true;
  }
  // One station visit's shopping.
  function shop(){
    for (let guard = 0; guard < 40; guard++){
      const items = shopAt(current).filter(itemReqsMet);
      const ready = items.filter(e => canCraft(e) && suitCostPayable(e));
      const wanted = ready.filter(e => want[e.name]).sort((a, b) => weightOf(b.name) - weightOf(a.name));
      if (wanted.length){ payAndCraft(wanted[0]); continue; }
      // A wanted item a convert or "?" away.
      const near = items.filter(e => want[e.name] && !canCraft(e) || want[e.name] && !suitCostPayable(e))
        .sort((a, b) => weightOf(b.name) - weightOf(a.name));
      if (near.some(e => enable(e) && payAndCraft(e))) continue;
      // Anything else players tend to make, if it spares the reserve.
      const keep = reserve();
      const extra = ready.filter(e => {
        const { els } = needsOf(e.reqs);
        return Object.entries(els).every(([s, k]) => count(s) - k >= (keep[s] || 0))
          && rnd() < 0.35 + 0.65 * (itemFreq[e.name] || 0);
      });
      if (extra.length){ payAndCraft(extra[0]); continue; }
      break;
    }
    // What held back the wanted items here (parts owned, elements short).
    shopAt(current).filter(e => want[e.name] && itemReqsMet(e)).forEach(e => {
      const { miss, suitMiss } = shortfall(e);
      Object.entries(miss).forEach(([s, k]) => tally(T.short, s, k));
      Object.entries(suitMiss).forEach(([su, k]) => tally(T.suitShort, su, k));
      tally(T.stuck, e.name);
    });
  }

  // ---- where next
  function chooseNext(){
    const here = state.lastStation;
    const opts = DATA.stations.map(s => s.name).filter(n => n !== here && canReachStation(here, n));
    const dice = TAKE + (state.matChecked ? (state.tripDice != null ? state.tripDice : state.matBonusDice || 0) : 1);
    const scored = opts.map(n => {
      const faces = STATION_BY_NAME[n].dice, have = { ...state.elements };
      faces.forEach(s => have[s] = (have[s] || 0) + dice / 6);
      let v = 0;
      shopAt(n).forEach(e => {
        const w = want[e.name] ? weightOf(e.name) : 0.25 * (itemFreq[e.name] || 0);
        if (!w) return;
        const missingItems = needsOf(e.reqs).items.filter(i => !owns(i.name));
        // Parts sold at the same station can be made on the same visit.
        const partsHere = missingItems.every(i => stationsSelling(i.name).includes(n));
        if (missingItems.length && !partsHere) return;
        const d = shortfall(e, have).total + (missingItems.length ? 1.5 : 0);
        v += w / Math.pow(1 + d, 1.5);
      });
      if (!state.visitedStations[n]) v += 0.6;
      v += 0.8 * transP(here, n);
      return [n, v];
    });
    // Mostly the best; sometimes the runner-up, like a person would.
    scored.sort((a, b) => b[1] - a[1]);
    return rnd() < 0.8 || scored.length < 2 ? scored[0][0] : scored[1][0];
  }

  // ---- the Display Mat: best arrangement of owned cards right now (this
  // check's order and destination included, via matScore()).
  function bestMat(budget = 500){
    const owned = state.items.filter(n => MAT_CARD_BY_NAME[n]);
    const val = names => {
      const cards = names.map(n => MAT_CARD_BY_NAME[n]);
      return matFits(cards) ? matScore(cards).total : -1;
    };
    const seeds = [state.mat.filter(owns),
      ...layouts.map(l => l.items.filter(owns)),
      [...owned].sort((a, b) => ITEM_POINTS[b] - ITEM_POINTS[a])];
    let best = [], bestV = val([]);
    seeds.forEach(s => {
      const cur = [];
      s.forEach(n => { if (!cur.includes(n) && matFits([...cur, n].map(x => MAT_CARD_BY_NAME[x]))) cur.push(n); });
      const v = val(cur);
      if (v > bestV){ best = cur; bestV = v; }
    });
    // First-improvement local search: add, drop or swap one card.
    let evals = 0, improved = true;
    while (improved && evals < budget){
      improved = false;
      const moves = [];
      owned.filter(n => !best.includes(n)).forEach(n => {
        moves.push([...best, n]);
        best.forEach((m, i) => moves.push(best.map((x, j) => j === i ? n : x)));
      });
      best.forEach((m, i) => moves.push(best.filter((x, j) => j !== i)));
      for (let i = moves.length - 1; i > 0; i--){ const j = Math.floor(rnd() * (i + 1)); [moves[i], moves[j]] = [moves[j], moves[i]]; }
      for (const m of moves){
        if (++evals > budget) break;
        const v = val(m);
        if (v > bestV){ best = m; bestV = v; improved = true; break; }
      }
    }
    state.mat = best;
    return bestV;
  }

  // ---- one run
  function playRun(opts){
    state = freshState(); state.mode = "classic";
    prefs.pinnedItems = []; selectedJobItem = null; travelPromptFor = null; lockInCommitted = false;
    plan = null; want = {};
    T = { q: [], dice: [], short: {}, suitShort: {}, stuck: {}, convFrom: {}, convTo: {}, qSpent: 0 };
    // The opening: a capstone (the plan's, if it has one) and its station's
    // six elements, then that station is turn 1.
    let start;
    // --start capstone: run i chases capstone i % 8 alone (reachability).
    if (opts.start === "capstone"){
      const cap = CAPSTONES[opts.index % CAPSTONES.length];
      setPlan({ name: "Capstone: " + cap, items: [cap] });
      start = capstoneStationOf(cap);
    }
    else if (opts.start === "random" || !layouts.length) start = DATA.stations[Math.floor(rnd() * DATA.stations.length)].name;
    else {
      choosePlan();
      const cap = plan.items.find(n => ITEM_TIER[n] === "CAPSTONE");
      start = cap ? capstoneStationOf(cap) : stationsSelling(plan.items[0])[0];
    }
    if (!plan) choosePlan();
    const capName = STATION_BY_NAME[start].capstone[1];
    setBingoCenter(capName);
    const gift = sortedDice(STATION_BY_NAME[start]);
    gift.forEach(give);
    goStation(start);
    gift.forEach(s => { const t = state.visitLog[0].elements; t[s] = (t[s] || 0) + 1; }); // as playStartingGift() logs it
    const plans = [plan && plan.name];
    for (let guard = 0; guard < 60 && !state.ended && !state.runComplete; guard++){
      doRoll();
      T.dice.push(state.lastRoll ? state.lastRoll.length : 0);
      shop();
      if (plan && !plans.includes(plan.name)) plans.push(plan.name);
      goMap();
      if (state.finalCheckPending){ bestMat(); T.q.push(matScore(matOnMat()).total); confirmFinalLockIn(); break; }
      const dest = chooseNext();
      screen = "map"; selectedMapStation = dest;
      if (isMatCheckVisit()){
        travelPromptFor = dest;
        startCheckOrder();
        bestMat();
        T.q.push(matScore(matOnMat()).total);
        confirmLockIn(); // scores, then travels (finishLockIn() -> goStation()) or ends the run
      } else {
        bestMat(300);
        T.q.push(matScore(matOnMat()).total);
        quietCheck();
        goStation(dest);
      }
    }
    // A missed gate ends the run before finishLockIn() logs the check.
    if (state.finalGameOver) state.checkLog.push({ v: state.visits, q: Math.round(matScore(matOnMat()).total), gameOver: true });
    return {
      mode: "classic", date: new Date().toISOString(), visits: state.visits,
      score: Math.round(state.bestMatScore || 0), itemScore: score(),
      checks: JSON.parse(JSON.stringify(state.checkLog || [])),
      capstones: CAPSTONES.filter(owns),
      visitLog: JSON.parse(JSON.stringify(state.visitLog || [])),
      bingoCard: state.bingoCard ? [...state.bingoCard] : null,
      bingoLinesCompleted: [...(state.bingoLinesCompleted || [])],
      // q[i]: the mat's score leaving turn i+1 (checks and quiet checks);
      // dice[i]: dice rolled on turn i+1.
      sim: { plans: plans.filter(Boolean), gameOver: !!state.finalGameOver, finalMat: [...state.mat],
        q: T.q.map(Math.round), dice: T.dice, short: T.short, suitShort: T.suitShort, stuck: T.stuck,
        convFrom: T.convFrom, convTo: T.convTo, qSpent: T.qSpent, qLeft: state.emptyElements || 0,
        leftover: { ...state.elements } },
    };
  }

  window.simPlay = (n, opts = {}) => {
    seed = opts.seed || 1;
    const out = [];
    for (let i = 0; i < n; i++) out.push(playRun({ ...opts, index: (opts.index || 0) + i }));
    return out;
  };
  // Breakpoints per round, for the report.
  window.simTiers = () => Array.from({ length: RUN_COMPLETE_VISIT }, (_, i) => ({ v: i + 1, ...lockInTiersForRound(i + 1) }));
})();
