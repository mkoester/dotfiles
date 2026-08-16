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
# Preseeding (skip prompts): export DF_DESKTOP / DF_NIRI / DF_HYPR / DF_DMS / DF_MESSENGERS /
#   DF_QUADLET / DF_ATUIN / DF_NODE / DF_DEV / DF_CADDY / DF_GO / DF_WSL / DF_GITA / DF_FRESH /
#   DF_LESSPIPE / DF_TOPGRADE = 1|0.
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

# ── optional preseeds from the workstation-private repo ──
# Nested sibling of this repo: shared/shell.env holds private-but-not-secret values common to
# every machine (GITLAB_HOST), <hostname>/host.env sets DF_* flags, SSH_AUTH_SOCK, etc.
# Same order as host-env.zsh reads them at shell start, so an install sees what a shell sees —
# they must not diverge, or a question's branch behaves differently under install.sh than the
# environment it is configuring. Sourcing is best-effort; absence is fine.
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
PRIVATE_REPO="$(dirname "$DOTFILES_REPO")/workstation-private"
HOST_DIR="$PRIVATE_REPO/$HOSTNAME_SHORT"
# host.env is also the answer STORE (see save_answers), so sourcing it must not clobber a DF_*
# the caller exported for this one run — snapshot those first and put them back afterwards.
declare -A ENV_PRESEED=()
for _v in $(compgen -v DF_ 2>/dev/null || true); do ENV_PRESEED["$_v"]="${!_v}"; done
if [ -f "$PRIVATE_REPO/shared/shell.env" ]; then
	# shellcheck disable=SC1090
	. "$PRIVATE_REPO/shared/shell.env"
fi
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
	# git-delta was MISSING here until 2026-08-16, and its absence broke git itself: the tracked
	# config-stow/git/.gitconfig sets `pager = delta` unconditionally, so on a Mac every
	# `git diff`/`git log` piped into a binary that does not exist. Not a cosmetic divergence —
	# the config and the package have to arrive together, the same pairing rule as hyprlock's
	# config in the DF_DESKTOP block.
	#
	# sqlite is deliberately NOT here, unlike the three Linux branches: macOS ships a working
	# system sqlite3, and Homebrew's is keg-only (it does not land on PATH), so naming it would
	# install something that changes nothing.
	brew)   pm_install zsh zoxide tmux git git-delta curl wget eza fzf ;;
esac

# THE GNU USERLAND ON macOS — the other half of oh-my-zsh-custom/macos.zsh, which was shipping
# without it. That file puts $HOMEBREW_PREFIX/opt/<f>/libexec/gnubin on PATH for coreutils,
# gnu-tar, gnu-sed, grep, findutils and gawk so that scripts written on the Linux boxes behave.
# None of those formulae was ever installed, so every `[[ -d $d ]]` test in it silently failed
# and the shell kept using the BSD tools — PATH *looked* configured, and `sed -i`, `grep -P` and
# `tar` went on failing in the exact way the comment there describes. Found 2026-08-16.
#
# The two must stay paired: the PATH block is inert without the formulae, and the formulae are
# invisible without the PATH block (Homebrew installs them g-prefixed — gsed, ggrep — precisely
# so they do NOT shadow the system tools).
#
# bash is here for the same reason: macOS still ships 3.2 (2007) at /bin/bash, and the fleet's
# `#!/usr/bin/env bash` convention only reaches a modern one if brew has installed it.
# gnu-getopt is keg-only and ships no gnubin, so macos.zsh puts its plain bin/ on PATH instead.
case "$PM" in
	brew)   pm_install coreutils gnu-tar gnu-sed grep findutils gawk gnu-getopt bash ;;
	*)      : ;;
esac

# TERMINFO FOR THE TERMINALS WE SSH *FROM* — deliberately NOT under DF_DESKTOP.
#
# This is a property of a machine you ssh INTO, so the machines that need it most are exactly
# the ones that answer DF_DESKTOP=0: the Fedora servers and the Pi. Without the entry, a bare
# ssh carries TERM=xterm-ghostty / xterm-kitty to a host that has never heard of it, and the
# remote side fails as `Error opening terminal` / a garbled TUI — which reads as a broken
# program rather than as a missing terminfo.
#
# Availability was checked per distro, not guessed (mdapi.fedoraproject.org, packages.debian.org):
#
#   kitty-terminfo    Arch yes   Fedora yes (noarch)   Debian yes (trixie)
#   ghostty-terminfo  Arch yes   Fedora NO             Debian NO
#
# So ghostty's is Arch-only, the same reasoning as the ghostty binary itself in the DF_DESKTOP
# block — naming it on dnf/apt would fail as "not found" rather than as "no such package
# exists". The Fedora/Debian gap is covered from the CLIENT side instead:
# config-stow/terminals/.config/ghostty/config sets `shell-integration-features = ssh-terminfo`,
# which pushes the description over the connection and `tic`s it into the remote's ~/.terminfo
# on first connect. That needs no package and no root, and covers hosts outside the fleet too —
# so this step is belt-and-braces for the fleet, not the only mechanism.
#
# On Arch both are already HARD dependencies of `ghostty` and `kitty` (`pacman -Si`), so naming
# them here changes nothing on a desktop and is the whole point on a headless box, where
# neither terminal is installed.
#
# brew: skipped. macOS ships an ancient ncurses and neither terminfo has a formula; the Mac is
# an ssh client here, not a target.
case "$PM" in
	pacman) pm_install kitty-terminfo ghostty-terminfo ;;
	apt)    pm_install kitty-terminfo ;;
	dnf)    pm_install kitty-terminfo ;;
	brew)   : ;;
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
# The brew variant's update-os calls `brew cu -y -a`, which is NOT part of Homebrew — it comes
# from the buo/cask-upgrade tap and is what upgrades casks (plain `brew upgrade` leaves most of
# them alone). Without the tap, update-os dies partway through on `Unknown command: cu`, after
# `brew upgrade` has already run, so it looks like a half-finished update rather than a missing
# tap. Printed rather than run: a tap is a persistent choice about where software comes from.
if [ "$PM" = brew ]; then
	info "update-os needs the cask-upgrade tap once on this machine:"
	info "  brew tap buo/cask-upgrade"
fi

# ══════════════════════════════════════════════════════════════════════════
step "6/8  Host-class options"

# Wayland desktop, compositor-agnostic (works under Niri, labwc, …): notifications, kanshi,
# waybar unit, ydotool, terminals, flatpak+Flathub. Niri itself is a SEPARATE question below —
# not every desktop runs it.
# Recorded for the same reason as DF_NIRI_ON/DF_HYPR_ON below: ask_yn returns a STATUS and does
# not assign the variable, so nothing after this block can read $DF_DESKTOP to decide anything.
# The terminal configs are stowed outside the block and need it.
DF_DESKTOP_ON=0

if ask_yn DF_DESKTOP "Wayland desktop (bar, monitor profiles, notifications)?"; then
	DF_DESKTOP_ON=1
	step "  desktop: notifications, kanshi, waybar unit, idle+lock, ydotool, flatpak"
	case "$PM" in
		# hyprlock is the fleet locker (it drives fprintd itself, so the fingerprint works
		# without a keypress). Arch-family only: it is NOT packaged on Debian/arm64, which is
		# why the Pi 500 stays on swaylock — don't add it to the apt branch.
		#
		# ghostty is here because it is the DEFAULT TERMINAL as of 2026-08-10: both
		# hyprland.lua's `term` and niri's MOD+RETURN spawn it by name, and three class-pinned
		# launchers (herdr, the hyprbinds cheat sheet, gitaw) call it explicitly. Without the
		# binary those keybinds do nothing at all, with no error anywhere — the same silent
		# shape as the missing `fzf` noted in the DF_HYPR block. Not added to apt/dnf: ghostty
		# is not in Debian/Fedora's standard repos, so a package name there would be a guess
		# that fails as "not found" rather than as "set up the vendor repo".
		#
		# flatpak is on every branch except brew: it is packaged under that exact name on
		# Arch, Debian and Fedora, so unlike ghostty/hyprlock above there is no guessing.
		pacman) pm_install libnotify kanshi waybar swayidle hyprlock ghostty flatpak ;;
		apt)    pm_install libnotify-bin flatpak ;;
		dnf)    pm_install libnotify flatpak ;;
		brew)   : ;;
	esac
	# The official Flathub remote. Needed because several desktop apps on this fleet have no
	# distro package at all in their current versions — ZapZap (the WhatsApp client) is
	# flatpak-first, and Threema Desktop 2.0 ships from Threema AG's own flatpak repo, which
	# cannot be added until flatpak itself works.
	#
	# SYSTEM remote, not --user. Two reasons: it matches what the fleet already had when this
	# was done by hand, and vendor install instructions (Threema's included) are bare
	# `flatpak install --from …` lines that resolve against the system installation — a --user
	# remote would leave those failing with a confusing "no remote" rather than obviously.
	#
	# --if-not-exists is what makes a re-run a no-op instead of an error, so this is safe on
	# every subsequent install.sh run.
	#
	# The `have` check is NOT redundant with the pm_install above: under --dry-run nothing was
	# actually installed, and without the DRYRUN arm the preview would silently omit this step
	# — a dry run that under-reports what a real run does is worse than no preview.
	if [ "$PM" != brew ] && { have flatpak || [ "$DRYRUN" -eq 1 ]; }; then
		run sudo flatpak remote-add --if-not-exists --system flathub \
			https://dl.flathub.org/repo/flathub.flatpakrepo
	elif [ "$PM" != brew ]; then
		warn "flatpak missing after install — Flathub remote not registered"
	fi
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
	# Terminal emulator configs: ghostty (the default since 2026-08-10), kitty (fallback) and
	# alacritty (previous default, kept working). Tracked since 2026-08-10 — before that all
	# three were hand-made on mkDell and synced nowhere, so any other machine got a terminal
	# with none of the keybinds or the font. Same silent-divergence failure as herdr's config.
	#
	# ONE package for three terminals, deliberately, against this repo's usual one-package-per-
	# tool habit: they are alternatives of the same thing and are kept consistent on purpose
	# (MesloLGS Nerd Font, Nord, the same clipboard keys), so a fallback stays usable. Their
	# configs live in three separate directories, so stow folds them with no conflict.
	#
	# NO `have` GUARD, unlike hyprlock directly above — and the difference is the point. A
	# missing hyprlock config makes hyprlock EXIT rather than lock, so file and binary must
	# arrive together; a config for a terminal that is not installed is simply an inert file.
	# Guarding here would instead mean a machine that later installs kitty silently gets an
	# unconfigured one.
	#
	# THE STOW ITSELF NOW LIVES BELOW THE BLOCK — see "Terminal emulator configs" after the
	# compositor questions. Only this reasoning stayed here, next to the packages it is about.
	#
	# MIDDLE-CLICK PASTE IN GHOSTTY IS THIS GSETTING — it is not a ghostty option.
	#
	# ghostty's GTK apprt drops every middle-click event when this is false
	# (src/apprt/gtk/class/surface.zig:2794 and :2854 at v1.3.1), ABOVE the modifier handling,
	# so plain AND shift+middle are equally dead and nothing is logged anywhere. The glib
	# schema default is false on Arch (GNOME distros ship an override), so it had never worked
	# on this fleet — see the long comment in config-stow/terminals/.config/ghostty/config.
	#
	# Not guarded on `have ghostty`: it is a GTK-wide setting, correct for every GTK app here,
	# and gsettings is part of glib which any Wayland desktop already has.
	#
	# GUARDED ON THE SCHEMA, NOT ON `have gsettings` — the binary existing is not the same
	# claim. brew installs glib as a dependency of plenty, so a Mac can have `gsettings` with
	# no org.gnome.desktop.interface schema (that ships in gsettings-desktop-schemas, a Linux
	# desktop package); `gsettings set` then exits 1, and under `set -euo pipefail` with run()
	# exec'ing directly that ABORTS the installer halfway through step 6. Same for a headless
	# Linux box that has glib but not the desktop schemas.
	#
	# `gsettings writable <schema> <key>` is the discriminating check — verified with both
	# controls: exit 0 when schema and key exist, exit 1 for "No such schema" and exit 1 for
	# "No such key". Output discarded; inside the Claude Code sandbox it also emits harmless
	# dconf-CRITICAL noise about a read-only /run/user, which does not affect the exit code.
	#
	# Read once per ghostty SURFACE init, so it takes effect in new windows/tabs only — the
	# installer says so rather than leaving it looking like the setting failed.
	if have gsettings && gsettings writable org.gnome.desktop.interface gtk-enable-primary-paste >/dev/null 2>&1; then
		run gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true
		info "middle-click paste: applies to NEW ghostty windows/tabs (read once per surface)"
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

# Terminal emulator configs: ghostty (the default since 2026-08-10), kitty (fallback) and
# alacritty (previous default, kept working). The reasoning for the one-package-for-three shape
# and for having no `have` guard is in the DF_DESKTOP block above, next to the packages.
#
# NOT GATED ON DF_DESKTOP — moved out 2026-08-16. That flag means *Wayland* desktop, so a Mac
# answers 0 to it correctly and was silently getting no terminal config at all: no Nerd Font, no
# Nord, none of the clipboard keys, and p10k rendering in fallback glyphs. The same reasoning as
# the terminfo step near the top of this file, which is deliberately outside DF_DESKTOP for the
# mirror-image reason — this is about the machine you SIT AT, which is not the same set as the
# machines running a Wayland compositor.
#
# The `brew` arm is what makes that true rather than just intended; a headless Linux box still
# answers DF_DESKTOP=0 and still gets nothing, which is correct — nobody sits at it.
if [ "$DF_DESKTOP_ON" -eq 1 ] || [ "$PM" = brew ]; then
	stow_pkg "$HOME" terminals
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
	# fzf drives the `hyprbinds` cheat sheet on SUPER+SHIFT+Slash (stowed below as
	# .local/bin/hyprbinds). Without it that keybind opens a terminal that immediately exits
	# with "fzf not installed" — which looks like a broken bind rather than a missing package.
	case "$PM" in
		pacman) pm_install hyprland xdg-desktop-portal-hyprland fzf ;;
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
	# NO Alt+Tab switcher is installed. hyprshell was tried and reverted on 2026-08-15 — it
	# breaks every focus bind while running; the full finding is in hyprland.lua beside the
	# SUPER+Tab unbind. Read that before adding one back.
	info "keybind cheat sheet: SUPER+SHIFT+/ (hyprbinds; reads the live table, so it cannot go stale)."
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

	# settings.json is the ONE exception to the "machine-local and untracked" rule above, and it
	# is deliberate (MK, 2026-08-16: one central config, not per machine). The first two-machine
	# diff found 97.7% of its ~530 keys already identical, so the per-host half is small enough to
	# live in one overlay — which is what shared/dms/{base,laptop}.json are.
	#
	# OVERWRITING WHATEVER THE GUI HOLDS IS THE POINT, not a side effect: the file is written 0444,
	# DMS then reports it read-only and never persists a change, and the previous file is kept as
	# .pre-deploy. Read-only blocks persistence, NOT tuning — the GUI still applies changes live,
	# so experimenting costs nothing and a re-run returns to the baseline. To keep a tweak, use the
	# Settings modal's copy button and paste into base.json.
	#
	# Skipped where the baseline is absent (no workstation-private clone) rather than failing: a
	# machine without the private repo is already handled that way for the kanshi/niri overlays.
	if [ -f "$PRIVATE_REPO/shared/dms/base.json" ]; then
		step "  dms: deploy the shared settings baseline (read-only)"
		run "$DOTFILES_REPO/scripts/dms-settings-deploy"
		# An external edit does NOT apply live — watchChanges reloads what is PARSED, not what is
		# drawn, and the bar's widget lists are not re-rendered (measured 2026-08-16 reordering
		# rightWidgets). So this is a real step, not a courtesy note.
		info "  run 'dms restart' to pick it up — the bar does not reload settings.json live."
	else
		info "  no shared/dms/base.json — skipping the DMS settings baseline."
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

# Messengers. A SEPARATE question from DF_DESKTOP on purpose: the Pi 500 is a desktop machine
# that has no business pulling four Electron/WebEngine apps, and the same split already exists
# for DF_DEV ("writes JS" is not "files issues"). Answer 1 on the personal workstations only.
#
# Signal and Telegram are OFFICIAL native clients and are taken from the distro repo where one
# exists. WhatsApp and Threema have no native Linux client at all:
#   * ZapZap is a WhatsApp Web wrapper — the most actively maintained of several, and Flathub
#     carries a newer version than the AUR (7.4 vs 7.2 as of 2026-08-11), so flatpak even on Arch.
#   * Threema Desktop 2.0 ships from Threema AG's OWN flatpak repo, not Flathub. The `--from`
#     form adds that remote as a side effect, which is why no separate remote-add is needed.
#     It is labelled beta and is still the right choice: the Flathub `ch.threema.threema-web-desktop`
#     is the OLD Threema-Web-in-Electron, in maintenance mode, and needs the phone online.
#
# On apt/dnf ALL FOUR come from Flathub, deliberately: telegram-desktop is packaged there but
# signal-desktop is NOT (Signal ships its own apt repo), and a guessed package name fails as
# "not found" rather than as "add the vendor repo" — the same reasoning as ghostty above.
#
# macOS is the platform where this all gets EASIER, and the branch is genuinely different rather
# than a translation of the Linux one (cask names checked against formulae.brew.sh, 2026-08-11):
#   * WhatsApp has an OFFICIAL native Mac client (`whatsapp`, Meta's own) — the thing that does
#     not exist on Linux at all. No wrapper needed, so no ZapZap here.
#   * Telegram is `telegram`, NOT `telegram-desktop`. Both casks exist: `telegram` is the native
#     Swift app from macos.telegram.org (v12.9), `telegram-desktop` is the same cross-platform Qt
#     build the Linux machines run (v7.0.9). The fleet is deliberately inconsistent on this one.
#   * Threema has NO cask for Desktop 2.0. The `threema` cask is 1.2.50 — the same legacy
#     Threema-Web-in-Electron rejected above — and `threema-desktop`/`threema-beta` do not exist
#     (checked). 2.0 ships as a DMG in separate Intel and Apple Silicon builds, so it is handed
#     over rather than guessed at: a hardcoded vendor URL breaks silently when they reorganise
#     the download page, and installing the legacy app here would put this machine on a
#     different Threema from the rest of the fleet.
if ask_yn DF_MESSENGERS "Messengers (Signal, Telegram, WhatsApp/ZapZap, Threema)?"; then
	if [ "$PM" = brew ]; then
		step "  messengers: signal, telegram, whatsapp (casks); threema by hand"
	else
		step "  messengers: signal, telegram, zapzap (flatpak), threema (flatpak)"
	fi
	case "$PM" in
		pacman) pm_install signal-desktop telegram-desktop ;;
		brew)   run brew install --cask signal telegram whatsapp ;;
	esac
	if [ "$PM" = brew ]; then
		# `uname -m` on the Mac itself, not a guess from the hostname: mkMac2017 is Intel and
		# mkMac2014 was too, but the next Mac on this fleet will not be.
		case "$(uname -m)" in
			arm64) threema_dmg="Apple Silicon" ;;
			*)     threema_dmg="Intel processor" ;;
		esac
		info "Threema: no cask for Desktop 2.0 (the \`threema\` cask is the legacy 1.2.50 web app)."
		info "  Download the \"For macOS ($threema_dmg)\" DMG by hand, checksums are on the page:"
		info "  https://threema.com/en/download/threema-private/desktop-beta"
	elif have flatpak || [ "$DRYRUN" -eq 1 ]; then
		[ "$PM" = pacman ] || run sudo flatpak install -y flathub org.signal.Signal
		[ "$PM" = pacman ] || run sudo flatpak install -y flathub org.telegram.desktop
		run sudo flatpak install -y flathub com.rtosta.zapzap
		# `--from` ERRORS on an already-installed app; the `<remote> <id>` form above only warns.
		# Not a cosmetic difference: under `set -e` the error aborts the whole installer, so every
		# step below this one — through save_answers — silently never runs on a second pass.
		# Verified against flatpak 1.18.1's source, because the two obvious flags do not help:
		# install_from() (app/flatpak-builtins-install.c:217) never consults --or-update, which is
		# handled only in the remote/ref path (:623), and --reinstall suppresses the error by
		# uninstalling and re-downloading the app on every run. Hence an explicit guard. Keeping an
		# installed Threema up to date is topgrade's job, not the installer's.
		if have flatpak && flatpak info ch.threema.threema-desktop >/dev/null 2>&1; then
			info "Threema Desktop already installed — leaving it to topgrade to update."
		else
			run sudo flatpak install -y --from \
				https://releases.threema.ch/flatpak/threema-desktop/ch.threema.threema-desktop.flatpakref
		fi
		# Threema's own documented workaround: the sandbox has no host file access by default,
		# which breaks drag-and-drop of attachments.
		run flatpak override --user ch.threema.threema-desktop --filesystem=host
	else
		warn "flatpak missing — skipping ZapZap and Threema (answer DF_DESKTOP=1, or install flatpak)"
	fi
	# Linux-only: the grid is a Hyprland window-rule + script arrangement, meaningless on macOS.
	if [ "$PM" != brew ]; then
		info "Hyprland users: SUPER+ALT+M opens all four as a 2x2 grid on the \`chat\` workspace."
		info "  Verify the window classes once with: hypr-messengers probe"
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

# Dev machine: the two git-forge CLIs. Its own question rather than part of DF_NODE — "writes
# JavaScript" and "files issues / creates repos" are different machine classes, and the NAS is
# the standing counter-example (Node yes, forge CLIs no).
if ask_yn DF_DEV "Dev machine (gh + glab forge CLIs)?"; then
	case "$PM" in
		pacman) pm_install github-cli glab ;;
		brew)   pm_install gh glab ;;
		# Deliberately no dnf/apt package list: both ship gh and glab through vendor repos that
		# have to be added first, and guessing a package name here would fail as "not found"
		# rather than as "set up the repo".
		*)      info "install gh + glab per their upstream instructions (both need a vendor repo on this distro)." ;;
	esac
	link_omz oh-my-zsh-custom forge.zsh
	# agent-cli.zsh rides on the same flag: a machine that files issues is the machine that runs
	# the AI CLIs. It is a separate file because it owns a separate concern — see its header for
	# why it exists at all (their installers edit the stow-symlinked ~/.zshrc, i.e. this repo).
	link_omz oh-my-zsh-custom agent-cli.zsh

	# Claude Code's OS-level sandbox dependencies. These ride on DF_DEV for the same reason
	# agent-cli.zsh does: a machine that runs the AI CLIs is the machine that needs them.
	#
	# WHY THIS IS INSTALLED RATHER THAN DOCUMENTED: a missing dependency does NOT disable the
	# sandbox loudly — it disables it SILENTLY. `sandbox.enabled: true` in settings.json is
	# accepted, the session runs completely UNSANDBOXED, and the only notice is inside the
	# interactive `/sandbox` view. `claude doctor` reports "No installation issues found".
	# The message lives in the Claude Code binary:
	#   "sandbox is enabled but dependencies are missing: …
	#    install missing tools (e.g. apt install bubblewrap socat)"
	# Measured on mkMac2014 (2026-08-10): bubblewrap present, socat absent, settings.json
	# correctly symlinked with sandbox.enabled true — and every Bash command ran unsandboxed
	# with full write access to $HOME. Nothing anywhere said so.
	#
	# Unlike gh/glab above, both packages are in the standard repos of every distro here, so
	# listing apt/dnf names is safe rather than a guess.
	case "$PM" in
		pacman) pm_install bubblewrap socat ;;
		apt)    pm_install bubblewrap socat ;;
		dnf)    pm_install bubblewrap socat ;;
		# macOS has its own sandbox implementation — bubblewrap is Linux-only and is neither
		# needed nor available. Network filters are installed from inside Claude Code.
		brew)   info "macOS sandbox: run '/sandbox install' inside Claude Code for the network filters." ;;
	esac

	# Verify rather than trust the install: this is the one dependency whose absence is
	# invisible at runtime, so a failed install must not pass quietly.
	for tool in bwrap socat; do
		if have "$tool"; then
			info "sandbox dep ok: $tool"
		elif [ "$PM" != brew ]; then
			warn "$tool MISSING — Claude Code will run UNSANDBOXED despite sandbox.enabled=true."
			warn "  Nothing warns you at runtime; check with /sandbox inside Claude Code."
		fi
	done
	# herdr's config rides on the same flag for the same reason: it is the terminal workspace
	# manager *for* those AI agents. Tracked since 2026-08-10 — it used to be hand-created per
	# machine, so settings silently differed between hosts (mkMac2014 had only
	# `onboarding = false` and still prompted on every new tab). Only config.toml is stowed;
	# session.json / sockets / logs in that directory stay machine-local.
	# herdr itself is NOT installed here: use `paru -S herdr-bin`, never the `herdr` AUR package,
	# which is a source build needing a full Rust+zig toolchain (hours on the 2014 MacBook) for a
	# byte-identical result. See okf practices/herdr.md.
	stow_pkg "$HOME" herdr
	# GITLAB_HOST is private, so it lives in workstation-private (shared/shell.env) and is
	# already in this shell if that repo is cloned — hence reading it rather than printing a
	# hostname into this public repo. Without it, glab defaults to gitlab.com for every
	# out-of-repo call, which fails in a way that looks like an auth problem.
	if [ -n "${GITLAB_HOST:-}" ]; then
		info "log in once per machine (tokens go to the OS keyring, not a config file):"
		info "  gh auth login"
		info "  glab auth login --hostname $GITLAB_HOST   # scope: api"
		info "  glab config set telemetry false -g"
	else
		warn "GITLAB_HOST is unset — glab will default to gitlab.com outside a repo."
		warn "  Set it in workstation-private/shared/shell.env, then open a new shell."
	fi
else
	unlink_omz oh-my-zsh-custom forge.zsh
	unlink_omz oh-my-zsh-custom agent-cli.zsh
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
