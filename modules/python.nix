{ lib, pkgs, ... }:
let
  # Generated at build time: running `micromamba shell hook` cost 150-300 ms
  # per shell. It only embeds the micromamba path; MAMBA_ROOT_PREFIX is read
  # at runtime.
  mambaHook = pkgs.runCommand "micromamba-hook.zsh" { } ''
    # micromamba 2.9 is mamba-cpp behind a wrapper, and the hook records the
    # wrapped binary (.mamba-wrapped), whose name it then rejects ("filename
    # must be mamba or micromamba"). Point it at the wrapper instead.
    HOME=$TMPDIR MAMBA_ROOT_PREFIX=$TMPDIR/mamba \
      ${pkgs.micromamba}/bin/micromamba shell hook --shell zsh \
      | sed -E 's#/nix/store/[^"]*/bin/\.mamba-wrapped#${pkgs.micromamba}/bin/micromamba#g' > $out
    if grep -q mamba-wrapped $out; then echo "micromamba hook still names the wrapped binary" >&2; exit 1; fi
  '';
in
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
    source ${mambaHook}
    alias mamba=micromamba
  '';
}
