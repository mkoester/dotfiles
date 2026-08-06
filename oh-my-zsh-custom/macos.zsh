#!/usr/bin/env zsh

# macos — Darwin-only shell setup: Homebrew's environment, then a GNU userland ahead of the
# BSD one. Linked unconditionally by install.sh (like host-env.zsh) and self-guarding, so it
# costs a single [[ ]] test on every Linux machine in the fleet and needs no DF_* flag.
#
# Why the GNU half exists at all: Homebrew installs these formulae with a `g` prefix — gtar,
# gsed, ggrep, gfind, gawk — specifically so they do NOT shadow the system tools. That is the
# safe default and it is also the trap: a script written on the Linux boxes calls plain `tar`
# or `sed -i` or `grep -P`, still gets BSD, and still fails. Each formula additionally ships a
# libexec/gnubin directory holding the same binaries under their UNPREFIXED names, so putting
# those on PATH is what actually makes Linux scripts run.
#
# Note this also fixes bash: macOS still ships 3.2 (2007) at /bin/bash — no associative arrays,
# no mapfile, no ${var^^} — and `brew install bash` puts 5.x in Homebrew's bin. The fleet's
# `#!/usr/bin/env bash` convention (OKF practices) is what lets that take effect; a hardcoded
# #!/bin/bash would still get the 2007 one.

[[ $OSTYPE == darwin* ]] || return 0

# Homebrew lives at /usr/local on Intel and /opt/homebrew on Apple silicon. Ask brew rather than
# branching on the architecture, and let it set HOMEBREW_PREFIX for the block below.
() {
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x $b ]]; then
      eval "$("$b" shellenv)"
      return 0
    fi
  done
  return 0
}

[[ -n $HOMEBREW_PREFIX ]] || return 0

() {
  local f d
  local -a gnuman

  # Unprefixed GNU binaries. Prepended, so they win over /usr/bin.
  for f in coreutils gnu-tar gnu-sed grep findutils gawk; do
    d=$HOMEBREW_PREFIX/opt/$f/libexec/gnubin
    [[ -d $d ]] && path=($d $path)

    d=$HOMEBREW_PREFIX/opt/$f/libexec/gnuman
    [[ -d $d ]] && gnuman+=($d)
  done

  # gnu-getopt is keg-only and ships no gnubin — its binary sits in the normal bin/. Worth
  # having: BSD getopt has no long options, which breaks any script using --foo=bar parsing.
  d=$HOMEBREW_PREFIX/opt/gnu-getopt/bin
  [[ -d $d ]] && path=($d $path)

  # The TRAILING colon matters: without it MANPATH becomes exhaustive and `man ls` would find
  # the GNU page but `man launchctl` nothing at all. An empty entry means "and the system path".
  (( $#gnuman )) && export MANPATH="${(j.:.)gnuman}:${MANPATH#:}"

  return 0
}

# Drop duplicate PATH entries (a re-sourced rc file would otherwise stack them).
typeset -U path

return 0
