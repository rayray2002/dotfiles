****# Nix-based Shell Environment — Design

**Date:** 2026-05-30
**Status:** Approved (design); pending implementation plan
**Author:** ray (with Claude)

## Goal

Convert the current shell environment into a **declarative, reproducible, Nix-managed
setup** that "lives with me for a long time." Replace the self-bootstrapping zsh4humans
(z4h) framework and the life-support powerlevel10k prompt with actively-maintained,
Nix-friendly tooling. Keep POSIX/zsh muscle memory intact.

## Decisions (locked)

| Axis | Decision | Rationale |
|---|---|---|
| **Scope** | User env only, via **home-manager (standalone)** | Manage CLI tools + dotfiles declaratively; leave macOS system + Homebrew GUI/casks untouched. Fully reversible. |
| **Shell** | **zsh** (home-manager native, no framework) | Keeps muscle memory + POSIX compatibility; drop z4h's runtime self-bootstrapping in favor of Nix-pinned plugins. |
| **Prompt** | **starship** | Rust, actively maintained, cross-shell, single TOML config, trivial in Nix. Replaces frozen powerlevel10k. |
| **Package scope** | **Core shell tools only** | Migrate interactive essentials to Nix; leave heavy/specialized tools + casks + fonts in Homebrew. |
| **Portability** | **Cross-platform (macOS + Linux)** | Same shell env builds on this Mac (aarch64-darwin) and Linux/GPU boxes (x86_64-linux). |
| **Pinning** | **Flake + flake.lock** | Byte-identical tools across machines; reproducible rebuilds. |

### Background: why move off z4h + p10k

- **powerlevel10k**: officially on "life support" — maintainer states no new features, won't
  fix most bugs, won't merge most PRs. Still works but frozen.
- **z4h (zsh4humans)**: same single maintainer; self-bootstraps/clones plugins at runtime,
  which fights Nix reproducibility.
- **starship + zsh-native plugins**: actively maintained, fully pinnable by Nix.

## Architecture

home-manager standalone, flake-based. `home-manager switch` builds a generation in the Nix
store and atomically swaps symlinks; rollback via `home-manager switch --rollback`.
`flake.lock` pins the exact nixpkgs commit so the same config reproduces everywhere.

```
dotfiles/
├── flake.nix              # inputs (nixpkgs, home-manager); outputs homeConfigurations
├── flake.lock             # pins exact versions → reproducible across machines
├── home/
│   ├── common.nix         # shared: imports modules/*, common home.packages (Mac & Linux)
│   ├── darwin.nix         # macOS-only (imports common + mac extras)
│   └── linux.nix          # Linux-only (imports common + GPU aliases / linux extras)
├── modules/
│   ├── zsh.nix            # programs.zsh: aliases, plugins, history, options, initContent
│   ├── starship.nix       # programs.starship.settings (TOML-as-Nix)
│   ├── git.nix            # programs.git + delta
│   ├── python.nix         # uv + micromamba (+ micromamba zsh hook)
│   ├── tmux.nix           # tmux config (symlink existing .tmux.conf.local or programs.tmux)
│   └── tools.nix          # fzf, zoxide, direnv, atuin, lazygit, yazi, claude-code + CLI packages
├── ssh/                   # existing config — symlinked via home.file
└── (legacy install_*.sh removed; replaced by home-manager)
```

**Two home configurations** exposed from the flake:
- `ray@mac` → `aarch64-darwin`
- `ray@linux` → `x86_64-linux`

Both import `common.nix`, so the interactive shell is identical; platform files add only
what differs.

## Components

### `modules/zsh.nix` — `programs.zsh`
- `enable = true` — home-manager generates `~/.zshrc` / `~/.zshenv` pointing into the store.
- `autosuggestion.enable = true` — Nix-pinned `zsh-autosuggestions`.
- `syntaxHighlighting.enable = true` — Nix-pinned `zsh-syntax-highlighting`
  (or `fast-syntax-highlighting` via `plugins`).
- `enableCompletion = true` — compsys.
- `plugins` — `fzf-tab` (fuzzy completion menu + preview) and `zsh-abbr`
  (fish-style inline abbreviations, enabled).
- `shellAliases` — migrate existing aliases: `l/ls/la/ll/lla` (eza), `cat=bat`, `vim=nvim`,
  `tree`, `ta`/`tl` (tmux). GPU/`loop` helper functions → `initContent` (or `linux.nix`).
- `history` — sane size + dedup options; `setopt glob_dots`, `no_auto_menu`.
- Integrations (`zoxide`, `fzf`, `direnv`) injected by their own `programs.*` modules rather
  than hand-written `eval` lines.

### `modules/starship.nix` — `programs.starship`
- `enable = true` — installs binary + auto-injects `starship init zsh` into generated rc.
- `settings = { ... }` — prompt config written to `~/.config/starship.toml` from Nix.
- Starting point: a clean default close to current p10k layout (dir, git branch/status,
  language/context, exit status). Tunable later.

### `modules/tools.nix` — core CLI tools
Prefer dedicated `programs.*` modules (they wire up config + shell integration):
`programs.fzf`, `programs.bat`, `programs.eza`, `programs.zoxide`, `programs.direnv`
(+ `nix-direnv`), `programs.git` (optional).
Plain `home.packages` for the rest: `ripgrep`, `fd`, `jq`, `tldr`, `gh`, `wget`, `tree`, etc.
**Neovim stays in Homebrew for now** (deferred).

**Stays in Homebrew** (out of scope): GUI casks, all nerd fonts, and heavy/specialized
tools (`qemu`, `lima`, `opencv`, `qt`, `pwntools`, `macfuse`, `xquartz`, CUDA-adjacent, …).

### `modules/tmux.nix`
Symlink the existing `tmux/.tmux.conf.local` via `home.file`, or migrate to `programs.tmux`.
Replaces the current `git clone gpakosz/.tmux` + `cp` install script.

### ssh
Symlink existing `ssh/config` (+ `authorized_keys` as appropriate) via `home.file`,
replacing `ssh/install.sh`'s `cp -r`. (Review what should be tracked vs machine-local.)

## Data flow / rebuild loop

1. Edit a `.nix` file.
2. `home-manager switch --flake .#ray@mac` (or `ray@linux`).
3. New generation built in `/nix/store`; `~/.config`, `~/.zshrc`, `~/.nix-profile`, etc.
   re-symlinked atomically.
4. Wrong? `home-manager switch --rollback`.
5. New machine: install Nix (+ enable flakes) → `git clone` → one `switch`.

## Coexistence with Homebrew

home-manager does not touch brew. Resulting PATH precedence:
`~/.nix-profile/bin` → `/opt/homebrew/bin` → system. Nix tools win on name collisions;
Homebrew keeps casks, fonts, and heavy/specialized packages.

## Error handling / safety

- **Reversible by construction**: every `switch` is a new generation; rollback restores the
  previous one. Old dotfiles backed up by home-manager on first run (`-b backup`).
- **No destructive deletes** of existing dotfiles until a successful `switch` is verified.
- **Login-shell change** (`chsh` to the Nix zsh, or point to HM-managed zsh) done explicitly
  and verified before removing z4h bootstrap from `.zshrc`.
- **Cross-platform guard**: platform-specific packages live in `darwin.nix`/`linux.nix` so a
  `switch` on either OS never references an unavailable package.

## Verification

- `home-manager switch` completes without error on macOS.
- New interactive zsh shows: autosuggestions, syntax highlighting, starship prompt,
  working `fzf-tab`, working aliases (`ll`, `cat`, `vim`, `ta`), `zoxide`/`z`, `direnv`.
- `which eza bat fzf zoxide rg fd starship` resolve to `~/.nix-profile/...`.
- z4h no longer bootstraps; `.p10k.zsh` no longer sourced.
- (If available) build-eval the `linux` configuration to catch platform breakage early.

## Out of scope (YAGNI)

- nix-darwin / system-level management (macOS defaults, system packages).
- Migrating Homebrew casks, fonts, or heavy/specialized CLI tools.
- Replacing neovim config internals (only its install method, optionally).
- nushell/fish (decided against; `nu` may be added later as a secondary tool only).

## Resolved decisions

- **Neovim**: keep in Homebrew for now. Nix-managing neovim (`programs.neovim` / config)
  is deferred to future work.
- **`zsh-abbr`**: include it (enabled), giving fish-style inline abbreviations in zsh.
- **Extra tooling** (added to `modules/tools.nix`): Tier-1 essentials `delta`, `lazygit`,
  `atuin` (synced fuzzy history — fits the cross-machine goal); modern coreutils `dust`,
  `duf`, `procs`, `sd`, `yazi`; dev utils `hyperfine`, `tokei`, `jless`; agentic-coding
  helpers `ast-grep`, `difftastic`, `watchexec`. `delta` is wired via a new `modules/git.nix`
  (`programs.git` + identity).
- **Python**: `micromamba` (the Nix-packaged "mamba", aliased `mamba`) manages environments /
  conda-forge + system deps (CUDA); `uv` is the fast pip *inside* an active env. New
  `modules/python.nix`. `pixi` noted as a future unified alternative but not adopted now.
- **AI / vibe-coding**: add `claude-code` via the auto-updating `sadjow/claude-code-nix` flake
  input (reproducible *and* current, since plain nixpkgs lags agent releases by days/weeks);
  installed through `modules/tools.nix`. Gemini CLI dropped (retired by Google 2026-05-19).
  aichat/llm/mods declined for now. A dedicated `modules/ai.nix` can be split out later if more
  agents are added.

## Open questions for implementation

- ssh: which files are safe to track in the repo vs keep machine-local.
