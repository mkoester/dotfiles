#!/usr/bin/env zsh

# Caddy web server aliases
# https://caddyserver.com/docs/command-line

CADDY_CONFIG="${CADDYCONFIG:-/etc/caddy/Caddyfile}"

alias caddyedit='sudoedit "$CADDY_CONFIG"'
alias caddyfmt='sudo caddy fmt --overwrite --config "$CADDY_CONFIG"'
alias caddyvalidate='sudo caddy validate --config "$CADDY_CONFIG"'
alias caddyreload='sudo systemctl reload caddy'
