# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
No version has been released yet. A development log in Spanish, with the
reasoning behind each decision, is in [BITACORA.md](BITACORA.md).

## [Unreleased]

### Added

- Step-by-step installer for elementary OS 8: `./install.sh [step...]`, with
  default steps `paquetes ghostty binarios configs shell escritorio atajos tema`
  and optional `zed fondos animado`.
- Ghostty as the default terminal (and in the dock), with JetBrains Mono Nerd
  Font and a Starship prompt; eza, bat, fzf, zoxide, btop, fastfetch, lazygit
  and lazydocker, with aliases in `~/.config/bash/omarchy-style.sh`.
- `tema`, a theme switcher that applies Omarchy's palettes and wallpapers to
  Ghostty, Starship, btop, Zed, the wallpaper, the Pantheon accent color and
  light/dark mode. Themes are downloaded on first use.
- Bundled **Matrix** theme with an animated katakana-rain wallpaper
  (`tema animado on|off`) and a Zed theme.
- Keyboard shortcuts in the Omarchy spirit (Super+Enter, Super+W, Super+1–9…).
- Wallpaper rotation every 30 minutes with a systemd user timer (`fondos`).
- Uninstaller: `./install.sh desinstalar [step...]` restores the files and
  desktop settings that were there before installing, using a record in
  `~/.local/state/pantheme/`.
- CI: shellcheck, py_compile and a smoke test in an `ubuntu:24.04` container,
  plus a weekly run to catch upstream changes.
- End-to-end test on an elementary OS 8 live session in a QEMU/KVM VM
  (`tests/vm/run.py`, run by hand), and README screenshots taken with it.
- `gsettings/atajos.sh --valores` lists the shortcuts it applies.
- `CONTRIBUTING.md`, `CHANGELOG.md`, MIT license, README in English and
  Spanish.

### Changed

- Renamed from `elementary-setup` to **pantheme**. The installer moves an old
  `~/.local/state/elementary-setup/` record to the new place automatically.
- `escritorio` only swaps elementary's Terminal for Ghostty in the dock
  instead of replacing the whole dock, and no longer changes the Terminal's
  font.
- Wallpapers go to the XDG pictures folder (or `$TEMA_WALLPAPERS`) instead of a
  fixed path.

### Fixed

- Right after installing, Ghostty opened without the Starship prompt and
  `fastfetch`, `tema` and the other tools in `~/.local/bin` were "not found"
  until logging out and back in: Ubuntu only adds `~/.local/bin` to `PATH` if
  it existed at login. `omarchy-style.sh` now adds it.
- Uninstalling left `~/.bashrc` one byte different from the original when it
  didn't end with a newline (as elementary OS's default `.bashrc`); now it's
  restored byte for byte.
- `./install.sh shell` on its own didn't create the install record, so a later
  `./install.sh desinstalar` said there was nothing to undo.
- The README's install instructions now install `git` first: elementary OS 8
  doesn't ship it.
- When a GitHub request fails (usually the API's rate limit of 60 requests per
  hour), the installer says so and suggests `GITHUB_TOKEN` instead of stopping
  without a message.
