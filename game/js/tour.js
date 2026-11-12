/* =====================================================================
   tour.js -- Guided tour slideshow.

   Guided tour: a slideshow of annotated screenshots (game/tutorial/*.webp,
   made by build_tutorial_assets.py). The callouts are drawn into the
   images, so it never touches game state; a later UI tweak just leaves a
   slide slightly out of date.
   ===================================================================== */
const TOUR_SLIDES = [
  "tutorial/0.webp",  // welcome/title slide
  "tutorial/1.webp", "tutorial/2.webp", "tutorial/3.webp", "tutorial/4.webp",
  "tutorial/5.webp", "tutorial/6.webp", "tutorial/7.webp", "tutorial/8.webp",
  "tutorial/9.webp", "tutorial/10.webp", "tutorial/11.webp", "tutorial/12.webp",
  "tutorial/13.webp", "tutorial/14.webp", "tutorial/15.webp",
];

let tourIdx = 0;
let tourWelcomeOnly = false;  // showWelcomeSlide(): just slide 0, tap/skip ends it outright

function tourRender(){
  document.getElementById("tourImg").src = TOUR_SLIDES[tourIdx];
  // Preload the next slide so advancing never shows a blank flash.
  if (tourIdx + 1 < TOUR_SLIDES.length) new Image().src = TOUR_SLIDES[tourIdx + 1];
}
function startTour(){
  tourWelcomeOnly = false;
  tourIdx = 0;
  document.getElementById("tour").classList.add("open");
  document.getElementById("tour").classList.remove("welcome");
  tourRender();
}
/* The welcome/title slide, shown at the start of every session. Play calls
   tourNext(), which ends the tour in welcome-only mode, revealing whatever is
   underneath. */
function showWelcomeSlide(){
  tourWelcomeOnly = true;
  tourIdx = 0;
  document.getElementById("tour").classList.add("open", "welcome");
  tourRender();
  syncCollectionsBtn();
  // No mouse tip here (or on the mode-select screen right after, see
  // openModePicker()) -- Professor Mouse stays absent from both, only
  // appearing once real gameplay starts.
}
function endTour(){
  document.getElementById("tour").classList.remove("open", "welcome");
  document.getElementById("tourImg").src = "";
  tourWelcomeOnly = false;
}
function tourNext(){
  if (tourWelcomeOnly || tourIdx >= TOUR_SLIDES.length - 1){
    const wasWelcome = tourWelcomeOnly;
    endTour();
    if (wasWelcome) openModePicker();
    return;
  }
  tourIdx++; tourRender();
}
function tourPrev(){
  if (tourIdx === 0) return;
  tourIdx--; tourRender();
}

document.getElementById("tourNext").addEventListener("click", tourNext);
document.getElementById("tourPrev").addEventListener("click", tourPrev);
// No Escape-to-close and no skip button, by design -- the tour (including
// the every-new-session welcome slide) can only be moved through forward
// or backward, never dismissed outright.
document.addEventListener("keydown", ev => {
  if (!document.getElementById("tour").classList.contains("open")) return;
  if (ev.key === "ArrowRight" || ev.key === " ") tourNext();
  else if (ev.key === "ArrowLeft") tourPrev();
});
/* "How to Play": periodic-table framing -> the 16-element roster (the
   element-card data, see showElCardPop()) -> a coachmark walkthrough of the
   live hub buttons (.tut-coach-spot). It only targets the bottom hub, which
   is on every screen, so no navigation is needed. */
function renderTutElementsGrid(){
  const syms = CORE_ELEMENT_SYMS.slice().sort((a, b) => ATOMIC_NUMBER[a] - ATOMIC_NUMBER[b]);
  document.getElementById("tutElGrid").innerHTML = syms.map(sym => {
    return `<div class="tut-el-card" style="--suit:${ELEMENT_COLOR[sym] || "#4a4f5c"}">
      <span class="tut-el-num">${ATOMIC_NUMBER[sym]}</span>
      <span class="tut-el-sym">${esc(sym)}</span>
      <span class="tut-el-name">${esc(ELEMENT_NAMES[sym] || sym)}</span>
    </div>`;
  }).join("");
}

/* Each step's anchor matches its button's side of the hub (To-Do List,
   Inventory, Home, Items, Settings), so the bubble never covers the
   spotlit button. */
// A function so the step list is built fresh each time.
function tutCoachSteps(){
  return [
    { sel: "#hubHome", pose: 10, anchor: "bottom-left", text: "Home rolls dice and confirms travel." },
    { sel: "#hubJobs", pose: 2, anchor: "bottom-left",
      text: "To-Do List: the items you're tracking." },
    { sel: "#hubInv", pose: 12, anchor: "bottom-left", text: "Inventory: all you've collected." },
    { sel: "#hubCodex", pose: 1, anchor: "bottom-right", text: "Look up any item's recipe here." },
    { sel: "#hubMarket", pose: 2, anchor: "bottom-right", text: "The Market: craft items and capstones from anywhere." },
    { sel: "#settingsBtn", pose: 2, anchor: "top-right", text: "Settings: adjust rules or go to Main Menu." },
    { sel: null, pose: 3, anchor: "top-right", text: "You're ready! 🎯 Go build!" },
  ];
}
let tutCoachIdx = 0;

function positionTutCoach(){
  const spot = document.getElementById("tutCoachSpot");
  const step = tutCoachSteps()[tutCoachIdx];
  const target = step.sel && document.querySelector(step.sel);
  if (!target){
    spot.classList.add("hidden");
    return;
  }
  spot.classList.remove("hidden");
  const r = target.getBoundingClientRect();
  const pad = 8;
  spot.style.left = (r.left - pad) + "px";
  spot.style.top = (r.top - pad) + "px";
  spot.style.width = (r.width + pad * 2) + "px";
  spot.style.height = (r.height + pad * 2) + "px";
}
/* Shows each step's text in Professor Mouse's bubble (the spotlight shows
   which button). The close button is hidden and the tour controls shown
   during the walkthrough; endTutCoach() restores the normal bubble. */
function renderTutCoach(){
  const step = tutCoachSteps()[tutCoachIdx];
  showMouseTip(step.pose, step.text, step.anchor);
  document.getElementById("mouseTip").classList.add("tut-coach-active");
  document.getElementById("mouseTipClose").hidden = true;
  document.getElementById("mouseTipTour").hidden = false;
  document.getElementById("mouseTipStep").textContent = `${tutCoachIdx + 1} / ${tutCoachSteps().length}`;
  document.getElementById("mouseTipNext").textContent =
    tutCoachIdx === tutCoachSteps().length - 1 ? "Start Playing" : "Next";
  positionTutCoach();
}
function startNewTutorial(){
  openOverlay("tutIntro");
}
document.getElementById("tutIntroNext").addEventListener("click", () => {
  closeOverlay("tutIntro");
  renderTutElementsGrid();
  openOverlay("tutElements");
});
document.getElementById("tutElementsNext").addEventListener("click", () => {
  closeOverlay("tutElements");
  tutCoachIdx = 0;
  document.getElementById("tutCoach").classList.add("open");
  renderTutCoach();
});
function endTutCoach(){
  document.getElementById("tutCoach").classList.remove("open");
  document.getElementById("mouseTip").classList.remove("tut-coach-active");
  document.getElementById("mouseTipTour").hidden = true;
  document.getElementById("mouseTipClose").hidden = false;
  hideMouseTip();
}
document.getElementById("mouseTipNext").addEventListener("click", () => {
  if (tutCoachIdx >= tutCoachSteps().length - 1){
    endTutCoach();
    return;
  }
  tutCoachIdx++;
  renderTutCoach();
});
// The spotlight/caption follow the live button's real position -- so if
// the viewport resizes mid-walkthrough (rotation, etc.), it doesn't end
// up pointing at empty space.
window.addEventListener("resize", () => {
  if (document.getElementById("tutCoach").classList.contains("open")) positionTutCoach();
  if (screen === "map") syncMapPaths();
});

document.getElementById("tourBtn").addEventListener("click", () => {
  closeOverlay("settings");
  startNewTutorial();
});
document.getElementById("tourPlayBtn").addEventListener("click", tourNext);
document.getElementById("tourSettingsBtn").addEventListener("click", () => {
  // Settings opens ON TOP of the welcome screen: #tour drops behind Settings
  // rather than closing, and closeOverlay() lifts it back.
  document.getElementById("tour").classList.add("behind-settings");
  openSettings();
});
