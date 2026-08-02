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

# gitaw [group] [interval] — live-refreshing gitad, grouped by workspace (-g),
# under a panel showing Claude Code usage and the status-symbol legend.
# Args are order-independent. A purely-integer arg is the refresh interval
# (default 1s); anything else is the group.
# Examples: `gitaw` · `gitaw 2` · `gitaw workspace_homelab` · `gitaw workspace_homelab 2`.
# The frame is rendered by ~/.local/bin/gitaw-panel (stow package `gita`), not
# inlined here: `watch` runs its command via `sh -c`, which can't see zsh
# functions/aliases — which is why this used to carry a copy of gitad's grep.
# -g caveats: a fully-clean workspace still prints its bare "<group>:" header (the
# grep only drops repo lines), and a repo in NO group disappears entirely — so if a
# repo vanishes from here but shows in `gitad`, its group is missing, not the repo.
gitaw() {
  local interval=1 group= a
  for a in "$@"; do [[ $a == <-> ]] && interval=$a || group=$a; done
  watch --color --interval "$interval" "gitaw-panel ${(q)group}"
}

# gitar — rebuild gita's view of ~/src and ~/Projects, in the order they display.
#
# It UNREGISTERS those two roots first, then re-adds them, because `gita add` is
# add-only: it skips paths already in repos.csv ("No new repos found!"), and a
# repo's group is assigned only as a side effect of *adding* it. Without the
# removal pass gitar could neither re-group an already-registered repo nor forget
# one whose directory is gone — it was a pure no-op on an established machine.
#
# Deliberately NOT `gita clear`: that wipes the whole registry, including repos
# living outside these two roots. Only repos whose path is under ~/src or
# ~/Projects are dropped; everything else keeps its registration, its group and
# its position. (Like `gita clear`, this does drop per-repo flags/colors for the
# repos it touches — we set none, so it costs nothing.)
#
# Groups end up in the order they are added, which is groups.csv order, which is
# what `gita ll -g` and `gitaw` print top to bottom:
#   1. okf        — the vault, outside the workspace_* glob
#   2. workspace_*— one group per workspace, nested members included
#   3. src        — ~/src, the live stow clones (dotfiles, workstation-private)
#   4. Projects   — everything else directly in ~/Projects
# Any group from outside these roots keeps its own position, ahead of these four.
#
# ~/src comes after the workspaces because gita derives a repo's NAME from the
# add order: the first repo to claim a basename keeps it, every later one is
# disambiguated as <parent>/<basename>. ~/src and workspace_homelab both hold
# `dotfiles` and `workstation-private`, and the workspace dev clones are the ones
# worth typing — so they are added first and ~/src's copies become
# src/dotfiles and src/workstation-private. Adding okf first costs nothing (no
# name collides with it) and buys the display order outright, which is why there
# is no separate reordering step: gita has no reorder command, so the only way to
# control group order is to add in it.
gitar() {
	local projects="$HOME/Projects" src="$HOME/src"
	# gita's own config-dir resolution (common.get_config_dir), so an overridden
	# GITA_PROJECT_HOME / XDG_CONFIG_HOME is honoured here too.
	local repos_csv="${GITA_PROJECT_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/gita/repos.csv"
	local -a stale
	local -A known
	# NOT `path`: zsh ties that name to $PATH, and `local path` still shadows the
	# special array, so reading repos.csv into it wipes PATH for the rest of the
	# function ("command not found: gita" on the very next line).
	local rpath name rest ws d base

	# `gita rm` takes names from an argparse `choices` list and rejects the WHOLE
	# call on one bad name — and gita drops any repo whose directory is gone from
	# that list while leaving its line in repos.csv (utils.get_repos validates with
	# is_git). Such a ghost is therefore in the file but un-removable by name, so
	# the removal list is intersected with what gita will actually accept. The
	# ghosts still disappear: a successful rm rewrites repos.csv from the
	# validated set. (Real case here: workspace_homelab/whipper.)
	for name in ${=$(gita ls)}; do known[$name]=1; done

	# repos.csv is read directly rather than asking `gita ls <name>` per repo: the
	# path is only exposed one repo at a time, and at ~0.45 s of Python start-up
	# per call that is 20+ seconds for this registry. Read-only, and the format
	# (path,name,type,flags) is what utils.write_to_repo_file emits.
	if [[ -r $repos_csv ]]; then
		while IFS=, read -r rpath name rest; do
			[[ -n ${known[$name]} ]] || continue
			case $rpath in
				($src|$src/*|$projects|$projects/*) stale+=("$name") ;;
			esac
		done < $repos_csv
	fi
	if (( $#stale )); then
		echo "== unregistering ${#stale} repo(s) under ~/src and ~/Projects =="
		# `gita rm` also drops each name from its groups, and a group left with no
		# repos is deleted on write — so no empty "<group>:" headers survive.
		gita rm "${(@)stale}" || return 1
	fi

	# One path per `gita add` call throughout: the multi-path form of -a crashes
	# upstream (auto_group NoneType when handed several parent dirs at once).
	# -a names the group after the path's own basename, which is why src, okf and
	# each workspace get exactly the group name they are called.
	# Order matters twice over: it fixes both the group order and which repo wins
	# a duplicated basename (see header). okf, then the workspaces, then ~/src.
	echo "== $projects/okf =="
	gita add -a "$projects/okf"
	for ws in $projects/workspace_*(N/); do
		echo "== $ws =="
		gita add -a "$ws"
	done
	if [[ -d $src ]]; then
		echo "== $src =="
		gita add -a "$src"
	fi

	# Everything else in ~/Projects, one repo per call into a shared `Projects`
	# group (-g, not -a: -a would give each its own single-repo group). Non-repo
	# directories are reported rather than passed to gita, which would just say
	# "Nothing to add" and leave you guessing which path it meant.
	for d in $projects/*(N/); do
		base=${d:t}
		[[ $base == okf || $base == workspace_* ]] && continue
		if [[ -d $d/.git ]]; then
			echo "== $d =="
			gita add -g Projects "$d"
		else
			echo "== $d — skipped, not a git repo =="
		fi
	done
}

