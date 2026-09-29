#!/usr/bin/env bash
# Copia al repo las configuraciones actuales de la máquina, para registrar
# cambios hechos a mano. Después: `git diff` para revisar y commitear.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CFG="$HOME/.config"

pull() {  # origen destino-relativo
  [ -f "$1" ] && cp "$1" "$REPO/$2" && echo "  $2"
}

echo "Capturando configuraciones:"
pull "$HOME/.local/bin/tema"                    bin/tema
pull "$CFG/ghostty/config"                      config/ghostty/config
pull "$CFG/starship.toml"                       config/starship.toml
pull "$CFG/fastfetch/config.jsonc"              config/fastfetch/config.jsonc
pull "$CFG/bash/omarchy-style.sh"               config/bash/omarchy-style.sh
pull "$CFG/lazygit/config.yml"                  config/lazygit/config.yml
pull "$CFG/lazydocker/config.yml"               config/lazydocker/config.yml
pull "$CFG/systemd/user/tema-fondo.service"     config/systemd/user/tema-fondo.service
pull "$CFG/systemd/user/tema-fondo.timer"       config/systemd/user/tema-fondo.timer
# No se capturan: btop.conf (btop lo reescribe entero) ni zed/settings.json (tokens).

echo
echo "Tema actual: $(cat "$CFG/tema/actual" 2>/dev/null || echo '—')"
git -C "$REPO" status --short
