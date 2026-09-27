#!/usr/bin/env zsh

# transfer — copying and moving big trees over slow links (SMB over Wi-Fi, ssh) with visible
# progress. Linked unconditionally by install.sh; rsync comes from its base-tools step (pairing rule).
#
#   rcopy SRC... DEST    rsync copy
#   rmove SRC... DEST    rsync move, then removes the emptied (local) source directories
#
# Trailing-slash semantics are rsync's: `src/` transfers the contents, `src` the directory itself.
# Plain paths only — an rsync option would be mistaken for a source by the cleanup below.
#
# Why not oh-my-zsh's `rsync-move`/`cpv`: --remove-source-files leaves every source directory
# behind, empty; a fixed -a floods SMB targets with chmod/chgrp errors; and a fixed -z is a no-op,
# because rsync only compresses on the wire — a mounted share is a LOCAL path to it. So both
# flags are decided per call instead:
#
#   -z  only when a SRC or DEST is remote (host:path, user@host:path, host::module, rsync://).
#   -a  only when the destination filesystem keeps what -a preserves — probed by writing a file
#       with an odd mode and a symlink. SMB/cifs mounts typically accept the chmod and report a
#       fixed mode, so the mode is read back rather than trusting chmod's exit status. Otherwise
#       -rt: contents and mtimes only. A remote DEST is assumed to be a POSIX filesystem (-a).
#
# macOS ships openrsync, which has per-file --progress only. GNU rsync (3.1+) adds --info=progress2,
# one line for the whole transfer — the view that matters for a big tree. Detected per call, so
# this still works (per-file) on a Mac without `port install rsync`.

# A colon before the first slash is rsync's own rule for "remote"; `./a:b` stays local.
_transfer_is_remote() {
  [[ $1 == rsync://* || ${1%%/*} == *:* ]]
}

# Does the filesystem that will receive DEST keep modes and symlinks?
_transfer_keeps_meta() {
  _transfer_is_remote $1 && return 0

  # DEST need not exist yet (rsync creates it) — probe the nearest existing ancestor.
  local d=$1
  [[ -d $d ]] || d=${d:h}
  while [[ ! -d $d ]]; do d=${d:h}; done

  local f l ok=1
  local -a m
  f=$(mktemp "$d/.transfer-probe.XXXXXX" 2>/dev/null) || return 1
  l=$f.link
  zmodload -F zsh/stat b:zstat
  if chmod 741 $f 2>/dev/null && zstat -A m +mode -- $f && (( (m[1] & 8#7777) == 8#741 )) \
      && ln -s ${f:t} $l 2>/dev/null && [[ -L $l ]]; then
    ok=0
  fi
  rm -f -- $f $l
  return $ok
}

# _transfer copy|move SRC... DEST
_transfer() {
  local op=$1; shift
  local name=r$op
  (( $# >= 2 )) || { print -u2 "usage: $name SRC... DEST"; return 2; }

  local -a opts=(-h) why=()
  if _transfer_keeps_meta ${@[-1]}; then
    opts+=(-a); why+=('-a: target keeps permissions')
  else
    opts+=(-rt); why+=('-rt: target does not keep permissions')
  fi

  local a
  for a in "$@"; do
    if _transfer_is_remote $a; then opts+=(-z); why+=("-z: $a is remote"); break; fi
  done

  # openrsync also prints an `rsync version 2.6.9 compatible` line, so test the version, not the name.
  if rsync --version 2>/dev/null | grep -Eq '^rsync +version (3\.[1-9]|[4-9])'; then
    opts+=(--info=progress2 --no-inc-recursive)
  else
    opts+=(--progress)
  fi

  [[ $op == move ]] && opts+=(--remove-source-files)

  print -u2 "$name: ${(j:, :)why}"
  # Only continues when rsync exits 0, so a partial transfer (exit 23/24) leaves the source intact.
  rsync $opts "$@" || return
  [[ $op == move ]] || return 0

  local src
  for src in "${@[1,-2]}"; do
    if _transfer_is_remote $src; then
      print -u2 "$name: $src is remote — its emptied directories were left in place"
    elif [[ $src == */ ]]; then
      find "$src" -mindepth 1 -type d -empty -delete
    elif [[ -d $src ]]; then
      find "$src" -type d -empty -delete
    fi
  done
}

rcopy() { _transfer copy "$@"; }
rmove() { _transfer move "$@"; }
