# Neovim

Neovim 0.12, its plugins and every language server come from Nix
(`modules/neovim.nix`), so all machines, rootless snoopy included, get the same editor
with nothing downloaded at runtime. `vim`, `vi` and `vimdiff` run it, and it's `$EDITOR`.
The Lua config is `nvim/lua/dots/`. Press `Space` and wait: which-key lists every key below.

## Python projects

Each project's code is analysed with its own interpreter and import paths, set in
`nvim/lua/dots/projects.lua` and matched by the longest path prefix:

| Path | Python | Extra import paths |
|---|---|---|
| `~/whole-arm-manipulation` | env `curobo` | `src`, repo root, `third-party/curobov2/src` |
| `~/whole-arm-manipulation/robot_scripts`, `~/dev_ws` | `/usr/bin/python3` (ROS 2 Humble) | `/opt/ros/humble/...` |
| `~/segment-anysim` | env `sam3d-objects` | repo root |

Without an entry: an activated env (`$VIRTUAL_ENV`, or `$CONDA_PREFIX` if not `base`),
then `<root>/.venv`. `:DotsPython` (`<leader>cp`) shows what the current buffer uses. Add a
project by adding a line to `projects.lua`.

- **basedpyright** reports types and undefined names, only for open files, and never
  analyses data, runs, outputs, vendored code or agent worktrees. Type strictness is per
  project (`typeChecking`).
- **ruff** does lint, quick fixes and import order, following each project's own
  `pyproject.toml` (e.g. line length 120 in whole-arm-manipulation).
- **Formatting is on demand only** (`<leader>cf`), never on save, so it never rewrites
  files of a repo that isn't ruff-formatted.

Other files: YAML, JSON, TOML, XML (URDF / xacro / MJCF / launch), Markdown, LaTeX, bash,
Lua and Nix have language servers; PDDL is highlighted as Lisp; ROS `.srv/.msg/.action`
get their own file type.

## Keys

`Space` is the leader. Kept from before: `;` enters the command line, `jk` leaves insert
mode.

| Keys | Does |
|---|---|
| `<leader><space>` | find anything (files, buffers, recent) |
| `<leader>ff` / `fF` | files / files including ignored and hidden ones |
| `<leader>fg` / `fG` | grep / grep everything; `<leader>fw` the word under the cursor |
| `<leader>fb` `fr` `fd` `fk` `f.` | buffers, recent, diagnostics, keymaps, resume |
| `-` | the file's directory as an editable buffer (rename, move, delete by editing) |
| `gd` `gr` `K` | definition, references, hover |
| `grn` `gra` `gri` `gO` | rename, code action, implementation, symbols (Neovim defaults) |
| `<leader>cf` `ca` `cr` `cd` `cs` `cp` | format, action, rename, line diagnostics, symbols, which Python |
| `]h` `[h` `<leader>gp` `gr` `gb` | next/previous change, preview, reset, blame |
| `<leader>gg` `gd` `gh` `gs` | lazygit, diff working tree, file history, changed files |
| `<leader>db` `dc` `do` `di` `dO` | breakpoint, start/continue, over, into, out |
| `<leader>dt` `dT` `du` `dq` | debug test under cursor / class, debug view, stop |
| `<leader>rr` `rl` `rs` `rc` `rf` | REPL: open, send line / selection / `# %%` cell / file |
| `<leader>ac` `af` `as` `ab` | Claude: toggle, focus, send selection, add file |
| `<leader>aa` `ad` | accept / reject Claude's proposed edit |
| `Ctrl+/`, `<leader>tt` | terminal |
| `af` `if` `ac` `ic` | function / class text objects (e.g. `vaf`, `dic`) |
| `sa` `sd` `sr` | add / delete / replace surroundings |

The file finder and grep never show secrets (`.env`, `*.age`, keys, `deepseek.sh`) or the
data / runs / output / vendored / worktree folders; the "everything" variants
(`fF`, `fG`) include them except `.git`.

## Debugging

`<leader>dc` offers: the current file, the file with arguments, a module
(`python -m scripts.pipeline.run …`), and attaching to a running debugpy, e.g. a solver
server started with `python -m debugpy --listen 5678 scripts/solver_server.py`.
`<leader>dt` debugs the pytest test under the cursor. The debugger (debugpy) comes from Nix;
your code runs in the project's env, so nothing needs installing in each env.

## REPL

`<leader>rr` opens IPython from the project's env beside the code (plain `python` if the
env has no IPython). Mark cells with `# %%` and send them with `<leader>rc` (`rn` sends and
moves to the next one): notebook-style exploration in a plain `.py` file.

## Claude Code

`<leader>ac` opens Claude Code in a side split connected to this Neovim: it sees your
selection, and its edits open here as diffs to accept (`<leader>aa`) or reject
(`<leader>ad`). A `claude` already running in another tmux pane connects with `/ide`.

## Over ssh and in tmux

Yanking copies to your local clipboard through the terminal (OSC 52), from any machine.
Paste with `p` (from Neovim's register) or your terminal's paste. Huge files (≥1.5 MB)
open without tree-sitter and LSP.
