{ ... }:
{
  imports = [ ./common.nix ../modules/claude-auto-update.nix ];
  home.homeDirectory = "/home/ray";

  home.sessionVariables.MAMBA_ROOT_PREFIX = "$HOME/miniforge3";
}
