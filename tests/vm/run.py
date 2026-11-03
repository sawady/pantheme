#!/usr/bin/env python3
"""End-to-end test of pantheme on an elementary OS live session, in a VM.

QEMU/KVM runs inside a Docker container (qemux/qemu) that boots the official
elementary OS ISO in live ("demo") mode. The driver types one bootstrap line
into a terminal of the live desktop; from then on a small agent inside the VM
runs the test steps as shell jobs (tests/vm/guest/*.sh) and reports back.
Screenshots are taken with QEMU's QMP `screendump`.

  tests/vm/run.py test            full run: boot, install, check, switch themes,
                                  uninstall, compare with the initial state
  tests/vm/run.py migration [rev] install an older revision (default: the last
                                  one with the `tema` command), upgrade it with
                                  this one, check, uninstall and compare
  tests/vm/run.py up              boot the VM, start the agent and leave it running
  tests/vm/run.py job <file|->    run a shell script in the VM (VM must be up)
  tests/vm/run.py shot <name>     screenshot to <out>/<name>.png
  tests/vm/run.py keys <combo>..  send key combos (e.g. meta_l-t, ret)
  tests/vm/run.py type <text>     type text
  tests/vm/run.py click <x> <y>   left click (the live session runs at 1280x800)
  tests/vm/run.py down            stop and remove the container

Options (environment):
  PANTHEME_VM_CACHE   ISO cache (default ~/.cache/pantheme-vm)
  PANTHEME_VM_OUT     output directory (default <repo>/vm-out/<date>)
  PANTHEME_VM_KEEP=1  leave the VM running after `test` or `migration`
  GITHUB_TOKEN        passed to the installer in the VM, for GitHub's API rate
                      limit (60 requests/hour without it; a run uses ~20). The
                      Ghostty step runs a third-party script that can read it:
                      prefer a token without scopes.

While the VM runs, watch it at http://127.0.0.1:8006 (noVNC).
Needs: Docker with access to /dev/kvm, ~4 GB of free RAM, ~3.5 GB for the ISO.
Not run in CI: GitHub's runners have no nested KVM for containers.
"""
import datetime
import hashlib
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
ISO_NAME = "elementaryos-8.1-stable-amd64.20260219.iso"
ISO_URL = f"https://dl.elementaryos.org/MTc5MzYzMDY4Nw==/{ISO_NAME}"
# From https://elementary.io/docs/installation#verify-your-download
ISO_SHA256 = "bda93040d08c05911fb159f8150bf8f4ef2db6567ef6e2acd197cb6f395d3446"
IMAGE = "qemux/qemu:7.50"
NAME = "pantheme-vm"
# Last commit before the theme command was renamed from `tema` to `pantheme`
OLD_REV = "e079848"
WEB, QMP, AGENT = 8006, 4444, 8800
CACHE = Path(os.environ.get("PANTHEME_VM_CACHE", Path.home() / ".cache/pantheme-vm"))
OUT = Path(os.environ.get(
    "PANTHEME_VM_OUT", REPO / "vm-out" / datetime.datetime.now().strftime("%Y%m%d-%H%M%S")))


T0 = time.time()


def log(*a):
    print(f"[{datetime.datetime.now():%H:%M:%S}]", *a, flush=True)


def sh(*cmd, check=True, **kw):
    return subprocess.run(cmd, check=check, text=True, **kw)


# ------------------------------------------------------------------ ISO
def fetch_iso():
    CACHE.mkdir(parents=True, exist_ok=True)
    iso = CACHE / ISO_NAME
    ok = CACHE / (ISO_NAME + ".sha256-ok")
    if not iso.exists():
        log(f"Downloading {ISO_URL}")
        part = iso.with_suffix(".part")
        sh("curl", "-fL", "-C", "-", "-o", str(part), ISO_URL)
        part.rename(iso)
    stamp = f"{iso.stat().st_size} {iso.stat().st_mtime_ns}"
    if not ok.exists() or ok.read_text() != stamp:
        log("Verifying SHA-256")
        h = hashlib.sha256()
        with open(iso, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 22), b""):
                h.update(chunk)
        if h.hexdigest() != ISO_SHA256:
            sys.exit(f"SHA-256 mismatch for {iso}: {h.hexdigest()}")
        ok.write_text(stamp)
    return iso


# ------------------------------------------------------------------ container
def container_running():
    r = sh("docker", "ps", "-q", "-f", f"name=^{NAME}$", capture_output=True)
    return bool(r.stdout.strip())


def up_container(iso):
    OUT.mkdir(parents=True, exist_ok=True)
    sh("docker", "rm", "-f", "-v", NAME, check=False, capture_output=True)
    log(f"Starting {IMAGE} (watch it at http://127.0.0.1:{WEB})")
    sh("docker", "run", "-d", "--name", NAME,
       "--device", "/dev/kvm",
       "--mount", "type=tmpfs,destination=/storage",
       "-e", "RAM_SIZE=6G", "-e", "CPU_CORES=4", "-e", "DISK_SIZE=4G",
       "-e", "NETWORK=slirp", "-e", f"QMP={QMP}",
       # The ISO is hybrid, so qemux/qemu would attach it as a writable USB
       # disk: boot from a qcow2 overlay instead and keep the cached ISO intact.
       "-v", f"{iso}:/iso/elementary.iso:ro", "-e", "BOOT=/storage/boot.qcow2",
       "-v", f"{REPO}:/pantheme:ro",
       "-v", f"{OUT}:/out",
       "-p", f"127.0.0.1:{WEB}:8006",
       "-p", f"127.0.0.1:{QMP}:{QMP}",
       "-p", f"127.0.0.1:{AGENT}:{AGENT}",
       "--stop-timeout", "5",
       "--entrypoint", "sh", IMAGE, "-c",
       "qemu-img create -q -f qcow2 -F raw -b /iso/elementary.iso /storage/boot.qcow2"
       " && exec /usr/bin/tini -s /run/entry.sh", capture_output=True)
    sh("docker", "exec", "-d", NAME, "python3", "/pantheme/tests/vm/agent_server.py", str(AGENT))


def down():
    if sh("docker", "ps", "-aq", "-f", f"name=^{NAME}$", capture_output=True).stdout.strip():
        fix_owner()
        sh("docker", "rm", "-f", "-v", NAME, capture_output=True)
        log(f"Container {NAME} removed")


def fix_owner():
    """Files written by QEMU (screenshots) belong to root inside the container."""
    sh("docker", "exec", NAME, "chown", "-R", f"{os.getuid()}:{os.getgid()}", "/out",
       check=False, capture_output=True)


# ------------------------------------------------------------------ QMP
class Qmp:
    def __init__(self, timeout=120):
        deadline = time.time() + timeout
        while True:
            try:
                self.s = socket.create_connection(("127.0.0.1", QMP), timeout=10)
                self.f = self.s.makefile("rwb")
                if json.loads(self.f.readline()).get("QMP"):
                    break
            except (OSError, ValueError):
                pass
            if time.time() > deadline:
                sys.exit("QMP did not answer")
            time.sleep(2)
        self.cmd("qmp_capabilities")

    def cmd(self, execute, **arguments):
        msg = {"execute": execute}
        if arguments:
            msg["arguments"] = arguments
        self.f.write(json.dumps(msg).encode() + b"\n")
        self.f.flush()
        while True:
            r = json.loads(self.f.readline())
            if "return" in r:
                return r["return"]
            if "error" in r:
                raise RuntimeError(f"QMP {execute}: {r['error']}")

    def shot(self, name):
        path = OUT / f"{name}.png"
        self.cmd("screendump", filename=f"/out/{name}.png", format="png")
        return path

    def keys(self, *combos, hold=60, gap=0.08):
        for combo in combos:
            self.cmd("send-key", keys=[{"type": "qcode", "data": k} for k in combo.split("-")],
                     **{"hold-time": hold})
            time.sleep(gap)

    def click(self, x, y, size=(1280, 800)):
        """Left click at screen pixel (x, y), through the absolute USB tablet."""
        pos = [{"type": "abs", "data": {"axis": axis, "value": int(v * 32767 / (n - 1))}}
               for axis, v, n in (("x", x, size[0]), ("y", y, size[1]))]
        self.cmd("input-send-event", events=pos)
        time.sleep(0.15)
        for down in (True, False):
            self.cmd("input-send-event", events=[{"type": "btn", "data": {"button": "left", "down": down}}])
            time.sleep(0.1)

    def type(self, text):
        self.keys(*(KEYMAP[c] for c in text), gap=0.03)


# US layout
KEYMAP = {c: c for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
KEYMAP.update({c.upper(): f"shift-{c}" for c in "abcdefghijklmnopqrstuvwxyz"})
KEYMAP.update({
    " ": "spc", "\n": "ret", "\t": "tab", "-": "minus", "=": "equal", "[": "bracket_left",
    "]": "bracket_right", "\\": "backslash", ";": "semicolon", "'": "apostrophe",
    "`": "grave_accent", ",": "comma", ".": "dot", "/": "slash",
})
for c, k in zip('!@#$%^&*()_+{}|:"~<>?', list("1234567890") + [
        "minus", "equal", "bracket_left", "bracket_right", "backslash", "semicolon",
        "apostrophe", "grave_accent", "comma", "dot", "slash"]):
    KEYMAP[c] = f"shift-{k}"


# ------------------------------------------------------------------ agent
def agent(path, data=None, timeout=30):
    req = urllib.request.Request(f"http://127.0.0.1:{AGENT}{path}", data=data)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def hello():
    try:
        return agent("/hello")["hello"]
    except (urllib.error.URLError, OSError, ValueError):
        return None


# Environment for every job in the VM
JOB_ENV = {"DEBIAN_FRONTEND": "noninteractive"}
if os.environ.get("GITHUB_TOKEN"):
    JOB_ENV["GITHUB_TOKEN"] = os.environ["GITHUB_TOKEN"]


def job(script, timeout=1800, quiet=False):
    """Runs a script in the VM; returns (rc, output)."""
    jid = agent("/enqueue", json.dumps({"script": script, "env": JOB_ENV}).encode())["id"]
    deadline, shown = time.time() + timeout, 0
    while time.time() < deadline:
        st = agent(f"/status/{jid}")
        if not quiet and len(st["output"]) > shown:
            sys.stdout.write(st["output"][shown:])
            sys.stdout.flush()
            shown = len(st["output"])
        if st["state"] == "done":
            return st["rc"], st["output"]
        time.sleep(2)
    raise TimeoutError(f"job {jid} did not finish in {timeout} s")


def guest(name, *args, **kw):
    """Runs tests/vm/guest/<name>.sh with arguments."""
    body = (HERE / "guest" / f"{name}.sh").read_text()
    quoted = " ".join("'" + a.replace("'", "'\\''") + "'" for a in args)
    return job(f"set -- {quoted}\n{body}", **kw)


# ------------------------------------------------------------------ boot
# Screen positions and colors at the live session's 1280x800 (elementary OS 8.1).
# The installer's title cycles through languages, so instead of waiting for the
# screen to settle the boot waits for these reference pixels.
WHITE = (250, 250, 250)
SELECT = (1000, 661)        # "Select" / "Next", bottom right of the installer
TRY_DEMO = (659, 279)       # "Try Demo Mode" radio button
INSTALLER = [((300, 150), WHITE), (SELECT, (188, 210, 231))]   # "Select" enabled
TRY_PAGE = [((300, 150), WHITE), (SELECT, (240, 240, 240))]    # "Next" disabled


def screen(qmp):
    """Screendump as (width, height, rgb bytes), in PPM (no Pillow needed)."""
    qmp.cmd("screendump", filename="/out/_probe.ppm")
    data = (OUT / "_probe.ppm").read_bytes()
    magic, size, _maxval, pixels = data.split(b"\n", 3)
    w, h = map(int, size.split())
    return w, h, pixels


def matches(qmp, checks, tol=14):
    w, _h, px = screen(qmp)
    for (x, y), rgb in checks:
        got = px[(y * w + x) * 3:(y * w + x) * 3 + 3]
        if len(got) < 3 or any(abs(a - b) > tol for a, b in zip(got, rgb)):
            return False
    return True


def wait_for(qmp, label, checks, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if matches(qmp, checks):
                time.sleep(1)       # let it finish drawing
                return True
        except (OSError, ValueError):
            pass
        time.sleep(1.5)
    qmp.shot(f"boot-timeout-{label}")
    sys.exit(f"Timed out waiting for: {label} (see boot-timeout-{label}.png)")


def wait_hello(timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        h = hello()
        if h:
            return h
        time.sleep(2)
    return None


def boot(qmp):
    """Live ISO -> installer -> "Try Demo Mode" -> terminal -> agent."""
    log("Waiting for the installer")
    wait_for(qmp, "installer", INSTALLER, 600)
    qmp.shot("boot-1-installer")
    qmp.keys("ret")                 # "English..." -> English (United States)
    time.sleep(2)
    for _ in range(3):              # language, keyboard layout, layout variant
        qmp.click(*SELECT)
        time.sleep(2.5)
    wait_for(qmp, "try-or-install", TRY_PAGE, 30)
    qmp.click(*TRY_DEMO)
    time.sleep(1)
    qmp.shot("boot-2-try-demo")
    qmp.click(*SELECT)
    log("Waiting for the demo session")
    deadline = time.time() + 120
    while matches(qmp, TRY_PAGE) and time.time() < deadline:
        time.sleep(2)
    # The session takes a few seconds and then opens a welcome app (where it
    # opens varies). Super+T opens a terminal on top of it; the agent's hello is
    # what tells that the bootstrap line was typed in the right place.
    time.sleep(25)
    qmp.shot("boot-3-session")
    for attempt in range(5):
        qmp.keys("meta_l-t")            # elementary's Terminal
        time.sleep(6 + 3 * attempt)
        qmp.type(f"wget -qO- 172.17.0.1:{AGENT}/b | bash\n")
        h = wait_hello(30)
        if h:
            qmp.shot("boot-4-agent")
            return h
        qmp.shot(f"boot-4-no-agent-{attempt}")
    sys.exit("The agent did not start in the VM (see boot-*.png)")


# ------------------------------------------------------------------ test
class Report:
    def __init__(self):
        self.rows, self.t0 = [], T0
        (OUT / "logs").mkdir(parents=True, exist_ok=True)

    def step(self, name, rc, output, started):
        n = len(self.rows) + 1
        logname = f"logs/{n:02d}-{name.replace(' ', '-').replace('/', '-')}.log"
        (OUT / logname).write_text(output)
        self.rows.append((name, rc, time.time() - started, logname))
        log(f"{'PASS' if rc == 0 else 'FAIL'}  {name}  ({time.time() - started:.0f} s)")
        return rc == 0

    def write(self, hello_info, shots):
        failed = [r for r in self.rows if r[1] != 0]
        lines = [
            "# pantheme VM test",
            "",
            f"- Result: **{'PASS' if not failed else 'FAIL'}** "
            f"({len(self.rows) - len(failed)}/{len(self.rows)} steps passed, "
            f"{(time.time() - self.t0) / 60:.1f} min)",
            f"- ISO: `{ISO_NAME}` (SHA-256 verified)",
            f"- VM: `{IMAGE}`, live session (\"Try Demo Mode\"), 4 vCPU, 6 GB RAM, KVM",
            f"- Commit: `{git_rev()}`",
            "- Session: " + " · ".join((hello_info or "?").split("\n")).strip(" ·"),
            "",
            "| Step | Result | Time | Log |",
            "|---|---|---|---|",
        ]
        for name, rc, secs, logname in self.rows:
            lines.append(f"| {name} | {'pass' if rc == 0 else f'**FAIL** (rc {rc})'} "
                         f"| {secs:.0f} s | [{logname}]({logname}) |")
        lines += ["", "## Screenshots", ""]
        lines += [f"- [{s}]({s}.png)" for s in shots]
        (OUT / "report.md").write_text("\n".join(lines) + "\n")
        return not failed


def git_rev():
    r = sh("git", "-C", str(REPO), "describe", "--always", "--dirty", capture_output=True, check=False)
    return r.stdout.strip() or "?"


def run_step(report, name, script_or_guest, *args, timeout=600, guest_script=True):
    started = time.time()
    log(f"... {name}")
    try:
        if guest_script:
            rc, out = guest(script_or_guest, *args, timeout=timeout, quiet=True)
        else:
            rc, out = job(script_or_guest, timeout=timeout, quiet=True)
    except TimeoutError as e:
        rc, out = 124, str(e)
    return report.step(name, rc, out, started)


def in_terminal(qmp, *commands, wait=3):
    """Types commands into the focused terminal."""
    for c in commands:
        qmp.type(c + "\n")
        time.sleep(wait)


def switch_theme(qmp, name):
    """Types `pantheme <name>` in the focused terminal and waits until it's applied."""
    for _ in range(3):
        in_terminal(qmp, "clear", wait=1)
        in_terminal(qmp, f"pantheme {name}", wait=1)
        for _ in range(15):
            rc, _ = job(f'[ "$(cat ~/.config/tema/actual)" = {name} ]', quiet=True)
            if rc == 0:
                time.sleep(2)
                return
            time.sleep(2)
        log(f"`pantheme {name}` didn't take effect, typing it again")
        qmp.keys("ctrl-c")


def session(body):
    """Boots the VM, runs body(qmp, step, shot), writes the report and stops the VM."""
    keep = os.environ.get("PANTHEME_VM_KEEP") == "1"
    iso = fetch_iso()
    up_container(iso)
    shots = []
    try:
        qmp = Qmp()
        info = boot(qmp)
        log("agent:", " ".join(info.split()))
        report = Report()

        def step(*a, **kw):
            return run_step(report, *a, **kw)

        def shot(name):
            qmp.shot(name)
            shots.append(name)

        body(qmp, step, shot)
        ok = report.write(info, shots)
        make_gif()
        log(f"Report: {OUT / 'report.md'}")
        return 0 if ok else 1
    finally:
        (OUT / "_probe.ppm").unlink(missing_ok=True)
        if keep:
            fix_owner()
            log(f"VM left running: http://127.0.0.1:{WEB}  (stop it with: {sys.argv[0]} down)")
        else:
            down()


def test():
    def body(qmp, S, shot):
        S("prepare live session", "prepare")
        S("download repository", "fetch")
        S("snapshot before", "state", "before")
        installed = S("install.sh all zed wallpaper-rotation animated",
                      "cd ~/pantheme && ./install.sh all zed wallpaper-rotation animated",
                      guest_script=False, timeout=2400)
        if installed:
            S("check install", "check-installed", timeout=300)
            S("messages in Spanish with LANG=es_AR", "spanish", timeout=300)

            # Screenshots, with plain wallpapers instead of the downloaded ones
            S("plain wallpapers for screenshots", "plain-walls")
            job("pkill -x ghostty; export PATH=$HOME/.local/bin:$PATH; pantheme tokyo-night", quiet=True)
            S("check theme tokyo-night", "check-theme", "tokyo-night", "dark", "grape")
            qmp.keys("meta_l-ret")      # the Super+Enter shortcut opens Ghostty
            time.sleep(5)
            in_terminal(qmp, "fastfetch", wait=4)
            shot("tokyo-night")
            in_terminal(qmp, "clear", wait=1)
            in_terminal(qmp, "pantheme", wait=2)
            in_terminal(qmp, "pantheme catppuccin-latte", wait=1)
            for _ in range(15):
                if job('[ "$(cat ~/.config/tema/actual)" = catppuccin-latte ]', quiet=True)[0] == 0:
                    break
                time.sleep(2)
            time.sleep(2)
            shot("pantheme-catppuccin-latte")
            S("check theme catppuccin-latte", "check-theme", "catppuccin-latte", "light", "any")
            switch_theme(qmp, "gruvbox")
            qmp.keys("ctrl-minus")      # smaller font: btop wants at least 80 columns
            time.sleep(2)
            in_terminal(qmp, "btop", wait=6)
            shot("btop-gruvbox")
            qmp.keys("q")
            time.sleep(1)
            qmp.keys("ctrl-0")
            time.sleep(2)
            S("check theme gruvbox", "check-theme", "gruvbox", "dark", "any")
            switch_theme(qmp, "matrix")
            in_terminal(qmp, "clear", "fastfetch", wait=4)
            shot("matrix")
            for i in range(12):
                qmp.shot(f"_matrix-{i:02d}")
                time.sleep(0.2)
            S("check theme matrix (animated)", "check-theme", "matrix", "dark", "lime", "animated")
            S("pantheme animated off|on (and tema animado)", "animated-toggle")
            qmp.keys("meta_l-w")        # the Super+W shortcut closes the window
            time.sleep(2)
            S("Super+W closed Ghostty", "! pgrep -x ghostty", guest_script=False)
            S("restore downloaded wallpapers", "plain-walls", "restore")

        S("install.sh uninstall", "cd ~/pantheme && ./install.sh uninstall",
          guest_script=False, timeout=600)
        S("animated wallpaper and timer stopped",
          "! pgrep -f 'tema/.*/animado' && ! systemctl --user is-enabled pantheme-wallpaper.timer",
          guest_script=False)
        S("snapshot after", "state", "after")
        S("compare with the initial state", "compare", "before", "after")
        shot("after-uninstall")

    return session(body)


def migration(rev):
    """An install made by an older revision, upgraded by running this one."""
    OUT.mkdir(parents=True, exist_ok=True)
    sh("git", "-C", str(REPO), "archive", "--format=tar.gz", "--prefix=pantheme-old/",
       "-o", str(OUT / "old-repo.tar.gz"), rev)

    def body(qmp, S, shot):
        S("prepare live session", "prepare")
        S("download repository", "fetch")
        S(f"download {rev}", "fetch", "out/old-repo.tar.gz", "pantheme-old")
        S("snapshot before", "state", "before")
        old = S(f"{rev}: install.sh todo fondos animado, tema matrix",
                "cd ~/pantheme-old && ./install.sh todo fondos animado && ~/.local/bin/tema matrix",
                guest_script=False, timeout=2400)
        if old:
            S(f"check the {rev} install", "check-old-install")
            S("new install.sh shell migrates it",
              "cd ~/pantheme && out=$(./install.sh shell 2>&1); echo \"$out\"; "
              "grep -q 'Migrating an install of' <<<\"$out\"", guest_script=False)
            S("check the migration", "check-migrated")
            shot("migrated")
        S("install.sh desinstalar with LANG=es_AR",
          "cd ~/pantheme && out=$(LANG=es_AR.UTF-8 ./install.sh desinstalar 2>&1); echo \"$out\"; "
          "grep -q 'Desinstalar: wallpaper-rotation' <<<\"$out\"", guest_script=False, timeout=600)
        S("animated wallpaper and timers stopped",
          "! pgrep -f 'tema/.*/animado' && ! systemctl --user is-enabled pantheme-wallpaper.timer"
          " && ! systemctl --user is-enabled tema-fondo.timer", guest_script=False)
        S("snapshot after", "state", "after")
        S("compare with the initial state", "compare", "before", "after")

    return session(body)


def make_gif():
    """Matrix animation from the frames taken right after the screenshot."""
    frames = sorted(OUT.glob("_matrix-*.png"))
    if not frames:
        return
    try:
        from PIL import Image
    except ImportError:
        log("Pillow not available: no GIF")
        return
    imgs = [Image.open(f).convert("RGB").resize((640, 400), Image.LANCZOS) for f in frames]
    # One palette for every frame, so the colors don't flicker
    palette = imgs[0].quantize(colors=128, method=Image.MEDIANCUT)
    imgs = [i.quantize(palette=palette, dither=Image.NONE) for i in imgs]
    imgs[0].save(OUT / "matrix.gif", save_all=True, append_images=imgs[1:], duration=200,
                 loop=0, optimize=True)
    for f in frames:
        f.unlink()


# ------------------------------------------------------------------ main
def use_running_out():
    """Subcommands that talk to a running VM write where `up`/`test` mounted /out."""
    global OUT
    if "PANTHEME_VM_OUT" in os.environ:
        return
    r = sh("docker", "inspect", "-f",
           '{{range .Mounts}}{{if eq .Destination "/out"}}{{.Source}}{{end}}{{end}}', NAME,
           capture_output=True, check=False)
    if r.returncode == 0 and r.stdout.strip():
        OUT = Path(r.stdout.strip())


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return
    what = args[0]
    if what not in ("up", "test", "migration"):
        use_running_out()
    if what == "up":
        up_container(fetch_iso())
        log("agent:", " ".join(boot(Qmp()).split()))
        fix_owner()
        log(f"VM running: http://127.0.0.1:{WEB}  (stop it with: {sys.argv[0]} down)")
    elif what == "down":
        down()
    elif what == "shot":
        print(Qmp().shot(args[1]))
        fix_owner()
    elif what == "keys":
        Qmp().keys(*args[1:])
    elif what == "click":
        Qmp().click(int(args[1]), int(args[2]))
    elif what == "type":
        Qmp().type(" ".join(args[1:]))
    elif what == "job":
        script = sys.stdin.read() if args[1] == "-" else Path(args[1]).read_text()
        rc, _ = job(script)
        sys.exit(rc)
    elif what == "test":
        sys.exit(test())
    elif what == "migration":
        sys.exit(migration(args[1] if len(args) > 1 else OLD_REV))
    else:
        sys.exit(f"unknown command: {what}")


if __name__ == "__main__":
    main()
