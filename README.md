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

```
sudo dnf install zsh autojump-zsh -y
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

make the alias for os updates available, e.g. for fedora Red Hat systems:

```
ln -s `pwd`/.zshrc-update-os-dnf.zsh ~/.zshrc-update-os.zsh
```

make the config files `.zshrc` and `.p10k.zsh` available in your home directory

```
[ ! -L ~/.zshrc ] || rm ~/.zshrc && [ ! -f ~/.zshrc ] || mv ~/.zshrc ~/.zshrc-manual-backup && \
[ ! -L ~/.p10k.zsh ] || rm ~/.p10k.zsh && [ ! -f ~/.p10k.zsh ] || mv ~/.p10k.zsh ~/.p10k-manual-backup.zsh && \
ln -s `pwd`/.zshrc ~/ && \
ln -s `pwd`/.p10k.zsh ~/
```
