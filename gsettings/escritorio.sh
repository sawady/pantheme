#!/usr/bin/env bash
# Ajustes de Pantheon: Ghostty como terminal principal y apariencia base.
# El fondo, el acento y el modo claro/oscuro los maneja `tema`.
set -euo pipefail

# Ghostty en el dock en lugar de la Terminal de elementary
gsettings set io.elementary.dock launchers \
  "['gala-multitaskingview.desktop', 'io.elementary.files.desktop', 'com.mitchellh.ghostty.desktop']"

# Ghostty como terminal por defecto (Super+T, "abrir en terminal")
gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
if [ "$(readlink -f /etc/alternatives/x-terminal-emulator)" != /usr/bin/ghostty ]; then
  echo "Aviso: x-terminal-emulator no apunta a Ghostty. Para cambiarlo:"
  echo "  sudo update-alternatives --set x-terminal-emulator /usr/bin/ghostty"
fi

# La Terminal de elementary queda con su fuente de fábrica (fuente del sistema)
gsettings reset io.elementary.terminal.settings font

# Modo oscuro por defecto (tema lo ajusta según el tema elegido)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

echo "Ajustes de escritorio aplicados."
