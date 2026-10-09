# Slurm helpers for hosts with `slurm = { ... };` in hosts.nix (snoopy).
# Defaults (partition, QoS, CPUs and memory per GPU) come from there.
{ config, lib, pkgs, host, ... }:
let
  cfg = host.slurm or null;
  # Jobs start outside the rootless env, so an interactive job re-enters it.
  jobShell = if host.noRoot != null then "${host.noRoot.location}/bin/nixshell" else "$SHELL -l";

  # Per-GPU view built from Slurm's allocation data (works without GPU access,
  # e.g. on a login shell where nvidia-smi can't see the devices).
  gpus = pkgs.writeShellApplication {
    name = "gpus";
    runtimeInputs = [ pkgs.gawk pkgs.coreutils ];   # squeue/scontrol come from the system
    text = ''
      node=''${1:-$(sinfo -h -N -o %N | head -1)}
      ngpu=$(scontrol show node "$node" | grep -oE 'gres/gpu=[0-9]+' | head -1 | cut -d= -f2)
      scontrol show job -d 2>/dev/null | awk -v ngpu="''${ngpu:-0}" -v me="$USER" '
        function expand(list, out,   n, parts, i, r, a, b, k) {
          n = split(list, parts, ",")
          for (i = 1; i <= n; i++) {
            if (split(parts[i], r, "-") == 2) { a = r[1]; b = r[2] } else { a = b = parts[i] }
            for (k = a; k <= b; k++) out[k] = 1
          }
        }
        /^JobId=/   { split($1, f, "="); job = f[2]; user = ""; state = "" }
        /UserId=/   { match($0, /UserId=[^(]+/); user = substr($0, RSTART + 7, RLENGTH - 7) }
        /JobState=/ { match($0, /JobState=[A-Z_]+/); state = substr($0, RSTART + 9, RLENGTH - 9) }
        / GRES=/ && state == "RUNNING" {
          s = $0
          while (match(s, /(gpu|shard)(:[A-Za-z0-9_]+)?:[0-9]+\([^)]*\)/)) {
            g = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
            inner = g; sub(/^[^(]*\(/, "", inner); sub(/\)$/, "", inner)
            if (g ~ /^gpu/) {
              sub(/^IDX:/, "", inner); delete idx; expand(inner, idx)
              for (i in idx) { whole[i] = 1; who[i] = who[i] " " user ":" job }
            } else {
              n = split(inner, c, ",")
              for (i = 1; i <= n; i++) {
                split(c[i], uv, "/"); if (uv[1] > 0) { used[i-1] += uv[1]; cap[i-1] = uv[2]; who[i-1] = who[i-1] " " user ":" job "(" uv[1] ")" }
              }
            }
          }
        }
        END {
          printf "%-4s %-14s %s\n", "GPU", "status", "jobs (user:job)"
          for (i = 0; i < ngpu; i++) {
            if (whole[i]) st = "whole GPU"
            else if (used[i] > 0) st = sprintf("shards %d/%d", used[i], cap[i])
            else { st = "free"; free = free " " i; nfree++ }
            line = sprintf("%-4d %-14s%s", i, st, who[i])
            if (index(who[i], " " me ":")) line = line "  <- yours"
            print line
          }
          printf "\n%d of %d GPUs completely free:%s\n", nfree, ngpu, free
        }'
    '';
  };
in
lib.mkIf (cfg != null) {
  home.packages = [ gpus ];

  programs.zsh.shellAliases = {
    sq = "squeue -u $USER -o '%.8i %.11P %.24j %.2t %.10M %.10L %.14b %.4C %.7m %R'";
    sqa = "squeue -o '%.8i %.10u %.11P %.20j %.2t %.10M %.14b %R'";
    susers = "squeue -h -t R -o %u | sort | uniq -c | sort -rn";
    shist = "sacct -u $USER -S now-7days -X -o JobID,JobName%24,Partition,State,Elapsed,AllocTRES%45";
    sk = "scancel";
    swatch = "watch -n 10 -t \"squeue -u $USER -o '%.8i %.11P %.24j %.2t %.10M %.10L %.14b %R'\"";
  };

  programs.zsh.initContent = ''
    # sgpu [gpus=1] [time=4:00:00] [partition] [-- extra srun flags]
    # (partition defaults to ${cfg.partition} for one GPU, ${cfg.multiGpuPartition} for more)
    # Interactive shell on GPUs, inside this environment.
    sgpu() {
      local -a pos extra cmd qos; local a dash=0
      for a in "$@"; do
        if (( dash )); then extra+=("$a"); elif [[ $a == -- ]]; then dash=1; else pos+=("$a"); fi
      done
      local n=''${pos[1]:-1} t=''${pos[2]:-4:00:00} p=''${pos[3]:-}
      if (( n > ${toString cfg.maxGpus} )); then
        print "at most ${toString cfg.maxGpus} GPUs per user here"; return 1
      fi
      # ${cfg.partition} allows one GPU per job; more go to ${cfg.multiGpuPartition}
      [[ -z $p ]] && { (( n > 1 )) && p=${cfg.multiGpuPartition} || p=${cfg.partition}; }
      [[ $p == ${cfg.partition} && -n "${cfg.qos or ""}" ]] && qos=(--qos=${cfg.qos or ""})
      cmd=(srun -p $p $qos --gres=gpu:$n -c $(( n * ${toString cfg.cpusPerGpu} )) --mem=$(( n * ${toString cfg.memPerGpuGB} ))G
           -t $t -J interactive $extra --pty ${jobShell})
      print -P "%F{blue}''${(j: :)cmd}%f"
      $cmd
    }

    # slog [jobid] -- follow a job's log (default: your most recent job)
    slog() {
      local j=''${1:-$(squeue -h -u $USER -o %i --sort=-V | head -1)}
      [[ -z $j ]] && j=$(sacct -u $USER -X -n -o JobID -S now-2days | tail -1 | tr -d ' ')
      local f=$(scontrol show job $j 2>/dev/null | grep -oE 'StdOut=[^ ]+' | cut -d= -f2)
      [[ -z $f ]] && f=$(sacct -j $j -X -n -o StdOut%400 2>/dev/null | tr -d ' ')
      if [[ -r $f ]]; then print -P "%F{blue}$f%f"; tail -n 60 -f $f; else print "no readable log for job $j ($f)"; fi
    }

    # snew NAME -- start NAME.sbatch from the usual template (and a logs/ dir)
    snew() {
      local name=''${1:?usage: snew NAME}
      [[ -e $name.sbatch ]] && { print "$name.sbatch exists"; return 1; }
      mkdir -p logs
      cat > $name.sbatch <<EOF
    #!/bin/bash
    #SBATCH --job-name=$name
    #SBATCH --partition=${cfg.partition}
    ${lib.optionalString (cfg.qos or null != null) "#SBATCH --qos=${cfg.qos}\n"}#SBATCH --gres=gpu:1
    #SBATCH --cpus-per-task=${toString cfg.cpusPerGpu}
    #SBATCH --mem=${toString cfg.memPerGpuGB}G
    #SBATCH --time=1-00:00:00
    #SBATCH --output=$PWD/logs/%x_%j.log
    # submit: sbatch $name.sbatch   follow: slog   cancel: sk <jobid>
    set -eu
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}=${v}\n") (cfg.jobEnv or { }))}
    cd $PWD
    nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv
    # python -u train.py ...
    EOF
      print "wrote $name.sbatch (logs in ./logs)"
    }
  '';
}
