"""Authenticated, rate-limited local reverse proxy for Ollama on Windows.

Binds strictly to 127.0.0.1:<PROXY_PORT> (default 11435) and forwards only
authenticated GET /api/tags and POST /api/chat requests to local Ollama
(127.0.0.1:11434). Any unauthenticated request receives HTTP 401; any
model-mutating or admin endpoint receives HTTP 403.
"""
from __future__ import annotations

import hmac
import json
import os
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Deque

import httpx

OLLAMA_UPSTREAM = os.environ.get("OLLAMA_UPSTREAM", "http://127.0.0.1:11434").rstrip("/")
PROXY_HOST = os.environ.get("OLLAMA_PROXY_HOST", "127.0.0.1")
PROXY_PORT = int(os.environ.get("OLLAMA_PROXY_PORT", "11435"))
AUTH_TOKEN = os.environ.get("OLLAMA_AUTH_TOKEN", "")
MAX_CONCURRENT = max(1, int(os.environ.get("OLLAMA_PROXY_MAX_CONCURRENT", "2")))
RATE_LIMIT_PER_MIN = max(1, int(os.environ.get("OLLAMA_PROXY_RPM", "20")))
REQUEST_TIMEOUT = float(os.environ.get("OLLAMA_PROXY_TIMEOUT", "90"))

_ALLOWED_ROUTES = {
    ("GET", "/api/tags"),
    ("POST", "/api/chat"),
}

_concurrency_sem = threading.BoundedSemaphore(MAX_CONCURRENT)
_rate_lock = threading.Lock()
_request_timestamps: Deque[float] = deque()


def _check_rate_limit() -> bool:
    now = time.monotonic()
    with _rate_lock:
        while _request_timestamps and (now - _request_timestamps[0]) > 60.0:
            _request_timestamps.popleft()
        if len(_request_timestamps) >= RATE_LIMIT_PER_MIN:
            return False
        _request_timestamps.append(now)
        return True


def _is_authorized(auth_header: str | None) -> bool:
    if not AUTH_TOKEN or not auth_header or not auth_header.startswith("Bearer "):
        return False
    provided = auth_header[7:].strip()
    return hmac.compare_digest(provided, AUTH_TOKEN)


class OllamaAuthProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args) -> None:  # noqa: A002
        # Never log Authorization headers or secrets
        print(f"[ollama-proxy] {self.address_string()} - {format % args}")

    def _send_json(self, status_code: int, payload: dict) -> None:
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _handle(self, method: str) -> None:
        if not _is_authorized(self.headers.get("Authorization")):
            self._send_json(401, {"error": "Unauthorized: missing or invalid Bearer token."})
            return

        path = self.path.split("?", 1)[0]
        if (method, path) not in _ALLOWED_ROUTES:
            self._send_json(403, {"error": f"Forbidden: {method} {path} is not exposed by this gateway."})
            return

        if not _check_rate_limit():
            self._send_json(429, {"error": "Rate limit exceeded for local Ollama gateway."})
            return

        body = b""
        if method == "POST":
            content_len = int(self.headers.get("Content-Length", "0"))
            if content_len > 256 * 1024:
                self._send_json(413, {"error": "Request payload too large."})
                return
            body = self.rfile.read(content_len) if content_len > 0 else b""

        acquired = _concurrency_sem.acquire(blocking=True, timeout=5.0)
        if not acquired:
            self._send_json(429, {"error": "Local Ollama is busy; please retry shortly."})
            return

        try:
            with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
                upstream_resp = client.request(
                    method=method,
                    url=f"{OLLAMA_UPSTREAM}{path}",
                    content=body if method == "POST" else None,
                    headers={"Content-Type": "application/json"} if method == "POST" else None,
                )
            resp_bytes = upstream_resp.content
            self.send_response(upstream_resp.status_code)
            self.send_header(
                "Content-Type",
                upstream_resp.headers.get("Content-Type", "application/json"),
            )
            self.send_header("Content-Length", str(len(resp_bytes)))
            self.end_headers()
            self.wfile.write(resp_bytes)
        except httpx.ConnectError:
            self._send_json(503, {"error": "Local Ollama daemon is not running on 127.0.0.1:11434."})
        except httpx.TimeoutException:
            self._send_json(504, {"error": "Local Ollama inference timed out."})
        except Exception as exc:
            self._send_json(502, {"error": f"Gateway error: {exc}"})
        finally:
            _concurrency_sem.release()

    def do_GET(self) -> None:  # noqa: N802
        self._handle("GET")

    def do_POST(self) -> None:  # noqa: N802
        self._handle("POST")


def main() -> None:
    if not AUTH_TOKEN:
        raise RuntimeError("OLLAMA_AUTH_TOKEN environment variable must be set before starting proxy.")
    server = ThreadingHTTPServer((PROXY_HOST, PROXY_PORT), OllamaAuthProxyHandler)
    print(f"[ollama-proxy] Listening on http://{PROXY_HOST}:{PROXY_PORT} -> {OLLAMA_UPSTREAM}")
    print(f"[ollama-proxy] Limits: max_concurrent={MAX_CONCURRENT}, rpm={RATE_LIMIT_PER_MIN}")
    server.serve_forever()


if __name__ == "__main__":
    main()
