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
# convention as the paperless taxonomy ↔ tagger prompt).

# _q_run <svc> <cmd...> — run <cmd...> as the service user with the user-systemd
# runtime dir set, exactly as the guidelines document. Internal helper.
_q_run() {
  local svc=$1; shift
  local uid; uid=$(id -u "$svc") || return 1
  sudo -u "$svc" "XDG_RUNTIME_DIR=/run/user/$uid" "$@"
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
  sudo -u "$svc" podman run --rm -it "$image" "${cmd[@]}"
}
