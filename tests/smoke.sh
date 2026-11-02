#!/usr/bin/env bash
# Smoke test de los pasos que no necesitan escritorio, pensado para un
# contenedor ubuntu:24.04 descartable (corre como root, usa la red):
#
#   docker run --rm -v "$PWD":/src:ro ubuntu:24.04 bash /src/tests/smoke.sh
#
# Instala, comprueba, reinstala (idempotencia), desinstala y verifica que
# quede todo como estaba. No lo corras en tu máquina: toca tu $HOME.
set -euo pipefail

if [ ! -f /.dockerenv ] && [ -z "${CI:-}" ] && [ -z "${SMOKE_FORCE:-}" ]; then
  echo "Esto modifica \$HOME: corrélo en un contenedor (o con SMOKE_FORCE=1)." >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
export DEBIAN_FRONTEND=noninteractive
export PATH="$HOME/.local/bin:$PATH"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/pantheme"
OLD_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/elementary-setup"
fail() { echo "FALLÓ: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

# Estado previo: un usuario con su propio .bashrc y config de Ghostty
printf '# bashrc original\nexport FOO=1\n' > "$HOME/.bashrc"
mkdir -p "$HOME/.config/ghostty"
printf '# ghostty original\nfont-size = 10\n' > "$HOME/.config/ghostty/config"
cp "$HOME/.bashrc" /tmp/bashrc.orig
cp "$HOME/.config/ghostty/config" /tmp/ghostty.orig

echo "== instalar"
"$REPO/install.sh" paquetes binarios configs shell tema

for b in starship fastfetch lazygit lazydocker tema; do
  [ -x "$HOME/.local/bin/$b" ] || fail "falta ~/.local/bin/$b"
done
for cmd in "starship --version" "fastfetch --version" "lazygit --version" \
           "lazydocker --version" "tema --help"; do
  $cmd >/dev/null || fail "no corre: $cmd"
done
ok "binarios"

ls "$HOME"/.local/share/fonts/JetBrainsMonoNerd/*.ttf >/dev/null || fail "falta la fuente"
ok "fuente"

[ "$(grep -c 'omarchy-style.sh' "$HOME/.bashrc")" = 1 ] || fail ".bashrc sin la línea"
bash -c '. ~/.config/bash/omarchy-style.sh' || fail "omarchy-style.sh no carga"
ok "shell"

[ "$(cat "$HOME/.config/tema/actual")" = tokyo-night ] || fail "tema actual"
grep -q '^theme = tema' "$HOME/.config/ghostty/config" || fail "ghostty no usa el tema"
grep -q 'palette = 0=' "$HOME/.config/ghostty/themes/tema" || fail "paleta de ghostty"
grep -q 'theme\[main_bg\]' "$HOME/.config/btop/themes/tema.theme" || fail "tema de btop"
ls "$HOME"/Pictures/Wallpapers/tokyo-night/*.jpg >/dev/null || fail "fondos de tokyo-night"
ok "tema tokyo-night"

tema matrix
grep -q 'seg2 = "#00ff41"' "$HOME/.config/starship.toml" || fail "paleta de matrix en starship"
ok "tema matrix (propio)"

echo "== reinstalar (idempotencia)"
"$REPO/install.sh" configs shell
[ "$(grep -c 'omarchy-style.sh' "$HOME/.bashrc")" = 1 ] || fail "la línea de .bashrc se duplicó"
ok "idempotente"

echo "== desinstalar"
"$REPO/install.sh" desinstalar

cmp -s "$HOME/.bashrc" /tmp/bashrc.orig || { diff /tmp/bashrc.orig "$HOME/.bashrc"; fail ".bashrc no quedó como antes"; }
cmp -s "$HOME/.config/ghostty/config" /tmp/ghostty.orig || fail "config de ghostty no se restauró"
for p in .local/bin/tema .local/bin/starship .local/bin/lazygit .config/starship.toml \
         .config/bash/omarchy-style.sh .config/btop .config/tema .local/share/tema \
         .local/share/fonts/JetBrainsMonoNerd .config/ghostty/themes/tema; do
  [ ! -e "$HOME/$p" ] || fail "quedó ~/$p"
done
[ ! -s "$STATE/manifest" ] || fail "el manifiesto no quedó vacío"
ok "desinstalado"

echo "== migrar un registro con el nombre viejo (elementary-setup)"
"$REPO/install.sh" configs shell >/dev/null
mv "$STATE" "$OLD_STATE"
sed -i 's/^# pantheme: /# elementary-setup: /' "$HOME/.bashrc"
"$REPO/install.sh" desinstalar
[ ! -e "$OLD_STATE" ] || fail "quedó el registro viejo"
cmp -s "$HOME/.bashrc" /tmp/bashrc.orig || { diff /tmp/bashrc.orig "$HOME/.bashrc"; fail ".bashrc tras migrar"; }
cmp -s "$HOME/.config/ghostty/config" /tmp/ghostty.orig || fail "ghostty tras migrar"
[ ! -e "$HOME/.config/starship.toml" ] || fail "quedó starship.toml tras migrar"
ok "migración del registro"

echo "== desinstalar sin nada registrado"
rm -rf "$STATE"
if "$REPO/install.sh" desinstalar; then fail "debería fallar sin registro"; fi
ok "sin registro"

echo
echo "Smoke test OK"
