{ host, ... }:
{
  imports = [
    ../modules/tools.nix
    ../modules/zsh.nix
    ../modules/theme.nix
    ../modules/starship.nix
    ../modules/git.nix
    ../modules/python.nix
    ../modules/tmux.nix
    ../modules/ssh.nix
    ../modules/dots-sync.nix
    ../modules/no-root.nix
  ];

  home.username = host.user;
  home.stateVersion = "25.05";

  # home-manager (master) currently reports a newer release than nixos-unstable;
  # the skew is expected on this channel combination, so silence the check.
  home.enableNixpkgsReleaseCheck = false;

  programs.home-manager.enable = true;

  # Every dots-sync that brings a change adds a generation; drop the ones
  # older than two weeks (and the store paths only they used) once a week.
  # Not on rootless hosts: there nix-portable's own Nix lives in the store too,
  # and their store sits on a large scratch disk anyway.
  nix.gc = {
    automatic = host.noRoot == null;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
