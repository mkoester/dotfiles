#!/usr/bin/env bash
# install.sh — set up these dotfiles on a fresh machine.
#
# Mirrors the README step-for-step (the README stays the reference / manual fallback).
# Detects the distro, installs the base tools, stows the config packages, sets up
# oh-my-zsh, then asks a few host-class questions to link only the pieces this machine
# needs. Idempotent and re-runnable — safe to run again after editing answers.
#
# Usage:
#   ./install.sh              # interactive
#   ./install.sh --dry-run    # print every command instead of running it (safe preview)
#   ./install.sh --yes        # non-interactive: take defaults + any DF_*/host.env preseeds
#
# Preseeding (skip prompts): export DF_DESKTOP / DF_NIRI / DF_QUADLET / DF_ATUIN / DF_NODE /
#   DF_CADDY / DF_GO / DF_WSL / DF_GITA / DF_FRESH / DF_LESSPIPE / DF_TOPGRADE = 1|0.
#   DF_STOW_BACKUP=1 answers "move conflicting files aside as *.pre-stow-backup?" up front
#   (unset/0 = skip a conflicting stow package instead of touching anything).
#   Override with
#   DOTFILES_PM=pacman|apt|dnf|brew. A per-machine host.env in the workstation-private repo
#   (see below) is sourced automatically and can set all of these.
set -euo pipefail

# ── resolve repo root from this script's own location (no hardcoded paths) ──
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_REPO="$(dirname "$SCRIPT_PATH")"
export DOTFILES_REPO
cd "$DOTFILES_REPO"

DRYRUN=0
ASSUME=0
while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) DRYRUN=1 ;;
		-y|--yes)  ASSUME=1 ;;
		-h|--help)
			awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$SCRIPT_PATH"
			exit 0 ;;
		*) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
	esac
	shift
done

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

# ask_yn VAR "Prompt" — resolve from env VAR if it holds a yes/no; else prompt (default No);
# --yes takes the default without prompting. Returns 0 for yes, 1 for no.
ask_yn() {
	local var="$1" prompt="$2" val="${!1:-}"
	case "$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')" in
		1|y|yes|true)  info "$prompt -> yes (preseed $var)"; return 0 ;;
		0|n|no|false)  info "$prompt -> no  (preseed $var)"; return 1 ;;
	esac
	[ "$ASSUME" -eq 1 ] && return 1
	local ans; read -r -p "    $prompt [y/N] " ans
	case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
		y|yes) return 0 ;; *) return 1 ;;
	esac
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

PM="$(detect_pm)"
if [ -z "$PM" ]; then
	warn "could not detect the package manager."
	read -r -p "    enter one of pacman|apt|dnf|brew: " PM
fi
step "Package manager: $PM"

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

# ── optional per-machine preseeds from the workstation-private repo ──
# Nested sibling of this repo: ../workstation-private/<hostname>/host.env sets DF_* flags,
# SSH_AUTH_SOCK, etc. Sourcing is best-effort; absence is fine.
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
PRIVATE_REPO="$(dirname "$DOTFILES_REPO")/workstation-private"
HOST_DIR="$PRIVATE_REPO/$HOSTNAME_SHORT"
if [ -f "$HOST_DIR/host.env" ]; then
	step "Found host preseeds: $HOST_DIR/host.env"
	# shellcheck disable=SC1090
	. "$HOST_DIR/host.env"
fi

# ── stow helpers ──
# stow_conflicts <target> <package> — relative paths stow would refuse to overwrite, one per
# line. Two message shapes are parsed because they differ by stow version:
#   2.4.x  * cannot stow ../pkgs/x/.foo over existing target .foo since neither a link nor …
#   2.3.x  * existing target is neither a link nor a directory: .foo
# plus (both)  * existing target is not owned by stow: .foo  — a real file, or a symlink some
# other clone owns (e.g. a target already stowed from ~/src/dotfiles).
# `|| true`: stow exits non-zero on conflict and `set -o pipefail` would abort the caller.
stow_conflicts() {
	{ stow --no --verbose -t "$1" -d "$DOTFILES_REPO/config-stow" "$2" 2>&1 >/dev/null || true; } |
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
	if ! stow -t "$target" -d "$DOTFILES_REPO/config-stow" "$pkg"; then
		warn "  stow '$pkg' failed — skipping it; fix the above and re-run ./install.sh"
	fi
}
# link_omz <repo-subdir> <file.zsh> — symlink a catalog file into ~/.<repo-subdir>/
link_omz() {
	run mkdir -p "$HOME/.$1"
	run ln -sf "$DOTFILES_REPO/$1/$2" "$HOME/.$1/"
}
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

# ══════════════════════════════════════════════════════════════════════════
# paru bootstrap runs BEFORE step 1 so that stow is installed *with paru*, not with pacman.
# The fleet rule is that pacman installs nothing but paru itself (OKF practices/development-
# environment.md); bootstrapping after step 1 would quietly make stow a second pacman install.
# Gate on repo availability (`pacman -Si paru`) rather than a distro ID — CachyOS carries paru,
# plain Arch does not, and detect_pm deliberately flattens derivatives into `pacman`.
if [ "$PM" = "pacman" ] && ! have paru; then
	if pacman -Si paru >/dev/null 2>&1; then
		run sudo pacman -S --needed paru
	else
		warn "paru not found and no configured repo provides it (plain Arch?)."
		warn "  build it from the AUR first (see README § arch/paru), then re-run."
		exit 1
	fi
fi

# ══════════════════════════════════════════════════════════════════════════
step "1/8  Install stow"
case "$PM" in
	# paru is the fleet rule for ALL installs. The bootstrap above has already installed or
	# demanded paru, so `have paru` is true here on every machine that gets this far — the
	# pacman fallback is a belt-and-braces branch that should never fire.
	pacman) if have paru; then run paru -S --needed stow; else run sudo pacman -S --needed stow; fi ;;
	# Mirror image on apt: bootstrap nala with bare apt (the one apt call), then use nala for
	# everything after — pm_install picks it up automatically once it is on PATH. `|| true` so a
	# distro that doesn't package nala still installs stow and falls back to apt.
	apt)    run sudo apt install -y nala || true
	        if have nala; then run sudo nala install -y stow; else run sudo apt install -y stow; fi ;;
	dnf)    run sudo dnf install -y stow ;;
	brew)   run brew install stow ;;
esac

# ══════════════════════════════════════════════════════════════════════════
step "2/8  Base tools"
case "$PM" in
	pacman) pm_install zsh zoxide tmux git git-delta curl wget eza sqlite fzf ;;
	apt)    pm_install zsh zoxide tmux git git-delta gitk curl wget eza fzf ;;
	dnf)    pm_install zsh zoxide tmux git git-delta gitk curl wget eza sqlite fzf ;;
	brew)   pm_install zsh zoxide tmux git curl wget eza fzf ;;
esac

# ══════════════════════════════════════════════════════════════════════════
step "3/8  Stow base config (git, vscode)"
stow_pkg "$HOME" git
run mkdir -p "$HOME/.config/Code/User"
stow_pkg "$HOME/.config" vscode
run mkdir -p "$HOME/.var/app/com.visualstudio.code/config/Code/User"
stow_pkg "$HOME/.var/app/com.visualstudio.code/config" vscode

# ══════════════════════════════════════════════════════════════════════════
step "4/8  oh-my-zsh + theme + plugins"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	run_sh 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
else
	info "~/.oh-my-zsh already present — skipping installer"
fi
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
# theme + plugins (clone-if-absent so re-runs don't fail)
clone_if_absent() { [ -d "$2" ] && info "$(basename "$2") present" || run git clone --depth=1 "$1" "$2"; }
clone_if_absent https://github.com/romkatv/powerlevel10k.git             "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
clone_if_absent https://github.com/zsh-users/zsh-autosuggestions          "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
clone_if_absent https://github.com/zsh-users/zsh-syntax-highlighting.git   "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
clone_if_absent https://github.com/MichaelAquilina/zsh-you-should-use.git  "$ZSH_CUSTOM_DIR/plugins/you-should-use"

step "  MesloLGS NF font (p10k glyphs, eza --icons)"
install_nerd_font

# link .zshrc / .p10k.zsh (replays the README "set up oh-my-zsh" block; ln -sf = re-runnable).
run mkdir -p "$HOME/.oh-my-zsh-config"
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then run mv "$HOME/.zshrc" "$HOME/.zshrc-manual-backup"; fi
if [ -f "$HOME/.p10k.zsh" ] && [ ! -L "$HOME/.p10k.zsh" ]; then run mv "$HOME/.p10k.zsh" "$HOME/.p10k-manual-backup.zsh"; fi
run ln -sf "$DOTFILES_REPO/oh-my-zsh-config/you-should-use.zsh" "$HOME/.oh-my-zsh-config/"
run ln -sf "$DOTFILES_REPO/.zshrc" "$HOME/"
run ln -sf "$DOTFILES_REPO/.p10k.zsh" "$HOME/"

# ══════════════════════════════════════════════════════════════════════════
step "5/8  update-os alias for this distro"
case "$PM" in
	pacman) UPDATE_OS=arch ;;
	apt)    UPDATE_OS=apt ;;
	dnf)    UPDATE_OS=dnf ;;
	brew)   UPDATE_OS=brew ;;
esac
run ln -sf "$DOTFILES_REPO/.zshrc-update-os-$UPDATE_OS.zsh" "$HOME/.zshrc-update-os.zsh"

# ══════════════════════════════════════════════════════════════════════════
step "6/8  Host-class options"

# Wayland desktop, compositor-agnostic (works under Niri, labwc, …): notifications, kanshi,
# waybar unit, ydotool. Niri itself is a SEPARATE question below — not every desktop runs it.
if ask_yn DF_DESKTOP "Wayland desktop (bar, monitor profiles, notifications)?"; then
	step "  desktop: notifications, kanshi, waybar unit, idle+lock, ydotool"
	case "$PM" in
		# hyprlock is the fleet locker (it drives fprintd itself, so the fingerprint works
		# without a keypress). Arch-family only: it is NOT packaged on Debian/arm64, which is
		# why the Pi 500 stays on swaylock — don't add it to the apt branch.
		pacman) pm_install libnotify kanshi waybar swayidle hyprlock ;;
		apt)    pm_install libnotify-bin ;;
		dnf)    pm_install libnotify ;;
		brew)   : ;;
	esac
	clone_if_absent https://github.com/MichaelAquilina/zsh-auto-notify.git "$ZSH_CUSTOM_DIR/plugins/auto-notify"
	link_omz oh-my-zsh-plugins-optional auto-notify.zsh
	link_omz oh-my-zsh-custom auto-notify.zsh
	# kanshi + systemd-user (gita-fetch/waybar/ydotool units)
	run mkdir -p "$HOME/.config/kanshi/config.d"
	stow_pkg "$HOME/.config" kanshi
	run mkdir -p "$HOME/.config/systemd/user"
	stow_pkg "$HOME/.config" systemd-user
	# custom xkb keymap (Caps-Lock -> German umlauts): generic + public, activated
	# per-machine in niri's local.kdl (or setxkbmap). Just needs to be on disk.
	stow_pkg "$HOME" xkb
	# hyprlock config. Stowed only where hyprlock exists — a missing config makes hyprlock
	# EXIT rather than lock, so the file and the binary must arrive together.
	if have hyprlock; then
		run mkdir -p "$HOME/.config/hypr"
		stow_pkg "$HOME" hyprlock
	fi
	# per-machine kanshi profiles from workstation-private, if present
	if [ -d "$HOST_DIR/kanshi" ]; then
		run_sh "ln -sf \"$HOST_DIR/kanshi/\"* \"$HOME/.config/kanshi/config.d/\""
	fi
	info "enable the user units yourself once logged into the graphical session:"
	info "  systemctl --user enable --now kanshi.service waybar.service ydotoold.service"
	info "  plus EXACTLY ONE idle unit: swayidle-laptop.service or swayidle-desktop.service"
	info "ydotool needs a /dev/uinput udev rule (root) — see README § niri/ydotool."
fi

# Niri compositor specifically (skip on non-Niri desktops like the Pi 500 / labwc).
if ask_yn DF_NIRI "Niri compositor (tracked niri config + Firefox placement)?"; then
	step "  niri: config.kdl skeleton + place-firefox script"
	case "$PM" in
		pacman) pm_install niri ;;
		*)      info "install niri from its own docs on this distro." ;;
	esac
	run mkdir -p "$HOME/.config/niri" "$HOME/.local/bin"
	stow_pkg "$HOME" niri
	# machine-specific overrides (real output, xkb path, Bluetooth binds) from workstation-private
	if [ -f "$HOST_DIR/niri/local.kdl" ]; then
		run ln -sf "$HOST_DIR/niri/local.kdl" "$HOME/.config/niri/local.kdl"
	fi
	info "niri machine-specific settings go in ~/.config/niri/local.kdl (include'd by config.kdl)."
fi

if ask_yn DF_QUADLET "Quadlet host (Podman services managed as dedicated users)?"; then
	have podman || warn "podman not found — quadlet.zsh helpers need it on this host."
	link_omz oh-my-zsh-custom quadlet.zsh
fi

if ask_yn DF_ATUIN "atuin shell-history sync (self-hosted)?"; then
	case "$PM" in
		# packaged (lands on the system PATH, no ~/.atuin/bin, no shell-rc edit): Arch, Debian 13+
		# trixie (18.x), Homebrew.
		pacman|apt|brew) pm_install atuin ;;
		# fallback installer: --no-modify-path so it can't append to the repo-symlinked ~/.zshrc
		# (~/.atuin/bin is put on PATH by oh-my-zsh-custom/atuin.zsh instead).
		*)               have atuin || run_sh "curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --no-modify-path" ;;
	esac
	link_omz oh-my-zsh-custom atuin.zsh
	run mkdir -p "$HOME/.config/atuin"
	# the config.toml carries the private server address — from workstation-private/shared/
	if [ -f "$PRIVATE_REPO/shared/atuin/config.toml" ]; then
		run ln -sf "$PRIVATE_REPO/shared/atuin/config.toml" "$HOME/.config/atuin/config.toml"
	else
		info "set your server in ~/.config/atuin/config.toml"
		info "  (template: workstation-private/shared/atuin/config.toml)"
	fi
	info "register/login once on this machine, then import + sync:"
	info "  atuin register -u <user> -e <email>   # or: atuin login -u <user>"
	info "  atuin import auto && atuin sync"
fi

if ask_yn DF_NODE "Node machine (fnm + pnpm)?"; then
	case "$PM" in
		pacman) pm_install fnm pnpm ;;
		brew)   pm_install fnm pnpm ;;
		*)      info "install fnm + pnpm per their upstream instructions (no distro package)." ;;
	esac
	link_omz oh-my-zsh-custom fnm.zsh
	link_omz oh-my-zsh-custom pnpm.zsh
fi

if ask_yn DF_TOPGRADE "topgrade (one-shot 'update everything' umbrella)?"; then
	case "$PM" in
		pacman) pm_install topgrade ;;
		brew)   pm_install topgrade ;;
		*)      info "install topgrade per upstream (cargo/prebuilt binary)." ;;
	esac
	stow_pkg "$HOME/.config" topgrade
fi

if ask_yn DF_CADDY "Caddy host (caddy* aliases)?";     then link_omz oh-my-zsh-custom caddy.zsh; fi
if ask_yn DF_GO    "Go machine (omz golang plugin)?";  then link_omz oh-my-zsh-plugins-optional golang.zsh; fi
if ask_yn DF_WSL   "WSL (route ssh through Windows)?"; then link_omz oh-my-zsh-config ssh-wsl.zsh; fi

# nala is the default on apt hosts (installed in step 1), so this is no longer a question —
# it just links the matching aliases + completion. Skipped if nala isn't packaged for the distro.
if [ "$PM" = "apt" ] && have nala; then
	run ln -sf "$DOTFILES_REPO/.zshrc-update-os-nala.zsh" "$HOME/.zshrc-update-os.zsh"
	link_omz oh-my-zsh-custom nala.zsh
fi

if ask_yn DF_GITA "gita multi-repo overview + auto-fetch?"; then
	case "$PM" in
		pacman) pm_install python-pipx ;; dnf) pm_install pipx ;;
		apt)    pm_install pipx ;;         brew) pm_install pipx ;;
	esac
	run pipx install gita
	link_omz oh-my-zsh-custom gita.zsh
	run mkdir -p "$HOME/.config/systemd/user"
	stow_pkg "$HOME/.config" systemd-user
	info "register repos and enable the fetch timer in a fresh shell:"
	info "  gitar && systemctl --user enable --now gita-fetch.timer"
fi

if ask_yn DF_FRESH "fresh terminal editor?"; then
	case "$PM" in
		pacman) pm_install fresh-editor-bin ;;
		brew)   pm_install fresh-editor ;;
		*)      info "install fresh-editor from its releases page or 'cargo install --locked fresh-editor'." ;;
	esac
	link_omz oh-my-zsh-custom fresh.zsh
fi

if ask_yn DF_LESSPIPE "lesspipe (rich less previews)?"; then
	case "$PM" in
		pacman) pm_install 7zip unrar cabextract bat ;;
		apt)    pm_install p7zip-full unrar-free cabextract bat; link_omz oh-my-zsh-custom bat.zsh ;;
		dnf)    pm_install p7zip p7zip-plugins unrar cabextract bat ;;
		brew)   pm_install p7zip unrar cabextract bat ;;
	esac
	link_omz oh-my-zsh-custom lesspipe.zsh
	info "lesspipe itself is a source build — see README § lesspipe (kept manual)."
fi

# ══════════════════════════════════════════════════════════════════════════
step "7/8  Default shell"
ZSH_BIN="$(command -v zsh || true)"
if [ -n "$ZSH_BIN" ] && [ "${SHELL:-}" != "$ZSH_BIN" ]; then
	if [ "$PM" = "brew" ] && ! grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null; then
		run_sh "echo \"$ZSH_BIN\" | sudo tee -a /etc/shells"
	fi
	run chsh -s "$ZSH_BIN"
else
	info "zsh already the login shell (or zsh not found)"
fi

# ══════════════════════════════════════════════════════════════════════════
step "8/8  Done"
info "Open a new shell (or 'exec zsh') to load everything."
[ "$DRYRUN" -eq 1 ] && info "(dry-run — nothing was actually changed)"
