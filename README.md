dot files / . files
===================

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
sudo dnf install -y zsh autojump-zsh tmux git curl wget lsd
```

#### deb based distros (e.g. Debian, Ubuntu, Mint, etc.)

```
sudo apt install -y zsh autojump tmux git curl wget
```

#### MacOS with Homebrew

```
brew install zsh autojump tmux git curl wget lsd
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

### Theme

https://github.com/romkatv/powerlevel10k#oh-my-zsh

```
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

#### Font

https://www.nerdfonts.com/font-downloads

- Meslo Nerd Font

### Tools

```
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

```
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
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
sudo groupadd --users $CURRENT_USER_NAME $SHARED_GROUP && \
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

##### MacOS with Homebrew

```
ln -s `pwd`/.zshrc-update-os-brew.zsh ~/.zshrc-update-os.zsh
```



#### set up oh-my-zsh

make the config files `.zshrc` and `.p10k.zsh` available in your home directory

```
[ ! -L ~/.zshrc ] || rm ~/.zshrc && [ ! -f ~/.zshrc ] || mv ~/.zshrc ~/.zshrc-manual-backup && \
[ ! -L ~/.p10k.zsh ] || rm ~/.p10k.zsh && [ ! -f ~/.p10k.zsh ] || mv ~/.p10k.zsh ~/.p10k-manual-backup.zsh && \
ln -s `pwd`/.zshrc ~/ && \
ln -s `pwd`/.p10k.zsh ~/
```
