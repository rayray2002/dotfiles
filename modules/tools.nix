{ inputs, pkgs, ... }:
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

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      style = "compact";
      inline_height = 20;
    };
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.lazygit.enable = true;

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
    du-dust
    duf
    procs
    sd
    # dev utilities
    hyperfine
    tokei
    jless
    # agentic-coding helpers
    ast-grep
    difftastic
    watchexec
  ] ++ [
    # AI agent CLI — auto-updating via the claude-code-nix flake input
    inputs.claude-code.packages.${pkgs.system}.default
  ];
}
