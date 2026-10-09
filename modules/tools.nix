{ config, inputs, lib, pkgs, ... }:
let
  # Shell integrations are generated once at build time and sourced, instead
  # of home-manager's default `eval "$(tool init zsh)"` in every new shell
  # (together ~150 ms of startup). The output only embeds the tool's own store
  # path, so it changes exactly when the tool does.
  initScript = name: cmd: pkgs.runCommand "${name}-init.zsh" { } ''
    HOME=$TMPDIR ${cmd} > $out
  '';
  exe = p: lib.getExe config.programs.${p}.package;
in
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;   # sourced below
    # fd: fast, skips .gitignored files, includes dotfiles
    defaultCommand = "fd --type f --hidden --exclude .git";
    fileWidget = {
      command = "fd --type f --hidden --exclude .git";
      options = [ "--preview 'bat --color=always --style=numbers --line-range=:200 {}'" ];
    };
    changeDirWidget = {
      command = "fd --type d --hidden --exclude .git";
      options = [ "--preview 'eza -T -L 2 --color=always --icons {}'" ];
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;   # sourced below
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false;   # sourced below
    silent = true;                  # no "direnv: export +FOO ..." on every cd
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = false;   # sourced below
    flags = [ "--disable-up-arrow" ];
    settings = {
      enter_accept = true;
      auto_sync = true;
      sync_frequency = "5m";
      filter_mode_shell_up_key_binding = "directory";
      style = "compact";
      inline_height = 20;
    };
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
  };

  programs.lazygit.enable = true;

  # Order matters: atuin after fzf so Ctrl+R is atuin's; zoxide after compinit.
  programs.zsh.initContent = lib.mkOrder 900 ''
    if [[ $options[zle] = on ]]; then
      source ${initScript "fzf" "${exe "fzf"} --zsh"}
      source ${initScript "atuin" "${exe "atuin"} init zsh ${lib.escapeShellArgs config.programs.atuin.flags}"}
    fi
    source ${initScript "zoxide" "${exe "zoxide"} init zsh ${lib.escapeShellArgs config.programs.zoxide.options}"}
    source ${initScript "direnv" "${exe "direnv"} hook zsh"}
  '';

  home.packages = with pkgs; [
    # core
    eza
    bat
    ripgrep
    fd
    jq
    tldr
    gh
    wget
    # modern coreutils
    dust
    duf
    procs
    sd
    # dev utilities
    hyperfine
    tokei
    jless
    # networking
    mosh                # 1.4+ — truecolor support (Ubuntu apt only ships 1.3.2)
    # agentic-coding helpers
    ast-grep
    difftastic
    watchexec
    # nix
    nh                  # Clean Nix CLI wrapper
    nix-output-monitor  # Pretty build logs
  ] ++ [
    # AI agent CLIs — each on its own flake input so they can be bumped
    # independently of the main nixpkgs pin.
    inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.nixpkgs-codex.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codex
  ];
}
