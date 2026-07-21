autoload -Uz colors && colors

if ! typeset -f git_prompt_info >/dev/null; then
  git_prompt_info() {
    local branch

    branch=$(git branch --show-current 2>/dev/null) || return 0
    [[ -n "$branch" ]] || return 0

    printf '%s%s%s' "$ZSH_THEME_GIT_PROMPT_PREFIX" "$branch" "$ZSH_THEME_GIT_PROMPT_SUFFIX"
  }
fi

#PROMPT="%{$fg[blue]%}%m %(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT="%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[blue]%}%m %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[yellow]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[red]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
