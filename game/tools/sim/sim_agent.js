/* Elementia simulator player. Injected into the real game page by
   run_sim.mjs: it plays whole runs through the game's own rule code
   (goStation, doRoll, craft, startCheckOrder, confirmLockIn, quietCheck,
   matScore, ...) with the screen-only parts (animations, windows,
   rendering) switched off.

   The player plays like a person who knows the game:
   - Capstone first: the run pins a capstone (its start station's, as the
     game's opening does) and chases its whole recipe tree, holding back
     elements for it. Once it's made, the next goal is the capstone whose
     tree it already owns most of.
   - Route planning: stations up to a few moves away are scored by what
     can be made there next, discounted by distance; it walks toward the best.
   - Guided by real play (window.SIM_GUIDE): History exports (runs) give an
     opening book -- a run starting where one of yours did follows your
     first turns' route -- plus how often you craft each item and where you
     go next. Saved layouts (layouts) give a secondary plan for the mat.
   - Side crafts only when they serve something: a part of some capstone,
     a card worth having on the mat, or something you usually make.
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
  // Opening book: start station -> your routes (station per turn).
  const OPENING_TURNS = 6;
  const openings = {};
  G.runs.forEach(r => { const st = r.visitLog[0] && r.visitLog[0].station; if (st) (openings[st] || (openings[st] = [])).push(r.visitLog.map(t => t.station)); });
  const layouts = G.layouts.filter(l => l.items.every(n => MAT_CARD_BY_NAME[n]));
  const layoutValue = l => +(l.name.match(/^\d+/) || [1500])[0];

  // ---- recipes
  const entryAt = (name, st) => ENTRIES.find(e => e.name === name && (!st || e.station === st));
  const shopAt = st => ENTRIES.filter(e => e.station === st && itemOpen(e.name) && !owns(e.name));
  const stationsSelling = name => [...new Set(ENTRIES.filter(e => e.name === name).map(e => e.station))];

  // ---- per-run tallies for the report (reset by playRun())
  let T = null;
  const tally = (o, k, n = 1) => { o[k] = (o[k] || 0) + n; };

  // ---- goals: the capstone being chased (goal) and a saved layout for the
  // mat (plan); want[item] = how much it matters.
  let plan = null, goal = null, want = {}, openingRoute = null;
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
  function setPlan(l){ plan = l; setWants(); }
  // Capstone tree: the capstone 8, its direct parts 5, deeper parts 3. The
  // layout's items and their parts add 1-1.5 on top.
  function setWants(){
    want = {};
    if (plan){
      closureOf(plan.items).forEach(n => { want[n] = 1; });
      plan.items.forEach(n => { want[n] = 1.5; });
    }
    if (goal){
      const depth = { [goal]: 0 }, queue = [goal];
      while (queue.length){
        const n = queue.shift(), e = entryAt(n);
        if (e) needsOf(e.reqs).items.forEach(i => { if (!(i.name in depth)){ depth[i.name] = depth[n] + 1; queue.push(i.name); } });
      }
      Object.entries(depth).forEach(([n, d]) => { want[n] = (want[n] || 0) + (d === 0 ? 8 : d === 1 ? 5 : 3); });
    }
  }
  const capTree = {};
  CAPSTONES.forEach(c => capTree[c] = closureOf([c]));
  const inSomeCapTree = n => CAPSTONES.some(c => !owns(c) && capTree[c].has(n));
  // Next capstone: the one whose tree is most owned already.
  function chooseGoal(){
    const open = CAPSTONES.filter(c => !owns(c));
    goal = open.length ? open.map(c => [c, [...capTree[c]].filter(owns).length / capTree[c].size])
      .sort((a, b) => b[1] - a[1])[0][0] : null;
    setWants();
  }
  const weightOf = n => (want[n] || 0) + (itemFreq[n] || 0);

  // ---- elements
  const take = (sym, n = 1) => { state.elements[sym] = count(sym) - n; if (state.elements[sym] <= 0) delete state.elements[sym]; };
  const give = sym => { state.elements[sym] = count(sym) + 1; };
  // Elements held back for the top wanted items whose parts are owned.
  function reserve(){
    const r = {};
    Object.keys(want).filter(n => !owns(n) && itemOpen(n)).map(n => entryAt(n)).filter(e => e && itemReqsMet(e))
      .sort((a, b) => weightOf(b.name) - weightOf(a.name)).slice(0, 4)
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
    if (goal && owns(goal)) chooseGoal();
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
    // Hedge: a mat under 1.5x the next check's first breakpoint (from turn 9,
    // when a miss starts to matter) makes any mat card worth crafting.
    const atRisk = state.visits >= 9 && matScore(matOnMat()).total < 1.5 * lockInTiersForRound(nextCheckRound()).one;
    for (let guard = 0; guard < 40; guard++){
      const items = shopAt(current).filter(itemReqsMet);
      const ready = items.filter(e => canCraft(e) && suitCostPayable(e));
      const wanted = ready.filter(e => want[e.name]).sort((a, b) => weightOf(b.name) - weightOf(a.name));
      if (wanted.length){ payAndCraft(wanted[0]); continue; }
      // A wanted item a convert or "?" away (on the last turn, anything --
      // a "?" left over is wasted).
      const last = state.visits >= RUN_COMPLETE_VISIT;
      const near = items.filter(e => (want[e.name] || last) && (!canCraft(e) || !suitCostPayable(e)))
        .sort((a, b) => weightOf(b.name) - weightOf(a.name) || ITEM_POINTS[b.name] - ITEM_POINTS[a.name]);
      if (near.some(e => enable(e) && payAndCraft(e))) continue;
      // Side crafts that serve something, if they spare the reserve.
      const keep = reserve();
      const extra = ready.filter(e => {
        const { els } = needsOf(e.reqs);
        // At risk, the mat comes before the held-back elements.
        return (atRisk && MAT_CARD_BY_NAME[e.name] || Object.entries(els).every(([s, k]) => count(s) - k >= (keep[s] || 0)))
          && (inSomeCapTree(e.name) || ITEM_POINTS[e.name] >= 8 || (itemFreq[e.name] || 0) >= 0.4 || last
            || ((atRisk || isMatCheckVisit()) && MAT_CARD_BY_NAME[e.name])); // anything for the mat
      }).sort((a, b) => ITEM_POINTS[b.name] - ITEM_POINTS[a.name]);
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
  // Moves between stations (Helicopter: everywhere is one move).
  const DIST = {};
  DATA.stations.forEach(({ name: from }) => {
    const d = { [from]: 0 }, queue = [from];
    while (queue.length){ const n = queue.shift(); (MAP_ADJ[n] || []).forEach(m => { if (!(m in d)){ d[m] = d[n] + 1; queue.push(m); } }); }
    DIST[from] = d;
  });
  const moves = (a, b) => a === b ? 0 : owns("Helicopter") ? 1 : DIST[a][b];
  // What a visit to station n is worth now: wanted items it sells whose
  // parts are owned (or made there too), by how close the elements are.
  function stationValue(n, dice){
    const have = { ...state.elements };
    STATION_BY_NAME[n].dice.forEach(s => have[s] = (have[s] || 0) + dice / 6);
    let v = 0;
    shopAt(n).forEach(e => {
      const w = want[e.name] ? weightOf(e.name) : 0.25 * (itemFreq[e.name] || 0);
      if (!w) return;
      const missingItems = needsOf(e.reqs).items.filter(i => !owns(i.name));
      if (missingItems.length && !missingItems.every(i => stationsSelling(i.name).includes(n))) return;
      const d = shortfall(e, have).total + (missingItems.length ? 1.5 : 0);
      v += w / Math.pow(1 + d, 1.5);
    });
    return v;
  }
  const ROUTE_DECAY = 0.55;
  function chooseNext(){
    const here = state.lastStation;
    const opts = DATA.stations.map(s => s.name).filter(n => n !== here && canReachStation(here, n));
    // Opening book: your route, while it's still a legal move.
    const book = openingRoute, t = state.visits; // the next visit is turn t+1
    if (book && t < OPENING_TURNS && book[t] && opts.includes(book[t])) return book[t];
    const dice = TAKE + (state.matChecked ? (state.tripDice != null ? state.tripDice : state.matBonusDice || 0) : 1);
    const val = {};
    DATA.stations.forEach(({ name }) => { val[name] = name === here ? 0 : stationValue(name, dice); });
    const scored = opts.map(n => {
      // This stop, plus the best station it's on the way to.
      const ahead = Math.max(0, ...DATA.stations.map(({ name: s }) => s === n || s === here ? 0 : val[s] * Math.pow(ROUTE_DECAY, moves(n, s))));
      let v = val[n] + ahead;
      if (!state.visitedStations[n]) v += 0.6;
      v += 0.8 * transP(here, n);
      return [n, v];
    });
    // Mostly the best; sometimes the runner-up, like a person would.
    scored.sort((a, b) => b[1] - a[1]);
    return rnd() < 0.85 || scored.length < 2 ? scored[0][0] : scored[1][0];
  }

  // ---- the Display Mat: the arrangement of owned cards a player would lock
  // in now. What counts at a check is the breakpoint cleared (dice, "?"),
  // so that comes first and Quarks break ties; the final check is pure
  // Quarks. A restriction gets a second search among mats that keep it --
  // breaking it at x0.75 can score more yet clear a lower breakpoint.
  function bestMat(budget = 500){
    const owned = state.items.filter(n => MAT_CARD_BY_NAME[n]);
    const o = currentOrder();
    const restr = o && o.id !== "grand" && CHECK_ORDERS[o.id] && CHECK_ORDERS[o.id].kind === "restriction";
    const keeps = names => !restr || CHECK_ORDERS[o.id].ok(names.map(n => MAT_CARD_BY_NAME[n]), o.p);
    const val = (names, mustKeep) => {
      const cards = names.map(n => MAT_CARD_BY_NAME[n]);
      if (!matFits(cards) || (mustKeep && !keeps(names))) return -1;
      const total = matScore(cards).total;
      return state.finalCheckPending ? total : emptyElementsForScore(total, matCheckRound()) * 1e7 + total;
    };
    const fill = s => { const cur = []; s.forEach(n => { if (!cur.includes(n) && matFits([...cur, n].map(x => MAT_CARD_BY_NAME[x]))) cur.push(n); }); return cur; };
    const seeds = [state.mat.filter(owns), ...layouts.map(l => l.items.filter(owns)),
      [...owned].sort((a, b) => ITEM_POINTS[b] - ITEM_POINTS[a])].map(fill);
    // First-improvement local search: add, drop or swap one card.
    function climb(starts, mustKeep, evalBudget){
      let best = [], bestV = val([], mustKeep);
      starts.forEach(c => { const v = val(c, mustKeep); if (v > bestV){ best = c; bestV = v; } });
      let evals = 0, improved = true;
      while (improved && evals < evalBudget){
        improved = false;
        const moves = [];
        owned.filter(n => !best.includes(n)).forEach(n => {
          moves.push([...best, n]);
          best.forEach((m, i) => moves.push(best.map((x, j) => j === i ? n : x)));
        });
        best.forEach((m, i) => moves.push(best.filter((x, j) => j !== i)));
        for (let i = moves.length - 1; i > 0; i--){ const j = Math.floor(rnd() * (i + 1)); [moves[i], moves[j]] = [moves[j], moves[i]]; }
        for (const m of moves){
          if (++evals > evalBudget) break;
          const v = val(m, mustKeep);
          if (v > bestV){ best = m; bestV = v; improved = true; break; }
        }
      }
      return [best, bestV];
    }
    let [best, bestV] = climb(seeds, false, budget);
    if (restr && !keeps(best)){
      // Make each seed keep the rule by dropping cards (the drop that
      // scores best each time), then search only rule-keeping mats.
      const comply = start => {
        let cur = [...start];
        while (cur.length && !keeps(cur)){
          const opts = cur.map((x, i) => cur.filter((y, j) => j !== i));
          cur = opts.find(keeps) || opts.sort((a, b) => val(b) - val(a))[0];
        }
        return cur;
      };
      const [kept, keptV] = climb([best, ...seeds].map(comply), true, budget);
      if (keptV >= bestV){ best = kept; bestV = keptV; }
    }
    state.mat = best;
    return bestV;
  }

  // ---- one run
  function playRun(opts){
    state = freshState(); state.mode = "classic";
    prefs.pinnedItems = []; selectedJobItem = null; travelPromptFor = null; lockInCommitted = false;
    plan = null; goal = null; want = {};
    T = { q: [], mats: [], dice: [], short: {}, suitShort: {}, stuck: {}, convFrom: {}, convTo: {}, qSpent: 0 };
    // The opening: the start station's capstone is pinned and chased; its
    // six elements are the gift, then that station is turn 1.
    //   guided: most runs start where one of yours did (and follow your
    //     opening); the rest anywhere.
    //   capstone: run i starts at capstone i % 8's station (reachability).
    //   random: anywhere, no opening book.
    const stations = DATA.stations.map(st => st.name), yours = Object.keys(openings);
    const start = opts.start === "capstone" ? capstoneStationOf(CAPSTONES[opts.index % CAPSTONES.length])
      : opts.start !== "random" && yours.length && rnd() < 0.6 ? yours[Math.floor(rnd() * yours.length)]
      : stations[Math.floor(rnd() * stations.length)];
    const book = opts.start === "random" ? null : openings[start];
    openingRoute = book ? book[Math.floor(rnd() * book.length)] : null;
    goal = STATION_BY_NAME[start].capstone[1];
    if (layouts.length) choosePlan(); else setWants();
    const capName = STATION_BY_NAME[start].capstone[1];
    setBingoCenter(capName);
    const gift = sortedDice(STATION_BY_NAME[start]);
    gift.forEach(give);
    goStation(start);
    gift.forEach(s => { const t = state.visitLog[0].elements; t[s] = (t[s] || 0) + 1; }); // as playStartingGift() logs it
    const plans = [goal, plan && plan.name];
    for (let guard = 0; guard < 60 && !state.ended && !state.runComplete; guard++){
      doRoll();
      T.dice.push(state.lastRoll ? state.lastRoll.length : 0);
      shop();
      [goal, plan && plan.name].forEach(p => { if (p && !plans.includes(p)) plans.push(p); });
      goMap();
      if (state.finalCheckPending){
        bestMat(); T.q.push(matScore(matOnMat()).total);
        T.mats.push({ v: state.visits, q: Math.round(T.q[T.q.length - 1]), o: "grand", items: [...state.mat] });
        confirmFinalLockIn(); break;
      }
      const dest = chooseNext();
      screen = "map"; selectedMapStation = dest;
      if (isMatCheckVisit()){
        travelPromptFor = dest;
        startCheckOrder();
        bestMat();
        T.q.push(matScore(matOnMat()).total);
        T.mats.push({ v: state.visits, q: Math.round(T.q[T.q.length - 1]), o: state.order && state.order.id, items: [...state.mat] });
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
        q: T.q.map(Math.round), mats: T.mats, dice: T.dice, short: T.short, suitShort: T.suitShort, stuck: T.stuck,
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
