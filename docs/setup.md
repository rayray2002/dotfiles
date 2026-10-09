# Setting up a machine

Every machine is an entry in `hosts.nix` (ssh alias → system, user) and gets a flake target
`<user>@<alias>`: `ray@mac`, `ray@xarm`, `ray@glamor_panda_ray`, `ray@ray-desktop`,
`borueihu@snoopy`.

## Adding a machine to the repo

1. `hosts.nix`: add `<alias> = { system = "x86_64-linux"; user = "..."; };`
   (plus `noRoot = { ... };` without root, see below, and `slurm = { ... };` if it runs
   Slurm, see [slurm.md](slurm.md)).
2. `ssh/config`: a `Host <alias>` block with its `User`. If it has more than one address,
   list them in `ssh/routes.nix` (LAN, then Tailscale, then school/jump); otherwise a plain
   `HostName`. See [ssh.md](ssh.md).
3. `ssh/known_hosts`: pin its host key under the alias, checked out of band
   (`ssh-keyscan -t ed25519 <address>`, then replace the address with the alias).
4. Its login key: **New device** in [ssh.md](ssh.md).
5. Optional per-machine settings: `home/hosts/<alias>.nix` is imported automatically.
6. `dots-sync "add <alias>"`, then install it as below.
7. Secrets: run `dots-secret init-host` on it, add its public key to
   `secrets/recipients.txt`, and `dots-secret rekey` from a machine that can already
   decrypt ([secrets.md](secrets.md)).

## Installing (with root / sudo)

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon        # asks for sudo
mkdir -p ~/.config/nix && echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
git clone https://github.com/rayray2002/dotfiles.git ~/dotfiles
nix run home-manager/master -- switch -b backup --flake ~/dotfiles#<user>@<alias>
sudo loginctl enable-linger $USER        # Linux: hourly sync also runs while logged out
```

`-b backup` renames files that are in the way (`~/.zshrc`, `~/.gitconfig`, ...) to
`*.backup` instead of failing. A symlink pointing outside the store (e.g. an old
`~/.tmux.conf -> .tmux/.tmux.conf`) isn't backed up: move it aside and re-run.

Make home-manager's zsh the login shell, so nothing else ever reads this zsh config
(another zsh can't load its compiled modules):

```bash
echo ~/.nix-profile/bin/zsh | sudo tee -a /etc/shells
sudo chsh -s ~/.nix-profile/bin/zsh $USER
```

Linger is optional: without it the hourly sync only runs while you're logged in and
catches up at the next login. Without sudo, `loginctl enable-linger` sometimes works as
yourself; otherwise ask an admin, or run `dots-pull` from your crontab.

## Installing without root (e.g. snoopy)

Root is needed once, to create `/nix`. Without it, Nix runs through
[nix-portable](https://github.com/DavHau/nix-portable) (bwrap): its store lives under a
directory you own and appears as `/nix` only inside its namespace. home-manager activates
into a **separate home** (`noRoot.home`), so the real `~` (its quota, its login shell, other
users' tools) is never touched. Interactive logins enter the env through a hook at the top
of the real `~/.zshrc`. Needs unprivileged user namespaces
(`unshare --user --map-root-user true` succeeds) and a few GB for the store.

```nix
# hosts.nix
snoopy = { system = "x86_64-linux"; user = "borueihu";
           noRoot = {
             location = "/scr/borueihu";           # nix-portable store + bin/ wrappers
             home = "/scr/borueihu/nixhome";       # $HOME inside the env
             flake = "/scr/borueihu/dotfiles-nix"; # this repo's checkout there
           }; };
```

On the new machine:

```bash
git clone https://github.com/rayray2002/dotfiles.git /tmp/dotfiles
/tmp/dotfiles/scripts/bootstrap-no-root <user>@<alias>
```

It installs nix-portable into `<location>/bin`, clones the repo to `noRoot.flake`, builds
and activates, and adds the hook to `~/.zshrc` (backup `.zshrc.pre-dotfiles`). Re-runnable.

| Command (in the env) | Does |
|---|---|
| `nixshell` | enter the env (the `~/.zshrc` hook runs it on login) |
| `hm-switch [flake]` | build and activate this host's config |
| `dots-pull`, `dots-sync` | as elsewhere; switching goes through `hm-switch` |
| `nix …` | Nix via nix-portable |

How it differs from a normal machine (`modules/no-root.nix`):
- `nixshell`, `hm-switch`, `nix` and `dots-pull` in `<location>/bin`, and the `dots-sync`
  timer in the real `~/.config/systemd/user`, are real files written at activation: they're
  used from outside the env, where `/nix` doesn't exist.
- Inside the env `$HOME` is `noRoot.home`. ssh keys from the real `~/.ssh` are linked in;
  `$SHELL` is home-manager's zsh, so tmux panes use it too.
- Only interactive logins enter the env. `ssh host cmd`, Slurm jobs, cron and system
  services run outside it: use `<location>/bin/nix …` or `nixshell` there.
- Plain shell: `NO_NIXSHELL=1 zsh` (or `ssh host bash`). The hook skips itself if the store
  is missing, so a wiped scratch disk can't lock you out.
- No automatic garbage collection there (nix-portable's own Nix lives in the store).
