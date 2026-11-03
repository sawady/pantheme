# shellcheck shell=bash
# Before migrating: what an install from before 0.1.0 (`tema`) left running.
set -uo pipefail
fails=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1 = $2"; else bad "$1 = $2 (expected $3)"; fi; }
sleep 3
if [ -f ~/.local/bin/tema ] && [ ! -L ~/.local/bin/tema ]; then ok "tema is a file"; else bad "tema is not a file"; fi
eq "tema-fondo.timer enabled" "$(systemctl --user is-enabled tema-fondo.timer 2>&1)" "enabled"
eq "tema-animado.service" "$(systemctl --user is-active tema-animado.service 2>&1)" "active"
if pgrep -f 'tema/matrix/animado' >/dev/null; then ok "matrix animated wallpaper running"; else bad "animated wallpaper not running"; fi
check() { if test -e "$1"; then ok "$1"; else bad "missing $1"; fi; }
check ~/.config/autostart/tema-animado.desktop
check ~/.config/systemd/user/tema-fondo.service
echo "record:"
sed 's/^/    /' ~/.local/state/pantheme/manifest
echo
echo "$fails failure(s)"
[ "$fails" -eq 0 ]
