# dotfiles repo

home-manager flake that defines my environment on every machine (Mac, Linux lab boxes, a
rootless Slurm server). `README.md` has the overview and layout; `docs/` explains each
feature. `AGENTS.md` is a link to this file (Codex reads that name).

`claude/CLAUDE.md` is different: it's the *user-level* instructions installed as
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` on every machine. Edit it for facts that
apply to all projects; edit this file for working on the repo itself.

## Making changes
- Machines: `hosts.nix` (ssh alias → system, user, `noRoot`, `slurm`). Per-machine
  settings: `home/hosts/<alias>.nix`. Everything else: one module per area in `modules/`.
- New files must be `git add`ed before Nix sees them (flake evaluation only reads tracked
  files).
- Activation scripts (`home.activation.*`): use `run` for commands, honour `DRY_RUN`, and
  `warnEcho` instead of failing when a machine isn't ready (no key, missing dir).
- Shell scripts go through `pkgs.writeShellApplication` (shellcheck runs at build).
- Rootless machines (`noRoot`, snoopy): `/nix` exists only inside nix-portable's
  namespace. Anything read from outside it (login hooks, systemd units, wrappers in
  `<location>/bin`) must be a real file written at activation, and links to files that
  may not exist must be created at activation too, never as `home.file` store symlinks
  (a dangling store symlink breaks the build there). `$HOME` there is `noRoot.home`.
- Secrets: never print or log plaintext. Pipe into `dots-secret set` / `age -e`; check
  results by hash or by asking the service who you are, never by `cat`.
- Commits: plain messages explaining why; no `Co-Authored-By: Claude` trailer.

## Verifying
```bash
# every machine's config evaluates (fast)
nix eval --raw .#homeConfigurations --apply 'cs: builtins.concatStringsSep " " (map (n: n + ":" + builtins.substring 11 6 cs.${n}.activationPackage.drvPath) (builtins.attrNames cs))'
scripts/ci-build                                  # build every config for this platform
nix run nixpkgs#actionlint -- .github/workflows/*.yml
```
- Linux configs can't be built on the Mac: CI (`check.yml`) builds them on every push to
  `main`. To inspect a Linux-only generated file locally, read it from the derivation
  (`nix derivation show -r <drv>`, the `text` env of the writeText).
- Test on a remote machine without touching its real state: isolated tmux servers
  (`tmux -L name`, plus `TMUX_CONF_LOCAL=` for oh-my-tmux), temp `ZDOTDIR`, scratch dirs.
- **Slurm: never let a test submit a job.** Define `srun() { print -r -- "$@"; }` (and the
  same for `sbatch`) in the test shell before calling the helpers.

## Rolling out
Commit, push `main`, then either `dots-sync` (from the Mac) or let the hourly timers pull.
`dots-status` shows which commit each machine runs. Rootless machines switch via
`<location>/bin/hm-switch`; others via `home-manager switch --flake ~/dotfiles#<user>@<alias>`.

## Gotchas
- zsh: a bare `=word` (e.g. `echo ====`) is command-path expansion and fails.
- ssh `ControlPath` sockets must stay under ~100 bytes including ssh's 17-char suffix.
- oh-my-tmux rebuilds `status-right` after plugins load; plugin hooks that live there go
  in `tmux_conf_theme_status_right`. tmux-resurrect writes to `~/.tmux/resurrect` unless
  `@resurrect-dir` is set.
- Ubuntu's `/usr/bin/zsh` can't load this config's compiled modules (glibc); the zsh guard
  swaps to home-manager's zsh.
- On snoopy, `nvidia-smi` outside a job is a sudo wrapper that fails in the env; use
  Slurm's data (`gpus`).
