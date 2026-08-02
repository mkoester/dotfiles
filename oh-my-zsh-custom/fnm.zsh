#!/usr/bin/env zsh

# fnm — Fast Node Manager. https://github.com/Schniz/fnm
#
# Guarded like atuin.zsh: install.sh links this file when the "Node machine?" question is
# answered yes, but on a distro with no fnm package (Fedora, plain Debian) it only *prints* an
# install hint — so the link can legitimately exist before the binary does. Without the guard
# every new shell on such a host opens with `command not found: fnm`.
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi
