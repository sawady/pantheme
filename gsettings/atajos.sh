#!/usr/bin/env bash
# Atajos de teclado para Pantheon (inspirados en Omarchy).
#
#   ./gsettings/atajos.sh              aplica los atajos
#   ./gsettings/atajos.sh --claves     lista las claves que toca (esquema clave)
#   ./gsettings/atajos.sh --restaurar  vuelve a los valores de fábrica
#
# `./install.sh desinstalar atajos` repone los valores que había antes de
# instalar, que no siempre son los de fábrica.
set -euo pipefail

WM=org.gnome.desktop.wm.keybindings
MK=org.gnome.settings-daemon.plugins.media-keys
DOCK=io.elementary.dock.keybindings
GALA=io.elementary.desktop.wm.keybindings

# "esquema clave valor"
BINDINGS=(
  "$GALA pip ['<Super><Shift>p']"                         # imagen en imagen
  "$WM toggle-fullscreen ['<Super>f']"                    # pantalla completa
  "$WM close ['<Alt>F4', '<Super>w']"                     # cerrar ventana
  "$MK terminal ['<Super>t', '<Super>Return']"            # terminal (Ghostty)
  "$MK www ['XF86WWW', '<Super><Shift>b']"                # navegador
  "$MK home ['XF86Explorer', '<Super><Shift>f']"          # archivos
  "$MK screensaver ['<Super>l', '<Super>Escape']"         # bloquear pantalla
)
for n in 1 2 3 4 5 6 7 8 9; do
  BINDINGS+=(
    "$WM switch-to-workspace-$n ['<Super>$n']"            # ir al escritorio N
    "$WM move-to-workspace-$n ['<Super><Shift>$n']"       # mover ventana al escritorio N
    "$DOCK launch-dock-$n ['<Super><Alt>$n']"             # abrir app N del dock
  )
done

for b in "${BINDINGS[@]}"; do
  read -r schema key value <<<"$b"
  case "${1:-}" in
    --claves)    echo "$schema $key" ;;
    --restaurar) gsettings reset "$schema" "$key" ;;
    "")          gsettings set "$schema" "$key" "$value" ;;
    *) echo "Opción desconocida: $1 (usá --claves o --restaurar)" >&2; exit 1 ;;
  esac
done

case "${1:-}" in
  --restaurar) echo "Atajos restaurados a los valores de fábrica." ;;
  "")          echo "Atajos aplicados." ;;
esac
