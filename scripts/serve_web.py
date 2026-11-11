#!/usr/bin/env python3
"""Local static server for the Flutter web build with no-cache headers.

Serves `apps/mobile/build/web` on http://localhost:8080 and forces the browser
to revalidate every asset, which prevents stale `main.dart.js` bundles from
being served after a rebuild.
"""
import http.server
import os
import socketserver

ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "apps", "mobile", "build", "web")
)
PORT = int(os.environ.get("WEB_PORT", "8080"))


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)


socketserver.TCPServer.allow_reuse_address = True

if __name__ == "__main__":
    with socketserver.ThreadingTCPServer(("0.0.0.0", PORT), NoCacheHandler) as httpd:
        print(f"Serving {ROOT} on http://localhost:{PORT} (no-cache)", flush=True)
        httpd.serve_forever()
