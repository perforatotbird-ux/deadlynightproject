#!/usr/bin/env python3
"""
Deadly Night MVP - Local HTTP Server with COOP/COEP support for Godot Web Exports.
"""
import http.server
import socketserver
import os
import sys

PORT = 8000
WEB_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "exports", "web")

class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        # Enable Cross-Origin Isolation headers for Godot Web/Wasm
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

def run_server(port=PORT):
    if not os.path.exists(WEB_DIR):
        os.makedirs(WEB_DIR, exist_ok=True)
    
    server_address = ("127.0.0.1", port)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(server_address, GodotWebHandler) as httpd:
        print(f"Serving Godot Web Export at http://127.0.0.1:{port}/")
        print(f"Directory: {WEB_DIR}")
        print("Press Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")

if __name__ == "__main__":
    p = int(sys.argv[1]) if len(sys.argv) > 1 else PORT
    run_server(p)
