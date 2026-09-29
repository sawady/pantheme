#!/usr/bin/env bash
# Atajos de teclado estilo Omarchy para Pantheon.
# Deshacer: ./gsettings/atajos.sh --restaurar
set -euo pipefail

WM=org.gnome.desktop.wm.keybindings
MK=org.gnome.settings-daemon.plugins.media-keys
DOCK=io.elementary.dock.keybindings
GALA=io.elementary.desktop.wm.keybindings

if [ "${1:-}" = "--restaurar" ]; then
  for n in 1 2 3 4 5 6 7 8 9; do
    gsettings reset $DOCK launch-dock-$n
    gsettings reset $WM move-to-workspace-$n
    gsettings reset $WM switch-to-workspace-$n
  done
  for k in pip; do gsettings reset $GALA $k; done
  for k in toggle-fullscreen close; do gsettings reset $WM $k; done
  for k in terminal www home screensaver; do gsettings reset $MK $k; done
  echo "Atajos restaurados a los valores de fábrica."
  exit 0
fi

for n in 1 2 3 4 5 6 7 8 9; do
  gsettings set $WM switch-to-workspace-$n "['<Super>$n']"          # ir al escritorio N
  gsettings set $WM move-to-workspace-$n "['<Super><Shift>$n']"     # mover ventana al escritorio N
  gsettings set $DOCK launch-dock-$n "['<Super><Alt>$n']"           # abrir app N del dock
done
gsettings set $GALA pip "['<Super><Shift>p']"                       # imagen en imagen
gsettings set $WM toggle-fullscreen "['<Super>f']"                  # pantalla completa
gsettings set $WM close "['<Alt>F4', '<Super>w']"                   # cerrar ventana
gsettings set $MK terminal "['<Super>t', '<Super>Return']"          # terminal (Ghostty)
gsettings set $MK www "['XF86WWW', '<Super><Shift>b']"              # navegador
gsettings set $MK home "['XF86Explorer', '<Super><Shift>f']"        # archivos
gsettings set $MK screensaver "['<Super>l', '<Super>Escape']"       # bloquear pantalla

echo "Atajos estilo Omarchy aplicados."
