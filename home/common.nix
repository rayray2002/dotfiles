{ ... }:
{
  imports = [
    ../modules/tools.nix
    ../modules/zsh.nix
  ];

  home.username = "ray";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
