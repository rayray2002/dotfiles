# dotfiles

Declarative shell environment managed with [home-manager](https://github.com/nix-community/home-manager) (flakes). zsh + starship + a curated modern CLI toolset, portable across macOS and Linux.

## First-time setup

1. Install Nix and enable flakes:
   ```bash
   sh <(curl -L https://nixos.org/nix/install)
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```
2. Clone and activate:
   ```bash
   git clone https://github.com/rayray2002/dotfiles.git ~/dotfiles && cd ~/dotfiles
   nix run home-manager/master -- switch -b backup --flake '.#ray@mac'   # or .#ray@linux
   ```
   `-b backup` renames any existing `~/.zshrc`, `~/.gitconfig`, etc. to `*.backup`
   instead of failing, so the first activation is non-destructive.

## Daily use

- Edit a `.nix` file, then apply:
  ```bash
  home-manager switch --flake ~/dotfiles#ray@mac     # or ray@linux
  ```
- Roll back the last change: `home-manager switch --rollback`
- Update pinned versions: `nix flake update` then switch again.

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
| `home/darwin.nix` (this mac) | `~/miniforge3` | reuses the pre-existing miniforge envs (`base`, `wam`, `telegram`, …) |
| `home/linux.nix` / fresh machines | `~/micromamba` | clean Nix-native root |

Environment *contents* are never stored in the repo — on a new machine you recreate
them from spec. The legacy mac root (`~/miniforge3`) can't be renamed by moving it
(env shebangs hardcode the prefix); it would have to be recreated.

## Layout

| Path | Purpose |
|------|---------|
| `flake.nix` | inputs + `ray@mac` / `ray@linux` home configurations |
| `home/common.nix` | shared config; imports all modules |
| `home/{darwin,linux}.nix` | per-platform home directory, mamba root, extras |
| `modules/zsh.nix` | zsh: aliases, plugins, history, helpers, PATH ordering |
| `modules/starship.nix` | prompt |
| `modules/tools.nix` | fzf, zoxide, direnv, atuin, lazygit, yazi, claude-code + CLI packages |
| `modules/git.nix` | git config + delta |
| `modules/python.nix` | uv + micromamba (root prefix set per-host) |
| `modules/tmux.nix` | tmux + oh-my-tmux + ssh config symlinks |

## Scope

Homebrew still manages GUI casks, fonts, and heavy/specialized tools (qemu, lima, opencv,
etc.). The Nix profile is prepended ahead of Homebrew on `PATH` (see `modules/zsh.nix`),
so CLI tools present in both resolve to Nix. Neovim is currently installed via Homebrew
(Nix migration deferred).
