# dotfiles

My working environment on every machine (macOS laptop, Linux lab machines, a rootless
Slurm GPU server), declared with [home-manager](https://github.com/nix-community/home-manager)
flakes: zsh + starship, tmux, ssh routing, a modern CLI toolset, Claude Code, encrypted
shared credentials, and machines that keep themselves in sync.

## Everyday commands

| Command | Does |
|---|---|
| `dots-sync "msg"` | commit this repo's changes, apply here, push, update every machine |
| `dots-status` | every machine: applied commit, last sync, current / behind / failing |
| `zhelp` | the shell's keys, shorthands, aliases and functions |
| `ta` | tmux: attach, or start a session |
| `dots-secret` | add / edit encrypted secrets |
| `gpus`, `sgpu`, `snew`, `sq` | Slurm on snoopy |
| `vim` | Neovim with Python/ROS-aware LSP, debugger, REPL (`Space` shows the keys) |
| `c`, `cr`, `cco` | Claude Code: start, resume, continue (`codex` for Codex) |

## Documentation

| | |
|---|---|
| [Setup](docs/setup.md) | install on a machine (with or without root), add a machine |
| [Sync](docs/sync.md) | `dots-sync`, hourly pulls, `dots-status`, updates, CI, garbage collection, troubleshooting |
| [Shell](docs/shell.md) | zsh keys, shorthands, aliases, tools, prompt, Python |
| [tmux](docs/tmux.md) | keys, saved sessions, clipboard over ssh, theme |
| [SSH](docs/ssh.md) | hosts, LAN → Tailscale → school routes, connection reuse, host and login keys |
| [Secrets](docs/secrets.md) | age-encrypted credentials (wandb, Hugging Face), `dots-secret` |
| [Slurm](docs/slurm.md) | GPU helpers and limits on snoopy |
| [Neovim](docs/neovim.md) | per-project Python (uv/conda envs, ROS), debugging, REPL, Claude Code in the editor |
| [Claude Code](docs/claude-code.md) | shared `CLAUDE.md`, plugins and status line, tmux integration |

## Layout

| Path | Purpose |
|------|---------|
| `flake.nix` | inputs + one home configuration per machine |
| `hosts.nix` | the machines: ssh alias → system, user, rootless and Slurm settings |
| `home/common.nix` | shared config: imports the modules, shared secrets, garbage collection |
| `home/{darwin,linux}.nix` | per-platform home directory, mamba root |
| `home/hosts/<alias>.nix` | optional per-machine settings, imported automatically |
| `modules/zsh.nix`, `tools.nix`, `starship.nix`, `theme.nix` | shell, CLI tools, prompt, shared colours |
| `modules/git.nix`, `python.nix` | git + delta; uv + micromamba |
| `modules/tmux.nix`, `tmux/.tmux.conf.local` | tmux, its plugins and settings |
| `modules/ssh.nix`, `ssh/` | ssh config, routes, pinned host keys, login keys + sync script |
| `modules/dots-sync.nix` | `dots-sync`, `dots-pull`, `dots-status`, `claude-update`/`codex-update`, hourly timer |
| `modules/no-root.nix`, `scripts/bootstrap-no-root` | machines without root (nix-portable) |
| `modules/secrets.nix`, `secrets/` | `dots-secret`, recipients, encrypted secrets |
| `modules/slurm.nix` | Slurm helpers |
| `modules/neovim.nix`, `nvim/lua/dots/` | Neovim, plugins, language servers; per-project Python in `projects.lua` |
| `modules/claude.nix`, `claude/CLAUDE.md` | Claude Code / Codex settings and shared instructions |
| `CLAUDE.md` (= `AGENTS.md`) | instructions for agents working on this repo |
| `.github/workflows/`, `scripts/ci-build` | build checks, daily claude-code + codex bump, weekly update PR |
| `docs/` | the documentation above |

## Scope

Homebrew still manages GUI casks, fonts and heavy, specialised tools on the Mac (qemu,
lima, opencv, ...). The Nix profile comes first on `PATH`, so CLI tools present in both
resolve to Nix.
