dot files / . files
===================

config files
------------

### clone this repository

**Clone location is permanent.** `stow` symlinks point back into the clone, so wherever this
lands is where `~/.gitconfig` and friends resolve to forever. `~/src/dotfiles` is the canonical
spot — do this first, before installing or running stow.

```sh
mkdir -p $HOME/src && \
git clone https://github.com/mkoester/dotfiles.git $HOME/src/dotfiles
```

or via `ssh`

```sh
mkdir -p $HOME/src && \
git clone git@github.com:mkoester/dotfiles.git $HOME/src/dotfiles
```

Sharing one clone between several users on a machine puts it in `/home/dotfiles` instead —
see [Sharing config with several users](#sharing-config-with-several-users-on-the-same-machine)
below, and clone there rather than here.

Everything from here on assumes you are in the repo root:

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}
```

### install `stow`

#### rpm based distros (e.g. fedora, RHEL (clones), etc.)

```sh
sudo dnf install -y stow
```

#### deb based distros (e.g. Debian, Ubuntu, Mint, etc.)

```sh
sudo apt install -y stow
```

#### arch based distros (e.g. Arch, CachyOS, EndeavourOS, Manjaro, etc.)

`paru` is not installed yet at this point in the guide, so `pacman` is used directly here.
It is only used directly twice: here, and to install paru itself — every other arch step
uses `paru`.

```sh
sudo pacman -S --needed stow
```

#### MacOS with Homebrew

```sh
brew install stow
```

### symlink config files via `stow`

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


zsh
---

### check current shell

- currently running shell
  + `ps -p $$`
- default shell for the user
  + `echo $SHELL`

### Install zsh

#### rpm based distros (e.g. fedora, RHEL (clones), etc.)

```sh
sudo dnf install -y zsh zoxide tmux git git-delta gitk curl wget eza sqlite fzf
```

#### deb based distros (e.g. Debian, Ubuntu, Mint, etc.)

```sh
sudo apt install -y zsh zoxide tmux git gitk curl wget eza fzf
```

`eza` needs Debian 13+ / Ubuntu 24.04+; `zoxide` needs Debian 12+ / Ubuntu 22.04+. On older
releases install them from the upstream releases instead of `apt`.

##### nala (optional)

```sh
sudo apt install -y nala && \
sudo nala install https://github.com/dandavison/delta/releases/download/0.17.0/git-delta_0.17.0_amd64.deb
```

you might have to install it manually (e.g. with Ubuntu 22.04 LTS): https://gitlab.com/volian/nala/-/wikis/Installation

#### arch based distros (e.g. Arch, CachyOS, EndeavourOS, Manjaro, etc.)

##### paru (required, install first)

The `update-os` / `s` aliases below are `paru` wrappers, so it is **not** optional on arch.
Install it before the packages, since everything below goes through it.

CachyOS ships it in its own repo. This is the other direct `pacman` use, for the obvious
reason that paru cannot install itself:

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

##### packages

```sh
paru -S --needed zsh zoxide tmux git git-delta curl wget eza sqlite fzf
```

`gitk` ships inside the `git` package here, so it needs no separate entry.

#### MacOS with Homebrew

```sh
brew install zsh zoxide tmux git curl wget eza fzf
```

### set zsh as default shell

- `chsh -s $(which zsh)` — works everywhere, MacOS included

  or

- `sudo usermod -s $(which zsh) $(whoami)` — **Linux only** (shadow-utils; MacOS has no `usermod`)

`chsh` only accepts shells listed in `/etc/shells`. Distro zsh packages add themselves; a
Homebrew zsh on MacOS does **not**, so add it once first:

```sh
echo $(which zsh) | sudo tee -a /etc/shells
```

oh-my-zsh
---------

### Installation

https://github.com/ohmyzsh/ohmyzsh#basic-installation

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Machine / user specific settings

The repo is already cloned to `$HOME/src/dotfiles` at the [top of this guide](#clone-this-repository) —
there is only ever one clone. The steps below assume you are in its root:

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}
```

#### Sharing config with several users on the same machine

**Linux only** — `groupadd` / `usermod` are shadow-utils and do not exist on MacOS, which needs
`dscl` / `sysadminctl` instead.

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
ln -s `pwd`/oh-my-zsh-custom/shared-dotfiles.zsh $HOME/.oh-my-zsh-config/
```


#### Make the alias for os updates available

##### dnf based distros (e.g. fedora, RHEL (clones), etc.)

```sh
ln -s `pwd`/.zshrc-update-os-dnf.zsh $HOME/.zshrc-update-os.zsh
```

##### apt based distros (e.g. Debian, Ubuntu, Mint, etc.)

```sh
ln -s `pwd`/.zshrc-update-os-apt.zsh $HOME/.zshrc-update-os.zsh
```

###### nala

```sh
ln -s `pwd`/.zshrc-update-os-nala.zsh $HOME/.zshrc-update-os.zsh && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -s `pwd`/oh-my-zsh-custom/nala.zsh $HOME/.oh-my-zsh-custom
```

##### pacman based distros (e.g. Arch, CachyOS, EndeavourOS, Manjaro, etc.)

Requires `paru` — see the arch section above.

```sh
ln -s `pwd`/.zshrc-update-os-arch.zsh $HOME/.zshrc-update-os.zsh
```

##### MacOS with Homebrew

```sh
ln -s `pwd`/.zshrc-update-os-brew.zsh $HOME/.zshrc-update-os.zsh
```

### Theme

https://github.com/romkatv/powerlevel10k#oh-my-zsh

```sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

#### Font

Meslo Nerd Font — required for p10k's glyphs and for `eza --icons`.

```sh
paru -S --needed ttf-meslo-nerd      # arch
brew install --cask font-meslo-lg-nerd-font   # MacOS
```

Elsewhere, download it manually: https://www.nerdfonts.com/font-downloads

### Tools / Plugins

```sh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

```sh
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

```sh
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/you-should-use
```

#### auto-notify (optional / Desktop only)

needs `notify-send`, which most desktop installs already have:

```sh
sudo apt install -y libnotify-bin    # deb (nala works too)
sudo dnf install -y libnotify        # rpm
paru -S --needed libnotify           # arch
```

```sh
git clone https://github.com/MichaelAquilina/zsh-auto-notify.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/auto-notify && \
mkdir -p $HOME/.oh-my-zsh-plugins-optional && ln -s `pwd`/oh-my-zsh-plugins-optional/auto-notify.zsh $HOME/.oh-my-zsh-plugins-optional/ && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -s `pwd`/oh-my-zsh-custom/auto-notify.zsh $HOME/.oh-my-zsh-custom/
```

### set up oh-my-zsh

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

### the three customization directories

`.zshrc` sources three directories at different points during startup. Which one a file belongs
in is decided by **when it has to run**, not by what it does:

| linked into | sourced | for |
|---|---|---|
| `~/.oh-my-zsh-config/` | before `plugins=(…)` and oh-my-zsh | variables and `zstyle` oh-my-zsh reads *as it loads* |
| `~/.oh-my-zsh-plugins-optional/` | after `plugins=(…)`, before oh-my-zsh | appending to the `plugins` array |
| `~/.oh-my-zsh-custom/` | last, after oh-my-zsh | aliases, functions, `PATH` |

All three are `[ -d ]`-guarded, so a directory you never create is simply skipped.

**The repo directory is not the target directory.** Three files under `oh-my-zsh-custom/` have
to be linked into `~/.oh-my-zsh-config/`, because they only take effect before oh-my-zsh loads.
Use the table below rather than inferring the target from the path.

### catalog

Nothing links itself. Each file needs its own `ln -sf`, and only on the machines it applies to —
which is why a fresh machine does not automatically match an old one. The shape is always:

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
mkdir -p $HOME/.oh-my-zsh-custom && \
ln -sf `pwd`/oh-my-zsh-custom/pnpm.zsh $HOME/.oh-my-zsh-custom/
```

| file in repo | link into | what it does | when |
|---|---|---|---|
| `oh-my-zsh-config/you-should-use.zsh` | `.oh-my-zsh-config` | you-should-use settings | always — part of [set up oh-my-zsh](#set-up-oh-my-zsh) |
| `oh-my-zsh-config/ssh-wsl.zsh` | `.oh-my-zsh-config` | routes `ssh`/`ssh-add` through the Windows `.exe`s | WSL only |
| `oh-my-zsh-custom/zsh-disable-compfix.zsh` | **`.oh-my-zsh-config`** | `ZSH_DISABLE_COMPFIX` — skips the insecure-directory check | shared/group-writable clone |
| `oh-my-zsh-custom/omz-no_automatic_updates.zsh` | **`.oh-my-zsh-config`** | disables oh-my-zsh self-update | everywhere `sys_upgrade` drives updates |
| `oh-my-zsh-custom/shared-dotfiles.zsh` | **`.oh-my-zsh-config`** | `create_new_user_with_shared_config()` | shared multi-user machines |
| `oh-my-zsh-plugins-optional/auto-notify.zsh` | `.oh-my-zsh-plugins-optional` | adds `auto-notify` to `plugins` | desktops |
| `oh-my-zsh-plugins-optional/golang.zsh` | `.oh-my-zsh-plugins-optional` | adds the omz `golang` plugin | Go machines |
| `oh-my-zsh-custom/auto-notify.zsh` | `.oh-my-zsh-custom` | `AUTO_NOTIFY_IGNORE` for long-running commands | with the plugin above |
| `oh-my-zsh-custom/bat.zsh` | `.oh-my-zsh-custom` | `alias bat='batcat'` | deb only |
| `oh-my-zsh-custom/brew-path.zsh` | `.oh-my-zsh-custom` | puts `~/homebrew/bin` on `PATH` | Homebrew installed under `$HOME` |
| `oh-my-zsh-custom/caddy.zsh` | `.oh-my-zsh-custom` | `caddyedit`/`caddyfmt`/`caddyvalidate`/`caddyreload` | hosts running Caddy |
| `oh-my-zsh-custom/fnm.zsh` | `.oh-my-zsh-custom` | `fnm env --use-on-cd` | Node machines (needs fnm) |
| `oh-my-zsh-custom/fresh.zsh` | `.oh-my-zsh-custom` | points `EDITOR`/`VISUAL`/`nano` at `fresh` | see [fresh](#fresh--terminal-editor) |
| `oh-my-zsh-custom/gita.zsh` | `.oh-my-zsh-custom` | `gitad`/`gitaw`/`gitar` | see [gita](#gita--multi-repo-git-overview--auto-fetch) |
| `oh-my-zsh-custom/lesspipe.zsh` | `.oh-my-zsh-custom` | `LESSOPEN` | see [lesspipe](#lesspipe) |
| `oh-my-zsh-custom/nala.zsh` | `.oh-my-zsh-custom` | completion setup, `~/.zfunc` on `fpath` | deb + nala |
| `oh-my-zsh-custom/pnpm.zsh` | `.oh-my-zsh-custom` | `PNPM_HOME`, `p*` aliases, completion | Node machines (needs pnpm) |
| `oh-my-zsh-custom/ssh-shared-authorized_keys.zsh` | `.oh-my-zsh-custom` | `update-ssh-shared-authorized_keys` | hosts using the shared key repo |

## lesspipe

```sh
LESSPIPE_VERSION="v2.12" && \
mkdir -p $HOME/src && \
cd $HOME/src && \
git clone https://github.com/wofr06/lesspipe.git && \
cd lesspipe && git checkout $LESSPIPE_VERSION && ./configure && make && sudo make install
```

go to the dotfiles repo and execute

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
mkdir -p $HOME/.oh-my-zsh-custom && \
ln -s `pwd`/oh-my-zsh-custom/lesspipe.zsh $HOME/.oh-my-zsh-custom/
```

you might want to install some tools used by `lesspipe`:

### dnf based distros (e.g. fedora, RHEL (clones), etc.)

```sh
sudo dnf install p7zip p7zip-plugins unrar cabextract bat
```

Recent Fedora dropped `p7zip`/`p7zip-plugins` in favour of a `7zip` package — if the above
errors on "No match", that is why. `unrar` needs RPM Fusion (non-free).

### deb based distros (e.g. Debian, Ubuntu, Mint, etc.)

```sh
sudo apt install -y p7zip-full unrar-free cabextract bat
```

Debian ships the binary as `batcat` (the name `bat` collides with another package), which is
what `oh-my-zsh-custom/bat.zsh` exists for — symlink it **on deb systems only**:

```sh
mkdir -p $HOME/.oh-my-zsh-custom && \
ln -s `pwd`/oh-my-zsh-custom/bat.zsh $HOME/.oh-my-zsh-custom/
```

### arch based distros (e.g. Arch, CachyOS, EndeavourOS, Manjaro, etc.)

`p7zip` is named `7zip` here.

```sh
paru -S --needed 7zip unrar cabextract bat
```

### MacOS with Homebrew

```sh
brew install p7zip unrar cabextract bat
```


fresh — terminal editor
-----------------------

[fresh](https://github.com/sinelaw/fresh) is a Rust terminal IDE with the UX of a GUI editor:
standard keybindings (`Ctrl+S`/`Ctrl+F`/`Ctrl+Z`), mouse support, a command palette, LSP, and
multi-GB file handling. GPL-2.0.

### install

Not in the arch repos — it comes from the AUR. Take the `-bin` package unless you want to
compile Rust:

```sh
paru -S --needed fresh-editor-bin      # arch, prebuilt (fresh-editor builds from source)
brew install fresh-editor              # MacOS
cargo install --locked fresh-editor    # anywhere with a Rust toolchain
```

Debian/Ubuntu `.deb` and Fedora `.rpm` packages are on the
[releases page](https://github.com/sinelaw/fresh/releases), and there is a Flatpak
(`flatpak install fresh-editor`) plus an AppImage.

**The package is `fresh-editor`, the binary is `fresh`.**

### shell integration

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
mkdir -p $HOME/.oh-my-zsh-custom && \
ln -sf `pwd`/oh-my-zsh-custom/fresh.zsh $HOME/.oh-my-zsh-custom/
```

That sets `EDITOR`/`VISUAL` and re-points the `nano` alias at fresh. It overrides `.zshrc`'s own
`alias nano='nano -c'` because `~/.oh-my-zsh-custom` is sourced *last* — so link it only where
fresh is actually installed, or `nano` becomes a broken alias.


gita — multi-repo git overview + auto-fetch
-------------------------------------------

[gita](https://github.com/nosarthur/gita) shows the status of all git repos across every
`~/Projects/workspace_*` on one screen. The `oh-my-zsh-custom/gita.zsh` helpers (auto-sourced)
add `gitad`/`gitaw`/`gitar`; the `systemd-user` stow package runs a periodic `gita fetch` timer.

### install & register

`pipx` is not part of the zsh package list above — install it first. Note arch names it
`python-pipx`, everyone else `pipx`:

```sh
paru -S --needed python-pipx     # arch
sudo dnf install -y pipx         # rpm
sudo apt install -y pipx         # deb
brew install pipx                # MacOS
```

```sh
cd ${DOTFILES_REPO:-$HOME/src/dotfiles} && \
pipx install gita && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -s `pwd`/oh-my-zsh-custom/gita.zsh $HOME/.oh-my-zsh-custom/
```

The symlink is what makes the helpers "auto-sourced" — `.zshrc` sources every `*.zsh` it finds
under `~/.oh-my-zsh-custom/`, but nothing puts the file there for you. Without it you get bare
`gita` and no `gitad`/`gitaw`/`gitar`. Open a new shell (or `exec zsh`) to pick them up.

Register every workspace's repos — **one path per `gita add -a`** (the multi-path form crashes,
upstream `auto_group` bug). The `gitar` alias does exactly that:

```sh
gitar   # loops: for ws in ~/Projects/workspace_*/ ~/Projects/okf/; do gita add -a "$ws"; done
```

The okf vault is appended explicitly — it lives at `~/Projects/okf`, outside the `workspace_*`
glob, so it would otherwise be missed on every fresh machine.

Day-to-day: `gitad` (repos with changes), `gitaw` (live-refreshing, grouped by workspace via
`gita ll -g`), `gita ll` (all).

### rebuilding the groups

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

### periodic auto-fetch timer (systemd user)

Fetches all registered repos every 5 min so `gita ll`'s ahead/behind counts stay fresh — fetch
only, never pull.

```sh
cd config-stow && \
mkdir -p $HOME/.config/systemd/user && \
stow -t $HOME/.config systemd-user && \
cd ..
systemctl --user daemon-reload && \
systemctl --user enable --now gita-fetch.timer
```

Verify, and check for SSH-auth failures on private remotes:

```sh
systemctl --user list-timers gita-fetch.timer
journalctl --user -u gita-fetch.service -n 30 --no-pager
```

A user timer does not inherit your login ssh-agent. If the log shows `Permission denied` on SSH
remotes, set `SSH_AUTH_SOCK` in `config-stow/systemd-user/systemd/user/gita-fetch.service` (match
`echo $SSH_AUTH_SOCK`), then `systemctl --user daemon-reload && systemctl --user restart
gita-fetch.timer`. HTTPS remotes fetch regardless.


kanshi — monitor layout profiles (Niri / Wayland)
-------------------------------------------------

The `arandr` + `autorandr` replacement: named output profiles, switched from a keybind with
`kanshictl switch <profile>`, and auto-applied on hotplug.

### install

```sh
paru -S --needed kanshi
```

```sh
cd config-stow && \
stow -t $HOME/.config kanshi && \
cd ..
```

### machine-specific profiles go in `config.d/` — not in this repo

**This repo is public.** The tracked `config-stow/kanshi/kanshi/config` is a generic skeleton
using connector names only. Real per-machine profiles go in `config.d/`, which is gitignored
and pulled in by the skeleton's `include ~/.config/kanshi/config.d/*`:

```sh
niri msg outputs                             # real names, modes, make/model/serial
$EDITOR ~/.config/kanshi/config.d/local.conf # same syntax; same-named profile wins
```

Because stow links the whole `kanshi` directory, files dropped in the repo's `config.d/` appear
in `~/.config/kanshi/config.d/` automatically — private, but stow-managed like everything else.

Keep `"Make Model Serial"` matching for `config.d/` only. It's the robust form — connector names
are non-deterministic with multiple GPUs or thunderbolt docks — but serials are hardware
identifiers and must not land in a public repo.

### enable

```sh
systemctl --user enable --now kanshi.service
```

If the package ships no unit (`pacman -Ql kanshi | grep systemd`), fall back to
`spawn-at-startup "kanshi"` in the Niri config.

### keybinds

Not tracked yet — no Niri stow package exists (open item). Add to `~/.config/niri/config.kdl`
by hand:

```kdl
Mod+Shift+D { spawn "kanshictl" "switch" "docked"; }
Mod+Shift+S { spawn "kanshictl" "switch" "solo"; }
```

`kanshictl status` shows the live profile when a switch appears to do nothing; `kanshictl reload`
re-reads the config.

**Do not also install `nwg-displays`.** It writes `~/.config/niri/monitor.kdl`, and the resulting
Niri config reload discards every transient change kanshi applied.


waybar — supervision drop-in
----------------------------

Waybar crashes around output add/remove (hotplug, docking, `kanshictl switch`, monitor blanking) —
an upstream GTK bug ([Waybar #3400](https://github.com/Alexays/Waybar/issues/3400)). Niri's
`spawn-sh-at-startup "waybar"` doesn't supervise it, so a crash means the bar stays gone. The fix
is the unit waybar already ships, plus a drop-in.

The drop-in rides along in the **`systemd-user`** package (stow it per the gita-fetch section
above), and upgrades `/usr/lib/systemd/user/waybar.service` to `Restart=always` with the start
rate limit disabled — otherwise a burst of crashes during one docking event trips the limit and
the bar stays dead regardless.

```sh
systemctl --user daemon-reload && \
systemctl --user enable --now waybar.service
```

Then **remove `spawn-sh-at-startup "waybar"`** from `~/.config/niri/config.kdl` — otherwise the
unit and Niri each start a bar and you get two.

Verify the drop-in actually took effect, and watch for crashes:

```sh
systemctl --user show waybar.service -p Restart -p StartLimitIntervalUSec
journalctl --user -u waybar.service -f
```

This also restores logging: `~/.config/waybar/waybar.sh` and `scripts/waybar-restart.sh` pipe
waybar's output to `/dev/null`, which is why crashes left no journal trace. Under the unit,
`systemctl --user restart waybar` replaces both scripts.
