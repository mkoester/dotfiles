#!/usr/bin/env bash
# install.sh — set up these dotfiles on a fresh machine.
#
# Mirrors the README step-for-step (the README stays the reference / manual fallback).
# Detects the distro, installs the base tools, stows the config packages, sets up
# oh-my-zsh, then asks a few host-class questions to link only the pieces this machine
# needs. Idempotent and re-runnable — safe to run again after editing answers.
#
# Usage:
#   ./install.sh                # re-use stored answers, ask only what is still unanswered
#   ./install.sh --reconfigure  # ask every question again, ENTER = the stored answer
#   ./install.sh --dry-run      # print every command instead of running it (safe preview)
#   ./install.sh --yes          # non-interactive: take stored answers/preseeds, No for the rest
#
# Answers are REMEMBERED: each host-class question you answer interactively is written back to
#   workstation-private/<hostname>/host.env as DF_<NAME>=1|0, so the next run stops asking and
#   just executes the matching steps. --reconfigure re-asks everything with the stored answer as
#   the default. Values are updated IN PLACE — including a commented-out hint line, which is
#   uncommented and set rather than left behind with a second copy appended below it — so a
#   host.env keeps its own order, grouping and per-key comments. Every host.env ships all DF_*
#   keys, so the append-under-a-marker path only ever fires for a brand-new file.
#   Answering NO also UNLINKS that option's zsh snippet if an earlier run had linked it, so a host
#   that stops being a quadlet/Node/atuin/... machine really stops loading those aliases.
#   (Without a workstation-private clone there is nowhere to save — the run says so and still works.)
#
# Preseeding (skip prompts): export DF_DESKTOP / DF_NIRI / DF_HYPR / DF_DMS / DF_QUADLET /
#   DF_ATUIN / DF_NODE / DF_CADDY / DF_GO / DF_WSL / DF_GITA / DF_FRESH / DF_LESSPIPE /
#   DF_TOPGRADE = 1|0.
#   An exported DF_* beats the stored host.env answer for that one run and is NOT saved, so
#   `DF_NIRI=0 ./install.sh` is a one-off override rather than a decision.
#   DF_STOW_BACKUP=1 answers "move conflicting files aside as *.pre-stow-backup?" up front
#   (unset/0 = skip a conflicting stow package instead of touching anything); it is deliberately
#   never stored — it is a per-conflict call, not a property of the machine.
#   Override with
#   DOTFILES_PM=pacman|apt|dnf|brew. A per-machine host.env in the workstation-private repo
#   (see below) is sourced automatically and can set all of these.
set -euo pipefail

# ── resolve repo root from this script's own location (no hardcoded paths) ──
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_REPO="$(dirname "$SCRIPT_PATH")"
export DOTFILES_REPO
cd "$DOTFILES_REPO"

# Every helper lives in lib.sh so `scripts/test` can source and drive it without running an
# install; this file keeps the 8-step procedure. lib.sh does nothing at source time.
# shellcheck source=lib.sh
. "$DOTFILES_REPO/lib.sh"

DRYRUN=0
ASSUME=0
RECONFIGURE=0
while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) DRYRUN=1 ;;
		-y|--yes)  ASSUME=1 ;;
		--reconfigure) RECONFIGURE=1 ;;
		-h|--help)
			awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$SCRIPT_PATH"
			exit 0 ;;
		*) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
	esac
	shift
done

PM="$(detect_pm)"
if [ -z "$PM" ]; then
	warn "could not detect the package manager."
	read -r -p "    enter one of pacman|apt|dnf|brew: " PM
fi
step "Package manager: $PM"

# ── optional per-machine preseeds from the workstation-private repo ──
# Nested sibling of this repo: ../workstation-private/<hostname>/host.env sets DF_* flags,
# SSH_AUTH_SOCK, etc. Sourcing is best-effort; absence is fine.
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
PRIVATE_REPO="$(dirname "$DOTFILES_REPO")/workstation-private"
HOST_DIR="$PRIVATE_REPO/$HOSTNAME_SHORT"
# host.env is also the answer STORE (see save_answers), so sourcing it must not clobber a DF_*
# the caller exported for this one run — snapshot those first and put them back afterwards.
declare -A ENV_PRESEED=()
for _v in $(compgen -v DF_ 2>/dev/null || true); do ENV_PRESEED["$_v"]="${!_v}"; done
if [ -f "$HOST_DIR/host.env" ]; then
	step "Found host settings: $HOST_DIR/host.env"
	# shellcheck disable=SC1090
	. "$HOST_DIR/host.env"
fi
for _v in "${!ENV_PRESEED[@]}"; do
	[ "${!_v:-}" = "${ENV_PRESEED[$_v]}" ] || info "$_v=${ENV_PRESEED[$_v]} from the environment overrides host.env for this run (not saved)"
	printf -v "$_v" '%s' "${ENV_PRESEED[$_v]}"
done
unset _v


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
# theme + plugins (clone_if_absent lives in lib.sh, so re-runs don't fail)
clone_if_absent https://github.com/romkatv/powerlevel10k.git           "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
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
# host-env.zsh loads workstation-private/<hostname>/{host.env,secrets.env} into every interactive
# shell — the runtime half of the file sourced above, which until now only reached the installer.
# Linked unconditionally and on every host: both files are optional and it no-ops without them.
link_omz oh-my-zsh-custom host-env.zsh
# macos.zsh sets up Homebrew's environment and puts the GNU userland (coreutils, gnu-tar, gnu-sed,
# grep, findutils, gawk) ahead of the BSD one, so scripts written on the Linux boxes behave.
# Linked unconditionally for the same reason as host-env.zsh: it self-guards on $OSTYPE, so on a
# Linux host it costs one [[ ]] test and needs no DF_* flag of its own.
link_omz oh-my-zsh-custom macos.zsh

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
else
	unlink_omz oh-my-zsh-plugins-optional auto-notify.zsh
	unlink_omz oh-my-zsh-custom auto-notify.zsh
fi

# Which compositors this run enabled. ask_yn returns a STATUS and does not assign the variable,
# so the DMS block below cannot read $DF_NIRI/$DF_HYPR to pick its variant — record it here.
# Deliberately not `have niri`/`have Hyprland`: under --dry-run nothing is installed, and the
# preview would then silently choose no variant at all.
DF_NIRI_ON=0
DF_HYPR_ON=0

# Niri compositor specifically (skip on non-Niri desktops like the Pi 500 / labwc).
if ask_yn DF_NIRI "Niri compositor (tracked niri config + Firefox placement)?"; then
	DF_NIRI_ON=1
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

# Hyprland compositor. Independent of DF_NIRI on purpose: a machine may carry both configs and
# pick the session at the greeter, which is exactly how Hyprland gets evaluated without giving
# up a working niri session.
if ask_yn DF_HYPR "Hyprland compositor (tracked hyprland.lua)?"; then
	DF_HYPR_ON=1
	step "  hyprland: hyprland.lua skeleton"
	case "$PM" in
		pacman) pm_install hyprland xdg-desktop-portal-hyprland ;;
		*)      info "install hyprland from its own docs on this distro." ;;
	esac
	# Shared with the hyprlock package (~/.config/hypr): mkdir first so stow does not fold the
	# directory into a single package symlink and then have to unfold it for the second one.
	run mkdir -p "$HOME/.config/hypr"
	stow_pkg "$HOME" hypr
	# machine-specific overrides (real monitor block, xkb path, which shell to spawn)
	if [ -f "$HOST_DIR/hypr/local.lua" ]; then
		run ln -sf "$HOST_DIR/hypr/local.lua" "$HOME/.config/hypr/local.lua"
	fi
	info "validate before logging in:  Hyprland --verify-config -c ~/.config/hypr/hyprland.lua"
	info "hyprland machine-specific settings go in ~/.config/hypr/local.lua (require'd by hyprland.lua)."
fi

# DankMaterialShell (DMS) — the Quickshell-based shell (bar, launcher, notifications, settings,
# polkit agent). Its OWN question rather than part of DF_HYPR: DMS ships a niri variant too, so
# "which shell" and "which compositor" are separate axes, and a machine may run either without
# the other.
#
# Packaging, read off the repos (2026-08-05) rather than assumed: `dms-shell` lives in **extra**,
# not the AUR, and depends on a virtual `dms-shell-compositor`. That is provided by the 0-byte
# metapackages `dms-shell-hyprland` (-> dms-shell + hyprland) and `dms-shell-niri`
# (-> dms-shell + niri). So installing `dms-shell` alone does not resolve — exactly one variant
# must come with it, and both may be installed side by side on a machine carrying both sessions.
if ask_yn DF_DMS "DankMaterialShell (DMS) desktop shell?"; then
	step "  dms: shell + a variant per enabled compositor"
	case "$PM" in
		pacman)
			dms_pkgs=()
			if [ "$DF_HYPR_ON" = 1 ]; then dms_pkgs+=(dms-shell-hyprland); fi
			if [ "$DF_NIRI_ON" = 1 ]; then dms_pkgs+=(dms-shell-niri); fi
			if [ "${#dms_pkgs[@]}" -eq 0 ]; then
				# Not an error worth aborting on, but silence here would leave a machine with
				# a shell answered "yes" and nothing installed, which looks like a broken run.
				warn "DF_DMS is on but neither Niri nor Hyprland was enabled — no dms-shell-<compositor>"
				warn "  variant to install. Enable a compositor and re-run, or set DF_DMS=0."
			else
				pm_install "${dms_pkgs[@]}"
			fi ;;
		*)  info "install DankMaterialShell from its own docs on this distro." ;;
	esac
	# DMS's config fragments are machine-local and UNTRACKED by design (the GUI writes them), so
	# nothing is stowed here — only the directory the Hyprland config require()s from.
	if [ "$DF_HYPR_ON" = 1 ]; then
		run mkdir -p "$HOME/.config/hypr/dms"
		info "deploy the DMS fragments yourself, in a TTY (they prompt for compositor + terminal):"
		info "  dms setup binds && dms setup colors && dms setup layout && dms setup cursor"
		info "  dms setup windowrules && dms setup outputs"
		# Plain `dms setup` writes hyprland.lua itself — which is the tracked stow symlink, so it
		# would either fail or replace the repo's file. Only the per-fragment subcommands are safe.
		info "NOT plain 'dms setup' — it wants to write hyprland.lua, which is a stow symlink."
	fi
	# `dms setup alttab` is niri-only (per `dms setup --help`), so it is mentioned only here.
	if [ "$DF_NIRI_ON" = 1 ]; then
		info "niri also has:  dms setup alttab   (niri-only subcommand)"
	fi

	# CachyOS's Niri and Hyprland editions install NOCTALIA, a second full Quickshell shell —
	# with its own idle daemon, ext-session-lock client and polkit agent, each of which fights
	# the DMS/swayidle ones (three lockouts on mkMac2014, 2026-07-30). Warn only when DMS was
	# chosen: on a machine deliberately running Noctalia there is nothing wrong to report.
	#
	# DETECT AND WARN ONLY — never remove. `cachyos-{hypr,niri}-noctalia` is the edition's whole
	# settings package (it Provides cachyos-desktop-settings and depends on hyprland/niri,
	# xdg-desktop-portal-*, uwsm), so an automated -Rns could uninstall the running compositor,
	# and its dependency list also carries packages this setup uses. Removal needs a human
	# reading pacman's list.
	if [ "$PM" = pacman ] && have pacman; then
		# The `|| true` is LOAD-BEARING, not defensive noise. grep exits 1 when nothing
		# matches; `set -o pipefail` makes that the pipeline's status, the command
		# substitution inherits it, and `set -e` then kills the whole script — SILENTLY,
		# with no message and exit 1 — on precisely the machines that have no Noctalia,
		# i.e. the ones with nothing wrong. Shipped broken and hit on mkMac2017 the same
		# day (2026-08-05), right after Noctalia was removed there. The stub test that
		# was supposed to cover it only counted "noctalia" in the output, and 0 matches
		# reads the same whether the warning was skipped or the script died before it.
		noctalia_pkgs=$(pacman -Qq 2>/dev/null | grep -E '^(noctalia|cachyos-(hypr|niri|mango|jay)-noctalia)$' | tr '\n' ' ' || true)
		if [ -n "$noctalia_pkgs" ]; then
			warn "Noctalia is installed alongside DMS: $noctalia_pkgs"
			warn "  Two shells means two idle daemons, two lock clients and two polkit agents."
			warn "  Remove it BY HAND — mark the shared packages explicit first, or -Rns takes them:"
			warn "    sudo pacman -D --asexplicit brightnessctl grim slurp wl-clipboard qt6ct satty"
			warn "    sudo pacman -Rns cachyos-hypr-noctalia   # then READ the list before confirming"
			warn "  See Workstation-Documentation/hardware/intel-mac-cachyos.md (Noctalia section)."
		fi
	fi
fi

if ask_yn DF_QUADLET "Quadlet host (Podman services managed as dedicated users)?"; then
	have podman || warn "podman not found — quadlet.zsh helpers need it on this host."
	link_omz oh-my-zsh-custom quadlet.zsh
else
	unlink_omz oh-my-zsh-custom quadlet.zsh
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
else
	unlink_omz oh-my-zsh-custom atuin.zsh
fi

if ask_yn DF_NODE "Node machine (fnm + pnpm)?"; then
	case "$PM" in
		pacman) pm_install fnm pnpm ;;
		brew)   pm_install fnm pnpm ;;
		*)      info "install fnm + pnpm per their upstream instructions (no distro package)." ;;
	esac
	link_omz oh-my-zsh-custom fnm.zsh
	link_omz oh-my-zsh-custom pnpm.zsh
else
	unlink_omz oh-my-zsh-custom fnm.zsh
	unlink_omz oh-my-zsh-custom pnpm.zsh
fi

if ask_yn DF_TOPGRADE "topgrade (one-shot 'update everything' umbrella)?"; then
	case "$PM" in
		# -bin: same upstream version, no Rust toolchain to build it (AUR-only either way).
		pacman) pm_install topgrade-bin ;;
		brew)   pm_install topgrade ;;
		*)      info "install topgrade per upstream (cargo/prebuilt binary)." ;;
	esac
	stow_pkg "$HOME/.config" topgrade
fi

if ask_yn DF_CADDY "Caddy host (caddy* aliases)?";     then link_omz oh-my-zsh-custom caddy.zsh
	else unlink_omz oh-my-zsh-custom caddy.zsh; fi
if ask_yn DF_GO    "Go machine (omz golang plugin)?";  then link_omz oh-my-zsh-plugins-optional golang.zsh
	else unlink_omz oh-my-zsh-plugins-optional golang.zsh; fi
if ask_yn DF_WSL   "WSL (route ssh through Windows)?"; then link_omz oh-my-zsh-config ssh-wsl.zsh
	else unlink_omz oh-my-zsh-config ssh-wsl.zsh; fi

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
	# gitaw-panel + gita-legend into ~/.local/bin. gitaw runs the panel through
	# `watch`, i.e. through `sh -c`, so it has to be a real script on PATH rather
	# than a zsh function; gita-legend is shared with okf's herdr-tab-gita.
	run mkdir -p "$HOME/.local/bin"
	stow_pkg "$HOME" gita
	run mkdir -p "$HOME/.config/systemd/user"
	stow_pkg "$HOME/.config" systemd-user
	info "register repos and enable the fetch timer in a fresh shell:"
	info "  gitar && systemctl --user enable --now gita-fetch.timer"
else
	unlink_omz oh-my-zsh-custom gita.zsh
fi

if ask_yn DF_FRESH "fresh terminal editor?"; then
	case "$PM" in
		pacman) pm_install fresh-editor-bin ;;
		brew)   pm_install fresh-editor ;;
		*)      info "install fresh-editor from its releases page or 'cargo install --locked fresh-editor'." ;;
	esac
	link_omz oh-my-zsh-custom fresh.zsh
else
	unlink_omz oh-my-zsh-custom fresh.zsh
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
else
	unlink_omz oh-my-zsh-custom lesspipe.zsh
	unlink_omz oh-my-zsh-custom bat.zsh   # only ever linked by this branch (apt)
fi

# every question has now been asked — persist what was answered interactively
save_answers

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
# Must be an `if`, not `[ … ] && info …`: as the LAST command in the script its status becomes
# the script's, so the `&&` form made a real (non-dry) run exit 1 after doing everything
# correctly. Invisible in testing, because --dry-run is exactly the case that makes it true.
if [ "$DRYRUN" -eq 1 ]; then
	info "(dry-run — nothing was actually changed)"
fi
