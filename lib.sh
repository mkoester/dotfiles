# lib.sh — the function library behind install.sh. Sourced, never executed.
#
# Split out of install.sh on 2026-08-03 for ONE reason: these functions are testable and the
# 8-step procedure around them is not. Everything here must therefore stay side-effect-free at
# source time — no installs, no prompts, no writes — so `scripts/test` can source this file,
# stub what it needs, and drive a single function against a fixture. install.sh keeps the
# procedure; if you add a helper, it belongs here.
#
# Globals the functions read (install.sh sets them; the defaults below keep `set -u` happy when
# tests source this file alone): DRYRUN, ASSUME, RECONFIGURE, PM, DOTFILES_REPO, HOST_DIR,
# HOSTNAME_SHORT.
: "${DRYRUN:=0}"
: "${ASSUME:=0}"
: "${RECONFIGURE:=0}"
: "${PM:=}"
: "${DOTFILES_REPO:=}"
: "${HOST_DIR:=}"
: "${HOSTNAME_SHORT:=}"

# ── output + run helpers ──
step() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '\033[1;34m ::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }

# run <cmd...> — a single command, honoring --dry-run.
run() {
	if [ "$DRYRUN" -eq 1 ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}
# run_sh <shell-string> — for the few steps that genuinely need the shell (curl | sh, globs).
run_sh() {
	if [ "$DRYRUN" -eq 1 ]; then printf '    [dry-run] %s\n' "$1"; else bash -c "$1"; fi
}
have() { command -v "$1" >/dev/null 2>&1; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ── host-class answers ──
# Answers given interactively during this run, as "VAR=1"/"VAR=0" — flushed to host.env by
# save_answers() once every question has been asked.
ANSWERS=()
record_answer() {
	# DF_STOW_BACKUP is a per-conflict call ("move THESE files aside?"), not a property of the
	# machine: storing a "no" would silently skip a future package that a future distro skeleton
	# happens to collide with. Deliberately never persisted.
	[ "$1" = DF_STOW_BACKUP ] && return 0
	ANSWERS+=("$1=$2")
}

# ask_yn VAR "Prompt" — returns 0 for yes, 1 for no, and remembers what was answered.
# Resolution order, highest first:
#   1. an exported DF_* for this run (one-off override; ENV_PRESEED, restored after host.env)
#   2. the stored answer in host.env — used without asking, UNLESS --reconfigure
#   3. an interactive prompt, defaulting to the stored answer (so ENTER keeps it), else No
# --yes never prompts: it takes the stored answer, or No where there is none.
ask_yn() {
	local var="$1" prompt="$2" val="${!1:-}" stored='' def hint ans
	case "$(lower "$val")" in
		1|y|yes|true)  stored=1 ;;
		0|n|no|false)  stored=0 ;;
	esac

	# A known answer is executed, not re-asked — that is the point of storing it.
	if [ -n "$stored" ] && [ "$RECONFIGURE" -eq 0 ]; then
		if [ "$stored" = 1 ]; then info "$prompt -> yes (stored $var)"; return 0; fi
		info "$prompt -> no  (stored $var)"; return 1
	fi

	def="${stored:-0}"
	if [ "$ASSUME" -ne 1 ]; then
		hint='[y/N]'; [ "$def" = 1 ] && hint='[Y/n]'
		read -r -p "    $prompt $hint " ans
		case "$(lower "$ans")" in
			y|yes) def=1 ;;
			n|no)  def=0 ;;
			'')    ;;              # ENTER keeps the stored answer
			*)     def=0 ;;
		esac
		record_answer "$var" "$def"
	fi
	[ "$def" = 1 ]
}

ANSWER_MARKER='# ── install.sh answers (re-ask with ./install.sh --reconfigure) ──'

# save_answers — write this run's answers back into host.env, in place. An existing DF_* line is
# updated (trailing comment kept) and, if it is a commented-out hint, UNCOMMENTED — appending a
# live copy under the marker instead would leave two lines for one key, the hint silently losing
# to the one below it. Only a key the file has no line for at all is appended. Bash sources this
# file at install time and zsh at shell start, so keep the lines POSIX-plain and unexported.
save_answers() {
	[ "${#ANSWERS[@]}" -eq 0 ] && return 0
	local f="$HOST_DIR/host.env" entry var val tmp
	if [ "$DRYRUN" -eq 1 ]; then
		printf '    [dry-run] save to %s: %s\n' "$f" "${ANSWERS[*]}"
		return 0
	fi
	if [ ! -d "$HOST_DIR" ]; then
		warn "no $HOST_DIR — answers not saved."
		warn "  clone workstation-private next to this repo (and mkdir $HOSTNAME_SHORT/) to remember them."
		return 0
	fi
	[ -f "$f" ] || printf '# %s — per-machine settings, sourced by install.sh and by every zsh.\n' "$HOSTNAME_SHORT" >"$f"
	for entry in "${ANSWERS[@]}"; do
		var="${entry%%=*}"; val="${entry#*=}"
		if grep -qE "^[[:space:]]*#?[[:space:]]*(export[[:space:]]+)?$var=" "$f"; then
			tmp="$(mktemp)"
			awk -v v="$var" -v n="$val" '
				$0 ~ "^[ \t]*#?[ \t]*(export[ \t]+)?" v "=" {
					match($0, /^[ \t]*/); lead = substr($0, 1, RLENGTH)
					rest = substr($0, RLENGTH + 1)
					# Uncomment a hint line, remembering how many chars the "#" prefix took…
					drop = length(rest); sub(/^#[ \t]*/, "", rest); drop -= length(rest)
					sub(/=[^ \t#]*/, "=" n, rest)
					# …and put them back into the padding, so the comment column holds.
					if (drop > 0 && (h = index(rest, "#")) > 1) {
						pad = sprintf("%" drop "s", "")
						rest = substr(rest, 1, h - 1) pad substr(rest, h)
					}
					$0 = lead rest
				}
				{ print }' "$f" >"$tmp"
			cat "$tmp" >"$f"; rm -f "$tmp"     # rewrite in place: keeps mode/owner and any symlink
		else
			grep -qF "$ANSWER_MARKER" "$f" || printf '\n%s\n' "$ANSWER_MARKER" >>"$f"
			printf '%s=%s\n' "$var" "$val" >>"$f"
		fi
	done
	info "answers saved to $f — re-ask them with ./install.sh --reconfigure"
}

# ── package-manager detection ──
detect_pm() {
	if [ -n "${DOTFILES_PM:-}" ]; then printf '%s' "$DOTFILES_PM"; return; fi
	[ "$(uname -s)" = "Darwin" ] && { printf 'brew'; return; }
	if [ -r /etc/os-release ]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		case " ${ID:-} ${ID_LIKE:-} " in
			*" arch "*)                printf 'pacman'; return ;;
			*" debian "*|*" ubuntu "*) printf 'apt';    return ;;
			*" fedora "*|*" rhel "*)   printf 'dnf';     return ;;
		esac
	fi
	local c; for c in pacman apt dnf brew; do have "$c" && { printf '%s' "$c"; return; }; done
	printf ''
}

# pm_install <pkg...> — install packages with the detected PM (paru ensured first on arch).
pm_install() {
	case "$PM" in
		pacman) run paru -S --needed "$@" ;;
		# nala is the fleet default on apt hosts (it is installed in step 1 below); bare apt is
		# only the fallback for a host where nala isn't available yet or isn't packaged.
		apt)    if have nala; then run sudo nala install -y "$@"; else run sudo apt install -y "$@"; fi ;;
		dnf)    run sudo dnf install -y "$@" ;;
		brew)   run brew install "$@" ;;
	esac
}

# ── stow helpers ──
# STOW_IGNORE — never stow Claude Code's scratch dirs. A `.claude/.cc-writes/` appears inside
# any directory Claude has written to, so editing a tracked file under config-stow leaves one
# next to it. Git never notices (both dirs are empty, and git does not track empty dirs), so a
# fresh clone is clean and this looks like a non-problem — but stow works on the filesystem and
# happily symlinks it into the target, e.g. ~/.config/xkb/.claude -> the repo. Passed to every
# stow call below rather than dropping a .stow-local-ignore into each package, since the next
# package to be Claude-edited would silently miss it.
# NB --ignore REPLACES stow's default ignore list; nothing in this repo relies on the defaults.
# Do NOT add ^…$ anchors: stow anchors the pattern itself, and '^\.claude$' silently matches
# nothing (measured — it still linked ~/.local/bin/.claude, while '\.claude' does not).
STOW_IGNORE='\.claude'

# stow_conflicts <target> <package> — relative paths stow would refuse to overwrite, one per
# line. Two message shapes are parsed because they differ by stow version:
#   2.4.x  * cannot stow ../pkgs/x/.foo over existing target .foo since neither a link nor …
#   2.3.x  * existing target is neither a link nor a directory: .foo
# plus (both)  * existing target is not owned by stow: .foo  — a real file, or a symlink some
# other clone owns (e.g. a target already stowed from ~/src/dotfiles).
# `|| true`: stow exits non-zero on conflict and `set -o pipefail` would abort the caller.
stow_conflicts() {
	{ stow --ignore="$STOW_IGNORE" --no --verbose -t "$1" -d "$DOTFILES_REPO/config-stow" "$2" 2>&1 >/dev/null || true; } |
		sed -n \
			-e 's/^ *\* cannot stow .* over existing target \(.*\) since .*$/\1/p' \
			-e 's/^ *\* existing target is not owned by stow: //p' \
			-e 's/^ *\* existing target is neither a link nor a directory: //p'
}

# stow_pkg <target> <package>
# stow refuses a whole package when any of its targets already exists as a real file (or as a
# foreign symlink) — and under `set -e` that aborts the installer mid-run, skipping the steps
# that would have worked. A fresh machine hits this routinely: distro skeletons ship their own
# rc files, and CachyOS's Niri edition installs an unowned ~/.config/niri/config.kdl via
# /etc/skel. So: simulate first, show exactly what is in the way (with symlink targets, so an
# already-stowed file from another clone is recognizable), and offer to move it aside as
# <file>.pre-stow-backup. Declining skips just this package and the run continues.
# Never `stow --adopt` — it pulls the local file's content INTO the repo, overwriting what is
# tracked (README § "Stow the config files").
stow_pkg() {
	local target="$1" pkg="$2" conflicts f
	run mkdir -p "$target"
	if [ "$DRYRUN" -eq 1 ]; then
		printf '    [dry-run] stow -t %s -d %s %s\n' "$target" "$DOTFILES_REPO/config-stow" "$pkg"
		conflicts="$(stow_conflicts "$target" "$pkg")"
		[ -n "$conflicts" ] && warn "would conflict in $target: $(printf '%s ' $conflicts)"
		return 0
	fi

	conflicts="$(stow_conflicts "$target" "$pkg")"
	if [ -n "$conflicts" ]; then
		warn "stow package '$pkg' conflicts with existing files under $target:"
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			ls -ld -- "$target/$f" 2>/dev/null | sed 's/^/      /' >&2 || printf '      %s\n' "$f" >&2
		done <<<"$conflicts"
		if ask_yn DF_STOW_BACKUP "move them aside as *.pre-stow-backup and stow '$pkg'?"; then
			while IFS= read -r f; do
				[ -n "$f" ] || continue
				run mv -v -- "$target/$f" "$target/$f.pre-stow-backup"
			done <<<"$conflicts"
		else
			warn "  skipping package '$pkg' — resolve by hand, then re-run ./install.sh"
			return 0
		fi
	fi

	# Belt-and-braces: a conflict shape the parser missed must not kill the whole run either.
	if ! stow --ignore="$STOW_IGNORE" -t "$target" -d "$DOTFILES_REPO/config-stow" "$pkg"; then
		warn "  stow '$pkg' failed — skipping it; fix the above and re-run ./install.sh"
	fi
}

# ── oh-my-zsh catalog links ──
# link_omz <repo-subdir> <file.zsh> — symlink a catalog file into ~/.<repo-subdir>/
link_omz() {
	run mkdir -p "$HOME/.$1"
	run ln -sf "$DOTFILES_REPO/$1/$2" "$HOME/.$1/"
}
# unlink_omz <repo-subdir> <file.zsh> — the inverse of link_omz. Answering "no" to a host-class
# question has to UNDO its shell integration, not merely skip it: a machine that used to be a
# quadlet/Node/atuin host otherwise keeps sourcing those aliases forever, and re-running with
# --reconfigure would look like it had no effect. Only a symlink pointing back into THIS repo is
# removed — a real file, or a link some other clone owns, is reported and left alone.
unlink_omz() {
	local link="$HOME/.$1/$2" target
	[ -L "$link" ] || { [ -e "$link" ] && warn "$link is a real file, not a link from this repo — leaving it."; return 0; }
	target="$(readlink -f "$link" 2>/dev/null || true)"
	case "$target" in
		"$DOTFILES_REPO"/*) run rm -vf "$link" ;;
		*) warn "$link points at ${target:-a missing target} (not this repo) — leaving it." ;;
	esac
}

# clone_if_absent <url> <dir> — re-runnable git clone for the omz theme/plugins.
clone_if_absent() { [ -d "$2" ] && info "$(basename "$2") present" || run git clone --depth=1 "$1" "$2"; }

# install_nerd_font — MesloLGS NF, the font p10k's glyphs (and `eza --icons`) need. Packaged on
# Arch/macOS; elsewhere download p10k's four styles into the SYSTEM font dir so every user on the
# machine gets them. (The terminal emulator still has to be pointed at "MesloLGS NF" by hand — that
# can't be scripted.)
install_nerd_font() {
	case "$PM" in
		pacman) pm_install ttf-meslo-nerd ;;
		brew)   run brew install --cask font-meslo-lg-nerd-font ;;
		*)      local base='https://github.com/romkatv/powerlevel10k-media/raw/master' style
		        run sudo mkdir -p /usr/local/share/fonts
		        for style in Regular Bold Italic "Bold%20Italic"; do
		            run sudo wget -q -P /usr/local/share/fonts "$base/MesloLGS%20NF%20$style.ttf"
		        done
		        run sudo fc-cache -f ;;
	esac
}
