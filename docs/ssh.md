# SSH

Only public material lives in the repo; private keys never leave the machine that made
them. Config: `ssh/`, `modules/ssh.nix`.

## Hosts

| Alias | Machine | Route |
|---|---|---|
| `mac` | the laptop | tailnet |
| `xarm`, `salep` | USC lab box | lab LAN → tailnet |
| `snoopy` | USC GPU server (user `borueihu`) | lab LAN → tailnet → LAN via xarm |
| `glamor_panda_ray`, `glamor_panda_shared` | Franka workstation (glamor-citrine) | lab LAN → tailnet |
| `ray-desktop` | home desktop | home LAN → tailnet |
| `carc` (= `discovery1`), `discovery2`, `endeavour1`, `endeavour2` | USC CARC login nodes (user `borueihu`, shared `/home1`) | jump through `xarm` |
| `hrimfaxi` | Caltech | tailnet |
| `ws1`…`ws7`, `meow1`, `meow2` | NTU CSIE workstations | `<name>.csie.ntu.edu.tw` |

## Routes: LAN → Tailscale → school

Machines with several addresses list them in order of preference in `ssh/routes.nix`; ssh
uses the first whose port 22 answers, and the last is the fallback (never probed). A LAN
address is skipped instantly when no local interface is on that network, so being away
costs nothing; other probes cost up to 1 s only when that route is down.
`ssh -G <host> | grep -E '^(hostname|proxyjump) '` shows the route picked from where you
are. `aliases` gives a machine several names (`salep` = `xarm`); all of them share one
route and one host key.

## Connection reuse

One connection per host is kept for 10 minutes after the last session (`ControlMaster`,
sockets in `~/.ssh/cm`): repeated ssh, scp, git and `dots-sync` skip the handshake
(~0.4 s → ~0.1 s). After a network change ssh opens a fresh connection on the new route.
If one ever hangs, `ssh-drop` closes them all.

## Host keys

`ssh/known_hosts` (installed as `~/.ssh/known_hosts.d/dotfiles`) pins our machines' keys,
read alongside the normal `~/.ssh/known_hosts`, so a new machine trusts them without a
prompt and every route to a machine checks the same entry (`HostKeyAlias`). After a
machine is reinstalled, verify its new key out of band, replace its lines and `dots-sync`.

## Login keys

`ssh/authorized_keys` lists the client keys (the Mac, ray-desktop) allowed into every host in
`ssh/managed-hosts`. `ssh/lab-keys` holds the lab machines' own keys (xarm, snoopy,
glamor-citrine, carc) and goes only to hosts marked `lab` there, so the lab machines can ssh
into each other. Nothing is ever pushed to the Mac, and hrimfaxi and the NTU workstations get
client keys only.

```bash
ssh/sync-authorized-keys                  # dry run: the diff per host
ssh/sync-authorized-keys --apply          # write it (or name hosts to limit)
ssh/sync-authorized-keys --apply --prune  # also drop keys outside the block
```

Only a `# BEGIN dotfiles … # END dotfiles` block in each remote file is managed; other
lines are kept and reported. Each write backs up the file, checks that a fresh login still
works, and restores the backup if it doesn't.

**New device**: `ssh-keygen -t ed25519`, add the `.pub` to `ssh/authorized_keys`, run the
sync from a machine that can already log in, and commit. On a Mac, set a passphrase and
`ssh-add --apple-use-keychain ~/.ssh/id_ed25519`; the config keeps it unlocked through the
Keychain.

**Rootless hosts**: inside the Nix env `ssh` is a wrapper around `/usr/bin/ssh -F ~/.ssh/config`
(modules/no-root.nix): root-owned system files look like `nobody`'s there, and ssh rejects
e.g. CARC's `/etc/ssh/ssh_config.d/05-redhat.conf`. `routedLan = true` in `hosts.nix` (carc)
makes `ssh-probe` try LAN addresses the host reaches by routing without an interface on them.
