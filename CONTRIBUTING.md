# Contributing

Thanks for helping! Issues and pull requests are welcome. Step names, messages
and comments are in Spanish for now; English is fine in issues and PRs.

## Before you start

- Open an issue first for anything bigger than a small fix, so we can agree on
  the approach.
- Keep the installer **reversible**: anything a step writes must go through
  `put`/`track` (files) or `save_keys` (gsettings) in `install.sh`, so that
  `./install.sh desinstalar` can undo it.
- Don't add third-party wallpapers or assets without a clear license (see the
  credits in the README).

## Testing

**Don't run `install.sh` or the tests on your own machine to try a change**:
they modify `$HOME` and the desktop settings. Use one of these:

1. **Lint** (fast, what CI runs first):

   ```bash
   shellcheck install.sh capturar.sh gsettings/*.sh tests/*.sh tests/vm/guest/*.sh config/bash/omarchy-style.sh
   python3 -m py_compile bin/tema temas/matrix/animado tests/vm/*.py
   ```

2. **Smoke test** in a throwaway Ubuntu 24.04 container (the base of
   elementary OS 8). It installs the steps that don't need a desktop, checks
   them, reinstalls, uninstalls and checks that `$HOME` is back to how it was:

   ```bash
   docker run --rm -v "$PWD":/src:ro ubuntu:24.04 bash /src/tests/smoke.sh
   ```

3. **VM test** on the real desktop (elementary OS 8 live session, run by
   hand; it isn't in CI because GitHub's runners have no KVM for it). It covers
   what the container can't: `escritorio`, `atajos`, `fondos`, `animado`,
   switching themes with `tema` and the gsettings part of the uninstaller:

   ```bash
   tests/vm/run.py test
   ```

   It downloads the official ISO once (~3.3 GB, SHA-256 checked) to
   `~/.cache/pantheme-vm/`, boots it with QEMU/KVM inside Docker
   ([qemux/qemu](https://github.com/qemus/qemu)), clicks through to "Try Demo
   Mode", runs `./install.sh todo zed fondos animado`, checks every setting,
   switches themes, uninstalls and compares the result with a snapshot taken
   before installing. The report, logs and screenshots go to
   `vm-out/<date>/report.md`. It takes about 5 minutes once the ISO is cached.

   Needs Docker with access to `/dev/kvm` (Linux, or WSL2 with nested
   virtualization), ~4 GB of free RAM and Python 3; Pillow is optional (only
   for the GIF). While it runs you can watch the VM at
   <http://127.0.0.1:8006>. To poke around by hand:

   ```bash
   tests/vm/run.py up                 # boot and start the agent, leave it running
   echo 'gsettings get org.gnome.desktop.interface gtk-theme' | tests/vm/run.py job -
   tests/vm/run.py shot desktop       # screenshot
   tests/vm/run.py down               # stop and remove the container
   ```

   `PANTHEME_VM_KEEP=1 tests/vm/run.py test` leaves the VM running at the end.
   A run makes about 20 unauthenticated GitHub API requests (the limit is 60
   per hour); if you hit it, wait or set `GITHUB_TOKEN` (a token without
   scopes: the Ghostty step runs a third-party install script).

## Commits and changelog

- Small, focused commits with a message that says why.
- Add a line to `CHANGELOG.md` under "Unreleased" for user-visible changes.
- CI (shellcheck, py_compile and the smoke test) must pass.
