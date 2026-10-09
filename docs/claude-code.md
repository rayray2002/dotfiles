# Claude Code

Installed from Nix on every machine (`claude-code-nix` input, bumped daily by CI;
`claude-update` bumps it now). Config: `modules/claude.nix`, `claude/CLAUDE.md`.

## Aliases

| | |
|---|---|
| `c` | `claude --dangerously-skip-permissions` (`--permission-mode auto` on snoopy) |
| `cr` | `claude --resume`: pick a past session |
| `cco` | `claude --continue`: continue the last session in this directory |

## CLAUDE.md: shared and per project

Claude Code combines several `CLAUDE.md` files; each has its own scope:

| File | Applies to | Shared through |
|---|---|---|
| `~/.claude/CLAUDE.md` | every project on the machine | **this repo** (`claude/CLAUDE.md`) |
| `<project>/CLAUDE.md` | that project (subfolders can add their own) | the project's git repo |
| `<project>/CLAUDE.local.md` | that project, just you | not shared (gitignored) |

The shared one holds what's true everywhere: the machines, Slurm etiquette and limits,
where data goes on snoopy, the dotfiles workflow, how to treat secrets. Project files
keep project knowledge. `~/.claude/CLAUDE.md` is a link to the repo file, so it stays
editable (including memory added with `#`); `dots-sync` shares the change.

To reuse a block of instructions across projects, keep it once in the repo and import it
from each project's `CLAUDE.md` with Claude Code's `@path` syntax, e.g.
`@~/.claude/CLAUDE.md` or `@~/dotfiles/claude/<snippet>.md`.

## Settings

A few keys are merged into `~/.claude/settings.json` at every activation (jq deep merge;
everything else in the file, like model, permissions or hooks, stays yours to change from
Claude):

- plugins: `claude-hud`, `superpowers`, `codex`, `ralph-loop`, and their marketplaces;
- the claude-hud status line, run with Node from Nix (works on every machine).

Change the shared set in `modules/claude.nix`.

## In tmux and over ssh

- Shift+Enter (and other modified keys) reach Claude inside tmux (`extended-keys`).
- Its notifications pass through tmux to iTerm2 (`allow-passthrough`).
- Copying from tmux reaches the Mac's clipboard over ssh (OSC 52).

## On snoopy

Interactive sessions run in the rootless env (`HOME=/scr/borueihu/nixhome`). For GPU work
Claude should use `sgpu` / `sbatch` (see [slurm.md](slurm.md)); the shared `CLAUDE.md` tells
it so.
