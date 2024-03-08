export PNPM_HOME="~/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Aliases

#taken some aliases from https://github.com/ntnyq/omz-plugin-pnpm/blob/main/pnpm.plugin.zsh
alias p='pnpm'

## Dependencies
alias pa='pnpm add'
alias pad='pnpm add --save-dev'
alias pap='pnpm add --save-peer'
alias prm='pnpm remove'
alias pi='pnpm install'
alias pls='pnpm list'
alias pu='pnpm update'
alias puil='pnpm update --interactive --latest'

## Run scripts
alias pr='pnpm run'
alias pd='pnpm run dev'
alias pb='pnpm run build'
alias plint='pnpm run lint'
alias pfmt='pnpm run format'


###-begin-pnpm-completion-###
if type compdef &>/dev/null; then
  _pnpm_completion () {
    local reply
    local si=$IFS

    IFS=$'\n' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" pnpm completion -- "${words[@]}"))
    IFS=$si

    if [ "$reply" = "__tabtab_complete_files__" ]; then
      _files
    else
      _describe 'values' reply
    fi
  }
  compdef _pnpm_completion pnpm
fi
###-end-pnpm-completion-###
