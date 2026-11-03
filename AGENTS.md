# dotfiles — agent notes

- **Never stow `~/.codex/config.toml`.** Codex writes it itself (project trust, `hooks.state`
  hashes, `[tui]`), so a tracked copy turns machine state into diffs in this public repo. Shared
  Codex policy goes in `system/codex/config.toml`, which `install.sh` copies to the system layer
  `/etc/codex/config.toml`.
