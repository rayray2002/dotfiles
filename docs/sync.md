# Keeping machines in sync

## Day to day

- **Edit on any machine, then `dots-sync "message"`.** It commits tracked changes, switches
  locally first (a broken config is never pushed), pushes, and runs `dots-pull` on every
  other machine over ssh in parallel (✓/✗ per machine; logs in
  `~/.local/state/dots-sync/<host>.log`). Untracked files are listed but not added.
- **Every machine also runs `dots-pull` hourly** (systemd timer / launchd agent), so ones that
  were off or unreachable catch up on their own. It fast-forwards `main` from GitHub (https,
  no keys needed) and switches only when there's a new commit. It refuses to touch a dirty
  checkout or another branch; the reason is printed in your next shell.
- **`dots-status`**: one line per machine with the commit it last applied, when its sync last
  ran cleanly, and whether it's current with GitHub's `main`, behind, failing (with the
  reason) or unreachable.
- Roll back the last change on one machine: `home-manager switch --rollback`.

Run `dots-sync` from the Mac or ray-desktop: only client keys are in `ssh/authorized_keys`,
so from a server (xarm, snoopy) the push step shows ✗ and the others update through their
timer instead. Pushing *to* the Mac needs Remote Login on.

## Updates

`flake.lock` is only ever changed in these places, never by a machine on its own:

| What | How |
|---|---|
| claude-code and codex, daily | `update-claude-code` GitHub Action: bumps both, builds the Linux configs, pushes |
| claude-code / codex, now | `claude-update` / `codex-update` (bump + `dots-sync`) |
| everything, weekly | `update-flake` Action (Mondays): bumps all inputs, builds every config on Linux and macOS, opens a **`flake.lock: weekly update`** PR listing the changes. Merge it to roll out. |
| anything, by hand | `nix flake update [input]`, then `dots-sync` |

Never leave lock changes uncommitted on a machine: they block its hourly sync.

## CI

`.github/workflows/check.yml` builds every machine's configuration on each push to `main`
and on pull requests (Linux configs on Ubuntu, the Mac's on macOS). `scripts/ci-build`
does the same locally for your platform. Workflows' own pushes don't trigger it, so the
daily agent bump builds before pushing.

## Garbage collection

Every sync that brings a change adds a home-manager generation. `nix.gc` runs weekly and
deletes generations older than 14 days and the store paths only they used. Not on
rootless machines.

## When a machine doesn't update

| Check | Command |
|---|---|
| all machines at once | `dots-status` |
| why the last sync stopped | printed in the next shell; `~/.local/state/dots-sync/error` |
| run it by hand, with output | `dots-pull` |
| a push from `dots-sync` | `~/.local/state/dots-sync/<host>.log` where you ran it |
| timer (Linux) | `systemctl --user list-timers dots-sync`, `journalctl --user -u dots-sync` |
| agent (macOS) | `~/.cache/dots-sync.log` |

The usual cause is uncommitted edits on that machine: commit them with `dots-sync` (or
discard them) and it resumes on the next run.
