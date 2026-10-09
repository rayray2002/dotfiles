{ host, ... }:
{
  imports = [ ./common.nix ];
  home.homeDirectory = "/home/${host.user}";

  home.sessionVariables.MAMBA_ROOT_PREFIX = "$HOME/miniforge3";
}
