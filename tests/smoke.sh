#!/usr/bin/env bash
# Smoke test of the steps that don't need a desktop, meant for a throwaway
# ubuntu:24.04 container (runs as root, uses the network):
#
#   docker run --rm -v "$PWD":/src:ro ubuntu:24.04 bash /src/tests/smoke.sh
#
# Installs, checks, reinstalls (idempotency), uninstalls and checks that
# everything is as it was; also the Spanish aliases and messages, and the
# migration of installs made by earlier versions. Don't run it on your
# machine: it changes your $HOME.
set -euo pipefail

if [ ! -f /.dockerenv ] && [ -z "${CI:-}" ] && [ -z "${SMOKE_FORCE:-}" ]; then
  echo "This changes \$HOME: run it in a container (or with SMOKE_FORCE=1)." >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
export DEBIAN_FRONTEND=noninteractive
export PATH="$HOME/.local/bin:$PATH"
unset LC_ALL LC_MESSAGES LANG
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/pantheme"
OLD_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/elementary-setup"
UNITS="$HOME/.config/systemd/user"
ES=es_AR.UTF-8
fail() { echo "FAILED: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }
# has <text> <command...>: the command succeeds and its output contains <text>
has() {
  local want="$1" out
  shift
  out="$("$@" 2>&1)" || fail "failed: $* ($out)"
  grep -qF -- "$want" <<<"$out" || { echo "$out"; fail "'$want' not in the output of: $*"; }
}
# fails_with <text> <command...>: the command fails and its output contains <text>
fails_with() {
  local want="$1" out
  shift
  if out="$("$@" 2>&1)"; then fail "should have failed: $*"; fi
  grep -qF -- "$want" <<<"$out" || { echo "$out"; fail "'$want' not in the output of: $*"; }
}

# Initial state: a user with their own .bashrc and Ghostty config
printf '# original bashrc\nexport FOO=1\n' > "$HOME/.bashrc"
mkdir -p "$HOME/.config/ghostty"
printf '# original ghostty\nfont-size = 10\n' > "$HOME/.config/ghostty/config"
cp "$HOME/.bashrc" /tmp/bashrc.orig
cp "$HOME/.config/ghostty/config" /tmp/ghostty.orig

echo "== install"
"$REPO/install.sh" packages binaries configs shell theme

for b in starship fastfetch lazygit lazydocker pantheme tema; do
  [ -x "$HOME/.local/bin/$b" ] || fail "missing ~/.local/bin/$b"
done
[ "$(readlink "$HOME/.local/bin/tema")" = pantheme ] || fail "tema is not a link to pantheme"
for cmd in "starship --version" "fastfetch --version" "lazygit --version" \
           "lazydocker --version" "pantheme --help" "tema --help"; do
  $cmd >/dev/null || fail "doesn't run: $cmd"
done
ok "binaries"

ls "$HOME"/.local/share/fonts/JetBrainsMonoNerd/*.ttf >/dev/null || fail "missing font"
ok "font"

[ "$(grep -c 'omarchy-style.sh' "$HOME/.bashrc")" = 1 ] || fail ".bashrc without the line"
grep -qx '# pantheme: prompt, aliases and tools' "$HOME/.bashrc" || fail ".bashrc comment"
bash -c '. ~/.config/bash/omarchy-style.sh' || fail "omarchy-style.sh doesn't load"
# Right after installing, the session doesn't have ~/.local/bin in PATH
# (~/.profile only adds it if it existed at login): omarchy-style.sh adds it.
env PATH=/usr/bin:/bin bash -c '. ~/.config/bash/omarchy-style.sh && command -v starship && command -v pantheme' \
  >/dev/null || fail "omarchy-style.sh doesn't add ~/.local/bin to PATH"
ok "shell"

[ "$(cat "$HOME/.config/tema/actual")" = tokyo-night ] || fail "current theme"
grep -q '^theme = tema' "$HOME/.config/ghostty/config" || fail "ghostty doesn't use the theme"
grep -q 'palette = 0=' "$HOME/.config/ghostty/themes/tema" || fail "ghostty palette"
grep -q 'theme\[main_bg\]' "$HOME/.config/btop/themes/tema.theme" || fail "btop theme"
ls "$HOME"/Pictures/Wallpapers/tokyo-night/*.jpg >/dev/null || fail "tokyo-night wallpapers"
ok "theme tokyo-night"

echo "== theme command, in English and with the Spanish aliases"
has "Theme matrix applied (dark, accent lime" pantheme matrix
grep -q 'seg2 = "#00ff41"' "$HOME/.config/starship.toml" || fail "matrix palette in starship"
has "Current theme: matrix" pantheme
has "Usage:" pantheme help
has "pantheme animated on|off" pantheme --help
pantheme tokyo-night >/dev/null
n=$(find "$HOME/Pictures/Wallpapers/tokyo-night" -name '*.jpg' | wc -l)
[ "$n" -gt 1 ] || fail "tokyo-night should have several wallpapers"
has ".jpg" pantheme wallpaper
[ "$(cat "$HOME/.config/tema/fondo")" = 1 ] || fail "wallpaper index after 'pantheme wallpaper'"
has ".jpg" tema fondo
[ "$(cat "$HOME/.config/tema/fondo")" = 2 ] || fail "wallpaper index after 'tema fondo'"
has "Animated wallpaper turned off." pantheme animated off
[ -e "$HOME/.config/tema/animado-off" ] || fail "animated off"
has "Animated wallpaper turned on" tema animado on
[ ! -e "$HOME/.config/tema/animado-off" ] || fail "animated on"
fails_with "Usage: pantheme animated on|off" pantheme animated sideways
fails_with "Unknown theme 'no-such-theme'" pantheme no-such-theme
ok "pantheme subcommands and tema aliases"

has "Tema actual: tokyo-night" env LANG=$ES pantheme
has "Uso:" env LANG=$ES tema ayuda
has "Fondo animado desactivado." env LANG=$ES tema animado off
has "Fondo animado activado" env LC_MESSAGES=$ES LANG=en_US.UTF-8 pantheme animated on
has "Animated wallpaper turned off." env LC_ALL=C LANG=$ES pantheme animated off
pantheme animated on >/dev/null
fails_with "No existe el tema 'no-such-theme'" env LANG=$ES pantheme no-such-theme
ok "theme command messages in Spanish (LC_ALL > LC_MESSAGES > LANG)"

echo "== installer: help, aliases and messages in both languages"
has "Default steps:" "$REPO/install.sh" --help
has "wallpaper-rotation" "$REPO/install.sh" help
has "Pasos por defecto:" env LANG=$ES "$REPO/install.sh" ayuda
fails_with "Unknown step: nope" "$REPO/install.sh" nope
fails_with "Paso desconocido: nope" env LANG=$ES "$REPO/install.sh" nope
has "Load omarchy-style.sh from ~/.bashrc" "$REPO/install.sh" shell
has "Cargar omarchy-style.sh desde ~/.bashrc" env LANG=$ES "$REPO/install.sh" shell
# Spanish step name and the former name of the initial theme variable
has "Tema matrix aplicado" env LANG=$ES TEMA_INICIAL=matrix "$REPO/install.sh" tema
has "Theme tokyo-night applied" env PANTHEME_THEME=tokyo-night "$REPO/install.sh" theme
ok "installer messages and aliases"

echo "== optional steps (no systemd in the container: only the files)"
"$REPO/install.sh" wallpaper-rotation animado >/dev/null
for f in pantheme-wallpaper.service pantheme-wallpaper.timer pantheme-animated.service; do
  [ -f "$UNITS/$f" ] || fail "missing $f"
done
[ -f "$HOME/.config/autostart/pantheme-animated.desktop" ] || fail "missing autostart entry"
grep -q 'pantheme wallpaper$' "$UNITS/pantheme-wallpaper.service" || fail "wallpaper unit command"
grep -qP '^animated\t\.config/autostart/pantheme-animated\.desktop$' "$STATE/manifest" \
  || fail "the Spanish step name should be recorded as 'animated'"
ok "wallpaper-rotation and animated"

echo "== reinstall (idempotency)"
"$REPO/install.sh" configs shell
[ "$(grep -c 'omarchy-style.sh' "$HOME/.bashrc")" = 1 ] || fail "the .bashrc line was duplicated"
[ "$(cut -f2 "$STATE/manifest" | sort | uniq -d)" = "" ] || fail "duplicated lines in the manifest"
ok "idempotent"

echo "== uninstall"
"$REPO/install.sh" uninstall

check_clean() {  # label
  cmp -s "$HOME/.bashrc" /tmp/bashrc.orig || { diff /tmp/bashrc.orig "$HOME/.bashrc"; fail ".bashrc ($1)"; }
  cmp -s "$HOME/.config/ghostty/config" /tmp/ghostty.orig || fail "ghostty config not restored ($1)"
  local p
  for p in .local/bin/pantheme .local/bin/tema .local/bin/starship .local/bin/lazygit \
           .config/starship.toml .config/bash/omarchy-style.sh .config/btop .config/tema \
           .local/share/tema .local/share/fonts/JetBrainsMonoNerd .config/ghostty/themes/tema \
           .config/systemd .config/autostart; do
    [ ! -e "$HOME/$p" ] && [ ! -L "$HOME/$p" ] || fail "$p is still there in \$HOME ($1)"
  done
  [ ! -s "$STATE/manifest" ] || { cat "$STATE/manifest"; fail "the manifest isn't empty ($1)"; }
}
check_clean "uninstall"
ok "uninstalled"

echo "== migrate a record with the old project name (elementary-setup)"
"$REPO/install.sh" configs shell >/dev/null
mv "$STATE" "$OLD_STATE"
sed -i 's/^# pantheme: prompt, aliases and tools$/# elementary-setup: prompt, aliases y herramientas/' "$HOME/.bashrc"
"$REPO/install.sh" desinstalar
[ ! -e "$OLD_STATE" ] || fail "the old record is still there"
check_clean "elementary-setup migration"
ok "record migration"

# Turns the current install into one made by a version from before 0.1.0: the
# command was `tema` (a file, not a link), the units and the autostart entry
# were tema-*, and the record used the Spanish step names.
make_tema_era() {
  "$REPO/install.sh" configs shell wallpaper-rotation animated >/dev/null
  mv "$UNITS/pantheme-wallpaper.service" "$UNITS/tema-fondo.service"
  mv "$UNITS/pantheme-wallpaper.timer" "$UNITS/tema-fondo.timer"
  mv "$UNITS/pantheme-animated.service" "$UNITS/tema-animado.service"
  mv "$HOME/.config/autostart/pantheme-animated.desktop" "$HOME/.config/autostart/tema-animado.desktop"
  sed -i -e 's/pantheme-wallpaper/tema-fondo/; s/pantheme-animated/tema-animado/' \
    -e 's/^wallpaper-rotation\t/fondos\t/; s/^animated\t/animado\t/' "$STATE/manifest"
  # An enabled timer, as `systemctl --user enable` leaves it
  mkdir -p "$UNITS/timers.target.wants"
  ln -s ../tema-fondo.timer "$UNITS/timers.target.wants/tema-fondo.timer"
  mkdir -p "$HOME/.local/bin"
  install -m755 "$REPO/bin/pantheme" "$HOME/.local/bin/tema"
  printf 'binarios\t.local/bin/tema\n' >> "$STATE/manifest"
  printf 'atajos\torg.example.schema\tkey\t%s\n' "'value'" >> "$STATE/gsettings"
  sed -i 's/^# pantheme: prompt, aliases and tools$/# pantheme: prompt, aliases y herramientas/' "$HOME/.bashrc"
  grep -q tema-fondo.timer "$STATE/manifest" || fail "make_tema_era: manifest"
}

echo "== migrate an install of tema (before 0.1.0) by installing"
make_tema_era
has "Migrating an install of \`tema\`" "$REPO/install.sh" configs
for f in tema-fondo.service tema-fondo.timer tema-animado.service timers.target.wants/tema-fondo.timer; do
  [ ! -e "$UNITS/$f" ] && [ ! -L "$UNITS/$f" ] || fail "$f is still there"
done
[ ! -e "$HOME/.config/autostart/tema-animado.desktop" ] || fail "old autostart entry still there"
for f in pantheme-wallpaper.service pantheme-wallpaper.timer pantheme-animated.service; do
  [ -f "$UNITS/$f" ] || fail "missing $f after migrating"
done
[ -f "$HOME/.config/autostart/pantheme-animated.desktop" ] || fail "missing autostart entry after migrating"
[ -x "$HOME/.local/bin/pantheme" ] || fail "missing pantheme after migrating"
[ "$(readlink "$HOME/.local/bin/tema")" = pantheme ] || fail "tema should be a link after migrating"
has "Current theme:" tema
if grep -qE '^(paquetes|binarios|escritorio|atajos|tema|fondos|animado)	' "$STATE/manifest" "$STATE/gsettings"; then
  fail "Spanish step names left in the record"
fi
grep -q 'tema-' "$STATE/manifest" && fail "old paths left in the manifest"
grep -qP '^wallpaper-rotation\t\.config/systemd/user/pantheme-wallpaper\.timer$' "$STATE/manifest" || fail "manifest: timer"
grep -qP '^animated\t\.config/autostart/pantheme-animated\.desktop$' "$STATE/manifest" || fail "manifest: autostart"
grep -qP '^binaries\t\.local/bin/pantheme$' "$STATE/manifest" || fail "manifest: pantheme"
grep -qP '^shortcuts\torg\.example\.schema\tkey\t' "$STATE/gsettings" || fail "gsettings record step name"
sed -i '/org\.example\.schema/d' "$STATE/gsettings"
# Running it again changes nothing
"$REPO/install.sh" configs | grep -q Migrating && fail "migrated twice"
"$REPO/install.sh" uninstall >/dev/null
check_clean "tema migration"
ok "tema-era install migrated, then uninstalled"

echo "== uninstall an install of tema (before 0.1.0) directly, in Spanish"
make_tema_era
sed -i '/org\.example\.schema/d' "$STATE/gsettings"
has "Desinstalar: wallpaper-rotation" env LANG=$ES "$REPO/install.sh" desinstalar
check_clean "tema-era uninstall"
ok "tema-era install uninstalled"

echo "== uninstall with nothing recorded"
rm -rf "$STATE"
fails_with "Nothing is recorded" "$REPO/install.sh" uninstall
ok "nothing recorded"

echo "== .bashrc without a final newline (like elementary OS's)"
printf '# original bashrc\nexport FOO=1' > "$HOME/.bashrc"
cp "$HOME/.bashrc" /tmp/bashrc-no-newline.orig
"$REPO/install.sh" shell >/dev/null
"$REPO/install.sh" uninstall shell >/dev/null
cmp -s "$HOME/.bashrc" /tmp/bashrc-no-newline.orig || { od -c "$HOME/.bashrc" | tail -3; fail ".bashrc without a final newline"; }
# With something added after our line: only our lines are removed
"$REPO/install.sh" shell >/dev/null
echo 'export BAR=2' >> "$HOME/.bashrc"
"$REPO/install.sh" uninstall shell >/dev/null
grep -q omarchy-style "$HOME/.bashrc" && fail "the .bashrc line is still there"
grep -qx 'export BAR=2' "$HOME/.bashrc" || fail "lost what was added afterwards"
ok "exact .bashrc"

echo
echo "Smoke test OK"
