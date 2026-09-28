#!/usr/bin/env zsh

# host-env — load this machine's private per-host environment into interactive shells.
#
# The workstation-private repo's <hostname>/host.env has always been sourced by install.sh to
# preseed its DF_* questions, but nothing sourced it at SHELL time — so `export` lines in it
# (MUSIC_EXPORT_ROOT and friends) silently never took effect. This file closes that gap.
#
# Four files, all optional, sourced in this order so the narrower scope wins:
#   shared/shell.env         tracked  — private but non-secret, identical on every machine
#                                       (GITLAB_HOST and friends)
#   shared/secrets.env       IGNORED  — GENERATED from Vaultwarden by workstation-private's
#                                       scripts/fleet-secrets. Fleet-wide credentials: the
#                                       MAPPING (secrets/manifest.tsv) is tracked, the values
#                                       never are. Before the per-host files, so a host can
#                                       still override one of them.
#   <hostname>/host.env      tracked  — DF_* preseeds + non-secret exports
#   <hostname>/secrets.env   IGNORED  — credentials belonging to THIS machine only (and anything
#                                       not yet migrated into the vault). Never committed.
#
# Keep both POSIX-plain (`NAME=value` / `export NAME=value`, `#` comments): host.env is read by
# bash during install and by zsh here, so anything shell-specific breaks one of the two.
# Sourcing DF_* here is harmless — they become ordinary non-exported shell variables.
#
# Paths are resolved from this file's own location (%x = the file being sourced, :A resolves
# the symlink into the dotfiles clone), so no clone location is hardcoded:
#   …/dotfiles/oh-my-zsh-custom/host-env.zsh  ->  …/workstation-private/<hostname>/
() {
  local self=${${(%):-%x}:A}
  local root=${self:h:h:h}/workstation-private
  local private=$root/${(%):-%m}
  local f
  for f in "$root/shared/shell.env" "$root/shared/secrets.env" \
           "$private/host.env" "$private/secrets.env"; do
    [[ -r $f ]] && source "$f"
  done
  # Every file is optional: a machine with no workstation-private clone (or no dir of its own,
  # or one that has never run `fleet-secrets pull`) must load silently. `return 0` so a failed
  # -r test isn't the file's exit status.
  return 0
}
