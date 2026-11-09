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
    document.getElementById("hubHome").click(); await wait(400);
    log.lockinFace = hubHomeFace();
    confirmLockIn(); await wait(6000);
    const nice = document.getElementById("lockInRewardNice"); if (nice) nice.click();
    await wait(1500);
  });
  log.afterTravel = screen + ":" + current + " visits " + state.visits;
  log.score = score();

  // Rule checks: each pushes an error when a rule breaks.
  const expect = (ok, msg) => { if (!ok) errs.push("rule: " + msg); };
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

    // Turn 24 completes the run: the end screen offers Keep playing, and in
    // Overtime an empty board (0 Quarks) at any Lock-In asks to end the run.
    const isOpen = id => document.getElementById(id).classList.contains("open");
    state.visits = RUN_COMPLETE_VISIT; state.runComplete = false; state.ended = false;
    goMap(); await wait(400);
    expect(state.runComplete && isOpen("endGame") && !document.getElementById("endContinue").hidden,
      "turn 24 should open the run-complete screen with Keep playing");
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
    render();
  });
  log.errs = errs;
  window.__smoke = log;
})();
