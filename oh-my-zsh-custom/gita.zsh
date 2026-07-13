# gita — multi-repo overview helpers (all monitored repos across every workspace)
# Setup (once per machine): pipx install gita; then `gitar` (below) to register
# every workspace's repos with gita.
# See dotfiles README § "gita multi-repo fetch timer" and
# OKF practices/git-and-workspaces.md § "Multi-repo overview & auto-fetch (gita)".

# gitad [group] — repos with something to report (dirty / ahead / behind).
# No arg = all workspaces; a group name scopes it (e.g. `gitad workspace_homelab`).
# Clean repos render as "[]"; the trailing space anchors on gita's padded status
# column so a commit subject with brackets (e.g. "[Save]") isn't read as a flag.
gitad() { gita ll "$@" | grep -v '\[\] '; }

# gitaw [group] [interval] — live-refreshing gitad; args are order-independent.
# A purely-integer arg is the refresh interval (default 1s); anything else is the
# group. Examples: `gitaw` · `gitaw 2` · `gitaw workspace_homelab` · `gitaw workspace_homelab 2`.
# The pipeline is inlined (not calling gitad): `watch` runs its command via `sh -c`,
# which can't see zsh functions/aliases — same reason the grep is duplicated here.
gitaw() {
  local interval=1 group= a
  for a in "$@"; do [[ $a == <-> ]] && interval=$a || group=$a; done
  watch --color --interval "$interval" "gita ll $group | grep -v '\\[\\] '"
}

# gitar — (re)register every workspace's repos with gita, one path per call.
# One path per invocation dodges the upstream `gita add -a` multi-path crash
# (auto_group NoneType when handed several parent dirs at once). Idempotent.
alias gitar='for ws in ~/Projects/workspace_*/; do echo "== ${ws} =="; gita add -a "$ws"; done'
