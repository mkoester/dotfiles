#!/usr/bin/env zsh

# update-os for a MacPorts machine that keeps Homebrew for casks (mkMac2017).
#
# Four managers' worth of work in one alias, in dependency order:
#   port selfupdate      refresh the ports tree first, or `upgrade outdated` sees a stale index
#   port -u upgrade      -u uninstalls the now-inactive old versions as it goes, which matters on
#                        a machine whose disk is the scarce resource
#   brew upgrade --cask  the GUI apps; no formula is installed here, so nothing else is touched
#   brew cu -y -a        the casks `brew upgrade --cask` SKIPS — the ones marked auto_updates or
#                        version :latest, which is most of them. NOT part of Homebrew: it comes
#                        from the buo/cask-upgrade tap, and without that tap this line dies with
#                        `Unknown command: cu` after everything before it has already run, which
#                        reads as a half-finished update rather than as a missing tap:
#                            brew tap buo/cask-upgrade
#   port reclaim         last, and after the brew cleanup, because it prompts
#
# The leading `df` is the fleet convention: see the disk situation before a run that consumes it,
# on a machine where /System/Volumes/Data and the swap volume tell different stories.
#
# NOT here: `softwareupdate`. macOS upgrades are triggered by hand on this machine because every
# one of them wipes the OCLP root patch and takes Wi-Fi with it — see workstation-private's
# MACOS-BASELINE.md § "OCLP root patches must be reapplied after every macOS update".
alias update-os="df -H / /System/Volumes/Data /private/var/vm \
  && sudo port selfupdate \
  && sudo port -u upgrade outdated \
  && brew upgrade --cask && brew cu -y -a && brew cleanup \
  && sudo port reclaim"
