# snoopy-only settings (from the former nix-borueihu-host branch). Rootless
# setup is in hosts.nix (noRoot) and modules/no-root.nix.
{ lib, ... }:
{
  # Fresh Nix-native micromamba root inside the nix-portable home.
  home.sessionVariables.MAMBA_ROOT_PREFIX = lib.mkForce "$HOME/micromamba";

  # Claude Code in auto permission mode here instead of skipping permissions.
  programs.zsh.shellAliases.c = lib.mkForce "claude --permission-mode auto";
}
