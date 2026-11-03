# shellcheck shell=bash
# `pantheme animated off|on` with a theme that has an animated wallpaper.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
fails=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }
running() { pgrep -f 'tema/.*/animado' >/dev/null; }
pantheme animated off
sleep 2
if running; then bad "still running after 'animated off'"; else ok "stopped by 'pantheme animated off'"; fi
pantheme animated on
sleep 3
if running; then ok "running again after 'animated on'"; else bad "not running after 'animated on'"; fi
tema animado off
sleep 2
if running; then bad "still running after 'tema animado off'"; else ok "stopped by 'tema animado off'"; fi
tema animado on
sleep 3
if running; then ok "running again after 'tema animado on'"; else bad "not running after 'tema animado on'"; fi
echo
echo "$fails failure(s)"
[ "$fails" -eq 0 ]
