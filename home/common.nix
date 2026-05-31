{ ... }:
{
  imports = [
    ../modules/tools.nix
    ../modules/zsh.nix
    ../modules/starship.nix
    ../modules/git.nix
    ../modules/python.nix
    ../modules/tmux.nix
  ];

  home.username = "ray";
  home.stateVersion = "25.05";

  # home-manager (master) currently reports a newer release than nixos-unstable;
  # the skew is expected on this channel combination, so silence the check.
  home.enableNixpkgsReleaseCheck = false;

  programs.home-manager.enable = true;
}
