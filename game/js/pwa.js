/* =====================================================================
   pwa.js -- PWA: web manifest + service worker, generated at runtime. Left out of
   the Artifact build (build_artifact.py).
   ===================================================================== */
/* Installable only over http(s); from file:// it still works offline. The
   manifest and service worker are generated at runtime as blobs, so the
   game stays one portable file. */
(function setupPWA(){
  try {
    const manifest = {
      name: "Elementia", short_name: "Elementia",
      description: "A STEM crafting game for summer camp.",
      start_url: ".", scope: ".", display: "standalone",
      background_color: "#0f2733", theme_color: "#0f2733", orientation: "any",
      icons: [{
        src: "data:image/svg+xml," + encodeURIComponent(
          `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
           <rect width="512" height="512" rx="112" fill="#2e9e5b"/>
           <text x="256" y="256" font-size="300" text-anchor="middle"
                 dominant-baseline="central">⚗️</text></svg>`),
        sizes: "any", type: "image/svg+xml", purpose: "any maskable"
      }]
    };
    const link = document.createElement("link");
    link.rel = "manifest";
    link.href = URL.createObjectURL(new Blob([JSON.stringify(manifest)], {type:"application/manifest+json"}));
    document.head.appendChild(link);

    if ("serviceWorker" in navigator && location.protocol.startsWith("http")){
      // Cache this page itself so a camp tablet keeps working with no signal.
      const sw = `
        const C = "elementia-v1";
        self.addEventListener("install", e => {
          self.skipWaiting();
          e.waitUntil(caches.open(C).then(c => c.add(new Request(${JSON.stringify(location.href)}, {cache:"reload"}))));
        });
        self.addEventListener("activate", e => {
          e.waitUntil(caches.keys().then(ks =>
            Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))).then(() => self.clients.claim()));
        });
        self.addEventListener("fetch", e => {
          if (e.request.method !== "GET") return;
          e.respondWith(
            fetch(e.request).then(r => {
              const copy = r.clone();
              caches.open(C).then(c => c.put(e.request, copy)).catch(()=>{});
              return r;
            }).catch(() => caches.match(e.request).then(r => r || caches.match(${JSON.stringify(location.href)})))
          );
        });`;
      const swUrl = URL.createObjectURL(new Blob([sw], {type:"text/javascript"}));
      navigator.serviceWorker.register(swUrl).catch(() => {});
    }
  } catch(e){ /* PWA is a progressive enhancement — never block the game */ }
})();
