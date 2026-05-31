{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    uv
    micromamba
  ];

  # MAMBA_ROOT_PREFIX is intentionally NOT set here — it is host-specific and
  # lives in home/{darwin,linux}.nix. This mac keeps a legacy ~/miniforge3 root
  # full of existing envs; a fresh machine should use a clean Nix-native root.

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
