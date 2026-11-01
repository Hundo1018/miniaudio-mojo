#!/usr/bin/env python3
"""Serve the browser example with the headers SharedArrayBuffer needs.

    python3 examples/web/serve.py [port]      # then open http://localhost:8000/

Serves examples/web/ plus build/wasm/audio.wasm (as /audio.wasm) and the generated
test clip (as /clip.wav). COOP/COEP make the page cross-origin isolated, which is
what lets main.js share a ring buffer with the AudioWorklet.
"""

import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
WEB = ROOT / "examples" / "web"
ALIASES = {
    "/audio.wasm": ROOT / "build" / "wasm" / "audio.wasm",
    "/clip.wav": ROOT / "build" / "test_assets" / "sine_440_stereo.wav",
}


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".js": "text/javascript"}

    def translate_path(self, path):
        alias = ALIASES.get(path.split("?")[0])
        return str(alias) if alias else super().translate_path(path)

    def do_POST(self):
        """/report: a ?selftest page posts its counters here (build/wasm/browser_report.json)."""
        if self.path != "/report":
            self.send_error(404)
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        (ROOT / "build" / "wasm" / "browser_report.json").write_bytes(body)
        self.send_response(204)
        self.end_headers()

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f"serving {WEB} on http://localhost:{port}/")
    ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=str(WEB))).serve_forever()
