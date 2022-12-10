#!/usr/bin/env zsh

alias update-ssh-shared-authorized_keys="echo -n 'Updating ssh-shared-authorized_keys repo: ' && sudo git -C /home/ssh-authorized-keys/ pull"
