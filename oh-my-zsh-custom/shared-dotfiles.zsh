#!/usr/bin/env zsh

export DOTFILES_REPO="/home/dotfiles"

create_new_user_with_shared_config () {
    NEW_USER_NAME=$1; \
    SHARED_DIR=$DOTFILES_REPO; \
    SHARED_GROUP=shared_config; \
    sudo adduser --groups $SHARED_GROUP $NEW_USER_NAME && \
    sudo su -c "ln -s $SHARED_DIR/.oh-my-zsh/ ~" $NEW_USER_NAME && \
    sudo su -c "ln -s $SHARED_DIR/.p10k.zsh ~/" $NEW_USER_NAME && \
    sudo su -c "rm ~/.zshrc; ln -s $SHARED_DIR/.zshrc ~/" $NEW_USER_NAME && \
    sudo su -c "mkdir -m 700 ~/.ssh; ln -s /home/ssh-authorized-keys/authorized_keys ~/.ssh/" $NEW_USER_NAME && \
    sudo su -c "mkdir -m 700 ~/.oh-my-zsh-config;" $NEW_USER_NAME && \
    sudo su -c "ln -s $SHARED_DIR/oh-my-zsh-custom/zsh-disable-compfix.zsh ~/.oh-my-zsh-config/" $NEW_USER_NAME && \
    sudo su -c "ln -s $SHARED_DIR/oh-my-zsh-custom/omz-no_automatic_updates.zsh ~/.oh-my-zsh-config/" $NEW_USER_NAME && \
    sudo su -c "touch ~/.zshrc-update-os.zsh" $NEW_USER_NAME && \
    sudo usermod -s $(which zsh) $NEW_USER_NAME
}
