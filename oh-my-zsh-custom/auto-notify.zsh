#!/usr/bin/env zsh
#
# zsh-auto-notify (MichaelAquilina) — commands that must NOT fire a desktop notification.
#
# HOW THE MATCHING ACTUALLY WORKS (read out of auto-notify.plugin.zsh, not recalled — the
# details below each change what a working entry looks like):
#
#   1. PREFIX match, not exact:   [[ "$target_command" == "$ignore"* ]]
#      So "claude" also covers "claude --resume", and "paru" covers "paru -Syu".
#   2. Only the LAST segment of a PIPELINE is tested (the string is split on "|").
#      `make | tee log` is judged as "tee log". Note it splits on "|" ONLY — a `&&` chain is
#      judged by its FIRST command (which is why the retired sys_upgrade alias, a `&&` chain
#      starting with `date`, could never have been listed below).
#   3. Tested AFTER ALIAS EXPANSION. This is the one that silently defeats an entry:
#      listing "s" does nothing, because `s` expands to `paru -Ss` before the hook sees it.
#      Functions and real binaries are NOT expanded, so `gitaw` (function), `herdr`, `claude`
#      and `z` all match as typed. Check with: whence -w <cmd>
#   4. A leading "sudo " is stripped first, so "paru" already covers "sudo paru".
#   5. Below AUTO_NOTIFY_THRESHOLD (default 10s) nothing notifies anyway — so short commands
#      need no entry, and everything here is listed because it RUNS LONG while you watch it.
#
# WHY `+=` AND NOT `=`: the plugin seeds its own 12 defaults (vim nvim less more man tig watch
# `git commit` top htop ssh nano) guarded by [[ -z "$AUTO_NOTIFY_IGNORE" ]], and oh-my-zsh
# sources custom/*.zsh AFTER plugins — so the array is already populated here and we append.
# Switching to `=` would silently drop all 12 defaults.

AUTO_NOTIFY_IGNORE+=(
    # ── Interactive AI / agent CLIs ────────────────────────────────────────────────
    # Long-running by nature and you are sitting in front of them; a "completed" toast on
    # every exit is pure noise. See oh-my-zsh-custom/agent-cli.zsh for these tools' shell
    # integration (and for why their installers must not be allowed to edit ~/.zshrc).
    #
    # All plain binaries, so they match literally (rule 3). Checked with `whence -w` on
    # mkMac2014, 2026-08-10:
    #   claude  present
    #   agy     present  — Antigravity
    #   codex   present on mkDell (package `openai-codex`); being rolled out to mkMac2014,
    #           mkDesktop and mkMac2017. Listing it on a machine that does not have it yet is
    #           harmless — an entry for a nonexistent command can never match.
    #
    # `gemini` was here until 2026-08-10 and is REMOVED: the Gemini CLI is no longer
    # supported, and `agy` is its working successor. It is also already absent from PATH
    # on this machine, so the entry had nothing left to match.
    "claude"
    "agy"
    "codex"

    # ── Terminal UIs ──────────────────────────────────────────────────────────────
    "herdr"          # /usr/bin/herdr — agent-aware terminal manager, a whole session
    "gitaw"          # zsh function (gita.zsh) — multi-repo panel
    "lazygit"        # not installed on every machine; harmless to pre-list
    "fzf"
    "atuin"

    # ── DELIBERATELY NOT LISTED: package management / system upkeep ───────────────
    # paru, topgrade and fresh are left NOISY on purpose (MK, 2026-08-10).
    # They are interactive, so they fit the pattern of everything above — but a long upgrade is
    # exactly the case where you wander off and want to be told it finished. Do not "fix" this
    # by adding them; the omission is the decision.
    # (`sys_upgrade` was listed here as a fourth until it was retired into topgrade on
    # 2026-08-19. It could not have been silenced from here anyway — it expanded to a `&&`
    # chain starting with `date`, and rule 2 splits on "|" only.)

    # ── Session / lock ────────────────────────────────────────────────────────────
    # hyprlock otherwise fires a notification every single time the screen is unlocked, since
    # the lock trivially outlives the 10s threshold.
    "hyprlock"

    # ── Follow-mode log readers ───────────────────────────────────────────────────
    # `journalctl -f` runs until you quit it. The prefix also covers plain `journalctl`,
    # which is fast enough never to notify regardless.
    "journalctl"

    # ── Pre-existing entries (kept) ───────────────────────────────────────────────
    "pnpm dev"
    "btop"
    "tldr"
    "tmux"
)

# ── Undo one plugin default: "top" ────────────────────────────────────────────────
# Because matching is a PREFIX match (rule 1), the plugin's built-in "top" entry also swallows
# "topgrade" — so simply *not listing* topgrade above was NOT enough to make it notify, which
# is the whole point of leaving the upgrade tools noisy. Measured, not assumed: with "top"
# present, _is_auto_notify_ignored "topgrade" returned "yes".
#
# There is no way to keep "top" and exempt "topgrade" — a prefix pattern cannot carve out a
# longer string. So "top" goes. The cost is nil here: btop is the monitor actually in use and
# is listed above, and "htop" is a separate default that this does not touch.
AUTO_NOTIFY_IGNORE=("${AUTO_NOTIFY_IGNORE[@]:#top}")
