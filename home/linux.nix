{ ... }:
{
  imports = [ ./common.nix ];
  home.homeDirectory = "/home/ray";

  home.sessionVariables.MAMBA_ROOT_PREFIX = "$HOME/miniforge3";
}
