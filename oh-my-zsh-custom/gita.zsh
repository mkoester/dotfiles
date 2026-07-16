# gita — multi-repo overview helpers (all monitored repos across every workspace)
# Setup (once per machine): pipx install gita; then `gitar` (below) to register
# every workspace's repos plus the okf vault.
# See dotfiles README § "gita multi-repo fetch timer" and
# OKF practices/git-and-workspaces.md § "Multi-repo overview & auto-fetch (gita)".

# gitad [group] — repos with something to report (dirty / ahead / behind).
# No arg = all workspaces; a group name scopes it (e.g. `gitad workspace_homelab`).
# Clean repos render as "[]"; the trailing space anchors on gita's padded status
# column so a commit subject with brackets (e.g. "[Save]") isn't read as a flag.
gitad() { gita ll "$@" | grep -v '\[\] '; }

# gitaw [group] [interval] — live-refreshing gitad, grouped by workspace (-g).
# Args are order-independent. A purely-integer arg is the refresh interval
# (default 1s); anything else is the group.
# Examples: `gitaw` · `gitaw 2` · `gitaw workspace_homelab` · `gitaw workspace_homelab 2`.
# The pipeline is inlined (not calling gitad): `watch` runs its command via `sh -c`,
# which can't see zsh functions/aliases — same reason the grep is duplicated here.
# -g caveats: a fully-clean workspace still prints its bare "<group>:" header (the
# grep only drops repo lines), and a repo in NO group disappears entirely — so if a
# repo vanishes from here but shows in `gitad`, its group is missing, not the repo.
gitaw() {
  local interval=1 group= a
  for a in "$@"; do [[ $a == <-> ]] && interval=$a || group=$a; done
  watch --color --interval "$interval" "gita ll -g $group | grep -v '\\[\\] '"
}

# gitar — register every workspace's NEW repos with gita, one path per call.
# Covers ~/Projects/workspace_*/ plus the okf vault, which sits outside that glob.
# One path per invocation dodges the upstream `gita add -a` multi-path crash
# (auto_group NoneType when handed several parent dirs at once).
#
# Add-only, NOT a repair tool: `gita add -a` skips paths already in repos.csv
# ("No new repos found!"), and a repo's group is assigned as a side effect of
# *adding* it — so gitar can neither re-group an already-registered repo nor
# drop a repo whose directory is gone. To rebuild group state, wipe first:
#   gita clear && gitar
# (gita clear also drops per-repo flags/colors — we set none, so it's free.)
alias gitar='for ws in ~/Projects/workspace_*/ ~/Projects/okf/; do echo "== ${ws} =="; gita add -a "$ws"; done'
