{ ... }:
{
  imports = [
    ../modules/tools.nix
    ../modules/zsh.nix
    ../modules/starship.nix
    ../modules/git.nix
    ../modules/python.nix
  ];

  home.username = "ray";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
