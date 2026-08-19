#!/usr/bin/env zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# ~/.oh-my-zsh-config/ — sourced BEFORE oh-my-zsh, for settings it reads as it loads:
# ZSH_DISABLE_COMPFIX, `zstyle ':omz:update'`, per-plugin config. Set after the source below,
# these are too late (compinit and the plugins have already run). Repo dir: oh-my-zsh-config/.
if [ -d "$HOME/.oh-my-zsh-config" ] ; then
    for FILE in `find -L "$HOME/.oh-my-zsh-config" -type f -name "*.zsh"`; source $FILE
fi

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git tmux fzf zoxide zsh-autosuggestions zsh-syntax-highlighting you-should-use)

# ~/.oh-my-zsh-plugins-optional/ — sourced after plugins=() but still BEFORE oh-my-zsh, so a file
# here can append to the plugins array (e.g. `plugins+=(golang)`) and have oh-my-zsh load it.
# Same "before" side as oh-my-zsh-config/; kept apart only to isolate plugin-list edits.
if [ -d "$HOME/.oh-my-zsh-plugins-optional" ] ; then
    for FILE in `find -L "$HOME/.oh-my-zsh-plugins-optional" -type f -name "*.zsh"`; source $FILE
fi

source $ZSH/oh-my-zsh.sh

# User configuration

# Sourced after oh-my-zsh so its aliases win. When the symlink is missing, define stubs that
# explain instead of failing with "command not found" — and don't print at startup, which would
# trip p10k's instant-prompt console-output warning.
if [[ -f ~/.zshrc-update-os.zsh ]]; then
    source ~/.zshrc-update-os.zsh
else
    _dotfiles_no_update_os() {
        print -u2 "[dotfiles] ~/.zshrc-update-os.zsh is missing — no 'update-os' / 's' aliases."
        print -u2 "Link the file for this distro, e.g.:"
        print -u2 "  ln -sf ${DOTFILES_REPO:-$HOME/src/dotfiles}/.zshrc-update-os-arch.zsh ~/.zshrc-update-os.zsh"
        print -u2 "See README: 'Make the alias for os updates available'."
        return 1
    }
    update-os() { _dotfiles_no_update_os }
    s() { _dotfiles_no_update_os }
fi


export DOTFILES_REPO="$(dirname `readlink -f $HOME/.zshrc`)"

export XDG_RUNTIME_DIR=/run/user/$(id -u)

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias ll="eza -hal --git --icons=auto --group-directories-first"
alias lt="eza --tree --level=2 --icons=auto"
alias lr="eza -l --git-repos --no-user --no-time --no-filesize"
alias j="z"
alias nano="nano -c"
alias update-dotfiles="echo -n 'Updating dotfiles repo: ' && git -C ${DOTFILES_REPO:-$HOME/src/dotfiles}/ pull"
# `sys_upgrade` and the five `update-omz-*` aliases were retired 2026-08-19 — topgrade does all
# of it now: `system` = paru -Syu, `shell` = omz update, and the [git] section of
# config-stow/topgrade/topgrade.toml pulls the dotfiles repo plus every $ZSH_CUSTOM plugin/theme.
# So it is `update-os` for the fast daily pass and `topgrade` for the full one. `update-dotfiles`
# stays because it is also useful on its own, without a whole upgrade run.

# Keep $path unique. zsh ties the `path` array to $PATH, and the -U attribute makes it discard a
# duplicate on assignment, keeping the FIRST occurrence — so every prepend below becomes
# idempotent, as does any added later, without each one needing its own membership test.
#
# Without this the prepends accumulate: each is guarded only by "does the directory exist", so a
# nested interactive shell re-adds every entry. Measured 2026-08-07 on mkMac2014 before this
# line: ~/.local/bin appeared THREE times in $PATH, and one more nesting level made it four.
# Harmless for lookup (the first hit wins) but it made `echo $PATH` unreadable.
#
# oh-my-zsh-custom/macos.zsh has carried `typeset -U path` since long before this; it is now
# redundant there but left alone, being macOS-only and untestable from here.
typeset -U path

# The prepends below assign the `path` ARRAY, not the PATH string, and that is load-bearing:
# -U dedupes on array assignment, but a scalar `export PATH="$dir:$PATH"` slips a duplicate
# through even with the attribute set (measured 2026-08-07 — ~/.local/bin still landed twice,
# and re-running `typeset -U path` afterwards collapsed it to one). zsh keeps `path` tied to
# PATH and exported, so nothing needs re-exporting. Same form atuin.zsh already uses.
[[ -d "$HOME/bin" ]]         && path=("$HOME/bin" $path)          # user's private bin
[[ -d "$HOME/.local/bin" ]]  && path=("$HOME/.local/bin" $path)   # pipx, agy, codex, gitaw-panel
[[ -d "$HOME/.cargo/bin" ]]  && path=("$HOME/.cargo/bin" $path)   # Rust binaries
[[ -d "$HOME/go/bin" ]]      && path=("$HOME/go/bin" $path)       # Go binaries

[[ -d /opt/bin ]] && export PATH="/opt/bin:$PATH"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ~/.oh-my-zsh-custom/ — sourced LAST, after oh-my-zsh, so these win over anything it or a plugin
# defined: aliases, functions, PATH. The counterpart to ~/.oh-my-zsh-config/ above; the two exist
# separately only because one runs before oh-my-zsh and the other after. Repo dir: oh-my-zsh-custom/.
if [ -d "$HOME/.oh-my-zsh-custom" ] ; then
    for FILE in `find -L "$HOME/.oh-my-zsh-custom" -type f -name "*.zsh"`; source $FILE
fi

# NOTE for AI-CLI installers (Antigravity, Codex, …): they append a PATH line HERE, and because
# ~/.zshrc is a stow symlink that edit lands in this PUBLIC repo — the Antigravity one hardcoded
# an absolute /home/<user> path. Remove any such line: ~/.local/bin is already on PATH from line
# 165, and oh-my-zsh-custom/agent-cli.zsh (linked by the installer's DF_DEV question) owns
# anything else those tools need. After running one, `git diff` in the dotfiles clone.
