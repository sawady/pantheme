#!/usr/bin/env bash
# Copies this machine's current configs into the repository, to record changes
# made by hand. Then review with `git diff` and commit.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CFG="$HOME/.config"

pull() {  # source destination-relative-to-repo
  [ -f "$1" ] || return 0
  mkdir -p "$(dirname "$REPO/$2")"
  cp "$1" "$REPO/$2" && echo "  $2"
}

echo "Capturing configs:"
pull "$HOME/.local/bin/pantheme"                     bin/pantheme
pull "$CFG/ghostty/config"                           config/ghostty/config
pull "$CFG/starship.toml"                            config/starship.toml
pull "$CFG/fastfetch/config.jsonc"                   config/fastfetch/config.jsonc
pull "$CFG/bash/omarchy-style.sh"                    config/bash/omarchy-style.sh
pull "$CFG/lazygit/config.yml"                       config/lazygit/config.yml
pull "$CFG/lazydocker/config.yml"                    config/lazydocker/config.yml
pull "$CFG/systemd/user/pantheme-wallpaper.service"  config/systemd/user/pantheme-wallpaper.service
pull "$CFG/systemd/user/pantheme-wallpaper.timer"    config/systemd/user/pantheme-wallpaper.timer
pull "$CFG/systemd/user/pantheme-animated.service"   config/systemd/user/pantheme-animated.service
pull "$CFG/autostart/pantheme-animated.desktop"      config/autostart/pantheme-animated.desktop
pull "$CFG/zed/themes/matrix.json"                   config/zed/themes/matrix.json
for t in "$REPO"/temas/*/; do
  name="$(basename "$t")"
  pull "$HOME/.local/share/tema/$name/colors.toml" "temas/$name/colors.toml"
  pull "$HOME/.local/share/tema/$name/animado"     "temas/$name/animado"
done
# Not captured: btop.conf (btop rewrites all of it) and zed/settings.json (tokens).

echo
echo "Note: config/starship.toml has the palette of the current theme; the repository keeps Tokyo Night's."
echo "Current theme: $(cat "$CFG/tema/actual" 2>/dev/null || echo '—')"
git -C "$REPO" status --short
