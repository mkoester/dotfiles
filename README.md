# dotfiles

My cross-machine shell + tool configuration, deployed with [GNU stow](https://www.gnu.org/software/stow/).
Packages under `config-stow/<pkg>/` symlink into place; the oh-my-zsh material is linked from
the top-level `oh-my-zsh-*` directories. Works across Arch, Debian, Fedora and macOS.

**This repo is public.** Machine- and device-specific data (monitor serials, Bluetooth MACs,
hostnames) must never be committed here — it lives in the private overlay repo and is pulled in
via gitignored `include`s (see [kanshi](#kanshi--monitor-profiles) and [niri](#niri--wayland-compositor)).

## Quick start — `./install.sh`

On a fresh machine, clone to the permanent location, then run the installer:

```sh
mkdir -p "$HOME/src" && git clone https://github.com/mkoester/dotfiles.git "$HOME/src/dotfiles"
cd "$HOME/src/dotfiles" && ./install.sh
```

It detects your distro, installs the base tools, stows the config, sets up oh-my-zsh, and asks a
few host-class questions (Wayland desktop? Niri? Quadlet host? Node? Caddy? …) to link only what
this machine needs. Niri is its own question, so a desktop that doesn't run it (e.g. a Pi on
labwc) is fine. It's **idempotent** — safe to re-run. Preview everything first with:

```sh
./install.sh --dry-run     # print every command instead of running it
./install.sh --yes         # non-interactive: take defaults + any preseeds
```

Preseed the questions with `DF_DESKTOP`/`DF_QUADLET`/`DF_NODE`/… = `1`/`0`, or drop a `host.env`
in the private repo (`./install.sh --help` lists them all). Everything below is the **manual
reference** the installer automates — read it when a step needs doing by hand.

---

> **Per-distro commands.** Each install step below is given for **Arch** (`paru`), **Debian**
> (`apt`), **Fedora** (`dnf`) and **macOS** (`brew`). Pick the one for your system. "Arch" covers
> CachyOS/EndeavourOS/Manjaro; "Debian" covers Ubuntu/Mint; "Fedora" covers RHEL clones.

## Clone this repository

**Clone location is permanent.** `stow` symlinks point back into the clone, so wherever this
lands is where `~/.gitconfig` and friends resolve to forever. `~/src/dotfiles` is the canonical
spot — do this first, before installing or running stow.

```sh
mkdir -p $HOME/src && git clone https://github.com/mkoester/dotfiles.git $HOME/src/dotfiles
```

or via `ssh`

```sh
mkdir -p $HOME/src && git clone git@github.com:mkoester/dotfiles.git $HOME/src/dotfiles
```

Sharing one clone between several users on a machine puts it in `/home/dotfiles` instead —
see [Sharing config with several users](#sharing-config-with-several-users-on-the-same-machine)
below, and clone there rather than here.

Everything from here on assumes you are in the repo root:

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}
```

## Install `stow`

### Arch
`paru` isn't built yet at this point, so `pacman` is used directly here. It's only used directly
twice: here, and to install paru itself — every other Arch step uses `paru`.
```sh
sudo pacman -S --needed stow
```
### Debian
```sh
sudo apt install -y stow
```
### Fedora
```sh
sudo dnf install -y stow
```
### macOS
```sh
brew install stow
```

## Stow the config files

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}/config-stow && \
stow -t $HOME git && \
mkdir -p $HOME/.config/Code/User && \
stow -t $HOME/.config vscode && \
mkdir -p $HOME/.var/app/com.visualstudio.code/config/Code/User && \
stow -t $HOME/.var/app/com.visualstudio.code/config vscode && \
cd ..
```

If a target already exists as a **real file** (a hand-written `~/.gitconfig`, say), stow refuses
and aborts *every* operation in that run — including the packages that would have succeeded:

```
cannot stow .gitconfig over existing target .gitconfig
  since neither a link nor a directory and --adopt not specified
All operations aborted.
```

Reconcile the two versions by hand first, then delete the local file and re-run. `stow --adopt`
does the opposite of what the name suggests — it pulls the local file's *content* into the repo,
overwriting what is tracked.

The `git` package carries both `.gitconfig` and `.gitignore_global` (wired up via
`core.excludesFile`), so a machine that stowed it before the global ignore existed needs
`stow -t $HOME git` re-run once to pick up the new symlink.

The global ignore is deliberately limited to OS and editor scratch — things no repo of mine
should have to know about. Build output, dependencies and caches stay in each project's own
`.gitignore`, where a rule that hides a file is visible to whoever hits it.

## zsh

Check your current shell: `echo $SHELL` (default) / `ps -p $$` (running).

### Arch
Install `paru` first (see [below](#paru-arch-only)) — the update-os aliases are paru wrappers.
```sh
paru -S --needed zsh zoxide tmux git git-delta curl wget eza sqlite fzf
```
`gitk` ships inside the `git` package here, so it needs no separate entry.
### Debian
```sh
sudo apt install -y zsh zoxide tmux git git-delta gitk curl wget eza fzf
```
`git-delta` is in apt since Debian 13 "trixie" (0.18.x). `eza` needs Debian 13+ / Ubuntu 24.04+;
`zoxide` needs Debian 12+ / Ubuntu 22.04+ — on older releases install these from the upstream
releases (delta ships a `.deb`) instead of `apt`.
### Fedora
```sh
sudo dnf install -y zsh zoxide tmux git git-delta gitk curl wget eza sqlite fzf
```
### macOS
```sh
brew install zsh zoxide tmux git curl wget eza fzf
```

### paru (Arch only)

The `update-os` / `s` aliases are `paru` wrappers, so it is **not** optional on Arch. Install it
before the packages, since everything below goes through it. CachyOS ships it in its own repo:

```sh
sudo pacman -S --needed paru
```

Everywhere else it comes from the AUR and has to be built once:

```sh
sudo pacman -S --needed base-devel git && \
git clone https://aur.archlinux.org/paru.git $HOME/src/paru && \
cd $HOME/src/paru && makepkg -si
```

**Never call paru with `sudo`** — it escalates on its own and refuses AUR installs when run as
root (`can't install AUR package as root`).

### nala (Debian only, optional)

```sh
sudo apt install -y nala && \
sudo nala install git-delta
```

On Ubuntu 22.04 LTS you may have to [install nala manually](https://gitlab.com/volian/nala/-/wikis/Installation).

### Set zsh as the default shell

- `chsh -s $(which zsh)` — works everywhere, macOS included

  or

- `sudo usermod -s $(which zsh) $(whoami)` — **Linux only** (shadow-utils; macOS has no `usermod`)

`chsh` only accepts shells listed in `/etc/shells`. Distro zsh packages add themselves; a
Homebrew zsh on macOS does **not**, so add it once first:

```sh
echo $(which zsh) | sudo tee -a /etc/shells
```

## oh-my-zsh

Install it ([upstream](https://github.com/ohmyzsh/ohmyzsh#basic-installation)):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Machine / user specific settings

The repo is already cloned to `$HOME/src/dotfiles` at the [top of this guide](#clone-this-repository) —
there is only ever one clone. The steps below assume you are in its root
(`cd ${DOTFILES_REPO:-$HOME/src/dotfiles}`).

#### Sharing config with several users on the same machine

**Linux only** — `groupadd` / `usermod` are shadow-utils and do not exist on macOS, which needs
`dscl` / `sysadminctl` instead. (Kept manual — the installer does not automate this.)

This is the one case where the clone does *not* live in `$HOME/src/dotfiles`; skip the clone at
the top of the guide and use `/home/dotfiles` throughout.

```sh
CURRENT_USER_NAME=`whoami` && \
SHARED_GROUP="shared_config" && \
sudo groupadd $SHARED_GROUP && \
sudo usermod -a -G $SHARED_GROUP $CURRENT_USER_NAME && \
DOTFILES_REPO="/home/dotfiles" && \
sudo git clone https://github.com/mkoester/dotfiles.git $DOTFILES_REPO && \
sudo chown -R $CURRENT_USER_NAME:$SHARED_GROUP $DOTFILES_REPO && \
sudo chmod 750 $DOTFILES_REPO
```

```sh
DOTFILES_REPO="/home/dotfiles" && \
mv $HOME/.oh-my-zsh/ $DOTFILES_REPO && \
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}/ && \
ln -s `pwd`/.oh-my-zsh/ $HOME/
```

```sh
DOTFILES_REPO="/home/dotfiles" && \
mkdir -p "$HOME/.oh-my-zsh-config" && \
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}/ && \
ln -s `pwd`/oh-my-zsh-config/shared-dotfiles.zsh $HOME/.oh-my-zsh-config/
```

#### Make the `update-os` alias available

Symlink the variant for your package manager:

```sh
# Arch
ln -sf `pwd`/.zshrc-update-os-arch.zsh $HOME/.zshrc-update-os.zsh
# Debian
ln -sf `pwd`/.zshrc-update-os-apt.zsh $HOME/.zshrc-update-os.zsh
# Debian + nala (also links the nala completion helper)
ln -sf `pwd`/.zshrc-update-os-nala.zsh $HOME/.zshrc-update-os.zsh && \
  mkdir -p $HOME/.oh-my-zsh-custom && ln -sf `pwd`/oh-my-zsh-custom/nala.zsh $HOME/.oh-my-zsh-custom/
# Fedora
ln -sf `pwd`/.zshrc-update-os-dnf.zsh $HOME/.zshrc-update-os.zsh
# macOS
ln -sf `pwd`/.zshrc-update-os-brew.zsh $HOME/.zshrc-update-os.zsh
```

The brew variant's `update-os` calls `brew cu -y -a`, which needs the
[`buo/cask-upgrade`](https://github.com/buo/homebrew-cask-upgrade) tap installed once:
`brew tap buo/cask-upgrade`.

### Theme

[powerlevel10k](https://github.com/romkatv/powerlevel10k#oh-my-zsh):

```sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

**Font** — Meslo Nerd Font, required for p10k's glyphs and `eza --icons`. `install.sh` does this
automatically (step 4); the manual equivalent:

```sh
paru -S --needed ttf-meslo-nerd            # Arch
brew install --cask font-meslo-lg-nerd-font  # macOS
```

On Debian/Fedora there's no clean package — download p10k's MesloLGS NF into the **system** font
dir so every user gets it (this is what `install.sh` runs):

```sh
base='https://github.com/romkatv/powerlevel10k-media/raw/master'
sudo mkdir -p /usr/local/share/fonts
sudo wget -q -P /usr/local/share/fonts "$base/MesloLGS%20NF%20Regular.ttf" "$base/MesloLGS%20NF%20Bold.ttf" "$base/MesloLGS%20NF%20Italic.ttf" "$base/MesloLGS%20NF%20Bold%20Italic.ttf"
sudo fc-cache -f
```

Either way, point your terminal emulator's font at **MesloLGS NF** afterward — that part is manual.

### Plugins

```sh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/you-should-use
```

#### auto-notify (optional / desktop only)

needs `notify-send`, which most desktop installs already have:

```sh
paru -S --needed libnotify      # Arch
sudo apt install -y libnotify-bin  # Debian (nala works too)
sudo dnf install -y libnotify      # Fedora
```

```sh
git clone https://github.com/MichaelAquilina/zsh-auto-notify.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/auto-notify && \
mkdir -p $HOME/.oh-my-zsh-plugins-optional && ln -sf `pwd`/oh-my-zsh-plugins-optional/auto-notify.zsh $HOME/.oh-my-zsh-plugins-optional/ && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -sf `pwd`/oh-my-zsh-custom/auto-notify.zsh $HOME/.oh-my-zsh-custom/
```

The `AUTO_NOTIFY_IGNORE` list in `auto-notify.zsh` references `btop` and `tldr`; install those
too if you use them (both optional, in every distro's repos as `btop` / `tldr`).

### Set up oh-my-zsh

make the config files `.zshrc` and `.p10k.zsh` available in your home directory

```sh
mkdir -p $HOME/.oh-my-zsh-config && \
[ ! -L $HOME/.zshrc ] || rm $HOME/.zshrc && [ ! -f $HOME/.zshrc ] || mv $HOME/.zshrc $HOME/.zshrc-manual-backup && \
[ ! -L $HOME/.p10k.zsh ] || rm $HOME/.p10k.zsh && [ ! -f $HOME/.p10k.zsh ] || mv $HOME/.p10k.zsh $HOME/.p10k-manual-backup.zsh && \
ln -sf `pwd`/oh-my-zsh-config/you-should-use.zsh $HOME/.oh-my-zsh-config/ && \
ln -sf `pwd`/.zshrc $HOME/ && \
ln -sf `pwd`/.p10k.zsh $HOME/
```

Two things this block gets right, both learned the hard way:

- The `mkdir -p` is load-bearing. `.oh-my-zsh-config` used to be created only by the optional
  multi-user section, so skipping that made the first `ln` fail — and since the whole block is
  one `&&` chain, `.zshrc` and `.p10k.zsh` were then never linked at all.
- The `ln -sf` (not `ln -s`) makes it **re-runnable**. Plain `ln -s` fails with "File exists" on
  a second run, but the `rm` earlier in the chain has *already deleted* the `.zshrc` symlink by
  then — so the abort left you with no `.zshrc` whatsoever. `-f` replaces instead of failing.

A real (non-symlink) `.zshrc` is moved to `.zshrc-manual-backup` first, so a fresh oh-my-zsh
install never loses its generated file.

### Why there are separate config / custom directories

oh-my-zsh reads most of its knobs (`ZSH_DISABLE_COMPFIX`, `zstyle ':omz:update'`, per-plugin
settings) **while it loads**, and applies your `plugins=(…)` list at that same moment. A setting
made *after* `source $ZSH/oh-my-zsh.sh` is simply too late — compinit has already run, the
plugins are already loaded. But aliases, functions and `PATH` are the opposite: they want to load
**last**, so they win over anything oh-my-zsh or a plugin defined.

One directory can't be both "before" and "after" oh-my-zsh, so `.zshrc` sources three, at three
points around that single `source` line:

| linked into | sourced | for |
|---|---|---|
| `~/.oh-my-zsh-config/` | **before** oh-my-zsh | vars & `zstyle` it reads as it loads (compfix, update mode, plugin config) |
| `~/.oh-my-zsh-plugins-optional/` | after `plugins=(…)`, still before oh-my-zsh | appending to the `plugins` array |
| `~/.oh-my-zsh-custom/` | **after** oh-my-zsh | aliases, functions, `PATH` — things that must override |

All three are `[ -d ]`-guarded, so a directory you never create is simply skipped. The split is
load-order, not taste: it is why `config` and `custom` can't be merged (they sit on opposite
sides of that `source` line), while `config` and `plugins-optional` *could* (both are "before").

**The repo mirrors the targets one-to-one.** A file's repo directory *is* its link target —
`oh-my-zsh-config/foo.zsh` links into `~/.oh-my-zsh-config/`, and so on. So the repo layout tells
you when each file loads; the catalog's "link into" column just restates the path.

### Catalog

Nothing links itself. Each file needs its own `ln -sf`, and only on the machines it applies to —
which is why a fresh machine does not automatically match an old one. `install.sh` automates
this via its host-class questions; to link one by hand the shape is always:

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
mkdir -p $HOME/.oh-my-zsh-custom && \
ln -sf `pwd`/oh-my-zsh-custom/pnpm.zsh $HOME/.oh-my-zsh-custom/
```

| file in repo | link into | what it does | when |
|---|---|---|---|
| `oh-my-zsh-config/you-should-use.zsh` | `.oh-my-zsh-config` | you-should-use settings | always — part of [set up oh-my-zsh](#set-up-oh-my-zsh) |
| `oh-my-zsh-config/ssh-wsl.zsh` | `.oh-my-zsh-config` | routes `ssh`/`ssh-add` through the Windows `.exe`s | WSL only |
| `oh-my-zsh-config/zsh-disable-compfix.zsh` | `.oh-my-zsh-config` | `ZSH_DISABLE_COMPFIX` — skips the insecure-directory check | shared/group-writable clone |
| `oh-my-zsh-config/omz-no_automatic_updates.zsh` | `.oh-my-zsh-config` | disables oh-my-zsh self-update | everywhere `sys_upgrade` drives updates |
| `oh-my-zsh-config/shared-dotfiles.zsh` | `.oh-my-zsh-config` | `create_new_user_with_shared_config()` | shared multi-user machines |
| `oh-my-zsh-plugins-optional/auto-notify.zsh` | `.oh-my-zsh-plugins-optional` | adds `auto-notify` to `plugins` | desktops |
| `oh-my-zsh-plugins-optional/golang.zsh` | `.oh-my-zsh-plugins-optional` | adds the omz `golang` plugin | Go machines |
| `oh-my-zsh-custom/auto-notify.zsh` | `.oh-my-zsh-custom` | `AUTO_NOTIFY_IGNORE` for long-running commands (`btop`, `tldr`, …) | with the plugin above |
| `oh-my-zsh-custom/bat.zsh` | `.oh-my-zsh-custom` | `alias bat='batcat'` | Debian only |
| `oh-my-zsh-custom/brew-path.zsh` | `.oh-my-zsh-custom` | puts `~/homebrew/bin` on `PATH` | Homebrew installed under `$HOME` |
| `oh-my-zsh-custom/caddy.zsh` | `.oh-my-zsh-custom` | `caddyedit`/`caddyfmt`/`caddyvalidate`/`caddyreload` | hosts running [Caddy](#caddy-hosts) |
| `oh-my-zsh-custom/fnm.zsh` | `.oh-my-zsh-custom` | `fnm env --use-on-cd` | [Node machines](#node-machines-fnm--pnpm) |
| `oh-my-zsh-custom/fresh.zsh` | `.oh-my-zsh-custom` | points `EDITOR`/`VISUAL`/`nano` at `fresh` | see [fresh](#fresh--terminal-editor) |
| `oh-my-zsh-custom/gita.zsh` | `.oh-my-zsh-custom` | `gitad`/`gitaw`/`gitar` | see [gita](#gita--multi-repo-git-overview--auto-fetch) |
| `oh-my-zsh-custom/lesspipe.zsh` | `.oh-my-zsh-custom` | `LESSOPEN` | see [lesspipe](#lesspipe) |
| `oh-my-zsh-custom/nala.zsh` | `.oh-my-zsh-custom` | completion setup, `~/.zfunc` on `fpath` | Debian + nala |
| `oh-my-zsh-custom/pnpm.zsh` | `.oh-my-zsh-custom` | `PNPM_HOME`, `p*` aliases, completion | [Node machines](#node-machines-fnm--pnpm) |
| `oh-my-zsh-custom/atuin.zsh` | `.oh-my-zsh-custom` | `atuin init zsh` — synced shell history | see [atuin](#atuin--shell-history-sync) |
| `oh-my-zsh-custom/quadlet.zsh` | `.oh-my-zsh-custom` | `qctl`/`qlog`/`qexec`/… Podman-quadlet helpers | see [quadlet hosts](#quadlet-hosts-server-side) |
| `oh-my-zsh-custom/ssh-shared-authorized_keys.zsh` | `.oh-my-zsh-custom` | `update-ssh-shared-authorized_keys` | hosts using the shared key repo |

## Node machines (fnm + pnpm)

`fnm.zsh` and `pnpm.zsh` assume the tools are installed. Install them, then link the catalog rows:

```sh
paru -S --needed fnm pnpm    # Arch
brew install fnm pnpm        # macOS
```

On Debian/Fedora there is no distro package — install [fnm](https://github.com/Schniz/fnm#installation)
and [pnpm](https://pnpm.io/installation) from upstream.

## topgrade — update everything

[topgrade](https://github.com/topgrade-rs/topgrade) is a one-shot "update everything" umbrella —
a **superset** of the `update-os` / `s` paru aliases. Where `update-os` is a paru wrapper (system
packages only, the fast daily pass), topgrade also sweeps the globals paru never sees: pnpm global
packages, rustup, cargo, flatpak, and so on. Its `system` step just calls paru, so running one or
the other never double-works; keep both.

The `config-stow/topgrade/` package carries `topgrade.toml`, symlinked to `~/.config`:

```sh
paru -S topgrade    # in extra
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}/config-stow && stow -t $HOME/.config topgrade && cd ..
```

Then `topgrade` (all steps), `topgrade --dry-run` (preview), or `topgrade only pnpm` (one step).

Note on pnpm: topgrade's built-in `pnpm` step runs `pnpm update -g` — **global packages only**. It
does *not* bump the pnpm **binary** (the `corepack use pnpm@X` nag). On an Arch box pnpm is the
pacman package, so the `system` step (paru) upgrades it and the nag clears itself. Only if pnpm is
corepack-managed do you need the commented `[commands]` self-bump line in `topgrade.toml`.

## Caddy hosts

`caddy.zsh` wraps `caddy fmt`/`validate` and `systemctl reload caddy`, so it needs Caddy present:

```sh
paru -S --needed caddy       # Arch
sudo apt install -y caddy    # Debian (see caddyserver.com for the apt repo)
sudo dnf install -y caddy    # Fedora
```

## lesspipe

```sh
LESSPIPE_VERSION="v2.12" && \
mkdir -p $HOME/src && \
cd $HOME/src && \
git clone https://github.com/wofr06/lesspipe.git && \
cd lesspipe && git checkout $LESSPIPE_VERSION && ./configure && make && sudo make install
```

Then link the helper:

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
mkdir -p $HOME/.oh-my-zsh-custom && \
ln -sf `pwd`/oh-my-zsh-custom/lesspipe.zsh $HOME/.oh-my-zsh-custom/
```

Optional tools lesspipe shells out to:

```sh
paru -S --needed 7zip unrar cabextract bat          # Arch (p7zip is named 7zip here)
sudo apt install -y p7zip-full unrar-free cabextract bat  # Debian
sudo dnf install p7zip p7zip-plugins unrar cabextract bat # Fedora (unrar needs RPM Fusion non-free)
brew install p7zip unrar cabextract bat             # macOS
```

Debian ships the binary as `batcat` (the name `bat` collides with another package), which is what
`oh-my-zsh-custom/bat.zsh` exists for — symlink it **on Debian only**:

```sh
mkdir -p $HOME/.oh-my-zsh-custom && ln -sf `pwd`/oh-my-zsh-custom/bat.zsh $HOME/.oh-my-zsh-custom/
```

Recent Fedora dropped `p7zip`/`p7zip-plugins` in favour of a `7zip` package — if the dnf line
errors on "No match", that is why.

## fresh — terminal editor

[fresh](https://github.com/sinelaw/fresh) is a Rust terminal IDE with the UX of a GUI editor:
standard keybindings (`Ctrl+S`/`Ctrl+F`/`Ctrl+Z`), mouse support, a command palette, LSP, and
multi-GB file handling. GPL-2.0. **The package is `fresh-editor`, the binary is `fresh`.**

```sh
paru -S --needed fresh-editor-bin      # Arch, prebuilt (fresh-editor builds from source)
brew install fresh-editor              # macOS
cargo install --locked fresh-editor    # anywhere with a Rust toolchain
```

Debian `.deb` and Fedora `.rpm` packages are on the
[releases page](https://github.com/sinelaw/fresh/releases), plus a Flatpak and an AppImage.

Shell integration:

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
mkdir -p $HOME/.oh-my-zsh-custom && \
ln -sf `pwd`/oh-my-zsh-custom/fresh.zsh $HOME/.oh-my-zsh-custom/
```

That sets `EDITOR`/`VISUAL` and re-points the `nano` alias at fresh. It overrides `.zshrc`'s own
`alias nano='nano -c'` because `~/.oh-my-zsh-custom` is sourced *last* — so link it only where
fresh is actually installed, or `nano` becomes a broken alias.

## gita — multi-repo git overview + auto-fetch

[gita](https://github.com/nosarthur/gita) shows the status of all git repos across every
`~/Projects/workspace_*` on one screen. The `oh-my-zsh-custom/gita.zsh` helpers (auto-sourced)
add `gitad`/`gitaw`/`gitar` (the `gitaw` live view uses `watch`, part of procps and usually
already present); the `systemd-user` stow package runs a periodic `gita fetch` timer.

Install via pipx (Arch names it `python-pipx`, everyone else `pipx`):

```sh
paru -S --needed python-pipx     # Arch
sudo dnf install -y pipx         # Fedora
sudo apt install -y pipx         # Debian
brew install pipx                # macOS
```

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
pipx install gita && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -sf `pwd`/oh-my-zsh-custom/gita.zsh $HOME/.oh-my-zsh-custom/
```

The symlink is what makes the helpers "auto-sourced" — `.zshrc` sources every `*.zsh` it finds
under `~/.oh-my-zsh-custom/`, but nothing puts the file there for you. Open a new shell (or
`exec zsh`) to pick them up.

Register every workspace's repos — **one path per `gita add -a`** (the multi-path form crashes,
upstream `auto_group` bug). The `gitar` alias does exactly that:

```sh
gitar   # loops: for ws in ~/Projects/workspace_*/ ~/Projects/okf/; do gita add -a "$ws"; done
```

The okf vault is appended explicitly — it lives at `~/Projects/okf`, outside the `workspace_*`
glob, so it would otherwise be missed on every fresh machine.

Day-to-day: `gitad` (repos with changes), `gitaw` (live-refreshing, grouped by workspace via
`gita ll -g`), `gita ll` (all).

### Rebuilding the groups

`gita add -a` is **add-only**: it skips repos already in `~/.config/gita/repos.csv`
("No new repos found!"), and a repo's group is assigned only as a side effect of *adding* it.
So `gitar` can't re-group registered repos or forget deleted ones — removing the groups and
re-running it just produces no-ops. A rebuild has to wipe both files first:

```sh
gita clear
gitar
gita group ll   # verify: one row per group
```

`gita clear` also drops per-repo flags and colors — we set none, so this is lossless.

Why it matters: `gita add -a` **appends** a group row rather than merging into an existing one,
so registering a repo into a workspace that already has a group leaves *two* rows with the same
name in `groups.csv`. The parse is last-row-wins, so the group silently shrinks to whatever was
added last, and `gita ll -g` quietly stops showing the rest while plain `gita ll` looks fine
(hit 2026-07-16: `workspace_homelab` collapsed to just `Workstation-Documentation`).

Two related quirks, both expected — not breakage:

- `gita add -a <dir>` registers `<dir>` **itself** when it's a repo, so each thin workspace repo
  shows up inside its own group next to its members. `gita group rmrepo` can remove it, but the
  repo then vanishes from `gita ll -g` entirely and the next rebuild re-adds it anyway.
- Two repos resolving to the same name are disambiguated by parent dir (`workspace_home/workspace_home`).
  Treat that as a **red flag** — it usually means a stray duplicate clone, not a naming clash.

### Periodic auto-fetch timer (systemd user)

Fetches all registered repos every 5 min so `gita ll`'s ahead/behind counts stay fresh — fetch
only, never pull.

```sh
cd config-stow && \
mkdir -p $HOME/.config/systemd/user && \
stow --no-folding -t $HOME/.config systemd-user && \
cd ..
systemctl --user daemon-reload && \
systemctl --user enable --now gita-fetch.timer
```

> **`--no-folding` is required, not optional.** This package now contains a drop-in
> directory (`systemd/user/waybar.service.d/`, see [waybar](#waybar--supervised-restart)).
> Plain `stow` "folds" a directory that doesn't yet exist on the target into a **single
> symlink** (`~/.config/systemd/user/waybar.service.d` → the package dir) — and **systemd
> does not traverse a symlinked `.d` drop-in directory**, so the override is silently
> ignored (`systemctl --user show waybar.service -p DropInPaths` comes back empty and
> `Restart` stays at the shipped `on-failure`). `--no-folding` makes stow create a **real**
> directory and symlink `override.conf` *inside* it, which systemd does read. If you already
> stowed without it, re-do the package: `stow -D -t $HOME/.config systemd-user && stow
> --no-folding -t $HOME/.config systemd-user`, then `systemctl --user daemon-reload`.

Verify, and check for SSH-auth failures on private remotes:

```sh
systemctl --user list-timers gita-fetch.timer
journalctl --user -u gita-fetch.service -n 30 --no-pager
```

A user timer does not inherit your login ssh-agent. If the log shows `Permission denied` on SSH
remotes, set `SSH_AUTH_SOCK` in `config-stow/systemd-user/systemd/user/gita-fetch.service` (match
`echo $SSH_AUTH_SOCK`), then `systemctl --user daemon-reload && systemctl --user restart
gita-fetch.timer`. HTTPS remotes fetch regardless.

## atuin — shell history sync

[atuin](https://atuin.sh) replaces the shell history with a synced, searchable database, backed
by my self-hosted [quadlet-atuin](https://github.com/mkoester/quadlet-atuin) server. `atuin.zsh`
runs `atuin init zsh` (guarded by a `command -v` check, so linking it on a machine without atuin
is harmless).

Install atuin:

```sh
paru -S --needed atuin       # Arch
brew install atuin           # macOS
sudo apt install -y atuin    # Debian 13+ (trixie) — packaged, on the system PATH
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --no-modify-path  # Fedora / older / anywhere
```

> **Why `--no-modify-path`, and the version caveat.** The upstream installer drops atuin in
> `~/.atuin/bin` and appends a PATH line to `~/.zshrc` — which is a **symlink into this repo**, so
> without `--no-modify-path` it silently edits the *tracked* `.zshrc`; `atuin.zsh` adds
> `~/.atuin/bin` to PATH instead. On Debian, `apt`'s atuin lags upstream (e.g. 18.6.1 vs 18.13.x) —
> **fine for a fresh install** (it syncs across the version gap; the newer migrations back
> kv/daemon features the old client doesn't use), so the package is used there. What is *not* fine
> is **downgrading a client after a newer one has run on the same box**: the newer binary migrates
> the local DB and the older one then can't open it (`migration … was previously applied but is
> missing`). That's a *local* DB downgrade, not a server break — fix by running the current client,
> and **do not delete `records.db`** (the sync source of truth) except on a throwaway box with no
> sync configured.

Link the shell integration:

```sh
mkdir -p $HOME/.oh-my-zsh-custom && ln -sf `pwd`/oh-my-zsh-custom/atuin.zsh $HOME/.oh-my-zsh-custom/
```

**The server address is private**, so the client `config.toml` (which holds `sync_address`) is
**not** tracked in this public repo — it lives in `workstation-private/shared/atuin/config.toml`
and the installer symlinks it to `~/.config/atuin/config.toml`. Set `sync_address` there to your
real domain. (A TOML config can't be split like the kanshi/niri skeletons, and the address must
stay out of public git, so the whole file is private.)

Then, **once per machine** (secret — never in a repo):

```sh
atuin register -u <user> -e <email>   # first machine; or `atuin login -u <user>` on the rest
atuin import auto                     # seed from the existing shell history
atuin sync
```

`atuin sync` runs automatically after commands (`auto_sync`); the daemon is off by default, so
sync happens in-shell. If you later enable the atuin daemon, keep `sync_address` in `config.toml`
(the daemon doesn't read the shell environment).

## quadlet hosts (server-side)

`oh-my-zsh-custom/quadlet.zsh` wraps the repetitive commands for managing rootless-Podman
[quadlet](https://github.com/mkoester?tab=repositories&q=quadlet) services, each of which runs as
a dedicated user. It collapses the invariant
`sudo -u <svc> XDG_RUNTIME_DIR=/run/user/$(id -u <svc>) systemctl --user …` prefix into
`qctl`/`qreload`/`qlog`/`qexec`/`qplog`/`qupdate`/`qvalidate`/`qsh`.

**Server-side only** — link it on the quadlet *host*, never on the workstation; the functions run
privileged commands against local service users. The installer's "Quadlet host?" question does
this. Its source of truth is the `quadlet-my-guidelines` Operations section — keep the two in
sync. To link by hand:

```sh
mkdir -p $HOME/.oh-my-zsh-custom && ln -sf `pwd`/oh-my-zsh-custom/quadlet.zsh $HOME/.oh-my-zsh-custom/
```

## kanshi — monitor profiles

The `arandr` + `autorandr` replacement for Wayland: named output profiles, switched from a
keybind with `kanshictl switch <profile>`, and auto-applied on hotplug.

```sh
paru -S --needed kanshi      # Arch
```

```sh
cd config-stow && stow -t $HOME/.config kanshi && cd ..
```

**Machine-specific profiles go in `config.d/` — not in this repo.** The tracked
`config-stow/kanshi/kanshi/config` is a generic skeleton using connector names only. Real
per-machine profiles go in `config.d/`, which is gitignored and pulled in by the skeleton's
`include ~/.config/kanshi/config.d/*`:

```sh
niri msg outputs                             # real names, modes, make/model/serial
$EDITOR ~/.config/kanshi/config.d/local.conf # same syntax; same-named profile wins
```

Keep `"Make Model Serial"` matching for `config.d/` only. It's the robust form — connector names
are non-deterministic with multiple GPUs or thunderbolt docks — but serials are hardware
identifiers and must not land in a public repo. These per-machine profiles live in the private
overlay repo; `install.sh` symlinks them in from there. Because stow links the whole `kanshi`
directory, files dropped in `config.d/` appear in `~/.config/kanshi/config.d/` automatically.

Enable it:

```sh
systemctl --user enable --now kanshi.service
```

If the package ships no unit (`pacman -Ql kanshi | grep systemd`), fall back to
`spawn-at-startup "kanshi"` in the Niri config. `kanshictl status` shows the live profile;
`kanshictl reload` re-reads the config.

**Do not also install `nwg-displays`.** It writes `~/.config/niri/monitor.kdl`, and the resulting
Niri config reload discards every transient change kanshi applied.

## niri — Wayland compositor

The `config-stow/niri/` package tracks a **public skeleton** Niri config plus the helper script.
niri itself (and waybar, below) are assumed installed on a desktop machine:

```sh
paru -S --needed niri waybar   # Arch (elsewhere: per each project's own install docs)
```

```sh
mkdir -p $HOME/.config/niri $HOME/.local/bin && \
cd config-stow && stow -t $HOME niri && cd ..
```

This links:

- `~/.config/niri/config.kdl` — the tracked skeleton: generic keybinds, the kanshi switch binds
  (`Mod+Shift+D` docked / `Mod+Shift+S` solo), and the Firefox-placement bind (`Mod+Shift+O`).
  It **omits** `spawn-sh-at-startup "waybar"` on purpose — waybar runs under its supervised unit
  (see [waybar](#waybar--supervised-restart)), so spawning it here too would give you two bars.
- `~/.local/bin/place-firefox-windows.sh` — re-homes restored single-profile Firefox windows onto
  workspaces by title (an i3-`assign` equivalent; see the Workstation-Documentation rationale).

**Machine- and device-specific overrides go in `~/.config/niri/local.kdl`**, `include`d
(optionally) by the skeleton so it wins: real `output` blocks, a custom xkb keymap path, and
Bluetooth quick-connect binds (which carry hardware MACs). It's gitignored here and supplied
per-machine by the private overlay repo — same pattern as kanshi's `config.d/`.

### ydotool (input injection)

For Wayland input injection (Stream Deck / macros), the `systemd-user` package ships a
`ydotoold.service`. It needs a udev rule for `/dev/uinput` (root, so **not** stow-managed):

```sh
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | \
  sudo tee /etc/udev/rules.d/99-uinput.rules
sudo usermod -aG input "$USER"    # then re-login
systemctl --user enable --now ydotoold.service
```

## waybar — supervised restart

Waybar crashes around output add/remove (hotplug, docking, `kanshictl switch`, monitor blanking) —
an upstream GTK bug ([Waybar #3400](https://github.com/Alexays/Waybar/issues/3400)). Niri's
`spawn-sh-at-startup "waybar"` doesn't supervise it, so a crash means the bar stays gone. The fix
is the unit waybar already ships, plus a drop-in.

The drop-in rides along in the **`systemd-user`** package (stow it per the gita-fetch section
above — **with `--no-folding`**, or systemd silently ignores the drop-in; see the note there),
and upgrades `/usr/lib/systemd/user/waybar.service` to `Restart=always` with the start
rate limit disabled — otherwise a burst of crashes during one docking event trips the limit and
the bar stays dead regardless.

```sh
systemctl --user daemon-reload && \
systemctl --user enable --now waybar.service
```

Then **ensure `spawn-sh-at-startup "waybar"` is absent** from `~/.config/niri/config.kdl` (the
tracked skeleton already omits it) — otherwise the unit and Niri each start a bar and you get two.

Verify the drop-in took effect, and watch for crashes:

```sh
systemctl --user show waybar.service -p DropInPaths -p Restart -p StartLimitIntervalUSec
journalctl --user -u waybar.service -f
```

Expect `Restart=always`, `StartLimitIntervalUSec=0`, and `DropInPaths=` listing the
`override.conf`. An **empty `DropInPaths`** with `Restart=on-failure` is the folding trap
above — the drop-in dir got stowed as a symlink; re-stow with `--no-folding`.

This also restores logging: the old `~/.config/waybar/waybar.sh` / `scripts/waybar-restart.sh`
piped waybar's output to `/dev/null`, which is why crashes left no journal trace. Under the unit,
`systemctl --user restart waybar` replaces both scripts.
