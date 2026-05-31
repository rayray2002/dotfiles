{ ... }:
{
  imports = [ ./common.nix ];
  home.homeDirectory = "/home/ray";

  # Fresh/Nix-native machines use a clean root rather than a legacy miniforge3.
  home.sessionVariables.MAMBA_ROOT_PREFIX = "$HOME/micromamba";
}
