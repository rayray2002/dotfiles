# Every machine that runs this flake. The attribute name is the machine's ssh
# alias (ssh/config) and its flake target is "<user>@<name>". dots-sync and the
# auto-sync timer (modules/dots-sync.nix) are generated from this list.
# noRoot: no root on that machine. Nix runs through nix-portable with its store
# under `location`; home-manager activates into `home` instead of the real home;
# `flake` is the checkout used there (modules/no-root.nix, scripts/bootstrap-no-root).
# slurm: Slurm helpers and their defaults (modules/slurm.nix).
{
  mac         = { system = "aarch64-darwin"; user = "ray"; };
  ray-desktop = { system = "x86_64-linux";   user = "ray"; };
  snoopy      = { system = "x86_64-linux";   user = "borueihu";
                  noRoot = {                      # /home has a ~15 GB quota
                    location = "/scr/borueihu";
                    home = "/scr/borueihu/nixhome";
                    flake = "/scr/borueihu/dotfiles-nix";
                  };
                  # 8x RTX A6000 under Slurm (modules/slurm.nix): sgpu / snew defaults
                  slurm = {
                    partition = "phd";
                    qos = "phd";                  # phd QoS: 1 GPU, 16 CPUs per job
                    multiGpuPartition = "partition-1";
                    maxGpus = 3;                  # per-user cap on partition-1
                    cpusPerGpu = 16;
                    memPerGpuGB = 96;
                    jobEnv.HF_HOME = "/scr/borueihu/cache/huggingface";
                  }; };
  xarm        = { system = "x86_64-linux";   user = "ray"; };  # tailnet name: salep
  # Franka/Panda workstation (glamor-citrine); single-user Nix owned by ray.
  # The other login on it, glamor_panda_shared, is a shared lab account: not managed.
  glamor_panda_ray = { system = "x86_64-linux"; user = "ray"; };
}
