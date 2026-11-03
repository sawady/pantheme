#!/usr/bin/env bash
# Keyboard shortcuts for Pantheon (inspired by Omarchy).
#
#   ./gsettings/shortcuts.sh           applies the shortcuts
#   ./gsettings/shortcuts.sh --keys    lists the keys it sets (schema key)
#   ./gsettings/shortcuts.sh --values  lists what it applies (schema key value)
#   ./gsettings/shortcuts.sh --reset   goes back to the factory defaults
#
# `./install.sh uninstall shortcuts` restores the values from before
# installing, which aren't always the factory defaults. The Spanish options of
# earlier versions (--claves, --valores, --restaurar) still work.
set -euo pipefail

case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in es*) UI=es ;; *) UI=en ;; esac
say() { if [ "$UI" = es ]; then echo "$2"; else echo "$1"; fi; }  # english spanish

WM=org.gnome.desktop.wm.keybindings
MK=org.gnome.settings-daemon.plugins.media-keys
DOCK=io.elementary.dock.keybindings
GALA=io.elementary.desktop.wm.keybindings

# "schema key value"
BINDINGS=(
  "$GALA pip ['<Super><Shift>p']"                         # picture in picture
  "$WM toggle-fullscreen ['<Super>f']"                    # fullscreen
  "$WM close ['<Alt>F4', '<Super>w']"                     # close window
  "$MK terminal ['<Super>t', '<Super>Return']"            # terminal (Ghostty)
  "$MK www ['XF86WWW', '<Super><Shift>b']"                # browser
  "$MK home ['XF86Explorer', '<Super><Shift>f']"          # files
  "$MK screensaver ['<Super>l', '<Super>Escape']"         # lock screen
)
for n in 1 2 3 4 5 6 7 8 9; do
  BINDINGS+=(
    "$WM switch-to-workspace-$n ['<Super>$n']"            # go to workspace N
    "$WM move-to-workspace-$n ['<Super><Shift>$n']"       # move window to workspace N
    "$DOCK launch-dock-$n ['<Super><Alt>$n']"             # open dock app N
  )
done

case "${1:-}" in
  --claves) mode=--keys ;;
  --valores) mode=--values ;;
  --restaurar) mode=--reset ;;
  ""|--keys|--values|--reset) mode="${1:-}" ;;
  *)
    say "Unknown option: $1 (use --keys, --values or --reset)" \
        "Opción desconocida: $1 (usá --keys, --values o --reset)" >&2
    exit 1 ;;
esac

for b in "${BINDINGS[@]}"; do
  read -r schema key value <<<"$b"
  case "$mode" in
    --keys)   echo "$schema $key" ;;
    --values) echo "$schema $key $value" ;;
    --reset)  gsettings reset "$schema" "$key" ;;
    "")       gsettings set "$schema" "$key" "$value" ;;
  esac
done

case "$mode" in
  --reset) say "Shortcuts reset to the factory defaults." "Atajos restaurados a los valores de fábrica." ;;
  "")      say "Shortcuts applied." "Atajos aplicados." ;;
esac
