#!/usr/bin/env zsh

# agent-cli — shell integration for the AI coding CLIs (Antigravity `agy`, OpenAI `codex`).
# Linked by install.sh's "dev machine?" question (DF_DEV), alongside forge.zsh.
#
# ── why this file exists ──
# These tools ship installers that append `export PATH=…` to ~/.zshrc. That file is a STOW
# SYMLINK into this repo, so the edit lands in a public, six-machine repo rather than in a local
# config — the Antigravity installer's version hardcoded an absolute /home/<user> path and was
# committed by accident (2026-08-07). This file is the sanctioned home for anything those tools
# need, and ~/.zshrc carries a note pointing here.
#
# After running such an installer: `git diff` in the dotfiles clone, and move whatever it added
# into this file — portably, and only if it is actually needed.
#
# ── deliberately empty of PATH handling ──
# The Antigravity line was `export PATH="$HOME/.local/bin:$PATH"`, which is already done by
# .zshrc line 165, guarded and portable. Repeating it here would be redundant on every machine,
# so it is not repeated: reverting the installer's edit was the whole fix. `agy` and a
# user-level `codex` both install into ~/.local/bin and are therefore already on PATH.
#
# Nothing else is set up yet either: `agy` 1.1.11 advertises no completion subcommand (checked
# 2026-08-07). When either tool grows completions, cache them the way forge.zsh caches gh/glab
# rather than eval'ing per shell.
#
# ── claude and codex: UPSTREAM INSTALLERS, not packages (since 2026-11-17) ──
# Both install to ~/.local/bin and have their own updater, so each can be updated on its own,
# without a full system upgrade. The install commands, and the order that keeps the codex
# installer out of ~/.zshrc, are in workstation-private/manifest/README.md.
#
#   agents-update            update every agent installed here
#   agents-update codex      only the named one(s)
#
# Each update runs through the fleet-vault launch guard when it is loaded, so an updater never
# sees the fleet secrets. agy is not covered: it has no update command we know of. Add it to
# _AGENTS_UPDATABLE once one is confirmed with `agy --help`.

typeset -ga _AGENTS_UPDATABLE=(claude codex)
typeset -g _AGENT_CLI_DOTFILES=${${(%):-%x}:A:h:h}

agents-update() {
  local -a todo failed
  local a
  todo=(${@:-$_AGENTS_UPDATABLE})
  for a in $todo; do
    if (( ! ${_AGENTS_UPDATABLE[(Ie)$a]} )); then
      print -u2 "agents-update: unknown agent '$a' (known: $_AGENTS_UPDATABLE)"
      failed+=$a
    elif (( ! $+commands[$a] )); then
      # Not being installed is fine for "update all", but an explicit request has to fail.
      (( $# )) && { print -u2 "agents-update: $a is not installed"; failed+=$a; }
    else
      print -P "%B── $a%b"
      $a update || failed+=$a
    fi
  done
  # Installers may add a line to ~/.zshrc, which is a symlink into this public repo.
  if ! git -C $_AGENT_CLI_DOTFILES diff --quiet -- '.zshrc' '.zprofile' '.bashrc' '.profile' 2>/dev/null; then
    print -u2 "agents-update: a shell rc file in $_AGENT_CLI_DOTFILES changed. Check its git diff and move what is needed into agent-cli.zsh"
  fi
  (( ! $#failed )) || { print -u2 "agents-update: failed: $failed"; return 1; }
}

_agents-update() { compadd -a _AGENTS_UPDATABLE; }
(( $+functions[compdef] )) && compdef _agents-update agents-update
