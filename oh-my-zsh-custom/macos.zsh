#!/usr/bin/env zsh

# macos — Darwin-only shell setup: the package managers' environments, then a GNU userland ahead
# of the BSD one. Linked unconditionally by install.sh (like host-env.zsh) and self-guarding, so
# it costs a single [[ ]] test on every Linux machine in the fleet and needs no DF_* flag.
#
# BOTH managers are handled, because mkMac2017 has both (2026-09-21). Homebrew moved Intel macOS
# to Tier 3 on 2026-09-13 — no new bottles, and `brew` stops running on Intel after 2027-09-01 —
# so formulae come from MacPorts, which still ships darwin_24.x86_64 archives. Homebrew stays for
# CASKS only, which MacPorts has no concept of. Keeping it formula-free is also what keeps
# /usr/local/lib and /usr/local/include empty, the collision MacPorts warns about.
#
# Why the GNU half exists at all: both managers install these tools with a `g` prefix — gtar,
# gsed, ggrep, gfind, gawk — specifically so they do NOT shadow the system tools. That is the
# safe default and it is also the trap: a script written on the Linux boxes calls plain `tar`
# or `sed -i` or `grep -P`, still gets BSD, and still fails. Each also ships a libexec/gnubin
# directory holding the same binaries under their UNPREFIXED names, so putting those on PATH is
# what actually makes Linux scripts run.
#
# The two managers differ in exactly one structural way here, read out of the Portfiles rather
# than assumed: MacPorts' coreutils, gsed, grep, findutils, gawk and gnutar all populate ONE
# SHARED ${prefix}/libexec/gnubin, where Homebrew gives each formula its own. So the MacPorts
# block below is one PATH entry and the Homebrew block is a loop over six.
#
# Note this also fixes bash: macOS still ships 3.2 (2007) at /bin/bash — no associative arrays,
# no mapfile, no ${var^^} — and `port install bash` puts 5.x in /opt/local/bin (`brew install
# bash` in Homebrew's bin). The fleet's `#!/usr/bin/env bash` convention (OKF practices) is what
# lets that take effect; a hardcoded #!/bin/bash would still get the 2007 one.
#
# PAIRING RULE — this file is inert without the packages, and the packages are invisible without
# this file. install.sh's GNU-userland step is the other half. They shipped unpaired once already
# (found 2026-08-16): every [[ -d $d ]] failed silently and PATH *looked* configured.

[[ $OSTYPE == darwin* ]] || return 0

# ── MacPorts ──
# Fixed prefix, unlike Homebrew: MacPorts is /opt/local on every Mac, Intel or Apple silicon.
() {
  [[ -x /opt/local/bin/port ]] || return 0

  local -a mp
  mp=(/opt/local/bin /opt/local/sbin)

  # The shared gnubin goes AHEAD of /opt/local/bin so the unprefixed names win over anything
  # MacPorts put there under the same name, and both go ahead of /usr/bin.
  [[ -d /opt/local/libexec/gnubin ]] && mp=(/opt/local/libexec/gnubin $mp)

  path=($mp $path)

  # The TRAILING colon matters: without it MANPATH becomes exhaustive and `man ls` would find
  # the GNU page but `man launchctl` nothing at all. An empty entry means "and the system path".
  local -a mpman
  [[ -d /opt/local/libexec/gnubin/man ]] && mpman+=(/opt/local/libexec/gnubin/man)
  [[ -d /opt/local/share/man ]]          && mpman+=(/opt/local/share/man)
  (( $#mpman )) && export MANPATH="${(j.:.)mpman}:${MANPATH#:}"

  return 0
}

# ── Homebrew ──
# Casks only on mkMac2017, but the formula handling below is kept correct rather than deleted:
# it costs nothing where no formula is installed (every [[ -d ]] simply fails) and it is still
# right for any future Apple-silicon machine, where Homebrew is Tier 1 and MacPorts is not
# needed. Homebrew lives at /usr/local on Intel and /opt/homebrew on Apple silicon — ask brew
# rather than branching on the architecture, and let it set HOMEBREW_PREFIX for the block below.
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

if [[ -n $HOMEBREW_PREFIX ]]; then
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
    # (MacPorts has no getopt port of its own — `getopt` is obsolete, replaced by util-linux,
    # which puts it straight in /opt/local/bin, so the MacPorts block above needs no equivalent
    # line.)
    d=$HOMEBREW_PREFIX/opt/gnu-getopt/bin
    [[ -d $d ]] && path=($d $path)

    (( $#gnuman )) && export MANPATH="${(j.:.)gnuman}:${MANPATH#:}"

    return 0
  }
fi

# Drop duplicate PATH entries (a re-sourced rc file would otherwise stack them).
typeset -U path

return 0
