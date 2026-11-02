#!/usr/bin/env python3
"""Guest side of the pantheme VM test: runs inside the elementary OS session.

Started from a terminal in the desktop session (so jobs inherit DISPLAY,
DBUS_SESSION_BUS_ADDRESS, etc.). Polls the job server, runs each job with
bash and posts the output back. Stdlib only.
"""
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

BASE = sys.argv[1].rstrip("/")


def request(path, data=None, headers=None, timeout=30):
    req = urllib.request.Request(BASE + path, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read()


def post(path, data, headers=None):
    for _ in range(5):
        try:
            return request(path, data, headers)
        except (urllib.error.URLError, OSError):
            time.sleep(2)


def run(job):
    env = dict(os.environ, PANTHEME_AGENT=BASE, **job.get("env", {}))
    with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as f:
        f.write(job["script"])
        script = f.name
    log = script + ".log"
    with open(log, "wb") as out:
        proc = subprocess.Popen(["bash", script], stdout=out, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, env=env, cwd=os.path.expanduser("~"),
                                start_new_session=True)
        while True:
            try:
                proc.wait(timeout=5)
                break
            except subprocess.TimeoutExpired:
                with open(log, "rb") as f:
                    post(f"/log/{job['id']}", f.read())
    with open(log, "rb") as f:
        post(f"/result/{job['id']}", f.read(), {"X-Exit-Code": str(proc.returncode)})


def main():
    # Started from a terminal: keep running in its own session, so the test
    # can close that terminal (screenshots) without killing the agent.
    if "--detached" not in sys.argv:
        subprocess.Popen([sys.executable, __file__, BASE, "--detached"], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=open("/tmp/pantheme-agent.log", "ab"),
                         stderr=subprocess.STDOUT)
        print("pantheme agent started in the background (log: /tmp/pantheme-agent.log)")
        return
    info = subprocess.run(
        "echo user=$(id -un) session=$XDG_SESSION_TYPE desktop=$XDG_CURRENT_DESKTOP "
        "display=$DISPLAY; . /etc/os-release; echo os=\"$PRETTY_NAME\"; "
        "sudo -n true 2>/dev/null && echo sudo=yes || echo sudo=no",
        shell=True, capture_output=True, text=True).stdout
    post("/hello", info.encode())
    print("pantheme agent running; jobs from", BASE, flush=True)
    while True:
        try:
            status, body = request("/job", timeout=40)
        except (urllib.error.URLError, OSError):
            time.sleep(2)
            continue
        if status == 200:
            job = json.loads(body)
            print(f"job {job['id']}")
            run(job)


if __name__ == "__main__":
    main()
