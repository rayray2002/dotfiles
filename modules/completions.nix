# Tab completion for the commands I use that zsh / home-manager don't cover.
#
# Search order (first match wins):
#   1. ours: zsh/completions/ (dots-secret, sgpu, slog), conda-zsh-completion
#      (conda, mamba, micromamba), Slurm's (sbatch, squeue, scontrol, ...) on
#      Slurm hosts
#   2. generated at first use for tools outside Nix that print their own
#      (docker, tailscale), cached in ~/.cache/zsh/completions and refreshed
#      when the tool is updated
#   3. the Nix profile's completions (gh, uv, codex, nh, ...) -- found through
#      $NIX_PROFILES only on some machines, so added explicitly
#   4. the system's: Ubuntu's vendor completions (systemctl, journalctl, ...),
#      Homebrew's on the Mac
{ config, lib, pkgs, inputs, host, ... }:
let
  # Slurm zsh completion contributed to SchedMD (bug 7786, never merged
  # upstream); covers sacct, salloc, sbatch, scancel, scontrol, sinfo, squeue,
  # srun, sstat, ...
  slurmCompletion = pkgs.fetchurl {
    name = "_slurm";
    url = "https://support.schedmd.com/attachment.cgi?id=11655";
    hash = "sha256-XoHEYG3BeGvfAy0YbxNCZD2II2S/b8ZPKRwmD+ZR4BU=";
  };

  ours = pkgs.runCommand "zsh-extra-completions" { } ''
    mkdir -p $out
    cp ${../zsh/completions}/_* $out/
    cp ${inputs.conda-zsh-completion}/_conda $out/
    ${lib.optionalString ((host.slurm or null) != null) "cp ${slurmCompletion} $out/_slurm"}
  '';

  # command -> arguments that make it print its zsh completion
  selfCompleting = { docker = "completion zsh"; tailscale = "completion zsh"; };

  systemDirs =
    if pkgs.stdenv.hostPlatform.isDarwin then [ "/opt/homebrew/share/zsh/site-functions" ]
    else [ "/usr/share/zsh/vendor-completions" "/usr/local/share/zsh/site-functions" ];
in
{
  # Runs before compinit (programs.zsh.completionInit is order 570).
  programs.zsh.initContent = lib.mkOrder 560 ''
    () {
      local cache=''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions cmd bin fresh=
      local -A gen=( ${lib.concatStringsSep " " (lib.mapAttrsToList (c: a: "${c} ${lib.escapeShellArg a}") selfCompleting)} )
      for cmd in ''${(k)gen}; do
        bin=''${commands[$cmd]}
        [[ -n $bin ]] || continue
        [[ -s $cache/_$cmd && $cache/_$cmd -nt $bin ]] && continue
        [[ -e $cache/.$cmd.failed && $cache/.$cmd.failed -nt $bin ]] && continue
        mkdir -p $cache
        if $bin ''${=gen[$cmd]} >| $cache/_$cmd.tmp 2>/dev/null && [[ -s $cache/_$cmd.tmp ]]; then
          mv -f $cache/_$cmd.tmp $cache/_$cmd; fresh=1
        else
          rm -f $cache/_$cmd.tmp; touch $cache/.$cmd.failed
        fi
      done
      # a new completion file needs a fresh dump to be picked up
      [[ -n $fresh ]] && rm -f ''${ZDOTDIR:-$HOME}/.zcompdump
      fpath=(${ours} $cache ${config.home.profileDirectory}/share/zsh/site-functions $fpath)
      local d
      for d in ${toString systemDirs}; do [[ -d $d ]] && fpath+=($d); done
    }
  '';
}
