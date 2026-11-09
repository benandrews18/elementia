# -*- coding: utf-8 -*-
"""Local web UI for the reachability simulation -- no code editing required.

    python reachability_lab.py

opens a page in your browser where you can edit station dice, which
station(s) sell each item, and the station graph, then click Run to see
the results -- all without touching build_guide.py or any other real game
file. See reachability_engine.py for why: it reads the live game data once
at startup as a starting point, but every experiment you run stays in your
browser tab until you explicitly download it; nothing is ever written back.

Standard library only -- no `pip install` needed.
"""
import json, pathlib, webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import reachability_engine as engine

HERE = pathlib.Path(__file__).resolve().parent
HTML_PATH = HERE / "reachability_lab.html"
PORT = 8934

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # keep the console quiet -- errors still show via send_error

    def _send_json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = HTML_PATH.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/baseline":
            self._send_json(engine.build_baseline())
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/api/run":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", 0))
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
            dice = payload["dice"]
            items = payload["items"]
            edges = [tuple(e) for e in payload["edges"]]
            trials = max(1, min(int(payload.get("trials", 25)), 200))
        except Exception as e:
            self._send_json({"errors": [f"Bad request: {e}"]}, status=400)
            return
        result = engine.run_grid(items, dice, edges, trials=trials)
        self._send_json(result)

def main():
    httpd = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    url = f"http://127.0.0.1:{PORT}/"
    print(f"Reachability Lab running at {url}")
    print("Press Ctrl+C to stop.")
    try:
        webbrowser.open(url)
    except Exception:
        pass
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")

if __name__ == "__main__":
    main()
