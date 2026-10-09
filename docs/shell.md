# Shell (zsh)

`zhelp` prints the keys, shorthands, aliases and functions below, generated from the
config so it's always current. Config: `modules/zsh.nix`, `modules/tools.nix`,
`modules/starship.nix`, `modules/theme.nix`.

## Keys

| Key | Does |
|---|---|
| ↑ / ↓ | history entries that start with what you've typed (plain history on an empty line) |
| Ctrl+R | atuin full-history search: Enter runs, Tab puts it on the line to edit |
| Tab | completion in an fzf menu; `<` / `>` switch groups; previews directories |
| Ctrl+T | fuzzy-insert a file path (fd, bat preview) |
| Alt+C | fuzzy `cd` into a subdirectory (eza tree preview; needs Option as Meta in iTerm2) |
| Ctrl+Space | a space that doesn't expand a shorthand |
| Ctrl+X Ctrl+E | edit the command line in `$EDITOR` |
| Alt/Ctrl+←/→ | move by word (stops at `/`, `_`, `.`); Home/End: line start/end |
| fn+↑ / fn+↓ | first / last history entry |

## Shorthands and aliases

Git shorthands **expand when you press space** (only as a command's first word), so you
see and keep the real command: `gst` git status, `gco` git checkout, `gcmsg` git commit -m,
`gp` git push, `gl` git pull.

| Alias | Runs |
|---|---|
| `l`, `ls`, `la`, `ll`, `lla`, `tree` | eza (icons; `ll` long; `tree` skips .git) |
| `cat` | bat without the pager (`bat` itself still pages) |
| `c`, `cr`, `cco` | Claude Code; resume a session; continue the last ([claude-code.md](claude-code.md)) |
| `ta`, `tl` | tmux attach (or start one), list sessions |
| `mamba` | micromamba |
| `vim` | nvim, where it's installed |
| `y` | yazi file manager; on quit, cd's to where you were |
| `z <part>`, `zi` | jump to a frequent directory (zoxide); pick with fzf |
| `cd -<Tab>` | recent directories; a directory name alone also cd's into it |

Functions: `dots-sync`, `dots-status`, `dots-pull`, `claude-update`, `codex-update` ([sync.md](sync.md)),
`dots-secret` ([secrets.md](secrets.md)), `ssh-drop` ([ssh.md](ssh.md)), `usegpu N` /
`whichgpu` (CUDA_VISIBLE_DEVICES), `loop 'cmd' secs`, and on snoopy the Slurm helpers
([slurm.md](slurm.md)).

To add your own: shorthands that expand go in `expandingAliases`, plain ones in `aliases`
(`modules/zsh.nix`); `zhelp` picks both up.

## Behaviour worth knowing

- `*` doesn't match dotfiles; Tab still completes them.
- Completion is case-insensitive and matches partial words (`f-b<Tab>` → `foo-bar`).
- History: 100k entries, shared live between shells, with timestamps; commands starting
  with a space aren't saved; `!!` / `!$` expand for review instead of running at once.
  atuin keeps the full searchable history.
- direnv loads `.envrc` silently (with nix-direnv for `use flake`).
- Machine-local settings: `~/.env.zsh` (every shell) and `~/.zprofile.local` (login
  shells, e.g. the Mac's `brew shellenv`); both sourced, neither tracked.
- Linux: an interactive zsh that isn't home-manager's (Ubuntu's `/usr/bin/zsh`, an old
  static zsh) replaces itself with home-manager's zsh before loading the config, since
  this config's compiled modules (fzf-tab) only load there.

## Completion

Tab completion covers the commands in use (`modules/completions.nix`):

| Commands | From |
|---|---|
| gh, uv, codex, nh, rg, fd, bat, eza, atuin, home-manager, nix, ... | the Nix packages themselves |
| `conda`, `mamba`, `micromamba` (incl. env names for `activate`) | [conda-zsh-completion](https://github.com/conda-incubator/conda-zsh-completion), patched for micromamba |
| `sbatch`, `squeue`, `scontrol`, `scancel`, `sacct`, `srun`, ... (snoopy) | the zsh completion contributed to [SchedMD bug 7786](https://support.schedmd.com/show_bug.cgi?id=7786) |
| `systemctl`, `journalctl`, `docker`, ... | the system's (Ubuntu vendor completions, Homebrew on the Mac) |
| `docker`, `tailscale` when not from Nix | generated on first use from the tool itself, cached in `~/.cache/zsh/completions` |
| `dots-secret`, `sgpu`, `slog` | `zsh/completions/` in this repo |

New completions are picked up after a switch (it resets the completion cache) or the
next day. To add one, drop `_name` into `zsh/completions/`, or add a self-completing tool
to `selfCompleting` in `modules/completions.nix`.

## Prompt and theme

Starship ("Tokyo Night" colours): OS, directory, git branch/status, language versions,
conda env and time; past prompts collapse to a single `❯`. The colours live in
`modules/theme.nix` and tmux reads the same palette, so the two always match.

## Tools

eza, bat, ripgrep, fd, jq, jless, sd, dust, duf, procs, tldr, gh, lazygit (+ delta for
side-by-side diffs), difftastic, ast-grep, hyperfine, tokei, watchexec, mosh, nh,
nix-output-monitor, fzf, atuin, zoxide, yazi, direnv, uv, micromamba, age, Claude Code and
Codex.

## Python

`micromamba` (`mamba`) manages environments (conda-forge + system deps like CUDA); `uv` is
the fast pip inside one:

```bash
mamba create -n proj python=3.12 && mamba activate proj
uv pip install <packages>
```

The root (`MAMBA_ROOT_PREFIX`) is per machine: `~/miniforge3` on the Mac and the Linux
machines (existing envs), `/scr/borueihu/miniforge3` on snoopy. Environment contents
aren't in the repo; recreate them from spec on a new machine.

## Startup time

~80 ms (`time zsh -i -c exit`). Tool init scripts (starship, fzf, atuin, zoxide, direnv,
micromamba) are generated at build time instead of running in every shell, and
`compinit` only does its full check once a day or after a switch.
