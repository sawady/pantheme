# shellcheck shell=bash
# Checks, inside the desktop session, what `./install.sh todo zed fondos animado` left.
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
check "tema runs" tema --help
check "JetBrains Mono Nerd Font installed" sh -c 'fc-list | grep -q "JetBrainsMono Nerd"'

# Shell
check ".bashrc loads omarchy-style.sh" grep -qF 'omarchy-style.sh' ~/.bashrc
check "interactive bash has starship and zoxide" bash -ic 'type starship_precmd && type z'

# escritorio
check "Ghostty in the dock" sh -c "gsettings get io.elementary.dock launchers | grep -q com.mitchellh.ghostty.desktop"
eq "default terminal" "$(gs org.gnome.desktop.default-applications.terminal exec)" "'ghostty'"

# atajos
while read -r schema key value; do
  eq "$schema $key" "$(gs "$schema" "$key")" "$value"
done < <(bash ~/pantheme/gsettings/atajos.sh --valores)

# tema (tokyo-night)
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

# fondos
eq "tema-fondo.timer enabled" "$(systemctl --user is-enabled tema-fondo.timer 2>&1)" "enabled"
eq "tema-fondo.timer active" "$(systemctl --user is-active tema-fondo.timer 2>&1)" "active"
before="$(gs org.gnome.desktop.background picture-uri)"
check "tema-fondo.service runs" systemctl --user start tema-fondo.service
n=$(find ~/Pictures/Wallpapers/tokyo-night -name '*.jpg' | wc -l)
if [ "$n" -gt 1 ]; then
  after="$(gs org.gnome.desktop.background picture-uri)"
  if [ "$after" != "$before" ]; then ok "wallpaper rotated ($n wallpapers)"; else bad "wallpaper did not rotate"; fi
fi

# animado
check "tema-animado.service installed" test -f ~/.config/systemd/user/tema-animado.service
check "autostart entry" test -f ~/.config/autostart/tema-animado.desktop
check "matrix theme bundled" test -x ~/.local/share/tema/matrix/animado

echo
echo "$fails failure(s)"
[ "$fails" -eq 0 ]
