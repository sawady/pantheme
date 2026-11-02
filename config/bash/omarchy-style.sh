# shellcheck shell=bash
# Prompt, aliases y herramientas para bash (inspirado en Omarchy).
# Lo carga una línea al final de ~/.bashrc (./install.sh shell).
# Cada herramienta se activa sólo si está instalada.

# ~/.local/bin (Starship, fastfetch, tema…). Ubuntu's ~/.profile only adds it
# if it already existed at login, which isn't the case right after installing.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH" ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

# Historial más útil
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# ls → eza (con íconos)
if have eza; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lh --icons=auto --group-directories-first --git'
  alias la='eza -lah --icons=auto --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons=auto --git-ignore'
fi

# cat → bat (en Ubuntu el binario se llama batcat)
if have batcat && ! have bat; then alias bat='batcat'; fi
if have bat || have batcat; then
  export BAT_THEME="ansi"
  alias cat='bat --paging=never --style=plain'
fi

# fzf: Ctrl+R historial, Ctrl+T archivos, Alt+C directorios
if have fzf; then
  # Colores ANSI: siguen la paleta de Ghostty, así cambian con `tema`
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=rounded \
    --color=fg:-1,bg:-1,gutter:-1,bg+:black,fg+:bright-white,query:bright-white \
    --color=hl:blue,hl+:bright-blue,border:bright-black,scrollbar:bright-black,info:bright-black \
    --color=prompt:cyan,pointer:magenta,marker:magenta,spinner:magenta,header:yellow,separator:bright-black"
  # shellcheck source=/dev/null
  [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
  alias ff='fzf --preview "batcat --color=always --style=numbers {} 2>/dev/null || cat {}"'
fi

# cd inteligente: `z proyecto` salta al directorio más usado
if have zoxide; then
  eval "$(zoxide init bash)"
  alias cd='z'
fi

# Atajos varios
alias ..='cd ..'
alias ...='cd ../..'
have btop && alias top='btop'
alias fetch='fastfetch'
have lazygit && alias lg='lazygit'
have lazydocker && alias lzd='lazydocker'

# Prompt
if have starship; then
  eval "$(starship init bash)"
fi

unset -f have
