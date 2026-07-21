# Portable interactive Zsh configuration for remote development servers.

export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
  export ZSH="$HOME/.oh-my-zsh"
elif [[ -d /usr/share/oh-my-zsh ]]; then
  export ZSH="/usr/share/oh-my-zsh"
else
  export ZSH="$HOME/.oh-my-zsh"
fi

ZSH_THEME="ginger"
plugins=(git)

# Keep Oh My Zsh current without prompting, matching the local workstation.
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 13

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz colors && colors
  setopt prompt_subst
  [[ -r "$ZSH_CUSTOM/themes/ginger.zsh-theme" ]] && source "$ZSH_CUSTOM/themes/ginger.zsh-theme"
fi

typeset -U path PATH
path=(
  "$HOME/.local/bin"
  $path
)
export PATH

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
[[ "$TERM" != "dumb" ]] && export COLORTERM="${COLORTERM:-truecolor}"

HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt append_history share_history hist_expire_dups_first hist_ignore_dups hist_reduce_blanks

alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias g='git'
alias v='nvim'

mkcd() {
  mkdir -p -- "$1" && builtin cd -- "$1"
}
