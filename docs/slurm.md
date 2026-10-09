# Slurm (snoopy)

snoopy has 8× RTX A6000 (48 GB) under Slurm, shared with other users. Helpers are enabled
by `slurm = { ... };` in `hosts.nix` (`modules/slurm.nix`), which also holds their defaults.

## Commands

| Command | Does |
|---|---|
| `gpus` | each GPU: free, used whole, or how many of its 48 shards are used, and by whose job |
| `sgpu [n] [time] [partition] [-- srun flags]` | interactive shell on n GPUs (default 1, 4 h), inside your usual environment |
| `snew NAME` | `NAME.sbatch` from the usual template, plus a `logs/` dir |
| `sq` | your jobs (time used/left, GRES, reason when pending) |
| `sqa` / `susers` | all jobs / running jobs per user |
| `slog [job]` | follow a job's log (default: your latest job) |
| `shist` | your jobs of the last 7 days |
| `sk JOB` / `swatch` | cancel / watch your queue |

```bash
gpus                                     # 4 of 8 GPUs completely free: 0 1 2 3
sgpu                                     # 1 GPU, 16 CPUs, 96 GB, 4 h on phd
sgpu 2 8:00:00                           # 2 GPUs go to partition-1
sgpu 1 2:00:00 partition-1 -- --qos=shared
snew train && $EDITOR train.sbatch && sbatch train.sbatch && slog
```

## Limits

| | |
|---|---|
| `phd` partition, `phd` QoS | 1 GPU and 16 CPUs per job, 5 days |
| `partition-1` (default) | 3 GPUs per user, 7 days; QoS `scavenger` (preemptible) and `shared` exist |

`sgpu` picks `phd` for one GPU and `partition-1` for 2-3, and refuses more than 3.

## Notes

- `nvidia-smi` only sees GPUs inside a job (on the login shell it goes through an admin
  wrapper that needs sudo, which fails in the rootless env); `gpus` uses Slurm's own
  allocation data, so it works anywhere.
- Jobs start outside the rootless Nix env. `sgpu` re-enters it inside the job (GPU still
  visible there). Batch scripts should use absolute paths (conda/uv envs on `/scr`). A job
  submitted from inside the env inherits `HOME=/scr/borueihu/nixhome`.
- Keep data, checkpoints and caches on `/scr/borueihu`; the home directory has a ~15 GB
  quota. `HF_HOME=/scr/borueihu/cache/huggingface` (also set by `snew`'s template).
- Defaults (`partition`, `qos`, `cpusPerGpu`, `memPerGpuGB`, `multiGpuPartition`, `maxGpus`,
  `jobEnv`) are in `hosts.nix` under `slurm`.
