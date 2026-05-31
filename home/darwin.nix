{ ... }:
{
  imports = [ ./common.nix ];
  home.homeDirectory = "/Users/ray";

  # This mac predates the Nix setup and already has a populated miniforge3 root
  # (base, wam, telegram, ...). Point micromamba at it so those envs keep working.
  home.sessionVariables.MAMBA_ROOT_PREFIX = "$HOME/miniforge3";
}
