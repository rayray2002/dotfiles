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
  Run it from the Mac or ray-desktop: only client keys are in `ssh/authorized_keys`,
  so from a server (xarm, snoopy) the push step shows ✗ and the other hosts pick the
  commit up through their timer instead. Pushing *to* the Mac needs Remote Login on.
- **Every host also runs `dots-pull` hourly** (systemd timer / launchd agent), so
  machines that were off catch up on their own. It fast-forwards `main` from GitHub
  and switches only when there is a new commit. It refuses to touch a dirty tree or
  another branch; the reason is printed in your next shell.
- `flake.lock` is bumped in one place only: the daily `update-claude-code` GitHub
  Action, or `claude-update` / `nix flake update` followed by `dots-sync`. Never leave
  lock changes uncommitted on a host — they block its auto-sync.
- Roll back the last change: `home-manager switch --rollback`

## Shell

Run **`zhelp`** for the keys, shorthands and functions this config adds. Highlights:
↑/↓ search history by what you've typed, Ctrl+R is atuin, Ctrl+T / Alt+C fuzzy-pick
files and directories with previews, Tab opens fuzzy completion, and git shorthands
(`gst`, `gco`, …) expand to the full command when you press space (Ctrl+Space doesn't).

Startup is kept fast (~80 ms): tool init scripts (starship, fzf, atuin, zoxide,
direnv, micromamba) are generated at build time instead of running on every shell,
and `compinit` only does its full check once a day or after a switch.

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

- **Client config** (`ssh/config` → `~/.ssh/config`): hosts grouped by site, with
  users and per-host options. `ssh -G <host> | grep hostname` shows the route picked.
- **Routes** (`ssh/routes.nix` → generated `~/.ssh/routes.conf`): each multi-route host
  lists its addresses in order of preference, **LAN → Tailscale → school / jump host**;
  ssh uses the first whose port 22 answers, and the last is the unprobed fallback. A LAN
  address is skipped instantly when no local interface is on that network, so being away
  costs nothing; other probes cost ≤1 s only when that route is down. `aliases` gives
  one machine several names (`salep` = `xarm`); the attribute name is its `HostKeyAlias`.
- **Pinned host keys** (`ssh/known_hosts` → `~/.ssh/known_hosts.d/dotfiles`): read
  alongside the normal `~/.ssh/known_hosts`, so a new machine trusts our hosts with no
  prompt. Multi-route hosts get `HostKeyAlias` from `ssh/routes.nix`, so every route checks one
  entry. After a
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
| `modules/ssh.nix` | links `~/.ssh/config` and the pinned host keys; generates `~/.ssh/routes.conf`; `ssh-probe` |
| `ssh/config` | ssh client config (users, per-host options, defaults) |
| `ssh/routes.nix` | ordered routes per multi-route host (LAN → Tailscale → school/jump) |
| `ssh/known_hosts` | pinned host keys for our machines |
| `ssh/authorized_keys`, `ssh/managed-hosts` | allowed login keys and the hosts that get them |
| `ssh/sync-authorized-keys` | pushes `authorized_keys` to `managed-hosts` (dry run by default) |
| `modules/dots-sync.nix` | `dots-sync` / `dots-pull` / `claude-update`, hourly pull timer |
| `.github/workflows/update-claude-code.yml` | daily claude-code lock bump |

## Scope

Homebrew still manages GUI casks, fonts, and heavy/specialized tools (qemu, lima, opencv,
etc.). The Nix profile is prepended ahead of Homebrew on `PATH` (see `modules/zsh.nix`),
so CLI tools present in both resolve to Nix. Neovim is currently installed via Homebrew
(Nix migration deferred).
