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

  await step("start", async () => { startFreshMode("classic"); await wait(2200); });
  await step("tutorial", async () => { for (let i = 0; i < 3; i++) classicTutNext(); await wait(200); });
  await step("capstone", async () => {
    openCapstoneConfirm("Fruit Cake"); await wait(150);
    document.getElementById("capConfirmGo").click();
    for (let i = 0; i < 40 && !document.getElementById("pinTip").classList.contains("open"); i++) await wait(100);
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
    if (e) { performSingleCraft(e); await wait(2500); closeOverlay("cardPop"); flushPendingReveal(); await wait(1500); closeItemReveal && closeItemReveal(); }
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
  log.errs = errs;
  window.__smoke = log;
})();
