#!/usr/bin/env bash
# Instalador del setup estilo Omarchy para elementary OS 8.
#
#   ./install.sh              todo (pide sudo sólo para apt)
#   ./install.sh <paso>...    sólo algunos pasos
#
# Pasos: paquetes binarios configs shell escritorio atajos zed fondos tema
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
CFG="$HOME/.config"
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# Descarga el asset de la última release de un repo de GitHub
gh_latest() {  # repo regex salida
  local url
  url=$(curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    python3 -c "import json,sys,re; print([a['browser_download_url'] for a in json.load(sys.stdin)['assets'] if re.search(r'$2', a['name'], re.I)][0])")
  curl -fsSL -o "$3" "$url"
}

paquetes() {
  say "Paquetes de apt"
  sudo apt update
  sudo apt install -y btop eza bat fzf zoxide curl unzip python3-pil
  if ! command -v ghostty >/dev/null; then
    say "Ghostty (paquete .deb de github.com/mkasberg/ghostty-ubuntu)"
    curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh | bash
  fi
}

binarios() {
  say "Binarios en ~/.local/bin (Starship, fastfetch, lazygit, lazydocker)"
  mkdir -p "$BIN"
  gh_latest starship/starship 'starship-x86_64-unknown-linux-musl\.tar\.gz$' "$TMP/starship.tgz"
  tar -xzf "$TMP/starship.tgz" -C "$BIN"
  gh_latest fastfetch-cli/fastfetch 'fastfetch-linux-amd64\.tar\.gz$' "$TMP/ff.tgz"
  tar -xzf "$TMP/ff.tgz" -C "$TMP" && install -m755 "$TMP/fastfetch-linux-amd64/usr/bin/fastfetch" "$BIN/"
  for r in lazygit lazydocker; do
    gh_latest "jesseduffield/$r" '_linux_x86_64\.tar\.gz$' "$TMP/$r.tgz"
    tar -xzf "$TMP/$r.tgz" -C "$TMP" "$r" && install -m755 "$TMP/$r" "$BIN/"
  done
  install -m755 "$REPO/bin/tema" "$BIN/tema"

  say "JetBrains Mono Nerd Font"
  mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
  gh_latest ryanoasis/nerd-fonts '^JetBrainsMono\.tar\.xz$' "$TMP/jbm.tar.xz"
  tar -xf "$TMP/jbm.tar.xz" -C "$HOME/.local/share/fonts/JetBrainsMonoNerd"
  fc-cache -f >/dev/null
}

# Copia un archivo del repo a su destino, respaldando el existente
put() {  # origen-relativo destino
  local src="$REPO/$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")"
    cp -a "$dst" "$BACKUP/${dst#$HOME/}"
  fi
  cp "$src" "$dst"
}

configs() {
  say "Configuraciones (respaldo de lo existente en $BACKUP)"
  put config/ghostty/config                    "$CFG/ghostty/config"
  put config/starship.toml                     "$CFG/starship.toml"
  put config/fastfetch/config.jsonc            "$CFG/fastfetch/config.jsonc"
  put config/bash/omarchy-style.sh             "$CFG/bash/omarchy-style.sh"
  put config/btop/btop.conf                    "$CFG/btop/btop.conf"
  put config/lazygit/config.yml                "$CFG/lazygit/config.yml"
  put config/lazydocker/config.yml             "$CFG/lazydocker/config.yml"
  put config/systemd/user/tema-fondo.service   "$CFG/systemd/user/tema-fondo.service"
  put config/systemd/user/tema-fondo.timer     "$CFG/systemd/user/tema-fondo.timer"
  put config/systemd/user/tema-animado.service "$CFG/systemd/user/tema-animado.service"
  put config/autostart/tema-animado.desktop    "$CFG/autostart/tema-animado.desktop"
  put config/zed/themes/matrix.json            "$CFG/zed/themes/matrix.json"

  # Temas propios (p. ej. matrix): paleta, fondo animado y fondos estáticos
  local t name
  for t in "$REPO"/temas/*/; do
    name="$(basename "$t")"
    put "temas/$name/colors.toml" "$HOME/.local/share/tema/$name/colors.toml"
    if [ -f "$t/animado" ]; then
      put "temas/$name/animado" "$HOME/.local/share/tema/$name/animado"
      chmod +x "$HOME/.local/share/tema/$name/animado"
    fi
    mkdir -p "$HOME/Pictures/Wallpapers/$name"
    cp "$t"/fondos/*.jpg "$HOME/Pictures/Wallpapers/$name/" 2>/dev/null || true
  done
}

shell() {
  say "Cargar omarchy-style.sh desde ~/.bashrc"
  local line='[ -f ~/.config/bash/omarchy-style.sh ] && . ~/.config/bash/omarchy-style.sh'
  if ! grep -qF "$line" "$HOME/.bashrc"; then
    printf '\n# Estilo Omarchy (prompt, aliases, herramientas)\n%s\n' "$line" >> "$HOME/.bashrc"
  fi
}

escritorio() { say "Ajustes de Pantheon"; bash "$REPO/gsettings/escritorio.sh"; }
atajos()     { say "Atajos de teclado"; bash "$REPO/gsettings/atajos.sh"; }

zed() {
  say "Zed"
  local f="$CFG/zed/settings.json"
  if [ ! -f "$f" ]; then
    mkdir -p "$CFG/zed" && sed '/^\/\//d' "$REPO/config/zed/settings.fragment.jsonc" > "$f"
    echo "Creado $f con el tema Tokyo Night."
  else
    echo "Ya existe $f: agrega a mano lo de config/zed/settings.fragment.jsonc"
    echo "(no se sobrescribe para no perder tus ajustes ni tokens)."
  fi
}

fondos() {
  say "Rotación de fondos cada 30 min"
  systemctl --user daemon-reload
  systemctl --user enable --now tema-fondo.timer
}

tema_inicial() { say "Tema inicial"; "$BIN/tema" tokyo-night; }

ALL=(paquetes binarios configs shell escritorio atajos zed fondos tema)
steps=("$@"); [ ${#steps[@]} -eq 0 ] && steps=("${ALL[@]}")
for s in "${steps[@]}"; do
  case "$s" in
    tema) tema_inicial ;;
    paquetes|binarios|configs|shell|escritorio|atajos|zed|fondos) "$s" ;;
    *) echo "Paso desconocido: $s (opciones: ${ALL[*]})"; exit 1 ;;
  esac
done

say "Listo. Abre una ventana nueva de Ghostty (Super+Enter)."
