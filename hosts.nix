# Every machine that runs this flake. The attribute name is the machine's ssh
# alias (ssh/config) and its flake target is "<user>@<name>". dots-sync and the
# auto-sync timer (modules/dots-sync.nix) are generated from this list.
# noRoot.store: no root on that machine; Nix runs in a user namespace with
# that directory mounted at /nix (modules/no-root.nix, scripts/bootstrap-no-root).
{
  mac         = { system = "aarch64-darwin"; user = "ray"; };
  ray-desktop = { system = "x86_64-linux";   user = "ray"; };
  snoopy      = { system = "x86_64-linux";   user = "borueihu";
                  noRoot.store = "/scr/borueihu/nix"; };  # /home has a ~15 GB quota
  xarm        = { system = "x86_64-linux";   user = "ray"; };  # tailnet name: salep
}
