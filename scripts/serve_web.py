#!/usr/bin/env python3
"""Local static server for the Flutter web build with no-cache headers.

Serves `apps/mobile/build/web` on http://localhost:8080 and forces the browser
to revalidate every asset, which prevents stale `main.dart.js` bundles from
being served after a rebuild. Also reverse-proxies `/api/*` to the FastAPI backend
at http://127.0.0.1:8000 so relative API calls succeed without CORS or 501 errors.
"""
import http.server
import os
import socketserver
import urllib.error
import urllib.request

ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "apps", "mobile", "build", "web")
)
PORT = int(os.environ.get("WEB_PORT", "8080"))
BACKEND_URL = os.environ.get("BACKEND_URL", "http://127.0.0.1:8000")


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def _proxy_to_backend(self):
        target_url = f"{BACKEND_URL}{self.path}"
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        # Copy incoming headers, omitting Host to avoid mismatch
        headers = {}
        for k, v in self.headers.items():
            if k.lower() not in ("host", "content-length"):
                headers[k] = v

        req = urllib.request.Request(
            target_url,
            data=body,
            headers=headers,
            method=self.command,
        )

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for header, value in resp.getheaders():
                    # Skip hop-by-hop headers and chunked transfer
                    if header.lower() not in ("transfer-encoding", "content-encoding"):
                        self.send_header(header, value)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for header, value in e.headers.items():
                if header.lower() not in ("transfer-encoding", "content-encoding"):
                    self.send_header(header, value)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(f'{{"error":"Bad gateway to backend: {str(e)}"}}'.encode("utf-8"))

    def do_GET(self):
        if self.path.startswith("/api/"):
            self._proxy_to_backend()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/"):
            self._proxy_to_backend()
        else:
            super().do_POST()

    def do_PUT(self):
        if self.path.startswith("/api/"):
            self._proxy_to_backend()
        else:
            self.send_error(501, f"Unsupported method ({self.command})")

    def do_DELETE(self):
        if self.path.startswith("/api/"):
            self._proxy_to_backend()
        else:
            self.send_error(501, f"Unsupported method ({self.command})")

    def do_PATCH(self):
        if self.path.startswith("/api/"):
            self._proxy_to_backend()
        else:
            self.send_error(501, f"Unsupported method ({self.command})")

    def do_OPTIONS(self):
        if self.path.startswith("/api/"):
            self._proxy_to_backend()
        else:
            self.send_response(200)
            self.send_header("Allow", "GET, HEAD, POST, PUT, DELETE, PATCH, OPTIONS")
            self.end_headers()

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)


socketserver.TCPServer.allow_reuse_address = True

if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), NoCacheHandler) as httpd:
        print(f"Serving {ROOT} on http://localhost:{PORT} (no-cache, proxying /api/ -> {BACKEND_URL})", flush=True)
        httpd.serve_forever()
