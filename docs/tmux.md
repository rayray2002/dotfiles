# tmux

[oh-my-tmux](https://github.com/gpakosz/.tmux) plus `tmux/.tmux.conf.local`
(`modules/tmux.nix`). After changing the config, `prefix r` reloads a running tmux.

## Starting

| | |
|---|---|
| `ta` | attach to the last session, or start one |
| `tl` | list sessions |
| `prefix C-c` / `prefix C-f` | new session / find a session by name |

The prefix is **Ctrl+B**, and **Ctrl+A** works too.

A tmux server only accepts clients of its own version. If a server was started by another
tmux (Ubuntu's, from before this config, or the previous version before an update),
attaching with Nix's tmux fails with "open terminal failed: not a terminal". On Linux,
`tmux`/`ta`/`tl` therefore use the binary that started the running server until you
restart it (`tmux kill-server` once nothing in it matters); new servers use Nix's tmux.

## Keys (after the prefix)

| Key | Does |
|---|---|
| `\|` / `-` | split side by side / one above the other (new pane keeps the directory) |
| `_` | split side by side (oh-my-tmux's key) |
| `h` `j` `k` `l` | move between panes |
| `H` `J` `K` `L` | resize the pane (repeatable) |
| `+` | maximize / restore the pane |
| `<` / `>` | swap the pane with the previous / next |
| `C-h` / `C-l` | previous / next window; `Tab` the last window |
| `C-S-h` / `C-S-l` | move the window left / right |
| `BTab` (Shift+Tab) | last session |
| `Enter` | copy mode: `v` select, `C-v` rectangle, `y` copy, `Esc` quit |
| `b` / `p` / `P` | list / paste / choose paste buffer |
| `m` / `M` | mouse on / off (on by default) |
| `` ` `` | process tree of the current pane |
| `C-s` / `C-r` | save / restore sessions now |
| `e` | edit `~/.tmux.conf.local` (the generated one; edit the repo copy to keep changes) |
| `r` | reload the config |

Outside the prefix, Ctrl+L clears the screen and the scrollback.

## What this config adds

- **Sessions survive reboots.** tmux-resurrect + tmux-continuum (from Nix, no plugin
  manager): saved every 15 minutes with pane contents to `~/.local/share/tmux/resurrect`,
  restored when a tmux server starts.
- **Clipboard over ssh.** Copying in tmux (and apps like nvim inside it) reaches the
  local clipboard through the terminal (OSC 52), also from remote machines. iTerm2 needs
  *Applications in terminal may access clipboard*, which is on.
- **Claude Code and other TUIs.** Extended keys, so Shift+Enter and similar reach the app;
  passthrough, so their notifications reach iTerm2 ([claude-code.md](claude-code.md)).
- 50k lines of scrollback; new panes use home-manager's zsh.
- **Theme** matches the shell prompt (shared palette in `modules/theme.nix`): session name
  on lavender, the current window in the prompt's blue, synchronized panes outlined in red.
  The status bar's right side shows the prefix/mouse indicators, time, date, user and host.
