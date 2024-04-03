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
