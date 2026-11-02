# shellcheck shell=bash
# Compares two snapshots taken with state.sh.
#   compare.sh <before> <after>
# Fails on any difference except the leftovers documented in the README
# (downloaded wallpapers, Zed's settings.json) and data written by the tools
# themselves while they ran (shell history, zoxide's database, lazygit state).
set -euo pipefail
a="/tmp/pantheme-state-$1.txt" b="/tmp/pantheme-state-$2.txt"
allowed='^[<>] f (Pictures/Wallpapers/|\.config/zed/settings\.json |\.bash_history |\.local/share/zoxide/|\.local/state/lazygit/)'
diff "$a" "$b" > /tmp/pantheme-diff.txt || true
grep -E '^[<>]' /tmp/pantheme-diff.txt > /tmp/pantheme-diff-lines.txt || true
grep -Ev "$allowed" /tmp/pantheme-diff-lines.txt > /tmp/pantheme-diff-unexpected.txt || true
echo "== expected leftovers"
grep -E "$allowed" /tmp/pantheme-diff-lines.txt | sed -E 's/ [0-9a-f]{12}$//' | awk '{print $1, $3}' \
  | sed -E 's#(Pictures/Wallpapers/[^/]+)/.*#\1/…#' | sort -u || true
echo "== unexpected differences"
if [ -s /tmp/pantheme-diff-unexpected.txt ]; then
  cat /tmp/pantheme-diff-unexpected.txt
  exit 1
fi
echo "(none)"
