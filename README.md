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
   nix run home-manager/master -- switch -b backup --flake '.#ray@mac'   # or .#ray@linux
   ```
   `-b backup` renames any existing `~/.zshrc`, `~/.gitconfig`, etc. to `*.backup`
   instead of failing, so the first activation is non-destructive.

## Daily use

- Edit a `.nix` file, then apply:
  ```bash
  home-manager switch --flake ~/dotfiles#ray@mac     # or ray@linux
  ```
- Roll back the last change: `home-manager switch --rollback`
- Update pinned versions: `nix flake update` then switch again.

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

## SSH

Only public material lives here; private keys never leave the machine that made them
(one ed25519 key per device).

- **Client config** (`ssh/config` → `~/.ssh/config`): hosts grouped by site. Machines
  with several routes probe the LAN or tailnet address with `nc` and fall back to the
  next route, e.g. `snoopy` goes direct over Tailscale, else via `xarm`. ssh keeps the
  first value it sees, so probes go before their fallback and `Host *` goes last.
- **Pinned host keys** (`ssh/known_hosts` → `~/.ssh/known_hosts.d/dotfiles`): read
  alongside the normal `~/.ssh/known_hosts`, so a new machine trusts our hosts with no
  prompt. Multi-route hosts set `HostKeyAlias`, so every route checks one entry. After a
  host is reinstalled, verify its new key out of band, replace its lines, and switch.
- **Login keys** (`ssh/authorized_keys`): the client keys allowed into every host in
  `ssh/managed-hosts`. Server keys (the ones snoopy, salep, … use for git) are kept out
  on purpose, so one shared server can't reach the rest. Push the list with:
  ```bash
  ssh/sync-authorized-keys                  # dry run: show the diff per host
  ssh/sync-authorized-keys --apply          # write it (or name hosts to limit)
  ssh/sync-authorized-keys --apply --prune  # also drop keys outside the block
  ```
  Only a `# BEGIN dotfiles … # END dotfiles` block in each remote file is managed;
  other lines are kept and reported. Each write backs up the file, checks that a
  fresh login still works, and restores the backup if it doesn't.
- **New device**: `ssh-keygen -t ed25519`, add the `.pub` to `ssh/authorized_keys`,
  run the sync from a machine that can already log in, and commit. On a Mac, set a
  passphrase and `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`; the config keeps it
  unlocked through the Keychain.

## Layout

| Path | Purpose |
|------|---------|
| `flake.nix` | inputs + `ray@mac` / `ray@linux` home configurations |
| `home/common.nix` | shared config; imports all modules |
| `home/{darwin,linux}.nix` | per-platform home directory, mamba root, extras |
| `modules/zsh.nix` | zsh: aliases, plugins, history, helpers, PATH ordering |
| `modules/starship.nix` | prompt |
| `modules/tools.nix` | fzf, zoxide, direnv, atuin, lazygit, yazi, claude-code + CLI packages |
| `modules/git.nix` | git config + delta |
| `modules/python.nix` | uv + micromamba (root prefix set per-host) |
| `modules/tmux.nix` | tmux + oh-my-tmux; links `~/.ssh/config` and the pinned host keys |
| `ssh/config` | ssh client config (hosts, routes, defaults) |
| `ssh/known_hosts` | pinned host keys for our machines |
| `ssh/authorized_keys`, `ssh/managed-hosts` | allowed login keys and the hosts that get them |
| `ssh/sync-authorized-keys` | pushes `authorized_keys` to `managed-hosts` (dry run by default) |

## Scope

Homebrew still manages GUI casks, fonts, and heavy/specialized tools (qemu, lima, opencv,
etc.). The Nix profile is prepended ahead of Homebrew on `PATH` (see `modules/zsh.nix`),
so CLI tools present in both resolve to Nix. Neovim is currently installed via Homebrew
(Nix migration deferred).
