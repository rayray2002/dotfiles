# snoopy-only settings (from the former nix-borueihu-host branch). Rootless
# setup is in hosts.nix (noRoot) and modules/no-root.nix.
{ lib, ... }:
{
  # The existing miniforge install on /scr holds the envs (sam3d-objects, wam,
  # ...); $HOME is the separate nix-portable home, so name it absolutely.
  home.sessionVariables.MAMBA_ROOT_PREFIX = lib.mkForce "/scr/borueihu/miniforge3";

  # Hugging Face cache (and token) on /scr, as the job scripts expect.
  home.sessionVariables.HF_HOME = "/scr/borueihu/cache/huggingface";

  # Claude Code in auto permission mode here instead of skipping permissions.
  programs.zsh.shellAliases.c = lib.mkForce "claude --permission-mode auto";
}
