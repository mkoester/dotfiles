#!/usr/bin/env zsh

alias update-os="df -H / /System/Volumes/Data /private/var/vm && brew upgrade && brew cu -y -a && brew cleanup"
