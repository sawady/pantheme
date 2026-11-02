#!/usr/bin/env bash
# pantheme — instalador por pasos para elementary OS 8 (inspirado en Omarchy).
#
#   ./install.sh                         pasos por defecto
#   ./install.sh <paso>...               sólo esos pasos (también los opcionales)
#   ./install.sh todo zed fondos         los de por defecto + algunos opcionales
#   ./install.sh desinstalar [paso...]   deshace todo, o sólo esos pasos
#
# Por defecto: paquetes ghostty binarios configs shell escritorio atajos tema
# Opcionales:  zed fondos animado
#
# Cada archivo que escribe el instalador queda registrado en
# ~/.local/state/pantheme/manifest; si ya existía, el original se
# guarda en ~/.local/state/pantheme/backup/ la primera vez.
set -euo pipefail

NAME=pantheme
REPO="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
CFG="$HOME/.config"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/$NAME"
MANIFEST="$STATE/manifest"   # paso<TAB>ruta relativa a $HOME
GSAVED="$STATE/gsettings"    # paso<TAB>esquema<TAB>clave<TAB>valor original
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DEFAULT=(paquetes ghostty binarios configs shell escritorio atajos tema)
OPTIONAL=(zed fondos animado)
PACKAGES=(btop eza bat fzf zoxide curl ca-certificates python3 python3-pil fontconfig xz-utils)
BASHRC_LINE='[ -f ~/.config/bash/omarchy-style.sh ] && . ~/.config/bash/omarchy-style.sh'
BASHRC_COMMENT="# $NAME: prompt, aliases y herramientas"
BASHRC_COMMENT_OLD='# Estilo Omarchy (prompt, aliases, herramientas)'
BASHRC_COMMENT_OLD2='# elementary-setup: prompt, aliases y herramientas'

SUDO=
[ "$(id -u)" -eq 0 ] || SUDO=sudo
STEP=

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"
}

# ------------------------------------------------------------ registro
# El proyecto se llamaba elementary-setup: si hay un registro con ese nombre,
# se mueve al nuevo para poder seguir desinstalando.
OLD_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/elementary-setup"
if [ -d "$OLD_STATE" ] && [ ! -e "$STATE" ]; then
  mkdir -p "$(dirname "$STATE")"
  mv "$OLD_STATE" "$STATE"
  echo "Registro movido de $OLD_STATE a $STATE."
fi

# Instalaciones anteriores al manifiesto: no hay manifiesto pero sí `tema`.
# En ese caso no se respalda lo que hay (ya es nuestro), salvo que exista un
# respaldo viejo en ~/.config-backup-*/ (se usa el más antiguo).
LEGACY=0
[ ! -f "$MANIFEST" ] && [ -e "$BIN/tema" ] && LEGACY=1

tracked() { [ -f "$MANIFEST" ] && cut -f2 "$MANIFEST" | grep -qxF "$1"; }

# Registra un destino antes de escribirlo y guarda el original la primera vez
track() {  # destino
  local dst="$1" rel="${1#"$HOME"/}" old
  mkdir -p "$STATE"
  tracked "$rel" && return 0
  if [ "$LEGACY" = 1 ]; then
    for old in "$HOME"/.config-backup-*/"$rel"; do
      [ -e "$old" ] || continue
      mkdir -p "$STATE/backup/$(dirname "$rel")"
      cp -a "$old" "$STATE/backup/$rel"
      break
    done
  elif [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$STATE/backup/$(dirname "$rel")"
    cp -a "$dst" "$STATE/backup/$rel"
  fi
  printf '%s\t%s\n' "$STEP" "$rel" >> "$MANIFEST"
}

# Copia un archivo del repo a su destino, registrándolo
put() {  # origen-relativo destino [modo]
  track "$2"
  mkdir -p "$(dirname "$2")"
  install -m "${3:-644}" "$REPO/$1" "$2"
}

# Guarda el valor actual de claves de gsettings (sólo la primera vez)
save_keys() {  # esquema clave...
  local schema="$1" key value
  shift
  have gsettings || return 0
  mkdir -p "$STATE"
  touch "$GSAVED"
  for key in "$@"; do
    cut -f2,3 "$GSAVED" | grep -qxF "$schema	$key" && continue
    value="$(gsettings get "$schema" "$key" 2>/dev/null)" || continue
    printf '%s\t%s\t%s\t%s\n' "$STEP" "$schema" "$key" "$value" >> "$GSAVED"
  done
}

# ------------------------------------------------------------ pasos
paso_paquetes() {
  say "Paquetes de apt"
  $SUDO apt-get update
  $SUDO apt-get install -y "${PACKAGES[@]}"
}

paso_ghostty() {
  if have ghostty; then
    echo "Ghostty ya está instalado."
    return
  fi
  say "Ghostty (paquete .deb de github.com/mkasberg/ghostty-ubuntu)"
  curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh | bash
}

# Descarga el asset de la última release de un repo de GitHub
gh_latest() {  # repo regex salida
  local url auth=()
  [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  url=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$1/releases/latest" |
    python3 -c 'import json, re, sys
assets = json.load(sys.stdin)["assets"]
print([a["browser_download_url"] for a in assets if re.search(sys.argv[1], a["name"], re.I)][0])' "$2")
  curl -fsSL -o "$3" "$url"
}

paso_binarios() {
  say "Binarios en ~/.local/bin (Starship, fastfetch, lazygit, lazydocker, tema)"
  if [ "$(uname -m)" != x86_64 ]; then
    echo "Sólo hay binarios para x86_64 (esta máquina es $(uname -m))." >&2
    return 1
  fi
  mkdir -p "$BIN"
  gh_latest starship/starship 'starship-x86_64-unknown-linux-musl\.tar\.gz$' "$TMP/starship.tgz"
  tar -xzf "$TMP/starship.tgz" -C "$TMP" starship
  track "$BIN/starship" && install -m755 "$TMP/starship" "$BIN/"
  gh_latest fastfetch-cli/fastfetch 'fastfetch-linux-amd64\.tar\.gz$' "$TMP/ff.tgz"
  tar -xzf "$TMP/ff.tgz" -C "$TMP"
  track "$BIN/fastfetch" && install -m755 "$TMP/fastfetch-linux-amd64/usr/bin/fastfetch" "$BIN/"
  local r
  for r in lazygit lazydocker; do
    gh_latest "jesseduffield/$r" '_linux_x86_64\.tar\.gz$' "$TMP/$r.tgz"
    tar -xzf "$TMP/$r.tgz" -C "$TMP" "$r"
    track "$BIN/$r" && install -m755 "$TMP/$r" "$BIN/"
  done
  put bin/tema "$BIN/tema" 755

  say "JetBrains Mono Nerd Font"
  local fonts="$HOME/.local/share/fonts/JetBrainsMonoNerd"
  track "$fonts"
  mkdir -p "$fonts"
  gh_latest ryanoasis/nerd-fonts '^JetBrainsMono\.tar\.xz$' "$TMP/jbm.tar.xz"
  tar -xf "$TMP/jbm.tar.xz" -C "$fonts"
  have fc-cache && fc-cache -f >/dev/null
  return 0
}

paso_configs() {
  say "Configuraciones en ~/.config (los originales quedan en $STATE/backup)"
  put config/ghostty/config             "$CFG/ghostty/config"
  put config/starship.toml              "$CFG/starship.toml"
  put config/fastfetch/config.jsonc     "$CFG/fastfetch/config.jsonc"
  put config/bash/omarchy-style.sh      "$CFG/bash/omarchy-style.sh"
  put config/btop/btop.conf             "$CFG/btop/btop.conf"
  put config/lazygit/config.yml         "$CFG/lazygit/config.yml"
  put config/lazydocker/config.yml      "$CFG/lazydocker/config.yml"

  # Temas propios (p. ej. matrix): paleta, fondo animado y fondos estáticos
  local t name f walls
  walls="$(wallpapers_dir)"
  for t in "$REPO"/temas/*/; do
    name="$(basename "$t")"
    put "temas/$name/colors.toml" "$HOME/.local/share/tema/$name/colors.toml"
    if [ -f "$t/animado" ]; then
      put "temas/$name/animado" "$HOME/.local/share/tema/$name/animado" 755
    fi
    for f in "$t"/fondos/*.jpg; do
      if [ -e "$f" ]; then
        put "temas/$name/fondos/$(basename "$f")" "$walls/$name/$(basename "$f")"
      fi
    done
  done
}

# Misma lógica que `tema`: $TEMA_WALLPAPERS, ~/Pictures/Wallpapers si ya existe,
# o la carpeta de imágenes de XDG (localizada) + /Wallpapers.
wallpapers_dir() {
  local pics=
  if [ -n "${TEMA_WALLPAPERS:-}" ]; then
    echo "$TEMA_WALLPAPERS"
    return
  fi
  [ -d "$HOME/Pictures/Wallpapers" ] || ! have xdg-user-dir || pics="$(xdg-user-dir PICTURES)"
  # Sin configurar, xdg-user-dir devuelve $HOME
  if [ -n "$pics" ] && [ "$pics" != "$HOME" ]; then
    echo "$pics/Wallpapers"
  else
    echo "$HOME/Pictures/Wallpapers"
  fi
}

paso_shell() {
  say "Cargar omarchy-style.sh desde ~/.bashrc"
  # Sin archivos que registrar: alcanza con que exista el registro para poder desinstalar
  mkdir -p "$STATE" && touch "$MANIFEST"
  touch "$HOME/.bashrc"
  if ! grep -qxF "$BASHRC_LINE" "$HOME/.bashrc"; then
    printf '\n%s\n%s\n' "$BASHRC_COMMENT" "$BASHRC_LINE" >> "$HOME/.bashrc"
  fi
}

paso_escritorio() {
  say "Ajustes de Pantheon (dock y terminal por defecto)"
  save_keys io.elementary.dock launchers
  save_keys org.gnome.desktop.default-applications.terminal exec
  save_keys org.gnome.desktop.interface color-scheme
  bash "$REPO/gsettings/escritorio.sh"
}

paso_atajos() {
  say "Atajos de teclado"
  local schema key
  while read -r schema key; do
    save_keys "$schema" "$key"
  done < <(bash "$REPO/gsettings/atajos.sh" --claves)
  bash "$REPO/gsettings/atajos.sh"
}

paso_tema() {
  say "Tema inicial (${TEMA_INICIAL:-tokyo-night})"
  save_keys org.gnome.desktop.interface color-scheme gtk-theme
  save_keys org.gnome.desktop.background picture-uri picture-uri-dark
  # Lo que genera `tema`, para poder quitarlo al desinstalar
  track "$CFG/ghostty/themes/tema"
  track "$CFG/btop/themes/tema.theme"
  track "$CFG/tema"
  "$BIN/tema" "${TEMA_INICIAL:-tokyo-night}"
}

paso_zed() {
  say "Zed"
  put config/zed/themes/matrix.json "$CFG/zed/themes/matrix.json"
  local f="$CFG/zed/settings.json"
  if [ ! -f "$f" ]; then
    mkdir -p "$CFG/zed" && sed '/^\/\//d' "$REPO/config/zed/settings.fragment.jsonc" > "$f"
    echo "Creado $f con el tema Tokyo Night."
  else
    echo "Ya existe $f: agregá a mano lo de config/zed/settings.fragment.jsonc"
    echo "(no se sobrescribe para no perder tus ajustes ni tokens)."
  fi
}

user_systemctl() { have systemctl && systemctl --user "$@" 2>/dev/null; }

paso_fondos() {
  say "Rotación de fondos cada 30 min (timer de systemd)"
  put config/systemd/user/tema-fondo.service "$CFG/systemd/user/tema-fondo.service"
  put config/systemd/user/tema-fondo.timer   "$CFG/systemd/user/tema-fondo.timer"
  user_systemctl daemon-reload || true
  user_systemctl enable --now tema-fondo.timer || echo "No se pudo activar el timer (¿hay sesión de systemd de usuario?)."
}

paso_animado() {
  say "Fondo animado (para los temas que tienen uno, como matrix)"
  put config/systemd/user/tema-animado.service "$CFG/systemd/user/tema-animado.service"
  put config/autostart/tema-animado.desktop    "$CFG/autostart/tema-animado.desktop"
  user_systemctl daemon-reload || true
  user_systemctl restart tema-animado.service || true
}

# ------------------------------------------------------------ desinstalar
TRASH="$STATE/desinstalado-$(date +%Y%m%d-%H%M%S)"

# Saca lo instalado (a $TRASH) y repone el original si había
restore() {  # ruta relativa a $HOME
  local rel="$1" dst="$HOME/$1"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$TRASH/$(dirname "$rel")"
    mv "$dst" "$TRASH/$rel"
  fi
  if [ -e "$STATE/backup/$rel" ] || [ -L "$STATE/backup/$rel" ]; then
    mkdir -p "$(dirname "$dst")"
    mv "$STATE/backup/$rel" "$dst"
    echo "  restaurado  ~/$rel"
  else
    echo "  quitado     ~/$rel"
    # Borra los directorios que quedaron vacíos (sin pasar de $HOME)
    local d
    d="$(dirname "$dst")"
    while [ "$d" != "$HOME" ] && rmdir "$d" 2>/dev/null; do d="$(dirname "$d")"; done
  fi
}

undo_files() {  # paso
  [ -f "$MANIFEST" ] || return 0
  local step rel
  # Al revés, para que los directorios se procesen después de su contenido
  tac "$MANIFEST" | while IFS=$'\t' read -r step rel; do
    if [ "$step" = "$1" ]; then restore "$rel"; fi
  done
  awk -F'\t' -v s="$1" '$1 != s' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
}

undo_keys() {  # paso
  [ -f "$GSAVED" ] || return 0
  if ! have gsettings; then
    echo "  (sin gsettings: no se restauran los ajustes del escritorio)"
    return 0
  fi
  local step schema key value
  while IFS=$'\t' read -r step schema key value; do
    [ "$step" = "$1" ] || continue
    if gsettings set "$schema" "$key" "$value"; then echo "  gsettings   $schema $key"; fi
  done < "$GSAVED"
  awk -F'\t' -v s="$1" '$1 != s' "$GSAVED" > "$GSAVED.tmp" && mv "$GSAVED.tmp" "$GSAVED"
}

quitar_paquetes() {
  echo "  Los paquetes de apt no se desinstalan (otros programas pueden usarlos)."
  echo "  Para quitarlos: sudo apt remove ${PACKAGES[*]:0:5}"
}

quitar_ghostty() {
  echo "  Ghostty no se desinstala. Para quitarlo: sudo apt remove ghostty"
}

quitar_binarios() {
  undo_files binarios
  have fc-cache && fc-cache -f >/dev/null
  return 0
}

quitar_shell() {
  [ -f "$HOME/.bashrc" ] || return 0
  grep -qxF "$BASHRC_LINE" "$HOME/.bashrc" || return 0
  mkdir -p "$TRASH"
  cp -a "$HOME/.bashrc" "$TRASH/.bashrc"
  # Si nada se agregó después, el archivo termina con el bloque exacto que
  # escribió `paso_shell`: se recortan esos bytes y queda idéntico al original
  # (aunque no terminara en salto de línea, como el .bashrc de elementary).
  local c n
  for c in "$BASHRC_COMMENT" "$BASHRC_COMMENT_OLD" "$BASHRC_COMMENT_OLD2"; do
    printf '\n%s\n%s\n' "$c" "$BASHRC_LINE" > "$TMP/bloque"
    n=$(wc -c < "$TMP/bloque")
    if tail -c "$n" "$TRASH/.bashrc" | cmp -s - "$TMP/bloque"; then
      head -c -"$n" "$TRASH/.bashrc" > "$HOME/.bashrc"
      echo "  quitada la línea de ~/.bashrc (copia en $TRASH/.bashrc)"
      return 0
    fi
  done
  # Si no, quita nuestras líneas y la línea en blanco que agregamos antes
  L="$BASHRC_LINE" C1="$BASHRC_COMMENT" C2="$BASHRC_COMMENT_OLD" C3="$BASHRC_COMMENT_OLD2" awk '
    $0 == ENVIRON["L"] || $0 == ENVIRON["C1"] || $0 == ENVIRON["C2"] || $0 == ENVIRON["C3"] { blank = 0; next }
    $0 == "" { if (blank) print ""; blank = 1; next }
    { if (blank) print ""; blank = 0; print }
    END { if (blank) print "" }
  ' "$TRASH/.bashrc" > "$HOME/.bashrc"
  echo "  quitada la línea de ~/.bashrc (copia en $TRASH/.bashrc)"
}

quitar_tema() {
  undo_files tema
  undo_keys tema
  # Paletas descargadas por `tema` (los temas propios los quita `configs`)
  local e rel
  for e in "$HOME"/.local/share/tema/*; do
    [ -e "$e" ] || continue
    rel="${e#"$HOME"/}"
    tracked_prefix "$rel/" && continue
    mkdir -p "$TRASH/.local/share/tema"
    mv "$e" "$TRASH/$rel"
    echo "  quitado     ~/$rel"
  done
  rmdir "$HOME/.local/share/tema" 2>/dev/null || true
  echo "  Los fondos descargados quedan en $(wallpapers_dir)/ (borralos a mano si querés)."
}

tracked_prefix() {
  [ -f "$MANIFEST" ] && cut -f2 "$MANIFEST" | awk -v p="$1" 'index($0, p) == 1 { f = 1 } END { exit !f }'
}

quitar_fondos() {
  user_systemctl disable --now tema-fondo.timer || true
  undo_files fondos
  user_systemctl daemon-reload || true
}

quitar_animado() {
  user_systemctl stop tema-animado.service || true
  undo_files animado
  user_systemctl daemon-reload || true
}

quitar_generico() {  # paso
  undo_files "$1"
  undo_keys "$1"
}

uninstall() {
  if [ ! -f "$MANIFEST" ] && [ ! -f "$GSAVED" ]; then
    echo "No hay nada registrado en $STATE."
    if [ -e "$BIN/tema" ]; then
      echo "Parece una instalación anterior al registro: corré una vez ./install.sh"
      echo "(con los mismos pasos que usaste) para registrarla y después desinstalá."
    fi
    exit 1
  fi
  local all=("${DEFAULT[@]}" "${OPTIONAL[@]}") wanted=("$@") i s
  [ ${#wanted[@]} -eq 0 ] && wanted=("${all[@]}")
  for s in "${wanted[@]}"; do valid_step "$s"; done
  # En orden inverso al de instalación
  for (( i=${#all[@]}-1; i>=0; i-- )); do
    s="${all[$i]}"
    [[ " ${wanted[*]} " == *" $s "* ]] || continue
    say "Desinstalar: $s"
    case "$s" in
      paquetes|ghostty|binarios|shell|tema|fondos|animado) "quitar_$s" ;;
      *) quitar_generico "$s" ;;
    esac
  done
  [ -d "$TRASH" ] && echo && echo "Lo que se sacó quedó en $TRASH"
  say "Listo. Abrí una terminal nueva para que se note."
}

# ------------------------------------------------------------ main
valid_step() {
  case " ${DEFAULT[*]} ${OPTIONAL[*]} " in
    *" $1 "*) return 0 ;;
  esac
  echo "Paso desconocido: $1" >&2
  echo "Por defecto: ${DEFAULT[*]}  ·  Opcionales: ${OPTIONAL[*]}" >&2
  exit 1
}

case "${1:-}" in
  -h|--help|ayuda) usage; exit 0 ;;
  desinstalar|--desinstalar) shift; uninstall "$@"; exit 0 ;;
esac

steps=()
[ $# -eq 0 ] && set -- todo
for s in "$@"; do
  if [ "$s" = todo ]; then steps+=("${DEFAULT[@]}"); else valid_step "$s"; steps+=("$s"); fi
done
for s in "${steps[@]}"; do
  STEP="$s"
  "paso_$s"
done

say "Listo. Abrí una ventana nueva de Ghostty (Super+Enter)."
