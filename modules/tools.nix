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
