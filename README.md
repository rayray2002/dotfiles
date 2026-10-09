# dotfiles

Declarative shell environment managed with [home-manager](https://github.com/nix-community/home-manager) (flakes). zsh + starship + a curated modern CLI toolset, portable across macOS and Linux.

## First-time setup

1. Install Nix and enable flakes:
   ```bash
   sh <(curl -L https://nixos.org/nix/install)
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```
2. Clone and activate:
   ```bash
   git clone https://github.com/rayray2002/dotfiles.git ~/dotfiles && cd ~/dotfiles
   nix run home-manager/master -- switch -b backup --flake '.#ray@mac'   # <user>@<host> from hosts.nix
   ```
   `-b backup` renames any existing `~/.zshrc`, `~/.gitconfig`, etc. to `*.backup`
   instead of failing, so the first activation is non-destructive.

## Daily use

Machines are listed in `hosts.nix` (ssh alias → system, user); each gets a flake
target `<user>@<alias>`. To add a machine, add it there and to `ssh/config`.

- **Edit on any machine, then `dots-sync "message"`.** It commits tracked changes,
  switches locally first (a broken config is never pushed), pushes, and runs
  `dots-pull` on every other host over ssh in parallel (✓/✗ per host, logs in
  `~/.local/state/dots-sync/`). Untracked files are listed but not added.
- **Every host also runs `dots-pull` hourly** (systemd timer / launchd agent), so
  machines that were off catch up on their own. It fast-forwards `main` from GitHub
  and switches only when there is a new commit. It refuses to touch a dirty tree or
  another branch; the reason is printed in your next shell.
- `flake.lock` is bumped in one place only: the daily `update-claude-code` GitHub
  Action, or `claude-update` / `nix flake update` followed by `dots-sync`. Never leave
  lock changes uncommitted on a host — they block its auto-sync.
- Roll back the last change: `home-manager switch --rollback`

## SSH routes

Hosts reachable several ways are listed once in `ssh/routes.nix`, in order of
preference: **LAN → Tailscale → school / jump host**. ssh uses the first route
whose port 22 answers; the last route is the unprobed fallback. A LAN address is
skipped instantly when no local interface is on that network, so being away from
home or the lab costs nothing; other probes cost ≤1 s only when that route is down.
`ssh -G <host> | grep hostname` shows the route picked.

- Extra names for one machine: `aliases` (e.g. `salep` = `xarm`).
- Every route of a machine shares one `HostKeyAlias`, so switching networks never
  re-prompts, and a stranger answering on the same private IP elsewhere fails the
  host-key check instead of getting your login.
- After adding a host, run `ssh-seed-known-hosts` once per machine to copy keys
  already trusted by IP to the alias (idempotent).
- `User`, X11 and other per-host options stay in `ssh/config`.

## Python

`micromamba` (aliased `mamba`) manages environments (conda-forge + system deps like CUDA);
`uv` is the fast pip inside an active env:
```bash
micromamba create -n proj python=3.12 && micromamba activate proj
uv pip install <packages>
```

The micromamba **root prefix is host-specific** (`MAMBA_ROOT_PREFIX`), set in the
per-host file rather than the shared `modules/python.nix`:

| Host | Root | Why |
|------|------|-----|
| `home/darwin.nix` (this mac) | `~/miniforge3` | reuses the pre-existing miniforge envs (`base`, `wam`, `telegram`, …) |
| `home/linux.nix` / fresh machines | `~/micromamba` | clean Nix-native root |

Environment *contents* are never stored in the repo — on a new machine you recreate
them from spec. The legacy mac root (`~/miniforge3`) can't be renamed by moving it
(env shebangs hardcode the prefix); it would have to be recreated.

## Layout

| Path | Purpose |
|------|---------|
| `flake.nix` | inputs + one home configuration per host |
| `hosts.nix` | the machines: ssh alias → system + user |
| `home/common.nix` | shared config; imports all modules |
| `home/{darwin,linux}.nix` | per-platform home directory, mamba root, extras |
| `modules/zsh.nix` | zsh: aliases, plugins, history, helpers, PATH ordering |
| `modules/starship.nix` | prompt |
| `modules/tools.nix` | fzf, zoxide, direnv, atuin, lazygit, yazi, claude-code + CLI packages |
| `modules/git.nix` | git config + delta |
| `modules/python.nix` | uv + micromamba (root prefix set per-host) |
| `modules/tmux.nix` | tmux + oh-my-tmux |
| `modules/ssh.nix`, `ssh/routes.nix` | ssh config symlink, generated multi-route blocks, `ssh-probe`, `ssh-seed-known-hosts` |
| `modules/dots-sync.nix` | `dots-sync` / `dots-pull` / `claude-update`, hourly pull timer |
| `.github/workflows/update-claude-code.yml` | daily claude-code lock bump |

## Scope

Homebrew still manages GUI casks, fonts, and heavy/specialized tools (qemu, lima, opencv,
etc.). The Nix profile is prepended ahead of Homebrew on `PATH` (see `modules/zsh.nix`),
so CLI tools present in both resolve to Nix. Neovim is currently installed via Homebrew
(Nix migration deferred).
