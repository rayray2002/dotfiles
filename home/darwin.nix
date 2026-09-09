{ lib, ... }:
{
  imports = [ ./common.nix ../modules/claude-auto-update-darwin.nix ];
  home.homeDirectory = "/Users/ray";

  home.sessionVariables = {
    MAMBA_ROOT_PREFIX = "/Users/ray/miniforge3";
  };

  programs.zsh.initContent = lib.mkOrder 1100 ''
    export MAMBA_ROOT_PREFIX="/Users/ray/miniforge3"
  '';
}
