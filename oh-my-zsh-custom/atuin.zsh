#!/usr/bin/env zsh

# atuin — magical shell history, synced to my self-hosted server. https://atuin.sh
# Sourced last (oh-my-zsh-custom) so atuin's Ctrl-R binding wins over the plugins that
# loaded earlier (zsh-autosuggestions / syntax-highlighting).
#
# --disable-up-arrow: Up stays zsh's own history-substring/line-up, atuin owns Ctrl-R only.
# It is an `atuin init` FLAG, not a config.toml key — there is no way to turn the Up binding
# off from ~/.config/atuin/config.toml, so this line is the only place it can be done
# (`atuin init --help` lists --disable-ctrl-r / --disable-up-arrow / --disable-ai).
#
# Link only where atuin is installed — the installer's "atuin?" question does this, and the
# guard below keeps a shell from breaking if the binary is missing.
#
# The server address is PRIVATE: it lives in ~/.config/atuin/config.toml (`sync_address`),
# supplied per machine from the workstation-private repo — never in this public repo.
# One-time per machine: `atuin register -u <user> -e <email>` (or `atuin login -u <user>`),
# then `atuin import auto && atuin sync`.
# A curl-installed atuin lives in ~/.atuin/bin — we run that installer with --no-modify-path (so it
# never edits this repo's symlinked .zshrc), which means its PATH line is skipped, so add it here.
# Distro packages (apt/pacman/brew) are already on PATH, so this is a harmless no-op for them.
[[ -d "$HOME/.atuin/bin" ]] && path=("$HOME/.atuin/bin" $path)
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"

  # Ctrl-R opens with `!(cd ` already in the query: fuzzy-syntax "doesn't contain (cd", which
  # hides the `(cd ~/repo && ga … && gcmsg …)` commit hand-overs from the list while keeping
  # them in history. Not `!^(cd`: older pastes start with a newline (^J) and would slip past a
  # prefix match. Delete the token to see everything; vicmd `/` stays unfiltered.
  # Needs search_mode = fuzzy (the default). On Esc/Ctrl-C atuin hands back the query, so the
  # token is stripped again and the line returns to what was typed before Ctrl-R.
  _atuin_search_hide_handover() {
    local orig=$BUFFER filter='!(cd '
    BUFFER="$filter$orig"
    "$@"
    [[ $BUFFER == "$filter"* ]] && { BUFFER=$orig; CURSOR=$#BUFFER; }
  }
  _atuin_search_quiet()       { _atuin_search_hide_handover _atuin_search }
  _atuin_search_quiet_viins() { _atuin_search_hide_handover _atuin_search_viins }
  zle -N atuin-search-quiet _atuin_search_quiet
  zle -N atuin-search-quiet-viins _atuin_search_quiet_viins
  bindkey -M emacs '^r' atuin-search-quiet
  bindkey -M viins '^r' atuin-search-quiet-viins
fi
