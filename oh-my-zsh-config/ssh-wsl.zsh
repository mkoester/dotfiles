#!/usr/bin/env zsh

alias ssh-add='ssh-add.exe'
export GIT_SSH_COMMAND='ssh-add.exe -l > /dev/null || ssh-add.exe && ssh.exe'
alias ssh=$GIT_SSH_COMMAND
