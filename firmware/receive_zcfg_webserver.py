#!/usr/bin/env python3


from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime

class UploadHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        data   = self.rfile.read(length)

        ts   = datetime.now().strftime('%Y%m%d_%H%M%S')
        name = f"zcfg_config.json.{ts}"
        with open(name, "wb") as f:
            f.write(data)

        print(f"[+]  {name} saved ({len(data)} Bytes)")

        self.send_response(200)
        self.end_headers()

    def log_message(self, fmt, *args):
        pass

def main():
    host, port = "0.0.0.0", 8080        
    srv = HTTPServer((host, port), UploadHandler)
    print(f"Listening on {host}:{port} – Ctrl‑C to stop.")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nServer closed.")

if __name__ == "__main__":
    main()
