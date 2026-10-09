# Every machine that runs this flake. The attribute name is the machine's ssh
# alias (ssh/config) and its flake target is "<user>@<name>". dots-sync and the
# auto-sync timer (modules/dots-sync.nix) are generated from this list.
# noRoot: no root on that machine. Nix runs through nix-portable with its store
# under `location`; home-manager activates into `home` instead of the real home;
# `flake` is the checkout used there (modules/no-root.nix, scripts/bootstrap-no-root).
{
  mac         = { system = "aarch64-darwin"; user = "ray"; };
  ray-desktop = { system = "x86_64-linux";   user = "ray"; };
  snoopy      = { system = "x86_64-linux";   user = "borueihu";
                  noRoot = {                      # /home has a ~15 GB quota
                    location = "/scr/borueihu";
                    home = "/scr/borueihu/nixhome";
                    flake = "/scr/borueihu/dotfiles-nix";
                  }; };
  xarm        = { system = "x86_64-linux";   user = "ray"; };  # tailnet name: salep
}
