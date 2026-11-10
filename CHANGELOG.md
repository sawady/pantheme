# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/). A development
log in Spanish, with the reasoning behind each decision, is in
[BITACORA.md](BITACORA.md).

## [Unreleased]

### Added

- Optional `gtk` step: the window colors of GTK 3 and 4 apps follow the theme.
  It imports a `pantheme.css` from `~/.config/gtk-{3,4}.0/gtk.css`, which
  `pantheme` rewrites on every theme change; uninstalling restores the files.

### Fixed

- With `PANTHEME_WALLPAPERS` outside `$HOME`, `./install.sh uninstall` left the
  bundled wallpapers in place while saying it had removed them. Now they are
  removed (or the original is put back), also for existing installs. Folders
  outside `$HOME` are left alone, even if they end up empty.
- A relative `PANTHEME_WALLPAPERS` was recorded as if it were relative to
  `$HOME`, so `./install.sh uninstall` could leave the wallpapers in place or
  take a file with the same path from `$HOME`. It is now resolved against the
  directory the installer runs in. Paths already recorded this way can't be
  told apart from ones in `$HOME`, so they are still read as relative to it.

## [0.1.0] - 2026-11-03

First public release.

### Added

- Step-by-step installer for elementary OS 8: `./install.sh [step...]`, with
  default steps `packages ghostty binaries configs shell desktop shortcuts
  theme`, optional `zed wallpaper-rotation animated`, and `all`, `uninstall`
  and `help`.
- Ghostty as the default terminal (and in the dock), with JetBrains Mono Nerd
  Font and a Starship prompt; eza, bat, fzf, zoxide, btop, fastfetch, lazygit
  and lazydocker, with aliases in `~/.config/bash/omarchy-style.sh`.
- `pantheme`, a theme switcher that applies Omarchy's palettes and wallpapers
  to Ghostty, Starship, btop, Zed, the wallpaper, the Pantheon accent color and
  light/dark mode. Themes are downloaded on first use. `pantheme wallpaper`
  switches to the next wallpaper.
- Bundled **Matrix** theme with an animated katakana-rain wallpaper
  (`pantheme animated on|off`) and a Zed theme.
- Keyboard shortcuts in the Omarchy spirit (Super+Enter, Super+W, Super+1–9…).
- Wallpaper rotation every 30 minutes with a systemd user timer
  (`wallpaper-rotation`).
- Uninstaller: `./install.sh uninstall [step...]` restores the files and
  desktop settings that were there before installing, using a record in
  `~/.local/state/pantheme/`.
- Messages in English, or in Spanish when the locale is Spanish (`LC_ALL`,
  `LC_MESSAGES` or `LANG` starting with `es`), for the installer and
  `pantheme`.
- CI: shellcheck, py_compile and a smoke test in an `ubuntu:24.04` container,
  plus a weekly run to catch upstream changes.
- End-to-end tests on an elementary OS 8 live session in a QEMU/KVM VM
  (`tests/vm/run.py test` and `tests/vm/run.py migration`, run by hand), and
  README screenshots taken with them.
- `gsettings/shortcuts.sh --values` lists the shortcuts it applies.
- `CONTRIBUTING.md`, `CHANGELOG.md`, MIT license, README in English and
  Spanish.

### Changed

These matter if you installed a development version before this release.

- Renamed from `elementary-setup` to **pantheme**. The installer moves an old
  `~/.local/state/elementary-setup/` record to the new place automatically.
- The theme command is now `pantheme` (it was `tema`), with English
  subcommands (`wallpaper`, `animated`, `help`). `tema` is installed as an
  alias and still accepts `fondo`, `animado` and `ayuda`.
- Installer steps have English names; the Spanish ones (`paquetes`,
  `binarios`, `escritorio`, `atajos`, `tema`, `fondos`, `animado`, `todo`,
  `desinstalar`, `ayuda`) still work as aliases.
- The systemd user units and the autostart entry are now
  `pantheme-wallpaper.service`/`.timer`, `pantheme-animated.service` and
  `pantheme-animated.desktop` (they were `tema-fondo.*`, `tema-animado.*`).
  The next `./install.sh` migrates an existing install: it stops and disables
  the old units, removes them, installs the new ones and updates the record.
  `./install.sh uninstall` handles both the old and the new names.
- `PANTHEME_THEME` and `PANTHEME_WALLPAPERS` replace `TEMA_INICIAL` and
  `TEMA_WALLPAPERS`, which still work.
- `gsettings/atajos.sh` and `gsettings/escritorio.sh` are now
  `gsettings/shortcuts.sh` (`--keys`, `--values`, `--reset`; the Spanish
  options still work) and `gsettings/desktop.sh`; `capturar.sh` is now
  `capture.sh`.
- `desktop` only swaps elementary's Terminal for Ghostty in the dock instead
  of replacing the whole dock, and no longer changes the Terminal's font.
- Wallpapers go to the XDG pictures folder (or `$PANTHEME_WALLPAPERS`) instead
  of a fixed path.

### Fixed

- Right after installing, Ghostty opened without the Starship prompt and
  `fastfetch`, `pantheme` and the other tools in `~/.local/bin` were "not
  found" until logging out and back in: Ubuntu only adds `~/.local/bin` to
  `PATH` if it existed at login. `omarchy-style.sh` now adds it.
- Uninstalling left `~/.bashrc` one byte different from the original when it
  didn't end with a newline (as elementary OS's default `.bashrc`); now it's
  restored byte for byte.
- `./install.sh shell` on its own didn't create the install record, so a later
  `./install.sh uninstall` said there was nothing to undo.
- The README's install instructions now install `git` first: elementary OS 8
  doesn't ship it.
- When a GitHub request fails (usually the API's rate limit of 60 requests per
  hour), the installer and `pantheme` say so and suggest `GITHUB_TOKEN`
  instead of stopping without a message or with a traceback.

[Unreleased]: https://github.com/sawady/pantheme/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sawady/pantheme/releases/tag/v0.1.0
