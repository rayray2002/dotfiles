# Nix Shell Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the zsh4humans + powerlevel10k + shell-script-based dotfiles setup with a declarative, reproducible, flake-based home-manager configuration (zsh + starship + core CLI tools), portable across this macOS machine and Linux.

**Architecture:** Standalone home-manager driven by a flake. `flake.nix` exposes two `homeConfigurations` (`ray@mac` → aarch64-darwin, `ray@linux` → x86_64-linux) that both import `home/common.nix`, which in turn imports focused modules under `modules/`. `home-manager switch` builds a generation in the Nix store and atomically swaps `$HOME` symlinks; rollback is one command. Homebrew is left in place for GUI casks, fonts, and heavy/specialized tools.

**Tech Stack:** Nix (flakes), home-manager, zsh (native, no framework) with `zsh-autosuggestions` / `zsh-syntax-highlighting` / `zsh-fzf-tab` / `zsh-abbr`, starship, fzf, zoxide, direnv (+ nix-direnv), eza, bat, ripgrep, fd.

---

## Notes for the executor (read first)

- **This plan touches your real `$HOME`.** Tasks 0–6 only build/eval (no activation). Task 7 is the first activation (`home-manager switch -b backup`), which backs up your existing `~/.zshrc`/`~/.zshenv`/`~/.p10k.zsh` before replacing them. Nothing is deleted until Task 8, after you've verified the new shell works.
- **Per-task build check** (no activation, safe to run anytime):
  `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
- **macOS already uses zsh as the login shell**, and home-manager writes `~/.zshrc` that the system zsh sources — so **no `chsh` is required**. (If `echo $SHELL` is not zsh, run `chsh -s /bin/zsh`.)
- **`home.stateVersion = "25.05"`** is set deliberately. Do not bump it casually — it only gates default-value migrations, and a low value is always safe.
- Repo lives at `/Users/ray/dotfiles`. All paths below are relative to that root.

---

## File structure (created by this plan)

```
dotfiles/
├── flake.nix              # inputs + two homeConfigurations + oh-my-tmux input
├── flake.lock             # generated, pins everything
├── home/
│   ├── common.nix         # username, stateVersion, imports of modules/*
│   ├── darwin.nix         # imports common; homeDirectory=/Users/ray; mac extras
│   └── linux.nix          # imports common; homeDirectory=/home/ray; GPU/linux extras
├── modules/
│   ├── tools.nix          # fzf, zoxide, direnv + home.packages (eza, bat, rg, fd, ...)
│   ├── zsh.nix            # programs.zsh: aliases, plugins, history, initContent
│   ├── starship.nix       # programs.starship
│   └── tmux.nix           # tmux pkg + oh-my-tmux base + .tmux.conf.local symlink
├── tmux/.tmux.conf.local  # existing (kept, referenced by modules/tmux.nix)
└── ssh/config             # existing (symlinked by modules/tmux.nix? -> handled in Task 5)
```

---

## Task 0: Install Nix + enable flakes (prerequisite — run by the user)

**This task is interactive and needs sudo; it cannot be done by a subagent.** If Nix is already installed and flakes are enabled, skip to Task 1.

- [ ] **Step 1: Confirm Nix is not already present**

Run: `command -v nix || echo "no nix"`
Expected: `no nix` (if it prints a path, Nix is installed — go to Step 4).

- [ ] **Step 2: Install Nix (official multi-user installer)**

In the user's terminal (the `! ` prefix runs it in this session):

```bash
sh <(curl -L https://nixos.org/nix/install)
```

(Alternative one-liner that enables flakes automatically: the Determinate Systems installer
`curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`.
The official installer above is used here for vendor-neutral longevity.)

Then open a new terminal (or `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`).

- [ ] **Step 3: Enable flakes**

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

- [ ] **Step 4: Verify**

Run: `nix --version && nix flake --help >/dev/null && echo "flakes ok"`
Expected: prints a version (e.g. `nix (Nix) 2.x`) followed by `flakes ok`.

No commit (no repo changes in this task).

---

## Task 1: Flake skeleton + minimal buildable home config

**Files:**
- Create: `flake.nix`
- Create: `home/common.nix`
- Create: `home/darwin.nix`

- [ ] **Step 1: Create `flake.nix`**

```nix
{
  description = "ray's home-manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oh-my-tmux = {
      url = "github:gpakosz/.tmux";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      mkHome = system: module:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs; };
          modules = [ module ];
        };
    in {
      homeConfigurations = {
        "ray@mac" = mkHome "aarch64-darwin" ./home/darwin.nix;
        "ray@linux" = mkHome "x86_64-linux" ./home/linux.nix;
      };
    };
}
```

- [ ] **Step 2: Create `home/common.nix` (minimal for now — modules added in later tasks)**

```nix
{ ... }:
{
  home.username = "ray";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
```

- [ ] **Step 3: Create `home/darwin.nix`**

```nix
{ ... }:
{
  imports = [ ./common.nix ];
  home.homeDirectory = "/Users/ray";
}
```

- [ ] **Step 4: Create a temporary stub `home/linux.nix` so the flake evaluates**

(Replaced with the real file in Task 6; needed now because the flake references it.)

```nix
{ ... }:
{
  imports = [ ./common.nix ];
  home.homeDirectory = "/home/ray";
}
```

- [ ] **Step 5: Build the mac config (this also creates `flake.lock`)**

Run: `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
Expected: completes with no error (first run downloads nixpkgs/home-manager and writes `flake.lock`). No output on success.

- [ ] **Step 6: Commit**

```bash
git add flake.nix flake.lock home/
git commit -m "feat(nix): flake skeleton + minimal home-manager config

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Core CLI tools module

**Files:**
- Create: `modules/tools.nix`
- Modify: `home/common.nix`

- [ ] **Step 1: Create `modules/tools.nix`**

`eza`/`bat` are installed as plain packages (not their `programs.*` modules) so they don't
auto-inject aliases that would collide with the explicit ones defined in `modules/zsh.nix`.
`fzf`/`zoxide`/`direnv` use their modules because we want their shell integration.

```nix
{ pkgs, ... }:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    eza
    bat
    ripgrep
    fd
    jq
    tldr
    gh
    wget
  ];
}
```

- [ ] **Step 2: Import it from `home/common.nix`**

Replace the contents of `home/common.nix` with:

```nix
{ ... }:
{
  imports = [
    ../modules/tools.nix
  ];

  home.username = "ray";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
```

- [ ] **Step 3: Build**

Run: `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
Expected: completes with no error.

- [ ] **Step 4: Commit**

```bash
git add modules/tools.nix home/common.nix
git commit -m "feat(nix): core CLI tools (fzf, zoxide, direnv, eza, bat, rg, fd, ...)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: zsh module

**Files:**
- Create: `modules/zsh.nix`
- Modify: `home/common.nix`

- [ ] **Step 1: Create `modules/zsh.nix`**

Aliases are ported from the old `zsh/.zshrc`. Note `cat` maps to `bat` (the old config used
the Debian-only `batcat` name; on Nix/macOS the binary is `bat`). The GPU/`loop` helper
functions and shell options are ported into `initContent`. `zoxide`/`fzf`/`direnv` init is
injected by their own modules (Task 2), so it is intentionally not repeated here.

In Nix indented strings (`'' ... ''`), a bare `$` (as in `$1`, `$TTY`) is literal; only
`${...}` triggers interpolation, so the shell functions below need no escaping.

```nix
{ lib, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    shellAliases = {
      l = "eza";
      ls = "eza --icons";
      la = "eza --icons -a";
      ll = "eza --icons -lg";
      lla = "eza --icons -lga";
      tree = "eza --icons -T -a -I .git";
      cat = "bat";
      vim = "nvim";
      ta = "tmux a";
      tl = "tmux ls";
    };

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-abbr";
        src = pkgs.zsh-abbr;
        file = "share/zsh/zsh-abbr/zsh-abbr.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        path=(~/bin $path)
        fpath=(~/.zfunc $fpath)
      '')
      (lib.mkOrder 1000 ''
        export GPG_TTY=$TTY

        setopt glob_dots
        setopt no_auto_menu

        # GPU helpers (ported from old .zshrc)
        usegpu() { export CUDA_VISIBLE_DEVICES="$1"; }
        whichgpu() { echo "$CUDA_VISIBLE_DEVICES"; }
        loop() { while true; do eval "$1"; sleep "$2"; clear; done; }

        # local, machine-specific overrides
        [[ -f ~/.env.zsh ]] && source ~/.env.zsh
      '')
    ];
  };
}
```

- [ ] **Step 2: Add the import to `home/common.nix`**

Change the `imports` list in `home/common.nix` to:

```nix
  imports = [
    ../modules/tools.nix
    ../modules/zsh.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
Expected: completes with no error. (If the `zsh-abbr` `file` path errors, confirm it with
`ls $(nix build --no-link --print-out-paths nixpkgs#zsh-abbr)/share/zsh/zsh-abbr/` and adjust.)

- [ ] **Step 4: Inspect the generated rc to confirm content landed**

Run: `nix build --no-link --print-out-paths '.#homeConfigurations."ray@mac".activationPackage' | xargs -I{} grep -l "usegpu" {}/home-files/.zshrc`
Expected: prints a path (the generated `.zshrc` contains the `usegpu` helper).

- [ ] **Step 5: Commit**

```bash
git add modules/zsh.nix home/common.nix
git commit -m "feat(nix): native zsh (aliases, history, fzf-tab, zsh-abbr, helpers)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: starship prompt module

**Files:**
- Create: `modules/starship.nix`
- Modify: `home/common.nix`

- [ ] **Step 1: Create `modules/starship.nix`**

`command_timeout` is raised so starship never truncates the prompt in larger git repos (the
one weak spot of starship's synchronous rendering). Settings start close to defaults; tune later.

```nix
{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 1000;

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      directory.truncation_length = 4;
      git_branch.symbol = " ";
    };
  };
}
```

- [ ] **Step 2: Add the import to `home/common.nix`**

Change the `imports` list to:

```nix
  imports = [
    ../modules/tools.nix
    ../modules/zsh.nix
    ../modules/starship.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
Expected: completes with no error.

- [ ] **Step 4: Commit**

```bash
git add modules/starship.nix home/common.nix
git commit -m "feat(nix): starship prompt

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: tmux + ssh dotfiles

**Files:**
- Create: `modules/tmux.nix`
- Modify: `home/common.nix`

The oh-my-tmux base (`gpakosz/.tmux`) comes from the `oh-my-tmux` flake input added in
Task 1, so it is pinned by `flake.lock` (no manual hashes). The existing
`tmux/.tmux.conf.local` and `ssh/config` are symlinked from the repo.

- [ ] **Step 1: Create `modules/tmux.nix`**

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [ pkgs.tmux ];

  # oh-my-tmux base config + the user's local overrides
  home.file.".tmux.conf".source = "${inputs.oh-my-tmux}/.tmux.conf";
  home.file.".tmux.conf.local".source = ../tmux/.tmux.conf.local;

  # ssh client config (NOT private keys; authorized_keys intentionally left out)
  home.file.".ssh/config".source = ../ssh/config;
}
```

- [ ] **Step 2: Add the import to `home/common.nix`**

Change the `imports` list to:

```nix
  imports = [
    ../modules/tools.nix
    ../modules/zsh.nix
    ../modules/starship.nix
    ../modules/tmux.nix
  ];
```

- [ ] **Step 3: Confirm the referenced files exist**

Run: `ls tmux/.tmux.conf.local ssh/config`
Expected: both paths listed (no "No such file").

- [ ] **Step 4: Build**

Run: `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
Expected: completes with no error.

- [ ] **Step 5: Commit**

```bash
git add modules/tmux.nix home/common.nix
git commit -m "feat(nix): tmux (oh-my-tmux base + local conf) and ssh config symlinks

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> **Note for the executor:** `ssh/authorized_keys` and `ssh/install.sh` are intentionally not
> managed here. Confirm with the user during Task 8 whether `authorized_keys` should be tracked
> at all (it is a server-side file, unusual in client dotfiles).

---

## Task 6: Real Linux config + cross-platform eval

**Files:**
- Modify: `home/linux.nix` (replace the Task 1 stub)

- [ ] **Step 1: Replace `home/linux.nix` with the real version**

GPU work happens on Linux boxes, so the `loop`/`usegpu` helpers already live in the shared
zsh module; this file only carries the Linux home directory and any future Linux-only packages.

```nix
{ ... }:
{
  imports = [ ./common.nix ];
  home.homeDirectory = "/home/ray";
}
```

- [ ] **Step 2: Eval the Linux config (build its derivation graph without realising binaries)**

Run: `nix eval '.#homeConfigurations."ray@linux".activationPackage.drvPath'`
Expected: prints a `/nix/store/....drv` path with no evaluation error. (This catches
platform-specific breakage without building Linux binaries on macOS.)

- [ ] **Step 3: Build the mac config once more to confirm nothing regressed**

Run: `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
Expected: completes with no error.

- [ ] **Step 4: Commit**

```bash
git add home/linux.nix
git commit -m "feat(nix): real cross-platform linux home configuration

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: First activation + verification

**No file changes.** This is the first time the new environment touches `$HOME`. The old
`~/.zshrc`, `~/.zshenv`, `~/.p10k.zsh` are backed up (`.backup` suffix), not destroyed.

- [ ] **Step 1: Record the current (pre-switch) tool paths for comparison**

Run: `for c in eza bat fzf zoxide rg fd starship; do printf "%s -> " "$c"; command -v "$c" || echo "(none)"; done`
Expected: notes where each currently resolves (likely `/opt/homebrew/bin/...` or none).

- [ ] **Step 2: Activate (bootstraps home-manager from the flake, backs up existing dotfiles)**

Run: `nix run home-manager/master -- switch -b backup --flake '.#ray@mac'`
Expected: ends with `Activating ...` lines and no error. Existing `~/.zshrc` etc. are renamed
to `~/.zshrc.backup`.

- [ ] **Step 3: Open a NEW terminal (or `exec zsh -l`) and verify the prompt + tools**

Run (in the new shell):
`for c in eza bat fzf zoxide rg fd starship; do printf "%s -> " "$c"; command -v "$c"; done`
Expected: each now resolves under `~/.nix-profile/bin/...` (or `/nix/store/...`).

- [ ] **Step 4: Verify interactive features manually**

Confirm in the new shell:
- The prompt is starship (a `❯` character; git info inside a repo).
- Typing a previously-run command shows a greyed **autosuggestion**.
- Commands are **syntax-highlighted** (valid command turns green, invalid red) as you type.
- `cd ` then `<TAB>` opens the **fzf-tab** fuzzy menu.
- `ll`, `cat <file>`, `z <dir>` (zoxide), and `ta`/`tl` aliases work.
- `abbr add gco='git checkout'` then typing `gco<space>` expands inline (zsh-abbr).

Expected: all behave as described.

- [ ] **Step 5: Verify direnv hook is active**

Run: `type _direnv_hook >/dev/null 2>&1 && echo "direnv hooked"`
Expected: `direnv hooked`.

- [ ] **Step 6: No commit** (activation produces no repo changes). If any check fails, fix the
  relevant module from Tasks 2–5, rebuild, re-run `home-manager switch --flake '.#ray@mac'`,
  and re-verify before proceeding.

---

## Task 8: Decommission the legacy setup

**Only after Task 7 fully passes.** Removes the z4h / powerlevel10k / shell-script remnants
that home-manager now supersedes.

**Files:**
- Delete: `zsh/.zshrc`, `zsh/.p10k.zsh`, `zsh/install_zsh.sh`, `zsh/install_commands.sh`
- Delete: `tmux/install.sh`, `ssh/install.sh`

- [ ] **Step 1: Confirm the new shell has been working in a fresh terminal** (sanity gate;
  do not delete the backups until you are confident). The home-manager backups
  (`~/.zshrc.backup`, `~/.p10k.zsh.backup`, `~/.zshenv.backup`) remain as a safety net.

- [ ] **Step 2: Remove obsolete repo files**

```bash
git rm zsh/.zshrc zsh/.p10k.zsh zsh/install_zsh.sh zsh/install_commands.sh \
       tmux/install.sh ssh/install.sh
```

- [ ] **Step 3: Confirm `ssh/authorized_keys` with the user**

Ask the user whether `ssh/authorized_keys` should stay tracked. If they say remove it:
`git rm ssh/authorized_keys`. Otherwise leave it. (Default: leave it, do nothing.)

- [ ] **Step 4: Build once more to ensure no module still referenced a deleted file**

Run: `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'`
Expected: completes with no error.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(nix): remove z4h/p10k and shell-script installers superseded by home-manager

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: README / usage docs

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create `README.md`**

```markdown
# dotfiles

Declarative shell environment managed with [home-manager](https://github.com/nix-community/home-manager) (flakes). zsh + starship + core CLI tools, portable across macOS and Linux.

## First-time setup

1. Install Nix and enable flakes:
   ```bash
   sh <(curl -L https://nixos.org/nix/install)
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```
2. Clone and activate:
   ```bash
   git clone <this-repo> ~/dotfiles && cd ~/dotfiles
   nix run home-manager/master -- switch -b backup --flake '.#ray@mac'   # or .#ray@linux
   ```

## Daily use

- Edit a `.nix` file, then apply:
  ```bash
  home-manager switch --flake ~/dotfiles#ray@mac     # or ray@linux
  ```
- Roll back the last change: `home-manager switch --rollback`
- Update pinned versions: `nix flake update` then switch again.

## Layout

| Path | Purpose |
|------|---------|
| `flake.nix` | inputs + `ray@mac` / `ray@linux` home configurations |
| `home/common.nix` | shared config; imports all modules |
| `home/{darwin,linux}.nix` | per-platform home directory + extras |
| `modules/zsh.nix` | zsh: aliases, plugins, history, helpers |
| `modules/starship.nix` | prompt |
| `modules/tools.nix` | fzf, zoxide, direnv + CLI packages |
| `modules/tmux.nix` | tmux + oh-my-tmux + ssh config symlinks |

## Scope

Homebrew still manages GUI casks, fonts, and heavy/specialized tools (qemu, lima, opencv,
etc.). Neovim is currently installed via Homebrew (Nix migration deferred).
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README for the home-manager setup

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Done criteria

- `nix build --no-link '.#homeConfigurations."ray@mac".activationPackage'` succeeds.
- `nix eval '.#homeConfigurations."ray@linux".activationPackage.drvPath'` succeeds.
- A fresh terminal shows the starship prompt with working autosuggestions, syntax
  highlighting, fzf-tab, zsh-abbr, aliases, zoxide, and direnv.
- `eza bat fzf zoxide rg fd starship` resolve into the Nix profile.
- z4h no longer bootstraps and `~/.p10k.zsh` is no longer sourced.
- Legacy install scripts and z4h/p10k files removed; `README.md` documents the workflow.
