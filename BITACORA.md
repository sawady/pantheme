# Bitácora

Registro de lo que se fue haciendo en la máquina, con la decisión detrás.

## 2026-09-29 — Setup inicial estilo Omarchy

**Contexto:** elementary OS 8 (Pantheon, X11). Objetivo: estética parecida a
Omarchy sin reemplazar el escritorio. Se descartó Hyprland por ahora (no está
en los repos de Ubuntu 24.04 y la GPU es híbrida con NVIDIA).

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
