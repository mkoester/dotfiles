#!/usr/bin/env zsh

# forge — shell integration for the two git-forge CLIs: gh (GitHub) and glab (GitLab).
# https://cli.github.com  ·  https://gitlab.com/gitlab-org/cli
#
# Linked by install.sh's "dev machine?" question (DF_DEV). Guarded like atuin.zsh / fnm.zsh:
# on a distro that packages neither, the installer only PRINTS an install hint, so the link can
# legitimately exist before the binaries do.
#
# ── the private half is NOT here ──
# The self-hosted GitLab's hostname is private and this repo is public, so `GITLAB_HOST` is set
# in the workstation-private repo (shared/shell.env, sourced by host-env.zsh) — never in a
# tracked file here. It matters more than it looks: glab's built-in default is `gitlab.com`
# (`glab config get host`), and glab only picks the host from the git remote when it is run
# INSIDE a repo. Every out-of-repo call — `glab repo create`, `glab api`, `glab issue list -R …`
# — therefore hits gitlab.com unless GITLAB_HOST says otherwise.
#
# Tokens live in the OS keyring, not in a config file, so nothing here reads a credential and a
# non-interactive context (timer, hook, script) has none unless it is given one another way.
# One-time per machine:
#   gh auth login                                  # GitHub
#   glab auth login --hostname "$GITLAB_HOST"      # scope: api  (write_repository is NOT needed,
#                                                  # git runs over SSH)
#   glab config set telemetry false -g             # defaults to ON and phones gitlab.com

# Completions are cached rather than eval'd on every shell start: `gh completion -s zsh` and its
# glab twin each fork a process and cost ~40 ms, which is real latency on every prompt. omz
# already creates $ZSH_CACHE_DIR/completions and prepends it to fpath, so dropping the files
# there is all that is needed.
#
# Regenerated when the cached file is OLDER THAN THE BINARY (-ot), so a package upgrade refreshes
# the completion by itself. A plain [[ -f ]] test would pin the completions of whichever version
# happened to be installed first, and the staleness would be invisible.
() {
  local cache="${ZSH_CACHE_DIR:-$HOME/.cache/zsh}/completions"
  local tool bin comp
  for tool in gh glab; do
    bin=$(command -v $tool) || continue
    comp="$cache/_$tool"
    if [[ ! -f $comp || $comp -ot $bin ]]; then
      [[ -d $cache ]] || command mkdir -p $cache
      # Failure must not abort the shell: a broken/half-installed binary would otherwise leave
      # an empty _gh that never regenerates (it would be newer than the binary from then on).
      if ! $tool completion -s zsh >| "$comp.tmp" 2>/dev/null; then
        command rm -f "$comp.tmp"
        continue
      fi
      command mv -f "$comp.tmp" "$comp"
    fi
  done
  return 0
}
