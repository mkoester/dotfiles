# Pending per-machine migrations

**What this file is for.** Most changes here take effect by pulling and re-running `install.sh`.
A few do not: they need a step run **once per machine**, in an order that matters, and usually on
a machine nobody is sitting at when the change is made. Those go here, newest first, and stay
until every machine has had them — then the entry is deleted, not ticked off.

**Why it exists as a file.** The alternative was a hand-over in a chat session, which is read
once and then gone; the failure mode this repo keeps hitting is a step that was *described*
somewhere and never *ran* anywhere (see `README.md` on units that are stowed but not enabled, and
on a member repo that was invisible on fresh machines for six weeks). A file in the repo that the
change itself is in is the shortest path between the two.

**Rules for an entry.** One heading per change, dated. Say which machines it applies to, give the
commands verbatim and in order, and — this is the part that earns the file — say **what breaks if
the order is wrong**, because an entry whose steps look independent will be run in any order.

---

## 2026-09-22 — hyprlock, swayidle and `screen-blank.sh` removed

**Applies to:** every machine that has ever run `install.sh` with `DF_DESKTOP=1`. Done on
`mkDesktop`. **Still pending on `mkMac2014` and `mkDell`.**

DMS now owns both the screen lock and the idle timers, and does fingerprint unlock itself
(`enableFprint`) — see `README.md` § "Screen lock and idle". The locker, the two `swayidle-*`
units and `screen-blank.sh` are deleted from this repo.

**`mkMac2014` must run step 1 before step 3, and this is a security question, not tidiness.**
Its `dms/overlay.json` in `workstation-private` set `acLockTimeout` / `batteryLockTimeout` to `0`
and `lockBeforeSuspend` to `false`, because swayidle was doing the locking there. That overlay is
now deleted too. Remove swayidle without re-deploying the settings first and the laptop **stops
locking at all** — it will not warn you, and the screen simply never locks again.

```sh
# 1. DMS takes over the idle policy (mkMac2014: this is what replaces the deleted overlay)
cd ~/src/dotfiles && git pull && ./scripts/dms-settings-deploy && dms restart

# 2. Confirm it actually took: a non-zero lock timeout, and fingerprint enabled
python3 -c 'import json;d=json.load(open("'"$HOME"'/.config/DankMaterialShell/settings.json"));print({k:d[k] for k in ("acLockTimeout","batteryLockTimeout","lockBeforeSuspend","enableFprint")})'

# 3. Only now: unstow the locker and drop the idle units
cd ~/src/dotfiles/config-stow && stow -D -t "$HOME" hyprlock
systemctl --user disable --now swayidle-laptop.service swayidle-desktop.service
rm -f ~/.config/systemd/user/swayidle-laptop.service \
      ~/.config/systemd/user/swayidle-desktop.service \
      ~/.config/systemd/user/screen-blank.sh
systemctl --user daemon-reload
paru -Rns hyprlock swayidle

# 4. Fingerprint on the lock screen (skip on a machine with no reader — the setting is inert there)
dms auth sync -t
fprintd-verify            # prints "verify-match" on a good finger
```

**If you already pulled before unstowing**, `stow -D hyprlock` is a silent no-op — stow decides
what to unlink from the package's *contents*, and they are gone. Delete the four symlinks by hand
(`~/.config/hypr/hyprlock.conf` and the three under `~/.config/systemd/user/`); that is all the
unstow would have done.

**Verify, on the machine, before calling it done:** lock with `SUPER+ALT+L`, touch the sensor, and
confirm it unlocks without a keypress. Then leave it idle past the timeout from step 2 and confirm
it locks on its own. The second half is the one that is easy to skip and is exactly what the
ordering trap above breaks.
