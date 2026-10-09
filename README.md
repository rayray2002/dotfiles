# dotfiles

Declarative shell environment managed with [home-manager](https://github.com/nix-community/home-manager) (flakes). zsh + starship + a curated modern CLI toolset, portable across macOS and Linux.

## First-time setup

1. Install Nix and enable flakes:
   ```bash
   sh <(curl -L https://nixos.org/nix/install)
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```
2. Clone and activate (the machine must already be in `hosts.nix`, see
   [Adding a machine](#adding-a-machine)):
   ```bash
   git clone https://github.com/rayray2002/dotfiles.git ~/dotfiles && cd ~/dotfiles
   nix run home-manager/master -- switch -b backup --flake '.#ray@mac'   # <user>@<alias>
   ```
   `-b backup` renames any existing `~/.zshrc`, `~/.gitconfig`, etc. to `*.backup`
   instead of failing, so the first activation is non-destructive.
3. Linux only: `loginctl enable-linger $USER` (may need sudo; already on for snoopy) so the hourly sync timer
   also runs while you're logged out.

### Without root (e.g. snoopy)

The steps above need root once, to create `/nix`. Without it, Nix runs through
[nix-portable](https://github.com/DavHau/nix-portable) (bwrap): its store lives under a
directory you own and appears as `/nix` only inside its namespace. home-manager activates
into a **separate home** (`noRoot.home`), not your real one, so the real `~` (quota, login
shell, anything else using it) stays untouched. Interactive logins enter the env through a
hook at the top of the real `~/.zshrc`. Needs unprivileged user namespaces
(`unshare --user --map-root-user true` succeeds) and a few GB free for the store.

```nix
# hosts.nix
snoopy = { system = "x86_64-linux"; user = "borueihu";
           noRoot = {
             location = "/scr/borueihu";          # nix-portable store + bin/ wrappers
             home = "/scr/borueihu/nixhome";      # $HOME inside the env
             flake = "/scr/borueihu/dotfiles-nix"; # this repo's checkout there
           }; };
```

On a new machine, add its entry, `dots-sync` it, then on the machine:
```bash
git clone https://github.com/rayray2002/dotfiles.git /tmp/dotfiles
/tmp/dotfiles/scripts/bootstrap-no-root <user>@<alias>
```
It installs nix-portable into `<location>/bin`, clones the repo to `noRoot.flake`, builds
and activates, and adds the hook to `~/.zshrc` (backup: `.zshrc.pre-dotfiles`). Re-runnable.

In the env:

| Command | Does |
|---|---|
| `nixshell` | enter the env (the `~/.zshrc` hook runs it on login) |
| `hm-switch [flake]` | build and activate this host's config |
| `dots-pull`, `dots-sync` | as on other hosts; switching goes through `hm-switch` |
| `nix …` | Nix via nix-portable |

How it differs from a normal host (`modules/no-root.nix`):
- `nixshell`, `hm-switch`, `nix` and `dots-pull` in `<location>/bin` and the
  `dots-sync` systemd timer in the real `~/.config/systemd/user` are real files written at
  activation, because they're used from outside the env, where `/nix` doesn't exist.
- Inside the env `$HOME` is `noRoot.home`; your ssh keys are linked in from the real
  `~/.ssh`, so git and ssh work as usual.
- Only interactive logins enter the env. `ssh host cmd`, Slurm jobs, cron and system
  services run outside it: use `<location>/bin/nix …` or `nixshell` there.
- Plain shell without the env: `NO_NIXSHELL=1 zsh` (or `ssh host bash`). The hook also
  skips itself if the store directory is missing, so a wiped `/scr` can't lock you out.

## Daily use

Machines are listed in `hosts.nix` (ssh alias → system, user); each gets a flake
target `<user>@<alias>`: `ray@mac`, `ray@ray-desktop`, `ray@xarm`, `ray@glamor_panda_ray`,
`borueihu@snoopy`.

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

When a host doesn't update:

| Check | Command |
|---|---|
| why the last auto-sync stopped | printed in the next shell; also `~/.local/state/dots-sync/error` |
| run it by hand, with output | `dots-pull` |
| a push from `dots-sync` | `~/.local/state/dots-sync/<host>.log` on the machine you ran it from |
| timer (Linux) | `systemctl --user list-timers dots-sync`, `journalctl --user -u dots-sync` |
| agent (macOS) | `~/.cache/dots-sync.log` |

The usual cause is uncommitted edits on that host: commit them with `dots-sync`, or
discard them, and it resumes on the next run.

### Adding a machine

1. `hosts.nix`: add `<ssh alias> = { system = ...; user = ...; };` (plus
   `noRoot = { ... };` if you have no root there, see
   [Without root](#without-root-eg-snoopy)).
2. `ssh/config`: a `Host <alias>` block with its `User`. If it has more than one
   address, list them in `ssh/routes.nix` (LAN, then Tailscale, then school/jump);
   otherwise give it a plain `HostName` here.
3. `ssh/known_hosts`: pin its key under the alias, checked out of band
   (`ssh-keyscan -t ed25519 <address>`, then replace the address with the alias).
4. Its own login key: see **New device** under [SSH](#ssh).
5. `dots-sync "add <alias>"`, then do [First-time setup](#first-time-setup) on it (or
   `scripts/bootstrap-no-root <user>@<alias>` without root).

## Shell

Run **`zhelp`** for the keys, shorthands and functions this config adds. Highlights:
↑/↓ search history by what you've typed, Ctrl+R is atuin, Ctrl+T / Alt+C fuzzy-pick
files and directories with previews, Tab opens fuzzy completion, and git shorthands
(`gst`, `gco`, …) expand to the full command when you press space (Ctrl+Space doesn't).

Behaviour worth knowing: `*` doesn't match dotfiles (Tab still completes them), `cat`
is `bat` without the pager, and `vim` means `nvim` only where nvim is installed. Put
per-machine settings and secrets in `~/.env.zsh`, which is sourced but not tracked.
To add a shorthand that expands on space, add it to `expandingAliases` in
`modules/zsh.nix`; plain aliases go in `aliases` there. `zhelp` picks up both.

Startup is kept fast (~80 ms, was ~170 ms): tool init scripts (starship, fzf, atuin,
zoxide, direnv, micromamba) are generated at build time instead of running on every
shell, and `compinit` only does its full check once a day or after a switch (which
deletes `~/.zcompdump`). Measure with `time zsh -i -c exit`.

## tmux

oh-my-tmux plus `tmux/.tmux.conf.local`. `ta` attaches, or starts a session if there is
none. Sessions are saved every 15 minutes and restored when tmux starts
(tmux-resurrect + tmux-continuum, provided by Nix; `prefix C-s` / `prefix C-r` save and
restore by hand). Copying in tmux reaches your local clipboard even over ssh (OSC 52; in
iTerm2 this needs *Applications in terminal may access clipboard*, which is on). After a
config change, `prefix r` reloads a running tmux.

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
| `home/darwin.nix` (the Mac) | `~/miniforge3` | reuses the pre-existing miniforge envs (`base`, `wam`, `telegram`, …) |
| `home/linux.nix` (Linux hosts) | `~/miniforge3` | matches the existing roots there; a fresh machine could use a clean `~/micromamba` |
| `home/hosts/snoopy.nix` | `/scr/borueihu/miniforge3` | the existing miniforge install with its envs; `$HOME` there is the separate `nixhome` |

Environment *contents* are never stored in the repo — on a new machine you recreate
them from spec. The legacy mac root (`~/miniforge3`) can't be renamed by moving it
(env shebangs hardcode the prefix); it would have to be recreated.

## SSH

Only public material lives here; private keys never leave the machine that made them
(one ed25519 key per device).

- **Client config** (`ssh/config` → `~/.ssh/config`): hosts grouped by site, with
  users and per-host options. `ssh -G <host> | grep -E '^(hostname|proxyjump) '` shows
  the route picked from where you are.
- **Routes** (`ssh/routes.nix` → generated `~/.ssh/routes.conf`): each multi-route host
  lists its addresses in order of preference, **LAN → Tailscale → school / jump host**;
  ssh uses the first whose port 22 answers, and the last is the unprobed fallback. A LAN
  address is skipped instantly when no local interface is on that network, so being away
  costs nothing; other probes cost ≤1 s only when that route is down. `aliases` gives
  one machine several names (`salep` = `xarm`); the attribute name is its `HostKeyAlias`.
- **Pinned host keys** (`ssh/known_hosts` → `~/.ssh/known_hosts.d/dotfiles`): read
  alongside the normal `~/.ssh/known_hosts`, so a new machine trusts our hosts with no
  prompt. Multi-route hosts get `HostKeyAlias` from `ssh/routes.nix`, so every route
  checks one entry. After a host is reinstalled, verify its new key out of band, replace
  its lines, and `dots-sync`.
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
| `modules/no-root.nix`, `scripts/bootstrap-no-root` | hosts without root: nix-portable, separate home, generated wrappers |
| `home/hosts/<alias>.nix` | optional per-machine settings, imported automatically |
| `.github/workflows/update-claude-code.yml` | daily claude-code lock bump |

## Scope

Homebrew still manages GUI casks, fonts, and heavy/specialized tools (qemu, lima, opencv,
etc.). The Nix profile is prepended ahead of Homebrew on `PATH` (see `modules/zsh.nix`),
so CLI tools present in both resolve to Nix. Neovim is currently installed via Homebrew
(Nix migration deferred).
