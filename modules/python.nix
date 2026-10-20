{ lib, pkgs, ... }:
let
  # nixpkgs' micromamba 2.9 is mamba-cpp behind a bash wrapper that (a) execs the
  # binary as `.mamba-wrapped`, a name micromamba rejects wherever it reads its own
  # path (`micromamba run`, the shell hook: "filename must be mamba or micromamba"),
  # and (b) forces CONDA_ENVS_PATH / CONDA_PKGS_DIRS to ~/.mamba, so envs ignore
  # MAMBA_ROOT_PREFIX. Ship the binary itself, named micromamba, without the wrapper.
  micromamba = pkgs.runCommand "micromamba-${pkgs.mamba-cpp.version}" { } ''
    install -Dm755 ${pkgs.mamba-cpp}/bin/.mamba-wrapped $out/bin/micromamba
  '';

  # Generated at build time: running `micromamba shell hook` cost 150-300 ms
  # per shell. It only embeds the micromamba path; MAMBA_ROOT_PREFIX is read
  # at runtime.
  mambaHook = pkgs.runCommand "micromamba-hook.zsh" { } ''
    HOME=$TMPDIR MAMBA_ROOT_PREFIX=$TMPDIR/mamba \
      ${micromamba}/bin/micromamba shell hook --shell zsh > $out
  '';
in
{
  home.packages = [
    pkgs.uv
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
