/* =====================================================================
   pwa.js -- Installed (home screen) app support: registers sw.js, so the
   game opens offline. The manifest (manifest.webmanifest) and iPhone tags
   are in elementia.html. Left out of the claude.ai build
   (build_artifact.py); the website gets it (deploy.py).
   ===================================================================== */
if ("serviceWorker" in navigator && location.protocol.startsWith("http")){
  navigator.serviceWorker.register("sw.js").catch(() => {}); // a progressive extra -- never block the game
}
