#!/usr/bin/env python3
"""Job server for the pantheme VM test. Runs inside the QEMU container.

The guest (a live elementary OS session) runs guest_agent.py, which polls this
server for shell jobs and posts their output back. The host-side driver
(run.py) enqueues jobs and waits for results through a port published only on
127.0.0.1.

  GET  /b                 bootstrap: shell snippet that starts the guest agent
  GET  /agent.py          the guest agent
  GET  /repo.tar.gz       the repository mounted at /pantheme (no .git)
  GET  /job               guest: next job as JSON, 204 if none (long poll ~20 s)
  POST /log/<id>          guest: output so far
  POST /result/<id>       guest: final output, exit code in X-Exit-Code
  POST /hello             guest: agent started (body: environment summary)
  POST /enqueue           host: body is JSON {"script": ..., "env": {...}} -> {"id": N}
  GET  /status/<id>       host: {"state": ..., "rc": ..., "output": ...}
  GET  /hello             host: {"hello": <body or null>}
"""
import io
import json
import os
import sys
import tarfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO = os.environ.get("PANTHEME_REPO", "/pantheme")
HERE = os.path.dirname(os.path.abspath(__file__))
LOCK = threading.Condition()
JOBS = {}      # id -> {"script", "env", "state", "rc", "output"}
QUEUE = []
HELLO = {"body": None}
NEXT = [1]


def repo_tarball():
    buf = io.BytesIO()
    skip = {".git", "__pycache__", "vm-out"}
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        tar.add(REPO, arcname="pantheme",
                filter=lambda ti: None if set(ti.name.split("/")) & skip else ti)
    return buf.getvalue()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        if "/job" not in self.path and "/status" not in self.path and "/log/" not in self.path:
            sys.stderr.write("agent-server: " + fmt % args + "\n")

    def send(self, code, body=b"", ctype="application/octet-stream"):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def do_GET(self):
        p = self.path
        if p == "/b":
            host = self.headers.get("Host")
            self.send(200, (
                f"wget -qO /tmp/pantheme-agent.py http://{host}/agent.py && "
                f"exec python3 /tmp/pantheme-agent.py http://{host}\n"), "text/plain")
        elif p == "/agent.py":
            with open(os.path.join(HERE, "guest_agent.py"), "rb") as f:
                self.send(200, f.read(), "text/x-python")
        elif p == "/repo.tar.gz":
            self.send(200, repo_tarball(), "application/gzip")
        elif p == "/job":
            with LOCK:
                LOCK.wait_for(lambda: QUEUE, timeout=20)
                if not QUEUE:
                    return self.send(204)
                jid = QUEUE.pop(0)
                JOBS[jid]["state"] = "running"
                job = {"id": jid, "script": JOBS[jid]["script"], "env": JOBS[jid]["env"]}
            self.send(200, json.dumps(job), "application/json")
        elif p.startswith("/status/"):
            jid = int(p.rsplit("/", 1)[1])
            with LOCK:
                j = JOBS.get(jid)
                out = {k: j[k] for k in ("state", "rc", "output")} if j else {"state": "unknown"}
            self.send(200, json.dumps(out), "application/json")
        elif p == "/hello":
            self.send(200, json.dumps({"hello": HELLO["body"]}), "application/json")
        else:
            self.send(404, "not found\n", "text/plain")

    def do_POST(self):
        p, data = self.path, self.body()
        if p == "/hello":
            HELLO["body"] = data.decode(errors="replace")
            self.send(200, "ok\n")
        elif p == "/enqueue":
            req = json.loads(data)
            with LOCK:
                jid = NEXT[0]
                NEXT[0] += 1
                JOBS[jid] = {"script": req["script"], "env": req.get("env", {}),
                             "state": "queued", "rc": None, "output": ""}
                QUEUE.append(jid)
                LOCK.notify_all()
            self.send(200, json.dumps({"id": jid}), "application/json")
        elif p.startswith("/log/") or p.startswith("/result/"):
            jid = int(p.rsplit("/", 1)[1])
            with LOCK:
                if jid in JOBS:
                    JOBS[jid]["output"] = data.decode(errors="replace")
                    if p.startswith("/result/"):
                        JOBS[jid]["rc"] = int(self.headers.get("X-Exit-Code", "-1"))
                        JOBS[jid]["state"] = "done"
            self.send(200, "ok\n")
        else:
            self.send(404, "not found\n", "text/plain")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8800
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
