#!/usr/bin/env bash
# Pantheon settings: Ghostty as the main terminal.
# The wallpaper, accent color and light/dark mode are handled by `pantheme`.
set -euo pipefail

case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in es*) UI=es ;; *) UI=en ;; esac
say() { if [ "$UI" = es ]; then echo "$2"; else echo "$1"; fi; }  # english spanish

GHOSTTY=com.mitchellh.ghostty.desktop
TERMINAL=io.elementary.terminal.desktop

# Ghostty in the dock: it replaces elementary's Terminal if it's there, or is
# added at the end. The other launchers are kept as they were.
current="$(gsettings get io.elementary.dock launchers)"
updated="$(python3 - "$current" "$TERMINAL" "$GHOSTTY" <<'PY'
import ast, sys
cur, old, new = sys.argv[1:]
cur = cur.removeprefix("@as ")
items = ast.literal_eval(cur) if cur.strip() else []
if new not in items:
    items = [new if i == old else i for i in items]
    if new not in items:
        items.append(new)
print(str(items))
PY
)"
[ "$updated" != "$current" ] && gsettings set io.elementary.dock launchers "$updated"

# Ghostty as the default terminal (Super+T, "open in terminal")
gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
if [ "$(readlink -f /etc/alternatives/x-terminal-emulator 2>/dev/null)" != /usr/bin/ghostty ]; then
  say "Note: x-terminal-emulator doesn't point to Ghostty. To change it:" \
      "Aviso: x-terminal-emulator no apunta a Ghostty. Para cambiarlo:"
  echo "  sudo update-alternatives --set x-terminal-emulator /usr/bin/ghostty"
fi

# Dark mode by default (`pantheme` adjusts it to the chosen theme)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

say "Desktop settings applied." "Ajustes de escritorio aplicados."
