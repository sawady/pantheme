# shellcheck shell=bash
# Prompt, aliases and tools for bash (inspired by Omarchy).
# Loaded by a line at the end of ~/.bashrc (./install.sh shell).
# Each tool is only set up if it is installed.

# ~/.local/bin (Starship, fastfetch, pantheme…). Ubuntu's ~/.profile only adds it
# if it already existed at login, which isn't the case right after installing.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH" ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

# More useful history
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# ls → eza (with icons)
if have eza; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lh --icons=auto --group-directories-first --git'
  alias la='eza -lah --icons=auto --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons=auto --git-ignore'
fi

# cat → bat (on Ubuntu the binary is called batcat)
if have batcat && ! have bat; then alias bat='batcat'; fi
if have bat || have batcat; then
  export BAT_THEME="ansi"
  alias cat='bat --paging=never --style=plain'
fi

# fzf: Ctrl+R history, Ctrl+T files, Alt+C directories
if have fzf; then
  # ANSI colors: they follow Ghostty's palette, so they change with `pantheme`
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=rounded \
    --color=fg:-1,bg:-1,gutter:-1,bg+:black,fg+:bright-white,query:bright-white \
    --color=hl:blue,hl+:bright-blue,border:bright-black,scrollbar:bright-black,info:bright-black \
    --color=prompt:cyan,pointer:magenta,marker:magenta,spinner:magenta,header:yellow,separator:bright-black"
  # shellcheck source=/dev/null
  [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
  alias ff='fzf --preview "batcat --color=always --style=numbers {} 2>/dev/null || cat {}"'
fi

# Smarter cd: `z project` jumps to the most used matching directory
if have zoxide; then
  eval "$(zoxide init bash)"
  alias cd='z'
fi

# Shortcuts
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
