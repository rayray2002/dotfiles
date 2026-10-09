# Tab completion for the commands I use that zsh / home-manager don't cover.
#
# Search order (first match wins):
#   1. generated at first use for tools outside Nix that print their own
#      (docker, tailscale), cached in ~/.cache/zsh/completions and refreshed
#      when the tool is updated
#   2. the Nix profile's: every package's (gh, uv, codex, nh, ...) and ours from
#      zsh/completions/ (dots-secret, sgpu, slog), conda-zsh-completion (conda,
#      mamba, micromamba) and Slurm's (sbatch, squeue, ...) on Slurm hosts.
#      Found through $NIX_PROFILES only on some machines, so added explicitly.
#   3. the system's: Ubuntu's vendor completions (systemctl, journalctl, ...),
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

  # Installed into the profile like any package's completions (a bare
  # /nix/store path in $fpath makes compinit flag /nix/store as insecure).
  ours = pkgs.runCommand "zsh-extra-completions" { } ''
    d=$out/share/zsh/site-functions
    mkdir -p $d
    cp ${../zsh/completions}/_* $d/
    # conda-zsh-completion finds envs via $CONDA_EXE, which only conda's own
    # hook sets: use $MAMBA_ROOT_PREFIX (micromamba) first. And list them with
    # the real ls, not an `ls` alias (eza --icons here).
    cp ${inputs.conda-zsh-completion}/_conda $d/_conda
    chmod u+w $d/_conda
    substituteInPlace $d/_conda \
      --replace-fail 'conda_path="''${''${CONDA_EXE}%bin/conda}/envs"' \
                     'conda_path="''${MAMBA_ROOT_PREFIX:-''${CONDA_EXE%bin/conda}}/envs"' \
      --replace-fail '&& ls $ls_opts' '&& command ls $ls_opts'
    ${lib.optionalString ((host.slurm or null) != null) "cp ${slurmCompletion} $d/_slurm"}
  '';

  # command -> arguments that make it print its zsh completion
  selfCompleting = { docker = "completion zsh"; tailscale = "completion zsh"; };

  systemDirs =
    if pkgs.stdenv.hostPlatform.isDarwin then [ "/opt/homebrew/share/zsh/site-functions" ]
    else [ "/usr/share/zsh/vendor-completions" "/usr/local/share/zsh/site-functions" ];
in
{
  home.packages = [ ours ];

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
      fpath=($cache ${config.home.profileDirectory}/share/zsh/site-functions $fpath)
      local d
      for d in ${toString systemDirs}; do [[ -d $d ]] && fpath+=($d); done
    }
  '';
}
