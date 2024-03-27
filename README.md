dot files / . files
===================

config files
------------

### install `stow`

#### rpm based distros (e.g. fedora, RHEL (clones), etc.)

```
sudo dnf install -y stow
```

#### deb based distros (e.g. Debian, Ubuntu, Mint, etc.)

```
sudo apt install -y stow
```

#### MacOS with Homebrew

```
brew install stow
```

### symlink config files via `stow`

```
cd config-stow && \
stow -t $HOME git && \
stow -t $HOME vscode
```

(TODO iterate through directory and execute for each package)


zsh
---

### check current shell

- currently running shell
  + `ps -p $$`
- default shell for the user
  + `echo $SHELL`

### Install zsh

#### rpm based distros (e.g. fedora, RHEL (clones), etc.)

```
sudo dnf install -y zsh autojump-zsh tmux git curl wget lsd sqlite fzf
```

#### deb based distros (e.g. Debian, Ubuntu, Mint, etc.)

```
sudo apt install -y zsh autojump tmux git curl wget fzf
```

##### nala (optional)

```
sudo apt install -y nala
```

you might have to install it manually (e.g. with Ubuntu 22.04 LTS): https://gitlab.com/volian/nala/-/wikis/Installation

#### MacOS with Homebrew

```
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

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Machine / user specific settings

#### Cloning this repository

```
cd ~ && \
mkdir src && \
cd src && \
git clone https://github.com/mkoester/dotfiles.git && \
cd dotfiles
```

#### Sharing config with several users on the same machine

```
CURRENT_USER_NAME=`whoami` && \
SHARED_GROUP="shared_config" && \
sudo groupadd $SHARED_GROUP && \
sudo usermod -a -G $SHARED_GROUP $CURRENT_USER_NAME && \
DOTFILES_REPO="/home/dotfiles" && \
sudo git clone https://github.com/mkoester/dotfiles.git $DOTFILES_REPO && \
sudo chown -R $CURRENT_USER_NAME:$SHARED_GROUP $DOTFILES_REPO && \
sudo chmod 750 $DOTFILES_REPO
```

```
DOTFILES_REPO="/home/dotfiles" && \
mv ~/.oh-my-zsh/ $DOTFILES_REPO && \
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}/ && \
ln -s `pwd`/.oh-my-zsh/ ~/
```

```
DOTFILES_REPO="/home/dotfiles" && \
mkdir -p "$HOME/.oh-my-zsh-config" && \
cd ${DOTFILES_REPO:-$HOME/src/dotfiles}/ && \
ln -s `pwd`/oh-my-zsh-custom/shared-dotfiles.zsh ~/.oh-my-zsh-config/
```


#### Make the alias for os updates available

##### dnf based distros (e.g. fedora, RHEL (clones), etc.)

```
ln -s `pwd`/.zshrc-update-os-dnf.zsh ~/.zshrc-update-os.zsh
```

##### apt based distros (e.g. Debian, Ubuntu, Mint, etc.)

```
ln -s `pwd`/.zshrc-update-os-apt.zsh ~/.zshrc-update-os.zsh
```

###### nala

```
ln -s `pwd`/.zshrc-update-os-nala.zsh ~/.zshrc-update-os.zsh && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -s `pwd`/oh-my-zsh-custom/nala.zsh ~/.oh-my-zsh-custom
```

##### MacOS with Homebrew

```
ln -s `pwd`/.zshrc-update-os-brew.zsh ~/.zshrc-update-os.zsh
```

### Theme

https://github.com/romkatv/powerlevel10k#oh-my-zsh

```
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

#### Font

https://www.nerdfonts.com/font-downloads

- Meslo Nerd Font

### Tools / Plugins

```
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

```
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

```
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/you-should-use
```

#### auto-notify (optional / Desktop only)

with Ubuntu based distros you might have to install a package

```
sudo <apt/nala> install libnotify-bin -y
```

```
git clone https://github.com/MichaelAquilina/zsh-auto-notify.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/auto-notify && \
mkdir -p $HOME/.oh-my-zsh-plugins-optional && ln -s `pwd`/oh-my-zsh-plugins-optional/auto-notify.zsh ~/.oh-my-zsh-plugins-optional/ && \
mkdir -p $HOME/.oh-my-zsh-custom && ln -s `pwd`/oh-my-zsh-custom/auto-notify.zsh ~/.oh-my-zsh-custom/
```

### set up oh-my-zsh

make the config files `.zshrc` and `.p10k.zsh` available in your home directory

```
[ ! -L ~/.zshrc ] || rm ~/.zshrc && [ ! -f ~/.zshrc ] || mv ~/.zshrc ~/.zshrc-manual-backup && \
[ ! -L ~/.p10k.zsh ] || rm ~/.p10k.zsh && [ ! -f ~/.p10k.zsh ] || mv ~/.p10k.zsh ~/.p10k-manual-backup.zsh && \
ln -s `pwd`/oh-my-zsh-config/you-should-use.zsh ~/.oh-my-zsh-config/ && \
ln -s `pwd`/.zshrc ~/ && \
ln -s `pwd`/.p10k.zsh ~/
```
