#!/usr/bin/env zsh

# lesspipe is a source build on every platform (see README § lesspipe), so its location is a
# property of how it was configured, not of the OS. This used to hardcode /usr/local/bin, which
# is autotools' default prefix and therefore right on Linux and on an Intel Homebrew Mac — and
# silently wrong on a MacPorts machine (/opt/local) or Apple silicon (/opt/homebrew). A wrong
# LESSOPEN does not error: `less` just shows the raw bytes, which reads as "lesspipe isn't
# working" rather than as "that path does not exist".
#
# Probe instead. `command -v` covers anything already on PATH; the explicit prefixes cover the
# case where it was installed somewhere PATH does not reach.
() {
  local p
  for p in \
    "$(command -v lesspipe.sh 2>/dev/null)" \
    /usr/local/bin/lesspipe.sh \
    /opt/local/bin/lesspipe.sh \
    "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/lesspipe.sh"
  do
    if [[ -n $p && -x $p ]]; then
      export LESSOPEN="|$p %s"
      return 0
    fi
  done
  return 0
}
