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
# ── codex: INSTALL FROM THE REPO, NOT THE UPSTREAM INSTALLER (updated 2026-08-10) ──
# This file said "codex is not installed on any machine" until 2026-08-10; it is now on mkDell
# and is being rolled out to mkMac2014, mkDesktop and mkMac2017.
#
# On Arch/CachyOS install it as the package **`openai-codex`** (official `extra`, plus a
# CachyOS-optimised rebuild in `cachyos-extra-v3` — verified with `pacman -Si` on 2026-08-10,
# both at 0.146.1). The command it provides is `codex`.
#
#     paru -S openai-codex
#
# That route matters for the reason this whole file exists: a packaged binary lands on PATH via
# /usr/bin and touches nothing, whereas the npm/curl installers are the kind that append an
# `export PATH=…` line to ~/.zshrc — a stow symlink into this public repo. Prefer the package.
#
# mkMac2017 is back on macOS (DOTFILES_PM=brew), so it needs the brew/npm route instead; the
# ~/.zshrc hazard applies there too, so check `git diff` in this clone afterwards either way.
#
# So this file is currently a no-op by design — it exists to be the place the next such line
# goes, instead of ~/.zshrc.
