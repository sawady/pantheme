# shellcheck shell=bash
# Checks that `tema <name>` was applied everywhere.
#   check-theme.sh <name> <light|dark> <accent|any> [animated]
set -uo pipefail
name="$1" mode="$2" accent="$3" animated="${4:-}"
fails=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1 = $2"; else bad "$1 = $2 (expected $3)"; fi; }
colors="$HOME/.local/share/tema/$name/colors.toml"
bg="$(sed -nE 's/^background *= *"(#[0-9a-fA-F]{6})".*/\1/p' "$colors" | head -1)"

eq "current theme" "$(cat ~/.config/tema/actual)" "$name"
eq "color-scheme" "$(gsettings get org.gnome.desktop.interface color-scheme)" "'prefer-$mode'"
gtk="$(gsettings get org.gnome.desktop.interface gtk-theme)"
if [ "$accent" = any ]; then
  case "$gtk" in "'io.elementary.stylesheet."*) ok "accent $gtk" ;; *) bad "accent $gtk" ;; esac
else
  eq "accent" "$gtk" "'io.elementary.stylesheet.$accent'"
fi
uri="$(gsettings get org.gnome.desktop.background picture-uri)"
case "$uri" in *"/Wallpapers/$name/"*) ok "wallpaper $uri" ;; *) bad "wallpaper $uri" ;; esac
eq "picture-uri-dark" "$(gsettings get org.gnome.desktop.background picture-uri-dark)" "$uri"
eq "Ghostty background" "$(sed -nE 's/^background = (.*)/\1/p' ~/.config/ghostty/themes/tema)" "$bg"
if grep -q "main_bg\]=\"$bg\"" ~/.config/btop/themes/tema.theme; then ok "btop theme"; else bad "btop theme"; fi
if grep -q '^\[palettes\.tema\]' ~/.config/starship.toml; then ok "starship palette"; else bad "starship palette"; fi
sleep 3
if [ -n "$animated" ]; then
  eq "tema-animado.service" "$(systemctl --user is-active tema-animado.service)" "active"
  if pgrep -f "tema/$name/animado" >/dev/null; then ok "animated wallpaper running"; else bad "animated wallpaper not running"; fi
else
  if pgrep -f 'tema/.*/animado' >/dev/null; then bad "an animated wallpaper is still running"; else ok "no animated wallpaper"; fi
fi
echo
echo "$fails failure(s)"
[ "$fails" -eq 0 ]
