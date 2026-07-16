dot files / . files
===================

config files
------------

### clone this repository

```sh
git clone https://github.com/mkoester/dotfiles.git && cd dotfiles
```

or via `ssh`

```sh
git clone git@github.com:mkoester/dotfiles.git && cd dotfiles
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

#### MacOS with Homebrew

```sh
brew install stow
```

### symlink config files via `stow`

```sh
cd config-stow && \
stow -t $HOME git && \
mkdir -p $HOME/.config/Code/User && \
stow -t $HOME/.config vscode && \
mkdir -p $HOME/.var/app/com.visualstudio.code/config/Code/User && \
stow -t $HOME/.var/app/com.visualstudio.code/config vscode && \
cd ..
```


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
sudo dnf install -y zsh autojump-zsh tmux git git-delta gitk curl wget lsd sqlite fzf
```

#### deb based distros (e.g. Debian, Ubuntu, Mint, etc.)

```sh
sudo apt install -y zsh autojump tmux git gitk curl wget fzf
```

##### nala (optional)

```sh
sudo apt install -y nala && \
sudo nala install https://github.com/dandavison/delta/releases/download/0.17.0/git-delta_0.17.0_amd64.deb
```

you might have to install it manually (e.g. with Ubuntu 22.04 LTS): https://gitlab.com/volian/nala/-/wikis/Installation

#### MacOS with Homebrew

```sh
brew install zsh autojump tmux git curl wget lsd fzf
```

### set zsh as default shell

- `chsh -s $(which zsh)`

  or

- `sudo usermod -s $(which zsh) $(whoami)`

oh-my-zsh
---------

### Installation

https://github.com/ohmyzsh/ohmyzsh#basic-installation

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Machine / user specific settings

#### Cloning this repository

```sh
cd $HOME && \
mkdir src && \
cd src && \
git clone https://github.com/mkoester/dotfiles.git && \
cd dotfiles
```

#### Sharing config with several users on the same machine

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

https://www.nerdfonts.com/font-downloads

- Meslo Nerd Font

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

with Ubuntu based distros you might have to install a package

```sh
sudo <apt/nala> install libnotify-bin -y
```

```sh
git clone https://github.com/MichaelAquilina/zsh-auto-notify.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/auto-notify && \
mkdir -p $HOME/.oh-my-zsh-plugins-optional && ln -s `pwd`/oh-my-zsh-plugins-optional/auto-notify.zsh $HOME/.oh-my-zsh-plugins-optional/ && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -s `pwd`/oh-my-zsh-custom/auto-notify.zsh $HOME/.oh-my-zsh-custom/
```

### set up oh-my-zsh

make the config files `.zshrc` and `.p10k.zsh` available in your home directory

```sh
[ ! -L $HOME/.zshrc ] || rm $HOME/.zshrc && [ ! -f $HOME/.zshrc ] || mv $HOME/.zshrc $HOME/.zshrc-manual-backup && \
[ ! -L $HOME/.p10k.zsh ] || rm $HOME/.p10k.zsh && [ ! -f $HOME/.p10k.zsh ] || mv $HOME/.p10k.zsh $HOME/.p10k-manual-backup.zsh && \
ln -s `pwd`/oh-my-zsh-config/you-should-use.zsh $HOME/.oh-my-zsh-config/ && \
ln -s `pwd`/.zshrc $HOME/ && \
ln -s `pwd`/.p10k.zsh $HOME/
```

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
ln -s `pwd`/oh-my-zsh-custom/lesspipe.zsh $HOME/.oh-my-zsh-custom/
```

you might want to install some tools used by `lesspipe`:

### dnf based distros (e.g. fedora, RHEL (clones), etc.)

```sh
sudo dnf install p7zip p7zip-plugins unrar cabextract bat
```


gita — multi-repo git overview + auto-fetch
-------------------------------------------

[gita](https://github.com/nosarthur/gita) shows the status of all git repos across every
`~/Projects/workspace_*` on one screen. The `oh-my-zsh-custom/gita.zsh` helpers (auto-sourced)
add `gitad`/`gitaw`/`gitar`; the `systemd-user` stow package runs a periodic `gita fetch` timer.

### install & register

```sh
pipx install gita
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
sudo pacman -S kanshi
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
