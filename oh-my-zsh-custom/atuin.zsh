#!/usr/bin/env zsh

# atuin — magical shell history, synced to my self-hosted server. https://atuin.sh
# Sourced last (oh-my-zsh-custom) so atuin's Up / Ctrl-R bindings win over the plugins that
# loaded earlier (zsh-autosuggestions / syntax-highlighting).
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
  eval "$(atuin init zsh)"
fi
