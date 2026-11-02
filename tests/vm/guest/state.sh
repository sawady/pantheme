# shellcheck shell=bash
# Snapshot of everything pantheme may touch: the desktop settings it changes,
# the files under $HOME and the systemd user units.
#   state.sh <label>   writes /tmp/pantheme-state-<label>.txt
set -euo pipefail
out="/tmp/pantheme-state-$1.txt"
keys=(
  "io.elementary.dock launchers"
  "org.gnome.desktop.default-applications.terminal exec"
  "org.gnome.desktop.interface color-scheme"
  "org.gnome.desktop.interface gtk-theme"
  "org.gnome.desktop.background picture-uri"
  "org.gnome.desktop.background picture-uri-dark"
)
while read -r schema key; do keys+=("$schema $key"); done < <(bash ~/pantheme/gsettings/atajos.sh --claves)
{
  echo "## gsettings"
  for sk in "${keys[@]}"; do
    # shellcheck disable=SC2086
    echo "$sk = $(gsettings get $sk)"
  done
  echo "## files"
  # Noise from the live session and caches is skipped; so is the test's own
  # copy of the repo and pantheme's record (kept on purpose after uninstalling).
  find "$HOME" \( -path "$HOME/.cache" -o -path "$HOME/pantheme" -o -path "$HOME/.local/state/pantheme" \
      -o -path "$HOME/.config/dconf" -o -path "$HOME/.config/pulse" -o -path "$HOME/.local/share/gvfs-metadata" \
      -o -path "$HOME/.local/share/recently-used.xbel" -o -path "$HOME/.local/share/tracker" \
      -o -path "$HOME/.local/state/wireplumber" -o -path "$HOME/.local/share/keyrings" \
      -o -path "$HOME/.local/share/flatpak" -o -path "$HOME/.local/share/zeitgeist" \
      -o -path "$HOME/.local/share/evolution" -o -path "$HOME/.local/share/io.elementary.gala" \
      -o -name ".xsession-errors*" \) -prune \
      -o \( -type f -printf 'f %P ' -exec sh -c 'md5sum < "$1" | cut -c1-12' _ {} \; \) \
      -o \( -type l -printf 'l %P -> %l\n' \) | sort -k2
  echo "## systemd --user"
  systemctl --user list-unit-files 'tema*' --no-legend 2>/dev/null || true
} > "$out"
echo "$out: $(grep -c '' "$out") lines"
