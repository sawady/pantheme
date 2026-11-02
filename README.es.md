# elementary-setup

[English](README.md) · Español

Instalador por pasos para **elementary OS 8** (Pantheon, X11): terminal
moderna, un cambiador de temas de un solo comando y atajos de teclado,
**inspirado en [Omarchy](https://omarchy.org)**, sin reemplazar el escritorio de
elementary.

- Terminal **Ghostty** con JetBrains Mono Nerd Font y prompt **Starship**.
- Herramientas: eza, bat, fzf, zoxide, btop, fastfetch, lazygit, lazydocker.
- **`tema`**: cambia todo el aspecto (terminal, prompt, btop, Zed, fondo,
  acento de Pantheon, claro/oscuro) con un comando, usando las paletas y
  fondos de los temas de Omarchy, más temas propios (como **Matrix**, con fondo
  animado).
- Atajos de teclado al estilo Omarchy (Super+Enter, Super+W, Super+1–9…).
- Todo se puede **deshacer**: `./install.sh desinstalar`.

## Capturas

<!-- TODO(capturas): sacarlas en una VM limpia de elementary OS 8, en docs/screenshots/ -->
Pendientes: escritorio con Tokyo Night, `tema` cambiando a un tema claro,
btop/lazygit siguiendo el tema, y Matrix con el fondo animado (GIF).

## Requisitos

elementary OS 8 en sesión **X11**, x86_64, internet y `sudo` (sólo para apt).

## Instalación

```bash
git clone https://github.com/sawady/elementary-setup.git
cd elementary-setup
./install.sh                    # pasos por defecto
./install.sh todo zed fondos    # por defecto + algunos opcionales
./install.sh atajos             # o sólo algunos pasos
```

| Paso | Qué hace |
|---|---|
| `paquetes` | apt: btop, eza, bat, fzf, zoxide, python3-pil y básicos |
| `ghostty` | Instala Ghostty con [ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu), si falta |
| `binarios` | Starship, fastfetch, lazygit, lazydocker, `tema` y la fuente en `~/.local` |
| `configs` | Copia `config/` a `~/.config` y los temas propios a `~/.local/share/tema` |
| `shell` | Agrega a `~/.bashrc` la línea que carga `omarchy-style.sh` |
| `escritorio` | Ghostty como terminal por defecto y en el dock (en lugar de la Terminal; el resto del dock queda igual) |
| `atajos` | Atajos de teclado |
| `tema` | Aplica Tokyo Night (`TEMA_INICIAL=<tema>` para otro) |

Opcionales (sólo si se nombran): `zed` (tema Matrix y ajustes de Zed),
`fondos` (rotación del fondo cada 30 min con un timer de systemd), `animado`
(fondo animado para los temas que lo tienen, al iniciar sesión).

## Desinstalación

```bash
./install.sh desinstalar              # todo
./install.sh desinstalar atajos zed   # sólo algunos pasos
```

El instalador registra cada archivo que escribe en
`~/.local/state/elementary-setup/manifest`, guarda los originales en
`backup/` y anota el valor previo de cada ajuste de gsettings que cambia. Al
desinstalar repone los originales (o saca lo nuestro, moviéndolo a
`desinstalado-<fecha>/`), quita la línea de `~/.bashrc`, restaura dock,
terminal, atajos, acento, modo y fondo, desactiva el timer y el servicio del
fondo animado, y borra binarios y fuente de `~/.local`.

No se deshace: paquetes de apt y Ghostty (se imprime cómo quitarlos), fondos
descargados y `~/.config/zed/settings.json`. Si instalaste antes de que
existiera el registro, corré `./install.sh` una vez más con los mismos pasos y
después desinstalá.

## `tema`

```bash
tema                 # tema actual + lista
tema catppuccin      # aplicar (lo descarga la primera vez)
tema fondo           # siguiente fondo
tema animado on|off  # fondo animado, si el tema tiene
```

Un tema propio es una carpeta con `colors.toml` (formato de Omarchy, con una
tabla `[starship]` opcional), `fondos/*.jpg` y, si se quiere, un ejecutable
`animado`.

Atajos, alias de terminal, estructura y desarrollo: ver el
[README en inglés](README.md).

## Créditos

No está afiliado a Omarchy, Basecamp ni elementary, Inc. Las paletas y fondos
de [Omarchy](https://github.com/omacom/omarchy) (MIT, David Heinemeier Hansson)
se descargan al usar `tema`; no están en este repo y los **fondos son de sus
autores**. `config/starship.toml` parte del preset Tokyo Night de Starship
(ISC). El tema Matrix y su fondo animado son propios. Detalle en el
[README en inglés](README.md#credits).

## Licencia

[MIT](LICENSE) © Federico A. Sawady O'Connor
