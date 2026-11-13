// Classic smoke test: plays start -> roll -> craft -> panels -> travel -> Lock-In and
// records any page errors in window.__smoke. Run it with: node game/tools/run_smoke.mjs
(async () => {
  const wait = ms => new Promise(r => setTimeout(r, ms));
  const errs = [];
  window.addEventListener("error", e => errs.push(e.message + " @" + (e.lineno || "")));
  window.addEventListener("unhandledrejection", e => errs.push("rejection: " + e.reason));
  const step = async (name, fn) => { try { await fn(); } catch (e) { errs.push(name + ": " + e.message); } };
  const log = {};
  document.getElementById("tour").style.display = "none";
  document.querySelectorAll(".overlay.open").forEach(o => o.classList.remove("open"));

  // Data: every item and recipe icon resolves (an unknown __MARKER__ would
  // render as raw text), and every recipe ingredient is a real item.
  await step("data", async () => {
    log.items = CORE_ITEM_NAMES.size;
    ENTRIES.forEach(e => {
      if (em(e.emoji).includes("__")) errs.push("no icon for " + e.name);
      e.reqs.forEach(r => {
        if (r.kind === "item" && !CORE_ITEM_NAMES.has(r.name)) errs.push(`${e.name} needs unknown item ${r.name}`);
        if (r.kind === "item" && em(r.emoji).includes("__")) errs.push(`no icon for ${r.name} in ${e.name}'s recipe`);
      });
    });
  });

  await step("start", async () => { startNewRun(); await wait(2200); });
  await step("tutorial", async () => { for (let i = 0; i < 3; i++) classicTutNext(); await wait(200); });
  await step("capstone", async () => {
    // Intro softlock guard: a tap on the backdrop (or Escape) must not close
    // the capstone choice or the pin tip -- the run can't start without them.
    const isOpen = id => document.getElementById(id).classList.contains("open");
    const esc = () => document.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape"}));
    if (!isOpen("capChoice")) errs.push("intro: capstone choice not open after the rules slides");
    document.getElementById("capChoice").click(); esc();
    if (!isOpen("capChoice")) errs.push("intro: outside tap/Escape closed the capstone choice");
    openCapstoneConfirm("Fruit Cake"); await wait(150);
    document.getElementById("capConfirmGo").click();
    for (let i = 0; i < 40 && !isOpen("pinTip"); i++) await wait(100);
    document.getElementById("pinTip").click(); esc();
    if (!isOpen("pinTip")) errs.push("intro: outside tap/Escape closed the pin tip");
    document.getElementById("pinTipOk").click(); await wait(1400);
  });
  log.atStation = screen + ":" + current;
  await step("roll", async () => {
    triggerRoll(); await wait(2600);
    const c = document.getElementById("rollCollect"); if (c && !c.hidden) c.click();
    await wait(1500);
  });
  log.rolled = state.rolledHere;
  await step("craft", async () => {
    state.elements = {}; ["H","C","O","Mg","S","Ca","N","Si","Al","Fe","K","P","Ti","Ni","Cu","Ag"].forEach(e => state.elements[e] = 3);
    render();
    const e = ENTRIES.find(x => x.station === current && canCraft(x) && !owns(x.name) && !itemSuitCosts(x.name).length);
    log.crafted = e && e.name;
    if (e) { performSingleCraft(e); await wait(2500); closeOverlay("cardPop"); await wait(500); }
  });
  await step("drawer", async () => { openDrawer(); render(); await wait(200); matDrawerView = "elements"; renderMatTop(); matDrawerView = "mat"; renderMatTop(); closeDrawer(); });
  // A collection completed on the mat is discovered right away: a window
  // shows it and "Add to Collections" saves it (+1 Star).
  await step("collection found", async () => {
    const saved = {items: state.items.slice(), mat: state.mat.slice(), unl: prefs.everUnlockedMatCollections.slice(), stars: prefs.stars};
    const c = MAT_COLLECTIONS.find(x => !prefs.everUnlockedMatCollections.includes(x.id) && matFits(x.items.map(n => MAT_CARD_BY_NAME[n])));
    document.querySelectorAll(".overlay.open").forEach(o => closeOverlay(o.id));
    state.items = [...new Set([...state.items, ...c.items])]; state.mat = c.items.slice(); prefs.stars = 0;
    render(); await wait(700);
    const ov = document.getElementById("collectionFound");
    if (!ov.classList.contains("open")) errs.push(`completing ${c.name} on the mat should open the collection window`);
    else {
      document.getElementById("collectionFoundAdd").click();
      if (!prefs.everUnlockedMatCollections.includes(c.id) || prefs.stars !== STARS_DISCOVERY || ov.classList.contains("open"))
        errs.push("Add to Collections should discover it, pay a Star and close");
    }
    state.items = saved.items; state.mat = saved.mat; prefs.everUnlockedMatCollections = saved.unl; prefs.stars = saved.stars; savePrefs();
    render();
  });
  // BINGO reward dismissed by a backdrop tap (not "Nice!") must unlock the
  // tray -- it used to leave #jobSheet locked and the game frozen.
  await step("bingo reward backdrop", async () => {
    ensureBingoCard();
    const savedLines = state.bingoLinesCompleted.slice(), savedQ = state.emptyElements;
    state.pendingBingoClears = [0];
    runBingoSequence();
    const ov = document.getElementById("bingoClearOverlay");
    for (let i = 0; i < 40 && !ov.classList.contains("open"); i++) await wait(100);
    if (!ov.classList.contains("open")) errs.push("BINGO reward never opened");
    ov.click();
    if (bingoClearInProgress || jobSheet.classList.contains("bingo-clearing"))
      errs.push("BINGO tray still locked after the reward was dismissed by a backdrop tap");
    await wait(2000);
    if (jobSheet.classList.contains("open")) errs.push("BINGO tray never closed after the reward");
    state.bingoLinesCompleted = savedLines; state.emptyElements = savedQ;
  });
  // Sort/Filter/Hide-mat must show on open even without a mat redraw.
  await step("float buttons", async () => {
    openDrawer({ peeked: true }); closeDrawer(); openDrawer();
    if (document.getElementById("matFilterBtn").hidden || document.getElementById("matSortBtn").hidden)
      errs.push("Inventory opened without its Sort/Filter buttons");
    closeDrawer();
    if (!document.getElementById("matFilterBtn").hidden) errs.push("Filter button still shown after closing the Inventory");
  });
  await step("todo", async () => { openJobBoard(); await wait(400); closeJobBoard(); await wait(300); });
  await step("market", async () => { openJobSelectTray(); await wait(500); bingoTab = "capstones"; renderJobBoard(); bingoTab = "bingo"; renderJobBoard(); closeJobBoard(); await wait(300); });
  await step("itemref", async () => { screen = "codex"; render(true); await wait(200); log.refRows = document.querySelectorAll(".refrow").length; screen = "station"; render(); });
  await step("convert", async () => { openConvertScreen(); await wait(200); closeOverlay("convert"); });
  await step("settings", async () => { openSettings(); await wait(100); closeOverlay("settings"); });
  await step("history", async () => { renderHistory && renderHistory(); });
  await step("travel", async () => {
    state.visits = 3; goMap(); await wait(300);
    const dest = Object.keys(MAP_NODE_POS).find(n => n !== state.lastStation && canTravelTo(n));
    selectedMapStation = dest; render(); await wait(100);
    document.getElementById("hubHome").click(); await wait(SHUTTER_CLOSE_MS * 2 + SHUTTER_HOLD_MS + 300);
    log.lockinFace = hubHomeFace();
    confirmLockIn(); await wait(6000);
    const nice = document.getElementById("lockInRewardNice"); if (nice) nice.click();
    await wait(1500);
  });
  log.afterTravel = screen + ":" + current + " visits " + state.visits;
  log.score = score();

  // Rule checks: each pushes an error when a rule breaks.
  const expect = (ok, msg) => { if (!ok) errs.push("rule: " + msg); };
  // Auto-place: crafts keep landing on the mat until they'd overflow it --
  // tier 1 cards stack two per slot, so that's more than 8 crafts.
  { const saved = state; state = freshState();
    const t1 = ENTRIES.filter(e => e.tier === "MATERIAL" && e.reqs.every(r => r.kind === "element")).slice(0, 10);
    t1.forEach(e => { e.reqs.forEach(r => state.elements[r.name] = 99); craft(e); });
    expect(t1.length < 10 || state.mat.length === 10, `10 tier 1 crafts should all auto-place, got ${state.mat.length}`);
    state = saved; }
  await step("rules", async () => {
    // New-player default settings (the runner starts with empty storage).
    expect(prefs.autoCardInspection === true && prefs.guidedTutorialEnabled === true
      && prefs.minigamesEnabled === false && prefs.lowMotion === false && !lowMotion(),
      "defaults should be: card inspection on, mouse tips on, mini-games off, low motion off");

    // Suit costs count only the four core elements per suit (not leftover Zn).
    state.elements = {Zn: 5};
    expect(suitSurplusOfSuit("metal", {}) === 0, "Zn counted toward metal suit cost");
    state.elements = {Fe: 2, Cu: 1};
    expect(suitSurplusOfSuit("metal", {Fe: 1}) === 2, "suit surplus should skip what the recipe reserves");

    // Convert: CONVERT_RATE of one element -> 1 of another.
    state.elements = {C: CONVERT_RATE};
    openConvertScreen(); convertFrom = "C"; convertTo = "O"; updateConvertUI();
    document.getElementById("convertGo").click();
    expect(count("C") === 0 && count("O") === 1, `convert gave C=${count("C")} O=${count("O")}`);
    await wait(900); closeOverlay("convert");

    // A redrawn (stale) BINGO card drops the old card's line progress.
    state.bingoCard = ensureBingoCard().slice(); state.bingoCard[0] = "Not A Real Item";
    state.bingoLinesCompleted = [0]; state.pendingBingoClears = [0]; state.bingoCenterChosen = true;
    ensureBingoCard();
    expect(!state.bingoLinesCompleted.length && !state.pendingBingoClears.length && !state.bingoCenterChosen,
      "redrawn BINGO card kept old line progress");

    // Tier 1 (MATERIAL) cards stack two to a slot, and each still scores.
    const t1 = ["Water", "Sand", "Clay"].map(n => MAT_CARD_BY_NAME[n]);
    expect(matOccupancy(t1) === 2, `3 tier 1 cards should use 2 slots, used ${matOccupancy(t1)}`);
    expect(matScore(t1).base === t1.reduce((n, c) => n + c.points, 0), "stacked tier 1 cards should each score");

    // Marketplace layouts: 3 rows of 4 by default, the 5x5 card behind
    // prefs.classicBingo; the layout is fixed when the run starts.
    { const saved = state, savedPref = prefs.classicBingo;
      prefs.classicBingo = false; state = freshState();
      expect(state.bingoLayout === "rows" && ensureBingoCard().length === 12 && bingoLines().length === 3
        && bingoLines().every(l => l.length === 4), "default Marketplace should be 3 rows of 4");
      expect(state.bingoCard.filter(n => ITEM_TIER[n] === "CREATION").length === 9, "rows should be mostly tier 3 (9 of 12)");
      prefs.classicBingo = true; state = freshState();
      expect(state.bingoLayout === "bingo" && ensureBingoCard().length === 25 && bingoLines().length === 12,
        "the 5x5 setting should give a 5x5 card with 12 lines");
      prefs.classicBingo = savedPref; state = saved; }

    // Rows layout: no capstones in the random draw; the chosen capstone gets
    // a row with items from its own station.
    { const saved = state, savedPref = prefs.classicBingo;
      prefs.classicBingo = false; state = freshState();
      expect(!ensureBingoCard().some(n => ITEM_TIER[n] === "CAPSTONE"), "the Market draw should have no capstones");
      const cap = bingoCapstoneChoices()[0];
      setBingoCenter(cap);
      const row = bingoLines()[0].map(i => state.bingoCard[i]);
      expect(row.includes(cap) && row.every(n => CORE_ITEM_STATION[n] === CORE_ITEM_STATION[cap])
        && new Set(state.bingoCard).size === 12 && state.bingoCard.filter(n => ITEM_TIER[n] === "CAPSTONE").length === 1,
        `the chosen capstone should get a row from its own station, got ${row.join(", ")}`);
      prefs.classicBingo = savedPref; state = saved; }

    // The To-Do hint only suggests something whose components are all owned.
    { const savedPins = prefs.pinnedItems.slice(), savedItems = state.items.slice();
      prefs.pinnedItems = [bingoCapstoneChoices()[0]]; state.items = [];
      const h = computeTodoHint();
      expect(h && itemReqsMet(h.entry) && h.roots.length === 1, `hint should be actionable, got ${h && h.name}`);
      prefs.pinnedItems = savedPins; state.items = savedItems; }

    // Collection clues: Stars buy clues; a clue names an undiscovered
    // collection and one of its items; its last item discovers it.
    { const savedPrefs = JSON.stringify({stars: prefs.stars, clues: prefs.collectionClues, unl: prefs.everUnlockedMatCollections});
      prefs.stars = 0; prefs.collectionClues = {}; grantStars(7);
      expect(prefs.stars === 7, "grantStars should add to prefs.stars");
      const before = prefs.everUnlockedMatCollections.length;
      const c = MAT_COLLECTIONS.find(x => !prefs.everUnlockedMatCollections.includes(x.id));
      let clue = null;
      for (let i = 0; i < c.items.length; i++){
        // force the clue onto c: everything else counts as discovered for this check
        const save = prefs.everUnlockedMatCollections;
        prefs.everUnlockedMatCollections = MAT_COLLECTIONS.filter(x => x !== c).map(x => x.id);
        clue = drawCollectionClue();
        prefs.everUnlockedMatCollections = save.concat(clue.discovered ? [c.id] : []);
      }
      expect(clue && clue.c === c && clue.discovered && !prefs.collectionClues[c.id], "revealing a collection's last item should discover it");
      buyClues(1); closeOverlay("clueOpen");
      expect(prefs.stars === 4, `one clue should cost ${CLUE_COST} Stars (left ${prefs.stars})`);
      // the "!" chip for a complete, undiscovered collection on the mat
      const d = MAT_COLLECTIONS.find(x => !prefs.everUnlockedMatCollections.includes(x.id) && x.items.length <= 4);
      expect(matComboChipsHTML(matScore(d.items.map(n => MAT_CARD_BY_NAME[n])), false).includes("data-hidden-col"),
        "a hidden collection on the mat should show a ! chip");
      const sp = JSON.parse(savedPrefs); prefs.stars = sp.stars; prefs.collectionClues = sp.clues; prefs.everUnlockedMatCollections = sp.unl; savePrefs(); }

    // Capstone signatures (each only while its capstone is on the mat).
    { const C = n => MAT_CARD_BY_NAME[n], savedStreak = state.ecoStreak, savedTP = travelPromptFor;
      const plain = MAT_CARDS.filter(c => !matIsCapstone(c) && !matIsTier1(c));
      const t1 = MAT_CARDS.filter(matIsTier1);
      const two = plain.filter(c => !matIsComplete(c, [c])).slice(0, 2);
      const sc = (cards) => matScore(cards);
      // Robot: +5 per card on the mat (itself included).
      { const a = sc([C("Robot"), ...two]), b0 = [C("Robot"), ...two].reduce((n, c) => n + c.points, 0);
        expect(a.base === b0 + 15, `Robot should add +5 per card (base ${a.base}, plain ${b0})`); }
      // Metropolis: 10 slots, 5 columns.
      { const L = matLayout([C("Metropolis")]); expect(L.slots === 10 && L.cols === 5, "Metropolis should give 10 slots");
        expect(matFits([C("Metropolis"), ...plain.slice(0, 8)]) && !matFits([C("Metropolis"), ...plain.slice(0, 9)]), "Metropolis mat should hold its 2 + 8 more"); }
      // Maglev Train: tier 1 stacks 3 to a slot, +2 each.
      { expect(matOccupancy([C("Maglev Train"), ...t1.slice(0, 3)]) === 3, "Maglev Train: 3 tier 1 cards should share one slot");
        const base = sc([C("Maglev Train"), t1[0]]).base; expect(base === C("Maglev Train").points + t1[0].points + 2, "Maglev Train: tier 1 +2"); }
      // Ecosystem: +1 multiplier per check in a row, counting this one.
      { state.ecoStreak = 2; expect(sc([C("Ecosystem")]).mult - sc([C("Ecosystem")]).sigs.length * 0 >= 4, "Ecosystem streak 2 should add +3 multiplier");
        state.ecoStreak = savedStreak; }
      // Fruit Cake: all 4 suits doubles the total.
      { const suits = Object.keys(ELEMENT_SUIT_LABEL), pick = suits.map(su => plain.find(c => c.pips.includes(su)));
        const m = [C("Fruit Cake"), ...pick]; const s1 = sc(m);
        expect(s1.layered && s1.total === (s1.base + s1.colBonus) * s1.mult * 2, "Fruit Cake with 4 suits should double the Quarks"); }
      // Coral Reef: +1 multiplier per different station.
      { const m = [C("Coral Reef"), ...two]; const k = new Set(m.flatMap(c => c.stations)).size;
        const plainMult = matScore(two).mult; expect(sc(m).sigs.find(g => g.name === "Coral Reef").label === `+${k}`, "Coral Reef should count stations"); }
      // Space Station: cards from the destination score x2.
      { const card = plain.find(c => c.stations.length === 1 && !matIsComplete(c, [c]));
        travelPromptFor = card.station; const a = sc([C("Space Station"), card]).base;
        travelPromptFor = null; const b = sc([C("Space Station"), card]).base;
        expect(a - b === card.points, `Space Station should double cards from the destination (${a} vs ${b})`); }
      // Switching off a collection that takes Maglev Train away must still
      // leave a mat that fits (its tier 1 stacks drop from 3 to 2 a slot).
      { const saved = {items: state.items, mat: state.mat};
        const t1n = t1.map(c => c.name), other = plain[0].name;
        state.items = ["Maglev Train", other, ...t1n]; state.mat = ["Maglev Train", ...t1n, other];
        removeCollectionFromMat(MAT_COLLECTIONS.find(c => c.items.includes("Maglev Train")).id);
        expect(matFits(matOnMat()), `removing Maglev Train's collection overfilled the mat (${matOccupancy(matOnMat())} slots)`);
        state.items = saved.items; state.mat = saved.mat; }
      travelPromptFor = savedTP; }

    // The mat is checked only when leaving a checkpoint turn (every 3rd).
    { const v = state.visits;
      const checks = [2, 3, 4, 5, 6, 7, 9].filter(n => { state.visits = n; return isMatCheckVisit(); });
      expect(checks.join() === "3,6,9", `mat checks should be on turns 3, 6, 9 only, got ${checks.join()}`);
      state.visits = 4; expect(matCheckRound() === 6, "the Quark meter between checks should show the next checkpoint's breakpoints");
      state.visits = v; }

    // Turn 24 completes the run: the end screen offers Keep playing, and in
    // Overtime an empty board (0 Quarks) at any Lock-In asks to end the run.
    const isOpen = id => document.getElementById(id).classList.contains("open");
    // Turn 24 ends with a final mat score first (Home's Final Score face).
    state.visits = RUN_COMPLETE_VISIT; state.runComplete = false; state.ended = false; state.bestMatScore = 0;
    state.mat = state.items.filter(n => MAT_CARD_BY_NAME[n]).slice(0, 4); lockInCommitted = false;
    goMap(); await wait(SHUTTER_CLOSE_MS * 2 + SHUTTER_HOLD_MS + 300); // the shutter scene change
    expect(state.finalCheckPending && hubHomeFace() === "final" && drawer.classList.contains("open") && !state.runComplete,
      "back on the map after turn 24 should open the mat for the final score");
    const finalQ = Math.round(matScore(matOnMat()).total);
    document.getElementById("hubHome").click();
    for (let i = 0; i < 80 && !isOpen("endGame"); i++) await wait(200);
    expect(state.runComplete && isOpen("endGame") && !document.getElementById("endContinue").hidden,
      "the final score should lead to the run-complete screen with Keep playing");
    const last = (state.checkLog || []).slice(-1)[0];
    expect(last && last.final && last.q === finalQ && Math.round(state.bestMatScore) >= finalQ,
      `the final score should be logged and count toward the top Quark score (${finalQ})`);
    expect(loadTrophies()["first-run"], "completing a run should award the First Run trophy (own storage key)");
    expect(document.getElementById("endTrophiesWrap").textContent.includes("First Run"),
      "the run-complete screen should list the new trophy");
    document.getElementById("endContinue").click(); await wait(200);
    expect(!isOpen("endGame") && !state.ended, "Keep playing should close the screen and continue");
    state.mat = []; state.visits = RUN_COMPLETE_VISIT + 1; lockInCommitted = false;
    confirmLockIn(); await wait(200);
    expect(isOpen("confirmBox"), "an Overtime Lock-In below the first breakpoint should ask to end the run");
    document.getElementById("confirmNo").click(); await wait(200);
    expect(!state.ended, "cancelling the Overtime prompt should keep the run going");

    // An old, minimal save still loads, with new fields defaulted.
    localStorage.setItem(SAVE_KEY, JSON.stringify({items: ["Water"], elements: {H: 2}, visits: 5, mode: "classic"}));
    const isNew = loadAll();
    expect(!isNew && owns("Water") && state.visits === 5 && Array.isArray(state.mat) && state.mode === "classic",
      "old save did not load cleanly");
    // A mat that overflows after a tier change is trimmed on load.
    const nonT1 = MAT_CARDS.filter(c => !matIsTier1(c) && !matIsCapstone(c)).slice(0, 10).map(c => c.name);
    localStorage.setItem(SAVE_KEY, JSON.stringify({items: nonT1, mat: nonT1, visits: 5, mode: "classic"}));
    loadAll();
    expect(state.mat.length === MAT_SLOTS_TOTAL && matFits(matOnMat()) && nonT1.every(owns),
      `an overfull mat should be trimmed to fit on load (kept ${state.mat.length})`);
    render();
  });
  log.errs = errs;
  window.__smoke = log;
})();
