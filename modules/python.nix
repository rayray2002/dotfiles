{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    uv
    micromamba
  ];

  # Point micromamba at the existing miniforge3 root so the pre-existing envs
  # (base, wam, telegram, ...) remain discoverable and `mamba activate <name>`
  # keeps working. New envs also land alongside them under ~/miniforge3/envs.
  home.sessionVariables.MAMBA_ROOT_PREFIX = "$HOME/miniforge3";

  programs.zsh.initContent = lib.mkOrder 1200 ''
    # micromamba (provides `micromamba activate <env>`; aliased to `mamba`).
    # The `mamba` alias must NOT exist when the hook is eval'd: the hook output
    # contains a literal `mamba()` definition that zsh refuses to parse while a
    # `mamba` alias is defined ("defining function based on alias"). So unalias
    # first, eval the hook, then (re)create the alias.
    unalias mamba 2>/dev/null
    eval "$(micromamba shell hook --shell zsh)"
    alias mamba=micromamba
  '';
}
