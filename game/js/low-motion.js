/* =====================================================================
   low-motion.js -- Low-motion preference: lowMotion()/applyLowMotion().

   Low motion: menus, trays and pop-ups appear instantly; celebration/flip/
   bounce effects are skipped; pulsing markers go steady. Kept: the Quark
   count-up during Lock-In, the dice roll and flight into the bag, and the
   mini-games. Follows the device's "reduce motion" setting until the player
   chooses in Settings.
   ===================================================================== */
function lowMotion(){
  if (prefs && typeof prefs.lowMotion === "boolean") return prefs.lowMotion;
  return matchMedia("(prefers-reduced-motion: reduce)").matches;
}
function applyLowMotion(){
  document.documentElement.classList.toggle("low-motion", lowMotion());
}
