# elementary-setup

Configuración de mi máquina con **elementary OS 8** (Pantheon, X11) para que
se vea y se use parecido a [Omarchy](https://omarchy.org): terminal Ghostty
con Tokyo Night, prompt Starship, herramientas modernas de terminal, un
cambiador de temas y atajos de teclado estilo Omarchy.

Todo es reproducible con `./install.sh`. Registro de cambios en
[BITACORA.md](BITACORA.md).

## Instalación

```bash
git clone https://github.com/sawady/elementary-setup.git ~/elementary-setup
cd ~/elementary-setup
./install.sh            # todo; pide sudo sólo para apt
./install.sh atajos     # o sólo algunos pasos
```

| Paso | Qué hace |
|---|---|
| `paquetes` | apt: btop, eza, bat, fzf, zoxide, python3-pil (+ Ghostty si falta) |
| `binarios` | Starship, fastfetch, lazygit, lazydocker, `tema` y JetBrains Mono Nerd Font en `~/.local` |
| `configs` | Copia las configuraciones de `config/` a `~/.config` (respalda lo existente) |
| `shell` | Agrega a `~/.bashrc` la línea que carga `omarchy-style.sh` |
| `escritorio` | Ghostty en el dock y como terminal por defecto |
| `atajos` | Atajos de teclado estilo Omarchy |
| `zed` | Tema Tokyo Night en Zed (sólo si no existe `settings.json`) |
| `fondos` | Timer de systemd que rota el fondo cada 30 min |
| `tema` | Aplica Tokyo Night con `tema` (descarga paleta y fondos) |

Para registrar cambios hechos a mano en la máquina: `./capturar.sh` y luego
`git diff`.

## Qué incluye

### Terminal
- **Ghostty** como terminal principal: JetBrains Mono Nerd Font 12, padding 14,
  opacidad 0.95. La Terminal de elementary queda con su configuración de fábrica.
- **Starship** con el preset Tokyo Night, con colores tomados de una paleta
  (`[palettes.tema]`) que reescribe `tema`. elementary se muestra con 😎.
- **fastfetch** (`fetch`), **btop** (`top`), **lazygit** (`lg`), **lazydocker** (`lzd`).
- Aliases en `config/bash/omarchy-style.sh`:

| Comando | Qué hace |
|---|---|
| `ls` `ll` `la` `lt` | eza con íconos y git (`lt` = árbol) |
| `cat` | bat con resaltado de sintaxis |
| `Ctrl+R` `Ctrl+T` `Alt+C` | fzf: historial, archivos, directorios |
| `ff` | fzf con vista previa |
| `z <dir>` / `cd` | zoxide |

fzf, lazygit y lazydocker usan colores ANSI, así que siguen el tema de Ghostty.

### Cambiador de temas: `tema`
Usa las paletas (`colors.toml`) y fondos de los 22 temas de Omarchy.

```bash
tema               # tema actual + lista
tema catppuccin    # aplicar (descarga la primera vez)
tema fondo         # siguiente fondo del tema actual
```

Además de los temas de Omarchy hay **temas propios** en `temas/`:

- **`matrix`**: verde fósforo sobre negro, con un tema de Zed propio y un
  **fondo animado** de lluvia de katakana (`temas/matrix/animado`, Python + GTK3
  + cairo, ~7 % de un núcleo a 15 fps). El fondo animado se controla con
  `tema animado on|off`; también se pueden usar las variables `MATRIX_FPS` y `MATRIX_SIZE`.

Un tema propio es una carpeta con `colors.toml` (mismo formato que Omarchy, con
una tabla `[starship]` opcional), `fondos/*.jpg` y, si se quiere, un ejecutable
`animado`. `install.sh configs` los copia a `~/.local/share/tema/`.

Aplica: colores de Ghostty (recarga las ventanas abiertas), paleta de Starship,
btop, tema de Zed (si hay equivalente), fondo de pantalla, acento de Pantheon y
modo claro/oscuro. Fondos en `~/Pictures/Wallpapers/<tema>/`.

### Atajos de teclado (Pantheon)

| Atajo | Acción |
|---|---|
| Super+Enter / Super+T | Ghostty |
| Super+W / Alt+F4 | Cerrar ventana |
| Super+F | Pantalla completa |
| Super+Shift+P | Imagen en imagen |
| Super+1–9 | Ir al escritorio N |
| Super+Shift+1–9 | Mover ventana al escritorio N |
| Super+Alt+1–9 | Abrir app N del dock |
| Super+Shift+B | Navegador |
| Super+Shift+F | Archivos |
| Super+Escape / Super+L | Bloquear pantalla |
| Super+Espacio | Lanzador de apps (sin cambios) |

Deshacer: `./gsettings/atajos.sh --restaurar`.

### Manual (no automatizable)
- **Chrome**: tema Tokyo Night desde la Chrome Web Store (la tienda no se puede
  automatizar), o *Personalizar Chrome* → color `#1a1b26`.
- **Slack**: *Preferencias → Apariencia → tema personalizado*: fondo `#1a1b26`,
  acento `#7aa2f7`, resaltado `#bb9af7`.

## Estructura

```
bin/tema                      cambiador de temas (Python)
temas/<nombre>/               temas propios (colors.toml, animado, fondos)
config/                       archivos que van a ~/.config
gsettings/escritorio.sh       dock, terminal por defecto
gsettings/atajos.sh           atajos (con --restaurar)
install.sh                    instalador por pasos
capturar.sh                   máquina → repo
```

## Notas
- Base: elementary OS 8 (Ubuntu 24.04 noble), X11, Intel Iris Xe + NVIDIA MX450.
- `~/.config/zed/settings.json` **no** se versiona (tiene tokens); sólo el
  fragmento del tema.
- Los fondos no se versionan: son de Omarchy y `tema` los descarga.
