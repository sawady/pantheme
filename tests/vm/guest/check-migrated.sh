# shellcheck shell=bash
# After running the new installer over an install from before 0.1.0: the tema-*
# units are gone, the pantheme-* ones run instead and the record is updated.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
fails=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1 = $2"; else bad "$1 = $2 (expected $3)"; fi; }
sleep 3
u=~/.config/systemd/user
for f in $u/tema-fondo.service $u/tema-fondo.timer $u/tema-animado.service \
         $u/timers.target.wants/tema-fondo.timer ~/.config/autostart/tema-animado.desktop; do
  if [ -e "$f" ] || [ -L "$f" ]; then bad "still there: $f"; else ok "removed $f"; fi
done
state="$(systemctl --user is-enabled tema-fondo.timer 2>&1)"
if [ "$state" = enabled ]; then bad "tema-fondo.timer still enabled"; else ok "tema-fondo.timer not enabled ($state)"; fi
eq "tema-animado.service" "$(systemctl --user is-active tema-animado.service 2>&1)" "inactive"
eq "pantheme-wallpaper.timer enabled" "$(systemctl --user is-enabled pantheme-wallpaper.timer 2>&1)" "enabled"
eq "pantheme-wallpaper.timer active" "$(systemctl --user is-active pantheme-wallpaper.timer 2>&1)" "active"
eq "pantheme-animated.service" "$(systemctl --user is-active pantheme-animated.service 2>&1)" "active"
if [ -f ~/.config/autostart/pantheme-animated.desktop ]; then ok "new autostart entry"; else bad "no new autostart entry"; fi
eq "animated wallpaper processes" "$(pgrep -fc 'tema/matrix/animado')" 1
eq "tema" "$(readlink ~/.local/bin/tema)" "pantheme"
if pantheme >/dev/null && tema >/dev/null; then ok "pantheme and tema run"; else bad "pantheme or tema fail"; fi
eq "current theme kept" "$(cat ~/.config/tema/actual)" "matrix"
m=~/.local/state/pantheme/manifest
if grep -qE '^(paquetes|binarios|escritorio|atajos|tema|fondos|animado)	' $m ~/.local/state/pantheme/gsettings; then
  bad "Spanish step names left in the record"
else
  ok "record uses the new step names"
fi
if grep -q 'tema-' $m; then bad "old paths in the manifest"; else ok "no old paths in the manifest"; fi
echo "record:"
sed 's/^/    /' $m
echo
echo "$fails failure(s)"
[ "$fails" -eq 0 ]
