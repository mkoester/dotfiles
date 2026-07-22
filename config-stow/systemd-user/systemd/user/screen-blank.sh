#!/usr/bin/env bash
# swayidle blank helper — dim the backlight to 0 on idle and restore it on resume, WITHOUT
# DPMS-off, so an external DisplayPort monitor keeps its link up and waybar survives. (The
# separate DPMS "off" idle tier still power-cycles it, but that's a deeper stage and the
# waybar-watchdog restores the bar.) See Workstation-Documentation/desktop/waybar-supervision.md.
#
#   Usage: screen-blank.sh dim|restore ddc|internal
#
# ddc backend prerequisites: ddcutil installed, the i2c-dev kernel module loaded, and the
# user in the i2c group (or an equivalent udev rule).
set -uo pipefail
action="${1:?usage: screen-blank.sh dim|restore ddc|internal}"
backend="${2:?usage: screen-blank.sh dim|restore ddc|internal}"
state="${XDG_RUNTIME_DIR:-/tmp}/screen-blank.${backend}"

case "$backend" in
  internal)
    case "$action" in
      dim)     brightnessctl -m get >"$state"; brightnessctl set 0 ;;
      restore) brightnessctl set "$(cat "$state" 2>/dev/null || echo 50%)" ;;
    esac
    ;;
  ddc)
    case "$action" in
      dim)
        # Save each detected monitor's current brightness (VCP 0x10) keyed by its I2C bus
        # (stable per connector, unlike ddcutil display numbers which reorder on DP hotplug),
        # then set it to 0.
        : >"$state"
        while read -r bus; do
          cur=$(ddcutil --terse --bus "$bus" getvcp 10 2>/dev/null | awk '{print $4}')
          [ -n "${cur:-}" ] && printf '%s %s\n' "$bus" "$cur" >>"$state"
          ddcutil --bus "$bus" setvcp 10 0 2>/dev/null
        done < <(ddcutil detect 2>/dev/null | sed -n 's|.*/dev/i2c-\([0-9]\+\).*|\1|p')
        ;;
      restore)
        while read -r bus v; do
          ddcutil --bus "$bus" setvcp 10 "$v" 2>/dev/null
        done <"$state"
        ;;
    esac
    ;;
  *) echo "unknown backend: $backend" >&2; exit 2 ;;
esac
