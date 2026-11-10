# Bitácora

Registro de lo que se fue haciendo en la máquina, con la decisión detrás.

## 2026-11-03 — CLI en inglés con alias en castellano (0.1.0)

- **El comando pasa a ser `pantheme`** (`bin/pantheme`): `pantheme <tema>`,
  `pantheme wallpaper`, `pantheme animated on|off`, `pantheme help`. `tema`
  queda como symlink en `~/.local/bin` y acepta `fondo`, `animado` y `ayuda`.
  Decisión de Federico: inglés para el público, sin romper a quien ya lo usa.
- **Pasos en inglés**: `packages ghostty binaries configs shell desktop
  shortcuts theme`, opcionales `zed wallpaper-rotation animated`, más `all`,
  `uninstall` y `help`. Los nombres viejos son alias. Para la rotación de
  fondos se eligió `wallpaper-rotation` y no `wallpapers`, porque el paso no
  descarga fondos (eso lo hace `pantheme`): instala el timer que los rota.
- **Mensajes en inglés, o en castellano si el idioma es castellano**
  (`LC_ALL` > `LC_MESSAGES` > `LANG`, como POSIX). Una tabla chica de
  mensajes en `install.sh` (`msg`) y en `bin/pantheme` (`MSG`), sin gettext.
  Los comentarios del código también pasaron al inglés.
- **Units y autoarranque renombrados** a `pantheme-wallpaper.service/.timer`,
  `pantheme-animated.service` y `pantheme-animated.desktop`. El instalador
  migra una instalación de la época de `tema` en cualquier corrida: para y
  desactiva las units viejas, las saca (al `removed-<fecha>/` del registro),
  instala las nuevas para lo que había, cambia `~/.local/bin/tema` por
  `pantheme` + alias y renombra los pasos del registro. `uninstall` deshace
  también los nombres viejos sin necesidad de migrar.
  - Las rutas de datos **no** se renombraron (`~/.local/share/tema`,
    `~/.config/tema`, `themes/tema` de Ghostty, la paleta `tema` de Starship):
    no se ven en el uso diario y moverlas obligaba a migrar datos del usuario.
- `gsettings/atajos.sh` → `shortcuts.sh` (`--keys`, `--values`, `--reset`, con
  las opciones viejas como alias), `escritorio.sh` → `desktop.sh`,
  `capturar.sh` → `capture.sh`. `PANTHEME_THEME` y `PANTHEME_WALLPAPERS`
  reemplazan a `TEMA_INICIAL` y `TEMA_WALLPAPERS` (que siguen andando).
- Si falla la descarga de un tema, `pantheme` explica lo del límite de la API
  de GitHub en lugar de tirar un traceback.
- Pruebas: el smoke test cubre los nombres nuevos, los alias, los dos idiomas
  y la migración de una instalación de `tema` simulada (migrando o
  desinstalando directo). En la VM, `tests/vm/run.py test` corre todo con los
  comandos nuevos y chequea los mensajes con `LANG=es_AR.UTF-8`; el nuevo
  `tests/vm/run.py migration` instala el último commit con `tema` con su
  propio instalador, corre el nuevo encima y desinstala en castellano.

## 2026-11-02 — Preparación para publicar

- **Nuevo nombre: pantheme** (antes `elementary-setup`). El registro de lo
  instalado pasa a `~/.local/state/pantheme/`; el instalador mueve el viejo
  solo, y al desinstalar también reconoce el comentario viejo de `.bashrc`.

- Licencia MIT, README en inglés (con `README.es.md`) y créditos a Omarchy,
  Starship y las herramientas que se instalan.
- **`install.sh desinstalar [paso...]`**: el instalador registra lo que escribe
  (`~/.local/state/pantheme/manifest`), guarda los originales y el valor
  previo de cada clave de gsettings, y al desinstalar lo repone todo.
- Pasos opcionales: `zed`, `fondos` y `animado` sólo se instalan si se nombran;
  Ghostty pasa a su propio paso.
- `escritorio` ya no reemplaza el dock entero (cambia la Terminal por Ghostty)
  ni toca la fuente de la Terminal de elementary.
- `tema`: usa `omacom/omarchy` (el repo se mudó), respeta la carpeta de imágenes
  de XDG y `$TEMA_WALLPAPERS`, y funciona sin escritorio (para CI).
- CI: shellcheck, py_compile y un smoke test en `ubuntu:24.04` que instala,
  reinstala y desinstala.

 — Setup inicial estilo Omarchy

**Contexto:** elementary OS 8 (Pantheon, X11). Objetivo: estética parecida a
Omarchy sin reemplazar el escritorio. Se descartó Hyprland por ahora (no está
en los repos de Ubuntu 24.04 y hay riesgo con GPUs híbridas).

### Nivel 1: terminal
- Instalados en `~/.local` (sin sudo): JetBrains Mono Nerd Font, Starship, fastfetch.
- apt: btop, eza, bat, fzf, zoxide.
- Ghostty configurado con Tokyo Night. Starship con preset `tokyo-night`.
- Aliases y herramientas en `~/.config/bash/omarchy-style.sh`, cargado desde
  una línea al final de `~/.bashrc` (el resto del `.bashrc` queda igual).
- Símbolo de elementary en Starship: 🍏 → 😎.

**Problema:** la Terminal de elementary se veía con letras muy espaciadas.
Tenía la fuente `JetBrainsMono Nerd Font 10`, pero la ventana estaba abierta
desde antes de instalar la fuente y cargó una fuente proporcional de
reemplazo. **Decisión:** dejar la Terminal de elementary con su configuración
de fábrica y usar Ghostty como terminal principal (dock, Super+T,
`default-applications.terminal`).

### Nivel 2: escritorio
- Fondo: `0-winding-road` del tema Tokyo Night de Omarchy.
- Acento: Blueberry → **Grape** (combina con los fondos morados).
- Modo oscuro: ya estaba activado.
- La fuente monoespaciada del sistema no se tocó, porque la usa la Terminal de elementary.

### Atajos estilo Omarchy
Ver tabla en el README. Ajuste respecto a la propuesta inicial: las apps del
dock pasaron a **Super+Alt+1–9**, porque Super+Shift+1–9 quedó para mover
ventanas entre escritorios.

### Extras
- **Zed:** tema oscuro Ayu Dark → Tokyo Night, más extensiones de temas en `auto_install_extensions`.
- **lazygit** (`lg`) y **lazydocker** (`lzd`) desde releases de GitHub.
- **`tema`:** cambiador de temas basado en los `colors.toml` de Omarchy. Genera los colores para Ghostty, Starship, btop y Zed, y cambia el fondo y el acento.
- Rotación de fondos cada 30 min con un timer de systemd de usuario.
- fzf pasó a colores ANSI para seguir el tema de Ghostty.

### Descartado
- Web apps, tmux/zellij y LazyVim: no interesan.
- Hyprland o i3: quizás más adelante.

## 2026-10-26: Tema Matrix

- **Tema propio `matrix`**: no hay uno así en Omarchy (el más parecido es
  `hackerman`). Paleta verde fósforo (`#00ff41`) sobre `#0d0208`; se mantiene un
  rojo para errores y borrados, para que los diffs se sigan leyendo bien.
- **Fondo animado** con lluvia de katakana espejado, como en la película. Es una
  ventana GTK3 de tipo DESKTOP (debajo de todo, en todos los escritorios, sin
  foco), dibujada con cairo y con los glifos pre-renderizados. Consume ~7 % de un
  núcleo a 15 fps. Lo maneja el servicio `tema-animado.service`, que arranca al
  iniciar sesión (`~/.config/autostart`).
  - Se eligió esto en lugar de xwinwrap o xscreensaver porque no requiere
    paquetes nuevos ni compilar nada.
- Fondo estático de respaldo (`1-lluvia.jpg`) generado con PIL, para la
  pantalla de bloqueo y la vista de escritorios.
- **Zed:** tema propio `Matrix` en `~/.config/zed/themes/matrix.json`.
- **`tema` ahora admite:**
  - temas locales en `~/.local/share/tema/<nombre>/`
  - ajustes por tema de la paleta de Starship (tabla `[starship]`, para tener
    texto oscuro sobre verde)
  - `tema animado on|off`
- **Corregido:** `capturar.sh` se cortaba en silencio si faltaba algún archivo.

## 2026-11-10: Color de las ventanas

- Las ventanas seguían con los grises de elementary (`#333`, `#3a3a3a`)
  aunque el resto fuera Tokyo Night. No hace falta tocar Gala: el fondo lo
  pinta cada app con GTK, y GTK carga `~/.config/gtk-{3,4}.0/gtk.css` después
  del tema.
- El stylesheet de elementary usa casi siempre colores literales (más de 500)
  y pocas reglas usan colores con nombre. Las barras de título
  (`@color_primary`) y las vistas (`@base_color`) sí; el resto (`.background`,
  popovers, menús, barras laterales, listas) se pisa con selectores.
- Reparto de tonos como en los editores con Tokyo Night: el contenido con
  `background`, el marco de la ventana con `dark_background` y las barras de
  título con `darker_background`. El acento no se toca, sigue siendo el de
  Pantheon (grape para Tokyo Night).
- `pantheme` escribe `pantheme.css` sólo si `gtk.css` lo importa, así que sin
  el paso `gtk` no cambia nada. El paso pone el `@import` primero (CSS lo
  exige) y reinstala el comando, porque una versión vieja de `pantheme` no
  sabría escribir los colores.
- Probado en la máquina con Configuración (GTK4) y Code (GTK3). Chrome, Slack
  y las apps Flatpak no leen ese CSS.
