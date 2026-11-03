# shellcheck shell=bash
# Checks, inside the desktop session, what `./install.sh all zed wallpaper-rotation animated` left.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
fails=0
ok()   { echo "ok    $*"; }
bad()  { echo "FAIL  $*"; fails=$((fails + 1)); }
check() { local what="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$what"; else bad "$what"; fi; }
gs()   { gsettings get "$1" "$2"; }
eq()   { local what="$1" got="$2" want="$3"; if [ "$got" = "$want" ]; then ok "$what = $got"; else bad "$what = $got (expected $want)"; fi; }

# Binaries and font
for b in ghostty starship fastfetch lazygit lazydocker btop eza batcat fzf zoxide; do
  check "$b runs" "$b" --version
done
check "pantheme runs" pantheme --help
check "tema is an alias of pantheme" test "$(readlink ~/.local/bin/tema)" = pantheme
check "tema runs" tema --help
check "JetBrains Mono Nerd Font installed" sh -c 'fc-list | grep -q "JetBrainsMono Nerd"'

# Shell
check ".bashrc loads omarchy-style.sh" grep -qF 'omarchy-style.sh' ~/.bashrc
check "interactive bash has starship and zoxide" bash -ic 'type starship_precmd && type z'

# desktop
check "Ghostty in the dock" sh -c "gsettings get io.elementary.dock launchers | grep -q com.mitchellh.ghostty.desktop"
eq "default terminal" "$(gs org.gnome.desktop.default-applications.terminal exec)" "'ghostty'"

# shortcuts
while read -r schema key value; do
  eq "$schema $key" "$(gs "$schema" "$key")" "$value"
done < <(bash ~/pantheme/gsettings/shortcuts.sh --values)

# theme (tokyo-night)
eq "current theme" "$(cat ~/.config/tema/actual)" "tokyo-night"
eq "color-scheme" "$(gs org.gnome.desktop.interface color-scheme)" "'prefer-dark'"
eq "accent" "$(gs org.gnome.desktop.interface gtk-theme)" "'io.elementary.stylesheet.grape'"
check "wallpaper from the theme" sh -c "gsettings get org.gnome.desktop.background picture-uri | grep -q '/Wallpapers/tokyo-night/'"
wall="$(gs org.gnome.desktop.background picture-uri | tr -d "'")"
check "wallpaper file exists" test -s "${wall#file://}"
check "Ghostty uses the generated theme" grep -q '^theme = tema' ~/.config/ghostty/config
check "btop uses the generated theme" grep -q 'color_theme = "tema"' ~/.config/btop/btop.conf

# zed
check "Zed Matrix theme" test -s ~/.config/zed/themes/matrix.json
check "Zed settings created" grep -q '"theme"' ~/.config/zed/settings.json

# wallpaper-rotation
eq "pantheme-wallpaper.timer enabled" "$(systemctl --user is-enabled pantheme-wallpaper.timer 2>&1)" "enabled"
eq "pantheme-wallpaper.timer active" "$(systemctl --user is-active pantheme-wallpaper.timer 2>&1)" "active"
before="$(gs org.gnome.desktop.background picture-uri)"
check "pantheme-wallpaper.service runs" systemctl --user start pantheme-wallpaper.service
n=$(find ~/Pictures/Wallpapers/tokyo-night -name '*.jpg' | wc -l)
if [ "$n" -gt 1 ]; then
  after="$(gs org.gnome.desktop.background picture-uri)"
  if [ "$after" != "$before" ]; then ok "wallpaper rotated ($n wallpapers)"; else bad "wallpaper did not rotate"; fi
  check "pantheme wallpaper" pantheme wallpaper
  if [ "$(gs org.gnome.desktop.background picture-uri)" != "$after" ]; then ok "pantheme wallpaper changed it"; else bad "pantheme wallpaper did not change it"; fi
  after="$(gs org.gnome.desktop.background picture-uri)"
  check "tema fondo (alias)" tema fondo
  if [ "$(gs org.gnome.desktop.background picture-uri)" != "$after" ]; then ok "tema fondo changed it"; else bad "tema fondo did not change it"; fi
else
  bad "tokyo-night has a single wallpaper ($n): can't check the rotation"
fi

# animated
check "pantheme-animated.service installed" test -f ~/.config/systemd/user/pantheme-animated.service
check "autostart entry" test -f ~/.config/autostart/pantheme-animated.desktop
check "matrix theme bundled" test -x ~/.local/share/tema/matrix/animado

echo
echo "$fails failure(s)"
[ "$fails" -eq 0 ]
