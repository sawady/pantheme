#!/usr/bin/env bash
# Ajustes de Pantheon: Ghostty como terminal principal.
# El fondo, el acento y el modo claro/oscuro los maneja `tema`.
set -euo pipefail

GHOSTTY=com.mitchellh.ghostty.desktop
TERMINAL=io.elementary.terminal.desktop

# Ghostty en el dock: reemplaza a la Terminal de elementary si está, o se
# agrega al final. El resto de los lanzadores queda como estaba.
current="$(gsettings get io.elementary.dock launchers)"
updated="$(python3 - "$current" "$TERMINAL" "$GHOSTTY" <<'EOF'
import ast, sys
cur, old, new = sys.argv[1:]
cur = cur.removeprefix("@as ")
items = ast.literal_eval(cur) if cur.strip() else []
if new not in items:
    items = [new if i == old else i for i in items]
    if new not in items:
        items.append(new)
print(str(items))
EOF
)"
[ "$updated" != "$current" ] && gsettings set io.elementary.dock launchers "$updated"

# Ghostty como terminal por defecto (Super+T, "abrir en terminal")
gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
if [ "$(readlink -f /etc/alternatives/x-terminal-emulator 2>/dev/null)" != /usr/bin/ghostty ]; then
  echo "Aviso: x-terminal-emulator no apunta a Ghostty. Para cambiarlo:"
  echo "  sudo update-alternatives --set x-terminal-emulator /usr/bin/ghostty"
fi

# Modo oscuro por defecto (`tema` lo ajusta según el tema elegido)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

echo "Ajustes de escritorio aplicados."
