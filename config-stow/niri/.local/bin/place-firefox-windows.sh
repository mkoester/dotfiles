#!/usr/bin/env bash
# place-firefox-windows.sh — re-home restored single-profile Firefox windows onto
# workspaces by title. A post-restore sweep, i3-`assign` equivalent.
#
# Why a sweep and not a niri window-rule: `open-on-workspace` is an *opening* property,
# so it can't re-home windows whose titles only settle after session restore. See
# Workstation-Documentation/desktop/niri-window-placement.md for the full rationale.
#
# Titles are only a stable anchor if you name the windows — the Winger Firefox extension
# prepends a persistent window name via `titlePreface`; match on that name prefix.
# Run with --dry-run first to tune RULES without moving anything.
set -euo pipefail

# title substring (jq regex `test`)  ->  workspace reference (index number or name)
declare -A RULES=(
  ["^mail"]=2
  ["^work"]=3
  ["^mon"]="mon"
)

APP_ID="firefox"                 # confirmed: niri msg --json windows | jq -r '.[].app_id'
EXPECT="${#RULES[@]}"            # wait for at least this many firefox windows
DRYRUN="${1:-}"                  # pass --dry-run to print instead of move

# Wait out session restore: poll until the firefox windows exist (max ~15s).
for _ in $(seq 1 30); do
  n="$(niri msg --json windows | jq -r --arg a "$APP_ID" \
        '[.[]|select(.app_id==$a)]|length')"
  [ "$n" -ge "$EXPECT" ] && break
  sleep 0.5
done

wins="$(niri msg --json windows)"
for pat in "${!RULES[@]}"; do
  ws="${RULES[$pat]}"
  id="$(jq -r --arg a "$APP_ID" --arg p "$pat" \
        'map(select(.app_id==$a and (.title|test($p)))) | .[0].id // empty' <<<"$wins")"
  if [ -z "$id" ]; then
    printf 'no firefox window matched /%s/\n' "$pat" >&2
  elif [ "$DRYRUN" = "--dry-run" ]; then
    printf 'would move win %s (/%s/) -> ws %s\n' "$id" "$pat" "$ws"
  else
    niri msg action move-window-to-workspace --window-id "$id" --focus false "$ws"
  fi
done
