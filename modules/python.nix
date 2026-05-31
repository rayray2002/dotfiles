{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    uv
    micromamba
  ];

  home.sessionVariables.MAMBA_ROOT_PREFIX = "$HOME/micromamba";

  programs.zsh.initContent = lib.mkOrder 1200 ''
    # micromamba (provides `micromamba activate <env>`; aliased to `mamba`)
    eval "$(micromamba shell hook --shell zsh)"
  '';
}
