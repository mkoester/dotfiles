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
# 2026-08-07) and `codex` is not installed on any machine. When either grows completions, cache
# them the way forge.zsh caches gh/glab rather than eval'ing per shell.
#
# So this file is currently a no-op by design — it exists to be the place the next such line
# goes, instead of ~/.zshrc.
