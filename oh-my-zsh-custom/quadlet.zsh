#!/usr/bin/env zsh

# quadlet — helpers for managing rootless-Podman quadlet services.
#
# SERVER-SIDE ONLY. Link this file only on a quadlet HOST (a server that actually
# runs the services). It is deliberately NOT part of the workstation set — the
# workstation is not the server, and these functions run privileged commands
# against local service users. The dotfiles installer links it behind the
# "Quadlet host?" question.
#
# Every service follows the same model (one dedicated user == service name, lingering
# rootless user systemd instance), so every management command shares one prefix:
#
#     sudo -u <svc> XDG_RUNTIME_DIR=/run/user/$(id -u <svc>) systemctl --user <verb> ...
#
# These wrappers collapse that boilerplate. <svc> is the service/user name; the
# default container is systemd-<svc> (the quadlet ContainerName default) and the
# default unit is <svc>; multi-container services pass the extra unit/container names.
#
# SOURCE OF TRUTH: quadlet-my-guidelines/README.md § "Operations" / "Frequently used
# commands" / "Debugging". Keep this file in sync with that doc — a change to the
# operational model there should be mirrored here, and vice versa (same two-way sync
# convention as the paperless taxonomy ↔ tagger prompt). The setup helpers (qsetup/qlink/
# qbackup-init/qpull) mirror the Setup and Backup sections every quadlet-* README repeats:
# user <svc>, repo cloned to ~<svc>/quadlet-<svc>, *.container/*.network/*.env symlinked into
# ~/.config/containers/systemd, *.service/*.timer into ~/.config/systemd/user.

# _q_run <svc> <cmd...> — run <cmd...> as the service user with the user-systemd
# runtime dir set, exactly as the guidelines document. Internal helper.
_q_run() {
  local svc=$1; shift
  local uid; uid=$(id -u "$svc") || return 1
  sudo -u "$svc" "XDG_RUNTIME_DIR=/run/user/$uid" "$@"
}

# _q_home <svc> — the service user's home, from the passwd database. Internal helper.
_q_home() {
  local home; home=$(getent passwd "$1" | cut -d: -f6)
  if [[ -z $home ]]; then print -u2 "quadlet: no such user: $1"; return 1; fi
  print -r -- "$home"
}

# _q_services — the service users: lingering users whose home is under /var/lib (so not
# your own login). The linger directory is world-readable; service homes are not.
_q_services() {
  local u
  for u in ${_Q_LINGER_DIR:-/var/lib/systemd/linger}/*(N:t); do
    [[ $(getent passwd "$u" | cut -d: -f6) == /var/lib/* ]] && print -r -- "$u"
  done
  return 0
}

# qctl <svc> <verb> [units...] — systemctl --user <verb> on the service unit(s).
# Default unit is <svc>; pass extra names for multi-container services, e.g.
#   qctl joplin restart joplin-db joplin
#   qctl linkding status
#   qctl atuin enable --now atuin-backup.timer
qctl() {
  if (( $# < 2 )); then print -u2 "usage: qctl <svc> <verb> [units...]"; return 2; fi
  local svc=$1 verb=$2; shift 2
  local units=("$@"); (( $#units )) || units=("$svc")
  _q_run "$svc" systemctl --user "$verb" "${units[@]}"
}

# qreload <svc> — daemon-reload, after editing .container / .network files.
qreload() {
  if (( $# != 1 )); then print -u2 "usage: qreload <svc>"; return 2; fi
  _q_run "$1" systemctl --user daemon-reload
}

# qlog <svc> [unit] [journalctl-args...] — journalctl --user -u <unit> (default <svc>).
# A non-flag second word is taken as the unit; the rest passes through. Default -n 50.
#   qlog joplin              # last 50 lines of the joplin unit
#   qlog joplin joplin-db -f # follow the db unit
#   qlog atuin -n 200        # 2nd word is a flag, so unit stays = atuin
qlog() {
  if (( $# < 1 )); then print -u2 "usage: qlog <svc> [unit] [journalctl-args...]"; return 2; fi
  local svc=$1; shift
  local unit=$svc
  if (( $# )) && [[ $1 != -* ]]; then unit=$1; shift; fi
  if (( $# == 0 )); then set -- -n 50; fi
  _q_run "$svc" journalctl --user -u "$unit" "$@"
}

# qexec [-c <container>] <svc> <cmd...> — podman exec -it into the container.
# Default container is systemd-<svc>; pass -c for services that set their own
# ContainerName= (e.g. rustdesk-hbbs).
#   qexec linkding python manage.py changepassword alice
#   qexec -c rustdesk-hbbs rustdesk sh
qexec() {
  local container=""
  if [[ $1 == -c ]]; then container=$2; shift 2; fi
  if (( $# < 2 )); then print -u2 "usage: qexec [-c <container>] <svc> <cmd...>"; return 2; fi
  local svc=$1; shift
  : ${container:=systemd-$svc}
  _q_run "$svc" podman exec -it "$container" "$@"
}

# qplog [-c <container>] <svc> — follow a container's podman logs (default systemd-<svc>).
qplog() {
  local container=""
  if [[ $1 == -c ]]; then container=$2; shift 2; fi
  if (( $# != 1 )); then print -u2 "usage: qplog [-c <container>] <svc>"; return 2; fi
  local svc=$1
  : ${container:=systemd-$svc}
  _q_run "$svc" podman logs -f "$container"
}

# qupdate <svc> — trigger podman auto-update manually.
qupdate() {
  if (( $# != 1 )); then print -u2 "usage: qupdate <svc>"; return 2; fi
  _q_run "$1" podman auto-update
}

# qvalidate <svc> — dry-run the quadlet generator to check .container/.network parsing.
# (No XDG_RUNTIME_DIR needed — matches the guidelines.)
qvalidate() {
  if (( $# != 1 )); then print -u2 "usage: qvalidate <svc>"; return 2; fi
  sudo -u "$1" /usr/lib/systemd/system-generators/podman-system-generator --user --dryrun 2>&1
}

# qsh <svc> <image> [cmd...] — run <image> interactively as the service user, bypassing
# systemd (default cmd /bin/sh). Useful for checking mounts / env / user mapping.
qsh() {
  if (( $# < 2 )); then print -u2 "usage: qsh <svc> <image> [cmd...]"; return 2; fi
  local svc=$1 image=$2; shift 2
  local cmd=("$@"); (( $#cmd )) || cmd=(/bin/sh)
  _q_run "$svc" podman run --rm -it "$image" "${cmd[@]}"
}

# qpodman <svc> <podman-args...> — any podman command as the service user.
#   qpodman joplin ps
#   qpodman paperless image inspect ghcr.io/paperless-ngx/paperless-ngx:3.2
qpodman() {
  if (( $# < 2 )); then print -u2 "usage: qpodman <svc> <podman-args...>"; return 2; fi
  local svc=$1; shift
  _q_run "$svc" podman "$@"
}

# qls — every service with its units and timers (units named <svc>*, plus podman-*).
qls() {
  if (( $# )); then print -u2 "usage: qls"; return 2; fi
  local svc
  for svc in $(_q_services); do
    print -P "%B$svc%b"
    _q_run "$svc" systemctl --user list-units --all --no-legend --plain "$svc*" 'podman-*'
  done
}

# qlink <svc> — (re)link the repo's quadlet files into place. Idempotent: run it again
# after the repo gains a file. Top-level *.container/*.network/*.env (incl. the local
# *.override.env, never *.template) → ~/.config/containers/systemd;
# *.service/*.timer → ~/.config/systemd/user. Listing runs as the service user, because
# its home is not readable by yours.
qlink() {
  if (( $# != 1 )); then print -u2 "usage: qlink <svc>"; return 2; fi
  local svc=$1 home repo f dest
  home=$(_q_home "$svc") || return 1
  repo=$home/quadlet-$svc
  local -a files
  files=(${(f)"$(_q_run "$svc" find "$repo" -maxdepth 1 -type f \
    \( -name '*.container' -o -name '*.network' -o -name '*.env' \
       -o -name '*.service' -o -name '*.timer' \))"})
  if (( ! $#files )); then print -u2 "qlink: no quadlet files in $repo"; return 1; fi
  _q_run "$svc" mkdir -p "$home/.config/containers/systemd" "$home/.config/systemd/user" || return 1
  for f in ${(o)files}; do
    case $f in
      *.service|*.timer) dest=$home/.config/systemd/user ;;
      *)                 dest=$home/.config/containers/systemd ;;
    esac
    _q_run "$svc" ln -sfn "$f" "$dest/${f:t}" || return 1
    print -r -- "linked ${f:t} → ~$svc/${dest#$home/}/"
  done
}

# qsetup <svc> [repo-url] — first-time setup of a quadlet service (README steps 1–6):
# service user (skipped if it exists), linger, clone to ~<svc>/quadlet-<svc>, every
# *.override.env.template copied to *.override.env where none exists yet, then qlink.
# repo-url defaults to the quadlet-<svc> naming convention; a wrong one fails at clone.
# Service-specific steps (data dirs, secrets, UID checks) stay in the repo's README.
qsetup() {
  if (( $# < 1 || $# > 2 )); then print -u2 "usage: qsetup <svc> [repo-url]"; return 2; fi
  local svc=$1 url=${2:-https://github.com/mkoester/quadlet-$1.git}
  if ! getent passwd "$svc" >/dev/null; then
    sudo useradd -m -d "/var/lib/$svc" -s /usr/sbin/nologin "$svc" || return 1
  fi
  sudo loginctl enable-linger "$svc" || return 1
  local home repo t
  home=$(_q_home "$svc") || return 1
  repo=$home/quadlet-$svc
  if _q_run "$svc" test -d "$repo/.git"; then
    print -r -- "repo already cloned: $repo (qpull $svc to update)"
  else
    _q_run "$svc" git clone "$url" "$repo" || return 1
  fi
  for t in ${(f)"$(_q_run "$svc" find "$repo" -maxdepth 1 -type f -name '*.override.env.template')"}; do
    if _q_run "$svc" test -e "${t%.template}"; then
      print -r -- "kept existing ${${t%.template}:t}"
    else
      _q_run "$svc" cp "$t" "${t%.template}" || return 1
      print -r -- "created ${${t%.template}:t} from template — fill it in"
    fi
  done
  qlink "$svc" || return 1
  print -r -- "next: the README's service-specific steps, then qreload $svc && qctl $svc start"
}

# qbackup-init <svc> — /var/backups/<svc> (owned <svc>:backup-readers, 2750), link the
# repo's units, enable <svc>-backup.timer. Needs the one-time server setup (backup-readers
# group, backupuser) from quadlet-my-guidelines § Backup.
qbackup-init() {
  if (( $# != 1 )); then print -u2 "usage: qbackup-init <svc>"; return 2; fi
  local svc=$1 dir=/var/backups/$1
  sudo mkdir -p "$dir" && sudo chown "$svc:backup-readers" "$dir" && sudo chmod 2750 "$dir" || return 1
  qlink "$svc" && qreload "$svc" && qctl "$svc" enable --now "$svc-backup.timer"
}

# qpull <svc> — deploy repo changes: git pull --ff-only as the service user, show what
# came in, qlink (new files), qreload. Stops before daemon-reload if the quadlet generator
# exits non-zero. Does NOT restart — run qctl <svc> restart [units...] when ready.
qpull() {
  if (( $# != 1 )); then print -u2 "usage: qpull <svc>"; return 2; fi
  local svc=$1 repo out before
  repo=$(_q_home "$svc")/quadlet-$svc || return 1
  before=$(_q_run "$svc" git -C "$repo" rev-parse HEAD) || return 1
  _q_run "$svc" git -C "$repo" pull --ff-only || return 1
  _q_run "$svc" git -C "$repo" log --oneline "$before..HEAD"
  qlink "$svc" || return 1
  if ! out=$(qvalidate "$svc"); then print -r -- "$out"; return 1; fi
  qreload "$svc" && print -r -- "reloaded; restart when ready: qctl $svc restart"
}

# Tab-complete the <svc> argument from the service users (compinit has run by the time
# oh-my-zsh sources custom files).
_q_complete() {
  if (( CURRENT == 2 )); then compadd -- $(_q_services); else _default; fi
}
if (( $+functions[compdef] )); then
  compdef _q_complete qctl qreload qlog qexec qplog qupdate qvalidate qsh qpodman qlink qbackup-init qpull
fi
