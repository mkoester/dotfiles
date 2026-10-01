#!/usr/bin/env zsh

# fleet-vault — `fv`, the fleet Vaultwarden account from the command line, plus the launch guard
# that keeps its secrets out of AI agents. Linked by install.sh under DF_DEV, beside rbw itself.
#
#   fv pull | status                    workstation-private/scripts/fleet-secrets
#   fv add ITEM [--var VAR] [--hosts H] [--agent] [--note TEXT] [--force]
#                                       prompt (hidden) -> vault item -> manifest row -> pull.
#                                       `{host}` in ITEM = this machine; no --var = vault-only.
#                                       --force rotates an existing item (old one: fv history).
#   fv copy ITEM [FIELD]                to the clipboard (checked), cleared after 45 s
#   fv inspect ITEM [FIELD]             print it to stdout
#                                       ITEM: exact name; a bare `vikunja-bot` -> vikunja-bot@<host>
#   fv ls | unlock | lock | sync | get | code | edit | rm | history
#                                       straight to rbw, always under RBW_PROFILE=fleet
#
# The profile is hard-set here rather than inherited: an EMPTY RBW_PROFILE is rbw's personal
# vault, and an unconfigured one silently talks to bitwarden.com (rbw src/dirs.rs). Prefer
# `fv copy` over `fv inspect` — inspect prints to the terminal, where scrollback keeps it.
# `fv get` is plain rbw: fuzzy name matching, no {host}, no @host fallback.
#
# ── the agent guard ──
# claude, codex and agy are wrapped so they start WITHOUT the fleet secrets in their environment,
# except rows the manifest marks agent=yes. It has to happen here, at launch: an agent inherits
# the environment of the shell that started it, and that shell has already sourced secrets.env
# (measured on mkDell 2026-10-01: every token in a Claude Code session's env, none of them from
# its shell snapshot). The names come from `fleet-secrets scrub-names`, which fails closed.
# Deliberately bypass with `command claude`. An agent started by something other than this shell
# (a herdr layout that execs it directly, a desktop launcher) is NOT covered.

# Resolved once, at source time: %x is this file only while it is being sourced.
typeset -g _FV_SELF=${${(%):-%x}:A}
typeset -g _FV_SCRIPT=${_FV_SELF:h:h:h}/workstation-private/scripts/fleet-secrets

_fv_rbw() {
  local d
  for d in "${XDG_CONFIG_HOME:-$HOME/.config}/rbw-fleet" "$HOME/Library/Application Support/rbw-fleet"; do
    [[ -r $d/config.json ]] && { RBW_PROFILE=fleet command rbw "$@"; return; }
  done
  print -u2 "fv: rbw profile 'fleet' is not configured — run dotfiles/install.sh (DF_DEV), then: RBW_PROFILE=fleet rbw login"
  return 1
}

fv() {
  local cmd=${1:-help}
  (( $# )) && shift
  case $cmd in
    pull|status|add|copy|inspect|scrub-names)
      [[ -x $_FV_SCRIPT ]] || { print -u2 "fv: $_FV_SCRIPT not found — clone workstation-private beside dotfiles"; return 1; }
      "$_FV_SCRIPT" $cmd "$@" ;;
    ls|list|unlock|unlocked|lock|sync|get|code|edit|rm|remove|history|search)
      _fv_rbw $cmd "$@" ;;
    help|-h|--help)
      sed -n '6,15s/^# \{0,1\}//p' $_FV_SELF ;;
    *) print -u2 "fv: unknown command '$cmd' — fv help"; return 2 ;;
  esac
}

# Completion never unlocks: item names are offered only while the vault is already open, so a
# <TAB> can never pop a pinentry.
_fv() {
  if (( CURRENT == 2 )); then
    compadd pull status add copy inspect ls unlock lock sync get code edit rm history help
  elif (( CURRENT == 3 )) && [[ $words[2] == (copy|inspect|get|code|edit|rm|history) ]]; then
    RBW_PROFILE=fleet command rbw unlocked 2>/dev/null || return 1
    local -a items
    items=(${(f)"$(RBW_PROFILE=fleet command rbw list 2>/dev/null)"})
    compadd -a items
  fi
}
(( $+functions[compdef] )) && compdef _fv fv

_fv_agent_exec() {
  local -a drop
  if [[ -x $_FV_SCRIPT ]]; then
    drop=(${(f)"$("$_FV_SCRIPT" scrub-names)"}) || {
      print -u2 "fv: cannot work out which secrets to withhold — not starting $1 with all of them."
      print -u2 "    Deliberately without the guard: command $1"
      return 1
    }
  fi
  # $commands[$1], not "$1": zsh's exec runs a FUNCTION of that name, i.e. this wrapper again.
  ( (( $#drop )) && unset $drop; exec $commands[$1] "${@:2}" )
}

() {
  local a
  for a in claude codex agy; do
    (( $+commands[$a] )) && functions[$a]="_fv_agent_exec $a \"\$@\""
  done
}
