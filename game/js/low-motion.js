/* =====================================================================
   low-motion.js -- Low-motion preference: lowMotion()/applyLowMotion().

   Low motion: menus, trays and pop-ups appear instantly; celebration/flip/
   bounce effects are skipped; pulsing markers go steady. Kept: the Quark
   count-up during Lock-In, the dice roll and flight into the bag, and the
   mini-games. Off unless the player turns it on in Settings (the device's
   own "reduce motion" setting is not used).
   ===================================================================== */
function lowMotion(){
  return !!(prefs && prefs.lowMotion === true);
}
function applyLowMotion(){
  document.documentElement.classList.toggle("low-motion", lowMotion());
}
