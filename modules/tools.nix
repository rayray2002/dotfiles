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

  # programs.zellij = {
  #   enable = true;
  #   enableZshIntegration = true;
  # };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
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
    # agentic-coding helpers
    ast-grep
    difftastic
    watchexec
    # nix
    nh                  # Clean Nix CLI wrapper
    nix-output-monitor  # Pretty build logs
  ] ++ [
    # AI agent CLI — auto-updating via the claude-code-nix flake input
    inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
