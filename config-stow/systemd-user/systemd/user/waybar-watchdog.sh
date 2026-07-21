#!/usr/bin/env bash
# Waybar #3400 workaround — restart waybar after an output add/remove so the bar
# re-renders cleanly.
#
# The GTK output-change bug leaves the waybar *process alive* but the bar on a
# re-added output invisible (a `.configure` desync: waybar logs a "successful" re-add
# that never renders — no crash, no critical). So neither Restart=always nor
# G_DEBUG=fatal-criticals catches it; only a full restart does. We trigger on the exact
# symptom waybar logs on any output removal, which is cause-agnostic (monitor sleep/wake,
# hotplug, docking, kanshi switch).
# See Workstation-Documentation/desktop/waybar-supervision.md §3.
set -uo pipefail

pending=0
# -u follows the unit across restarts; -n0 starts at "now" (no history replay);
# -o cat prints just the message text.
journalctl --user -u waybar.service -f -n0 -o cat | \
while true; do
  if (( pending )); then
    # Debounce: after an output was removed, wait for the journal to fall quiet for 3s
    # (absorbing the remove -> ".configure timeout" -> reconfigure burst) so we restart
    # once, after the output has settled — restarting mid-transition would just re-hit
    # the same buggy mid-life add.
    if read -r -t 3 line; then
      : # more activity — keep waiting, extends the debounce window
    else
      systemctl --user restart waybar.service
      pending=0
      continue
    fi
  else
    read -r line || break   # EOF = journalctl exited; leave, systemd Restart= brings us back
  fi
  case "$line" in
    *"Bar removed from output"*) pending=1 ;;
  esac
done
