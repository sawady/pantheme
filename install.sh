#!/usr/bin/env bash
# pantheme: step-by-step installer for elementary OS 8 (inspired by Omarchy).
#
#   ./install.sh                       default steps
#   ./install.sh <step>...             only those steps (optional ones too)
#   ./install.sh all zed               default steps + some optional ones
#   ./install.sh uninstall [step...]   undo everything, or only those steps
#   ./install.sh help
#
# Every file the installer writes is recorded in ~/.local/state/pantheme/manifest;
# if it already existed, the original is saved in ~/.local/state/pantheme/backup/
# the first time. Messages are in Spanish when the locale is Spanish, and the
# Spanish step names of earlier versions still work.
set -euo pipefail

NAME=pantheme
REPO="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
CFG="$HOME/.config"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/$NAME"
MANIFEST="$STATE/manifest"   # step<TAB>path relative to $HOME (absolute if it is outside)
GSAVED="$STATE/gsettings"    # step<TAB>schema<TAB>key<TAB>original value
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DEFAULT=(packages ghostty binaries configs shell desktop shortcuts theme)
OPTIONAL=(zed wallpaper-rotation animated gtk)
PACKAGES=(btop eza bat fzf zoxide curl ca-certificates python3 python3-pil fontconfig xz-utils)
BASHRC_LINE='[ -f ~/.config/bash/omarchy-style.sh ] && . ~/.config/bash/omarchy-style.sh'
BASHRC_COMMENT="# $NAME: prompt, aliases and tools"
# Comments written by earlier versions, recognized when uninstalling
BASHRC_COMMENTS=(
  "$BASHRC_COMMENT"
  '# pantheme: prompt, aliases y herramientas'
  '# elementary-setup: prompt, aliases y herramientas'
  '# Estilo Omarchy (prompt, aliases, herramientas)'
)
INITIAL_THEME="${PANTHEME_THEME:-${TEMA_INICIAL:-tokyo-night}}"
# Line that the `gtk` step puts in ~/.config/gtk-{3,4}.0/gtk.css (same as in bin/pantheme)
GTK_IMPORT='@import url("pantheme.css");'

SUDO=
[ "$(id -u)" -eq 0 ] || SUDO=sudo
STEP=
LEGACY=0

# ------------------------------------------------------------ messages
# Spanish when the locale for messages is Spanish (LC_ALL > LC_MESSAGES > LANG)
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
  es*) UI=es ;;
  *)   UI=en ;;
esac

# shellcheck disable=SC2016  # backquotes and $VARS in messages are literal
msg() {  # key -> printf format, in the user's language
  local en es
  case "$1" in
    usage) en='pantheme: step-by-step installer for elementary OS 8, inspired by Omarchy.

Usage:
  ./install.sh                       default steps (same as `all`)
  ./install.sh <step>...             only those steps (optional ones too)
  ./install.sh all zed               default steps + some optional ones
  ./install.sh uninstall [step...]   undo everything, or only those steps
  ./install.sh help                  this help

Default steps:
  packages            apt: btop, eza, bat, fzf, zoxide, python3-pil and basics
  ghostty             the Ghostty terminal, if it is missing
  binaries            Starship, fastfetch, lazygit, lazydocker, pantheme and
                      JetBrains Mono Nerd Font into ~/.local
  configs             config files into ~/.config, bundled themes
  shell               one line in ~/.bashrc that loads omarchy-style.sh
  desktop             Ghostty as the default terminal and in the dock
  shortcuts           keyboard shortcuts
  theme               apply the initial theme ($PANTHEME_THEME, or tokyo-night)
Optional steps:
  zed                 Matrix theme and theme settings for Zed
  wallpaper-rotation  next wallpaper every 30 minutes (systemd timer)
  animated            animated wallpaper, for themes that have one (matrix, tokyo-night)
  gtk                 window colors of GTK apps follow the theme

The Spanish names of earlier versions still work: paquetes, binarios,
escritorio, atajos, tema, fondos, animado, todo, desinstalar, ayuda.
Messages are in Spanish when the locale is Spanish (LANG=es_...).'
           es='pantheme: instalador por pasos para elementary OS 8, inspirado en Omarchy.

Uso:
  ./install.sh                       pasos por defecto (igual que `all`)
  ./install.sh <paso>...             sólo esos pasos (también los opcionales)
  ./install.sh all zed               los de por defecto + algunos opcionales
  ./install.sh uninstall [paso...]   deshace todo, o sólo esos pasos
  ./install.sh help                  esta ayuda

Pasos por defecto:
  packages            apt: btop, eza, bat, fzf, zoxide, python3-pil y básicos
  ghostty             la terminal Ghostty, si falta
  binaries            Starship, fastfetch, lazygit, lazydocker, pantheme y
                      JetBrains Mono Nerd Font en ~/.local
  configs             configuraciones en ~/.config, temas propios
  shell               una línea en ~/.bashrc que carga omarchy-style.sh
  desktop             Ghostty como terminal por defecto y en el dock
  shortcuts           atajos de teclado
  theme               aplica el tema inicial ($PANTHEME_THEME, o tokyo-night)
Opcionales:
  zed                 tema Matrix y ajustes de tema para Zed
  wallpaper-rotation  siguiente fondo cada 30 minutos (timer de systemd)
  animated            fondo animado, para los temas que tienen uno (matrix, tokyo-night)
  gtk                 el color de las ventanas de las apps GTK sigue al tema

Los nombres en castellano de versiones anteriores siguen andando: paquetes,
binarios, escritorio, atajos, tema, fondos, animado, todo, desinstalar, ayuda.
Los mensajes salen en castellano si el idioma es castellano (LANG=es_...).' ;;
    record_moved) en='Moved the install record from %s to %s.'
                  es='Registro movido de %s a %s.' ;;
    h_migrate) en='Migrating an install of `tema` to the new names (pantheme-*)'
               es='Migrando una instalación de `tema` a los nombres nuevos (pantheme-*)' ;;
    h_packages) en='apt packages'
                es='Paquetes de apt' ;;
    ghostty_present) en='Ghostty is already installed.'
                     es='Ghostty ya está instalado.' ;;
    h_ghostty) en='Ghostty (.deb package from github.com/mkasberg/ghostty-ubuntu)'
               es='Ghostty (paquete .deb de github.com/mkasberg/ghostty-ubuntu)' ;;
    gh_ghostty) en='The Ghostty installer failed (it queries GitHub).'
                es='Falló el instalador de Ghostty (consulta GitHub).' ;;
    gh_release) en='Could not get the latest release of %s from GitHub.'
                es='No se pudo consultar la última versión de %s en GitHub.' ;;
    gh_limit) en="If it is GitHub's API rate limit (60 requests per hour without a token),\nwait a while or set GITHUB_TOKEN."
              es='Si es el límite de pedidos de la API de GitHub (60 por hora sin token),\nesperá un rato o definí GITHUB_TOKEN.' ;;
    h_binaries) en='Binaries in ~/.local/bin (Starship, fastfetch, lazygit, lazydocker, pantheme)'
                es='Binarios en ~/.local/bin (Starship, fastfetch, lazygit, lazydocker, pantheme)' ;;
    not_x86) en='Binaries are only available for x86_64 (this machine is %s).'
             es='Sólo hay binarios para x86_64 (esta máquina es %s).' ;;
    h_font) en='JetBrains Mono Nerd Font'
            es='JetBrains Mono Nerd Font' ;;
    h_configs) en='Config files in ~/.config (the originals are kept in %s)'
               es='Configuraciones en ~/.config (los originales quedan en %s)' ;;
    h_shell) en='Load omarchy-style.sh from ~/.bashrc'
             es='Cargar omarchy-style.sh desde ~/.bashrc' ;;
    h_desktop) en='Pantheon settings (dock and default terminal)'
               es='Ajustes de Pantheon (dock y terminal por defecto)' ;;
    h_shortcuts) en='Keyboard shortcuts'
                 es='Atajos de teclado' ;;
    h_theme) en='Initial theme (%s)'
             es='Tema inicial (%s)' ;;
    h_zed) en='Zed'
           es='Zed' ;;
    zed_created) en='Created %s with the Tokyo Night theme.'
                 es='Creado %s con el tema Tokyo Night.' ;;
    zed_exists) en='%s already exists: add what is in config/zed/settings.fragment.jsonc by hand\n(it is not overwritten, so you keep your settings and tokens).'
                es='Ya existe %s: agregá a mano lo de config/zed/settings.fragment.jsonc\n(no se sobrescribe para no perder tus ajustes ni tokens).' ;;
    h_rotation) en='Wallpaper rotation every 30 minutes (systemd user timer)'
                es='Rotación del fondo cada 30 minutos (timer de systemd de usuario)' ;;
    timer_failed) en='Could not enable the timer (is there a systemd user session?).'
                  es='No se pudo activar el timer (¿hay sesión de systemd de usuario?).' ;;
    h_animated) en='Animated wallpaper (for themes that have one, like matrix or tokyo-night)'
                es='Fondo animado (para los temas que tienen uno, como matrix o tokyo-night)' ;;
    h_gtk) en='Window colors of GTK apps (~/.config/gtk-3.0 and gtk-4.0)'
           es='Colores de las ventanas de las apps GTK (~/.config/gtk-3.0 y gtk-4.0)' ;;
    gtk_restart) en='Open apps take the colors when restarted. Chrome, Electron apps (Slack, VS Code…)\nand Flatpak apps keep their own.'
                 es='Las apps abiertas toman los colores al reiniciarlas. Chrome, las apps Electron\n(Slack, VS Code…) y las Flatpak mantienen los suyos.' ;;
    restored) en='  restored    %s'
              es='  restaurado  %s' ;;
    removed) en='  removed     %s'
             es='  quitado     %s' ;;
    no_gsettings) en='  (no gsettings: the desktop settings are not restored)'
                  es='  (sin gsettings: no se restauran los ajustes del escritorio)' ;;
    keep_packages) en='  apt packages are not removed (other programs may use them).\n  To remove them: sudo apt remove %s'
                   es='  Los paquetes de apt no se desinstalan (otros programas pueden usarlos).\n  Para quitarlos: sudo apt remove %s' ;;
    keep_ghostty) en='  Ghostty is not removed. To remove it: sudo apt remove ghostty'
                  es='  Ghostty no se desinstala. Para quitarlo: sudo apt remove ghostty' ;;
    bashrc_removed) en='  removed the line from ~/.bashrc (copy in %s)'
                    es='  quitada la línea de ~/.bashrc (copia en %s)' ;;
    walls_kept) en='  Downloaded wallpapers stay in %s/ (delete them by hand if you want).'
                es='  Los fondos descargados quedan en %s/ (borralos a mano si querés).' ;;
    nothing_recorded) en='Nothing is recorded in %s.'
                      es='No hay nada registrado en %s.' ;;
    legacy_hint) en='It looks like an install from before the record existed: run ./install.sh once\n(with the same steps you used) to record it, and then uninstall.'
                 es='Parece una instalación anterior al registro: corré una vez ./install.sh\n(con los mismos pasos que usaste) para registrarla y después desinstalá.' ;;
    h_uninstall) en='Uninstall: %s'
                 es='Desinstalar: %s' ;;
    trash) en='What was removed is in %s'
           es='Lo que se sacó quedó en %s' ;;
    done_uninstall) en='Done. Open a new terminal to see the change.'
                    es='Listo. Abrí una terminal nueva para que se note.' ;;
    unknown_step) en='Unknown step: %s'
                  es='Paso desconocido: %s' ;;
    step_list) en='Default: %s  ·  Optional: %s'
               es='Por defecto: %s  ·  Opcionales: %s' ;;
    finished) en='Done. Open a new Ghostty window (Super+Enter).'
              es='Listo. Abrí una ventana nueva de Ghostty (Super+Enter).' ;;
    *) en="$1" es="$1" ;;
  esac
  if [ "$UI" = es ]; then printf '%s' "$es"; else printf '%s' "$en"; fi
}

# t key [args...]: prints a message from the table
t() {
  local f
  f="$(msg "$1")"
  shift
  # shellcheck disable=SC2059  # the format comes from the table above
  printf -- "$f\n" "$@"
}
say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$(t "$@")"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Spanish step names of earlier versions -> current names
canon() {
  case "$1" in
    paquetes) echo packages ;;
    binarios) echo binaries ;;
    escritorio) echo desktop ;;
    atajos) echo shortcuts ;;
    tema) echo theme ;;
    fondos) echo wallpaper-rotation ;;
    animado) echo animated ;;
    todo) echo all ;;
    desinstalar|--desinstalar|--uninstall) echo uninstall ;;
    ayuda|-h|--help) echo help ;;
    *) echo "$1" ;;
  esac
}

# ------------------------------------------------------------ record
prepare_record() {
  # The project was called elementary-setup: a record under that name is moved
  # to the new place, so that it can still be uninstalled.
  local old="${XDG_STATE_HOME:-$HOME/.local/state}/elementary-setup" f
  if [ -d "$old" ] && [ ! -e "$STATE" ]; then
    mkdir -p "$(dirname "$STATE")"
    mv "$old" "$STATE"
    t record_moved "$old" "$STATE"
  fi
  # Installs from before the manifest: there is no manifest, but the command is
  # there. Then what is there isn't backed up (it's already ours), unless there
  # is an old backup in ~/.config-backup-*/ (the oldest one is used).
  if [ ! -f "$MANIFEST" ] && { [ -e "$BIN/tema" ] || [ -e "$BIN/pantheme" ]; }; then
    LEGACY=1
  fi
  # Before 0.1.0 the record used the Spanish step names
  for f in "$MANIFEST" "$GSAVED"; do
    [ -f "$f" ] || continue
    awk -F'\t' -v OFS='\t' '
      BEGIN {
        n = split("paquetes packages binarios binaries escritorio desktop atajos shortcuts " \
                  "tema theme fondos wallpaper-rotation animado animated", a, " ")
        for (i = 1; i < n; i += 2) m[a[i]] = a[i + 1]
      }
      $1 in m { $1 = m[$1] }
      { print }' "$f" > "$f.tmp"
    if cmp -s "$f" "$f.tmp"; then rm "$f.tmp"; else mv "$f.tmp" "$f"; fi
  done
}

tracked() { [ -f "$MANIFEST" ] && cut -f2 "$MANIFEST" | grep -qxF "$1"; }

untrack() {  # recorded path
  [ -f "$MANIFEST" ] || return 0
  awk -F'\t' -v p="$1" '$2 != p' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
}

# Records a destination before writing it, and saves the original the first time
track() {  # destination
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

# Copies a file from the repository to its destination, recording it
put() {  # source-relative-to-repo destination [mode]
  track "$2"
  mkdir -p "$(dirname "$2")"
  install -m "${3:-644}" "$REPO/$1" "$2"
}

# Saves the current value of gsettings keys (only the first time)
save_keys() {  # schema key...
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

user_systemctl() { have systemctl && systemctl --user "$@" 2>/dev/null; }

# Removes the links that enabling a timer leaves, if systemctl couldn't
drop_wants() {  # unit...
  local dir="$CFG/systemd/user/timers.target.wants" u
  for u in "$@"; do
    if [ -L "$dir/$u" ]; then rm "$dir/$u"; fi
  done
  rmdir "$dir" 2>/dev/null || true
}

# ------------------------------------------------------------ migration
# Before 0.1.0 the theme command was `tema`, and its systemd units and autostart
# entry were named tema-*. They are replaced by pantheme-* (and `tema` becomes
# an alias of `pantheme`), keeping the record up to date.
OLD_UNITS=(
  "wallpaper-rotation .config/systemd/user/tema-fondo.timer"
  "wallpaper-rotation .config/systemd/user/tema-fondo.service"
  "animated .config/systemd/user/tema-animado.service"
  "animated .config/autostart/tema-animado.desktop"
)

migrate_tema() {  # steps about to run (not reinstalled here)
  local entry step rel found=0 redo=() s
  for entry in "${OLD_UNITS[@]}"; do
    rel="${entry#* }"
    if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then found=1; fi
  done
  if [ -f "$BIN/tema" ] && [ ! -L "$BIN/tema" ]; then found=1; fi
  [ "$found" = 1 ] || return 0

  say h_migrate
  user_systemctl disable --now tema-fondo.timer || true
  user_systemctl stop tema-animado.service || true
  for entry in "${OLD_UNITS[@]}"; do
    step="${entry%% *}" rel="${entry#* }"
    [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ] || continue
    restore "$rel"
    untrack "$rel"
    [[ " ${redo[*]} " == *" $step "* ]] || redo+=("$step")
  done
  drop_wants tema-fondo.timer
  user_systemctl daemon-reload || true

  if [ -f "$BIN/tema" ] && [ ! -L "$BIN/tema" ]; then
    STEP=binaries
    install_command
    echo "  ~/.local/bin/tema -> pantheme"
  fi
  # The same features under the new names
  for s in ${redo[@]+"${redo[@]}"}; do
    [[ " $* " == *" $s "* ]] && continue
    STEP="$s"
    "step_${s//-/_}"
  done
}

# ------------------------------------------------------------ steps
step_packages() {
  say h_packages
  $SUDO apt-get update
  $SUDO apt-get install -y "${PACKAGES[@]}"
}

step_ghostty() {
  if have ghostty; then
    t ghostty_present
    return
  fi
  say h_ghostty
  if ! curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh | bash; then
    { t gh_ghostty; t gh_limit; } >&2
    return 1
  fi
}

# Downloads an asset of the latest release of a GitHub repository
gh_latest() {  # repo regex output
  local url auth=()
  [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  if ! url=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$1/releases/latest" |
    python3 -c 'import json, re, sys
assets = json.load(sys.stdin)["assets"]
print([a["browser_download_url"] for a in assets if re.search(sys.argv[1], a["name"], re.I)][0])' "$2"); then
    { t gh_release "$1"; t gh_limit; } >&2
    return 1
  fi
  curl -fsSL -o "$3" "$url"
}

# The theme command, and `tema` (its former name) as an alias
install_command() {
  put bin/pantheme "$BIN/pantheme" 755
  track "$BIN/tema"
  ln -sfn pantheme "$BIN/tema"
}

step_binaries() {
  say h_binaries
  if [ "$(uname -m)" != x86_64 ]; then
    t not_x86 "$(uname -m)" >&2
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
  install_command

  say h_font
  local fonts="$HOME/.local/share/fonts/JetBrainsMonoNerd"
  track "$fonts"
  mkdir -p "$fonts"
  gh_latest ryanoasis/nerd-fonts '^JetBrainsMono\.tar\.xz$' "$TMP/jbm.tar.xz"
  tar -xf "$TMP/jbm.tar.xz" -C "$fonts"
  have fc-cache && fc-cache -f >/dev/null
  return 0
}

step_configs() {
  say h_configs "$STATE/backup"
  put config/ghostty/config             "$CFG/ghostty/config"
  put config/starship.toml              "$CFG/starship.toml"
  put config/fastfetch/config.jsonc     "$CFG/fastfetch/config.jsonc"
  put config/bash/omarchy-style.sh      "$CFG/bash/omarchy-style.sh"
  put config/btop/btop.conf             "$CFG/btop/btop.conf"
  put config/lazygit/config.yml         "$CFG/lazygit/config.yml"
  put config/lazydocker/config.yml      "$CFG/lazydocker/config.yml"

  # Bundled themes (e.g. matrix): palette, animated wallpaper and static wallpapers.
  # A folder without colors.toml only adds files to the Omarchy theme of the
  # same name (e.g. tokyo-night/animado); `pantheme` still downloads its palette.
  local dir name f walls
  walls="$(wallpapers_dir)"
  for dir in "$REPO"/temas/*/; do
    name="$(basename "$dir")"
    if [ -f "$dir/colors.toml" ]; then
      put "temas/$name/colors.toml" "$HOME/.local/share/tema/$name/colors.toml"
    fi
    if [ -f "$dir/animado" ]; then
      put "temas/$name/animado" "$HOME/.local/share/tema/$name/animado" 755
    fi
    for f in "$dir"/fondos/*.jpg; do
      if [ -e "$f" ]; then
        put "temas/$name/fondos/$(basename "$f")" "$walls/$name/$(basename "$f")"
      fi
    done
  done
}

# Same logic as `pantheme`: $PANTHEME_WALLPAPERS, ~/Pictures/Wallpapers if it
# exists, or the (localized) XDG pictures folder + /Wallpapers.
wallpapers_dir() {
  local pics='' custom="${PANTHEME_WALLPAPERS:-${TEMA_WALLPAPERS:-}}"
  if [ -n "$custom" ]; then
    # The record reads relative paths as relative to $HOME, not to this directory
    case "$custom" in
      /*) echo "$custom" ;;
      *)  echo "$PWD/$custom" ;;
    esac
    return
  fi
  [ -d "$HOME/Pictures/Wallpapers" ] || ! have xdg-user-dir || pics="$(xdg-user-dir PICTURES)"
  # When it isn't configured, xdg-user-dir prints $HOME
  if [ -n "$pics" ] && [ "$pics" != "$HOME" ]; then
    echo "$pics/Wallpapers"
  else
    echo "$HOME/Pictures/Wallpapers"
  fi
}

step_shell() {
  say h_shell
  # No files to record: the record only has to exist, so that it can be uninstalled
  mkdir -p "$STATE" && touch "$MANIFEST"
  touch "$HOME/.bashrc"
  if ! grep -qxF "$BASHRC_LINE" "$HOME/.bashrc"; then
    printf '\n%s\n%s\n' "$BASHRC_COMMENT" "$BASHRC_LINE" >> "$HOME/.bashrc"
  fi
}

step_desktop() {
  say h_desktop
  save_keys io.elementary.dock launchers
  save_keys org.gnome.desktop.default-applications.terminal exec
  save_keys org.gnome.desktop.interface color-scheme
  bash "$REPO/gsettings/desktop.sh"
}

step_shortcuts() {
  say h_shortcuts
  local schema key
  while read -r schema key; do
    save_keys "$schema" "$key"
  done < <(bash "$REPO/gsettings/shortcuts.sh" --keys)
  bash "$REPO/gsettings/shortcuts.sh"
}

step_theme() {
  say h_theme "$INITIAL_THEME"
  save_keys org.gnome.desktop.interface color-scheme gtk-theme
  save_keys org.gnome.desktop.background picture-uri picture-uri-dark
  # What `pantheme` generates, so that it can be removed when uninstalling
  track "$CFG/ghostty/themes/tema"
  track "$CFG/btop/themes/tema.theme"
  track "$CFG/tema"
  "$BIN/pantheme" "$INITIAL_THEME"
}

step_zed() {
  say h_zed
  put config/zed/themes/matrix.json "$CFG/zed/themes/matrix.json"
  local f="$CFG/zed/settings.json"
  if [ ! -f "$f" ]; then
    mkdir -p "$CFG/zed" && sed '/^\/\//d' "$REPO/config/zed/settings.fragment.jsonc" > "$f"
    t zed_created "$f"
  else
    t zed_exists "$f"
  fi
}

step_wallpaper_rotation() {
  say h_rotation
  put config/systemd/user/pantheme-wallpaper.service "$CFG/systemd/user/pantheme-wallpaper.service"
  put config/systemd/user/pantheme-wallpaper.timer   "$CFG/systemd/user/pantheme-wallpaper.timer"
  user_systemctl daemon-reload || true
  user_systemctl enable --now pantheme-wallpaper.timer || t timer_failed
}

step_animated() {
  say h_animated
  put config/systemd/user/pantheme-animated.service "$CFG/systemd/user/pantheme-animated.service"
  put config/autostart/pantheme-animated.desktop    "$CFG/autostart/pantheme-animated.desktop"
  user_systemctl daemon-reload || true
  user_systemctl restart pantheme-animated.service || true
}

step_gtk() {
  say h_gtk
  # `pantheme` writes the colors, so it has to be a version that knows this step
  STEP=binaries install_command
  local v f
  for v in gtk-3.0 gtk-4.0; do
    f="$CFG/$v/gtk.css"
    track "$f"
    track "$CFG/$v/pantheme.css"
    mkdir -p "$CFG/$v"
    touch "$f"
    if ! grep -qxF "$GTK_IMPORT" "$f"; then
      # @import has to go before any rule; the user's own CSS stays after it
      { printf '%s\n' "$GTK_IMPORT"; cat "$f"; } > "$TMP/gtk.css"
      cat "$TMP/gtk.css" > "$f"
    fi
  done
  "$BIN/pantheme" "$(cat "$CFG/tema/actual" 2>/dev/null || echo "$INITIAL_THEME")"
  t gtk_restart
}

# ------------------------------------------------------------ uninstall
TRASH="$STATE/removed-$(date +%Y%m%d-%H%M%S)"

# How a recorded path is shown to the user
# shellcheck disable=SC2088  # the ~ is only for display
shown() {
  case "$1" in
    /*) echo "$1" ;;
    *)  echo "~/$1" ;;
  esac
}

# Moves what was installed to $TRASH, and puts the original back if there was one
restore() {  # recorded path: relative to $HOME, or absolute if it is outside
  # A ../ would take it out of $TRASH, maybe to the same place as its backup
  local rel="$1" dst="$1" trashed="${1//..\//up/}"
  case "$rel" in
    /*) ;;
    *)  dst="$HOME/$rel" ;;
  esac
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$TRASH/$(dirname "$trashed")"
    mv "$dst" "$TRASH/$trashed"
  fi
  if [ -e "$STATE/backup/$rel" ] || [ -L "$STATE/backup/$rel" ]; then
    mkdir -p "$(dirname "$dst")"
    mv "$STATE/backup/$rel" "$dst"
    t restored "$(shown "$rel")"
  else
    t removed "$(shown "$rel")"
    # Removes the directories left empty, only below $HOME: the ones outside it
    # (also through ..) aren't in the record and may be the user's
    case "/$rel/" in
      //*|*/../*) ;;
      *)
        local d="$rel"
        while d="$(dirname "$d")"; [ "$d" != . ] && rmdir "$HOME/$d" 2>/dev/null; do :; done
        ;;
    esac
  fi
}

undo_files() {  # step
  [ -f "$MANIFEST" ] || return 0
  local step rel
  # In reverse, so that directories are handled after their contents
  tac "$MANIFEST" | while IFS=$'\t' read -r step rel; do
    if [ "$step" = "$1" ]; then restore "$rel"; fi
  done
  awk -F'\t' -v s="$1" '$1 != s' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
}

undo_keys() {  # step
  [ -f "$GSAVED" ] || return 0
  if ! have gsettings; then
    t no_gsettings
    return 0
  fi
  local step schema key value
  while IFS=$'\t' read -r step schema key value; do
    [ "$step" = "$1" ] || continue
    if gsettings set "$schema" "$key" "$value"; then echo "  gsettings   $schema $key"; fi
  done < "$GSAVED"
  awk -F'\t' -v s="$1" '$1 != s' "$GSAVED" > "$GSAVED.tmp" && mv "$GSAVED.tmp" "$GSAVED"
}

undo_packages() {
  t keep_packages "${PACKAGES[*]:0:5}"
}

undo_ghostty() {
  t keep_ghostty
}

undo_binaries() {
  undo_files binaries
  have fc-cache && fc-cache -f >/dev/null
  return 0
}

undo_shell() {
  [ -f "$HOME/.bashrc" ] || return 0
  grep -qxF "$BASHRC_LINE" "$HOME/.bashrc" || return 0
  mkdir -p "$TRASH"
  cp -a "$HOME/.bashrc" "$TRASH/.bashrc"
  # If nothing was added afterwards, the file ends with the exact block that
  # `step_shell` wrote: those bytes are cut and it is identical to the original
  # (even if it didn't end with a newline, like elementary OS's .bashrc).
  local c n
  for c in "${BASHRC_COMMENTS[@]}"; do
    printf '\n%s\n%s\n' "$c" "$BASHRC_LINE" > "$TMP/block"
    n=$(wc -c < "$TMP/block")
    if tail -c "$n" "$TRASH/.bashrc" | cmp -s - "$TMP/block"; then
      head -c -"$n" "$TRASH/.bashrc" > "$HOME/.bashrc"
      t bashrc_removed "$TRASH/.bashrc"
      return 0
    fi
  done
  # Otherwise, removes our lines and the blank line added before them
  L="$BASHRC_LINE" C="$(printf '%s\n' "${BASHRC_COMMENTS[@]}")" awk '
    BEGIN { n = split(ENVIRON["C"], cs, "\n"); for (i = 1; i <= n; i++) if (cs[i] != "") ours[cs[i]] = 1 }
    $0 == ENVIRON["L"] || ($0 in ours) { blank = 0; next }
    $0 == "" { if (blank) print ""; blank = 1; next }
    { if (blank) print ""; blank = 0; print }
    END { if (blank) print "" }
  ' "$TRASH/.bashrc" > "$HOME/.bashrc"
  t bashrc_removed "$TRASH/.bashrc"
}

undo_theme() {
  undo_files theme
  undo_keys theme
  # Palettes downloaded by `pantheme` (`configs` removes the bundled themes)
  local e f rel
  for e in "$HOME"/.local/share/tema/*; do
    [ -e "$e" ] || continue
    rel="${e#"$HOME"/}"
    if tracked_prefix "$rel/"; then
      # A bundled folder that only adds files (tokyo-night/animado): the
      # downloaded palette next to them goes, the bundled files stay for `configs`
      for f in "$e"/*; do
        [ -e "$f" ] || continue
        rel="${f#"$HOME"/}"
        tracked "$rel" && continue
        mkdir -p "$TRASH/$(dirname "$rel")"
        mv "$f" "$TRASH/$rel"
        t removed "$(shown "$rel")"
      done
      continue
    fi
    mkdir -p "$TRASH/.local/share/tema"
    mv "$e" "$TRASH/$rel"
    t removed "$(shown "$rel")"
  done
  rmdir "$HOME/.local/share/tema" 2>/dev/null || true
  t walls_kept "$(wallpapers_dir)"
}

tracked_prefix() {
  [ -f "$MANIFEST" ] && cut -f2 "$MANIFEST" | awk -v p="$1" 'index($0, p) == 1 { f = 1 } END { exit !f }'
}

# Both the current units and the ones of earlier versions (tema-*)
undo_wallpaper_rotation() {
  user_systemctl disable --now pantheme-wallpaper.timer || true
  user_systemctl disable --now tema-fondo.timer || true
  drop_wants pantheme-wallpaper.timer tema-fondo.timer
  undo_files wallpaper-rotation
  user_systemctl daemon-reload || true
}

undo_animated() {
  user_systemctl stop pantheme-animated.service || true
  user_systemctl stop tema-animado.service || true
  undo_files animated
  user_systemctl daemon-reload || true
}

undo_generic() {  # step
  undo_files "$1"
  undo_keys "$1"
}

uninstall() {
  if [ ! -f "$MANIFEST" ] && [ ! -f "$GSAVED" ]; then
    t nothing_recorded "$STATE"
    if [ -e "$BIN/tema" ] || [ -e "$BIN/pantheme" ]; then t legacy_hint; fi
    exit 1
  fi
  local all=("${DEFAULT[@]}" "${OPTIONAL[@]}") wanted=() i s
  for s in "$@"; do
    s="$(canon "$s")"
    if [ "$s" = all ]; then wanted+=("${all[@]}"); continue; fi
    valid_step "$s"
    wanted+=("$s")
  done
  [ ${#wanted[@]} -eq 0 ] && wanted=("${all[@]}")
  # In the reverse order of installing
  for (( i=${#all[@]}-1; i>=0; i-- )); do
    s="${all[$i]}"
    [[ " ${wanted[*]} " == *" $s "* ]] || continue
    say h_uninstall "$s"
    case "$s" in
      packages|ghostty|binaries|shell|theme|wallpaper-rotation|animated) "undo_${s//-/_}" ;;
      *) undo_generic "$s" ;;
    esac
  done
  if [ -d "$TRASH" ]; then echo; t trash "$TRASH"; fi
  say done_uninstall
}

# ------------------------------------------------------------ main
valid_step() {
  case " ${DEFAULT[*]} ${OPTIONAL[*]} " in
    *" $1 "*) return 0 ;;
  esac
  {
    t unknown_step "$1"
    t step_list "${DEFAULT[*]}" "${OPTIONAL[*]}"
  } >&2
  exit 1
}

case "$(canon "${1:-}")" in
  help) t usage; exit 0 ;;
  uninstall) shift; prepare_record; uninstall "$@"; exit 0 ;;
esac

steps=()
[ $# -eq 0 ] && set -- all
for s in "$@"; do
  s="$(canon "$s")"
  if [ "$s" = all ]; then steps+=("${DEFAULT[@]}"); else valid_step "$s"; steps+=("$s"); fi
done
prepare_record
migrate_tema "${steps[@]}"
for s in "${steps[@]}"; do
  STEP="$s"
  "step_${s//-/_}"
done

say finished
